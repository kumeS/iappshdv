#!/usr/bin/env bash
# ============================================================
# verify_code_quality.sh (v36 – Homebrew パッケージインストール・互換性強化)
#   - 重複コード検出 (jscpd：コンソール出力のみ)
#   - コード整形 (swiftformat：デフォルト設定を使用)
#   - 静的解析 (swiftlint：違反件数を警告表示、詳細オフ)
#   - ファイル行数統計 (長いファイルの特定)
#   - サイクロマティック複雑度 (swiftlint：複雑度チェックに代用) ※swift-complexityの代わり
#   - 未使用コード解析 (periphery：使用されていないコードの検出)
#   - IPAサイズチェック (基準値との比較)
#   - シンボルUUID重複確認 (dwarf情報の検証)
#   - 依存パッケージ脆弱性検査 (osv-scanner：セキュリティ脆弱性検出)
#   - ライセンス互換性チェック (licenseplist：GPL系ライセンス検出)
#   - 依存ライブラリ更新状況 (CocoaPods/SwiftPM：メジャーバージョン更新検出)
#   ※ 全フェーズ実行 → 最終サマリ & exit code
# Usage: verify_code_quality.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
# ============================================================

IFS=$'\n\t'
# 古いbashとの互換性のため、-uを外す
set -eo pipefail

# --- 引数チェック & ディレクトリ移動 ------------------------
SILENT_MODE=0
AUTO_YES=0
UPDATE_DEPS=0
PROJECT_DIR=""
IPA_PATH=""
BASELINE_MB=""

# 引数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--silent)
      SILENT_MODE=1
      shift
      ;;
    -y|--yes)
      AUTO_YES=1
      shift
      ;;
    -u|--update-deps)
      UPDATE_DEPS=1
      shift
      ;;
    -*)
      echo "Error: Unknown option $1"
      echo "Usage: $0 <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]"
      exit 1
      ;;
    *)
      if [[ -z "$PROJECT_DIR" ]]; then
        PROJECT_DIR="$1"
      elif [[ -z "$IPA_PATH" ]]; then
        IPA_PATH="$1"
      elif [[ -z "$BASELINE_MB" ]]; then
        BASELINE_MB="$1"
      else
        echo "Error: Too many arguments"
        echo "Usage: $0 <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_DIR" ]]; then
  echo "Usage: $0 <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]"
  exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: Directory '$PROJECT_DIR' not found."
  exit 1
fi
cd "$PROJECT_DIR"

# --- Config ------------------------------------------------
# 重複コードの許容閾値（この数値以下なら警告のみ）
JSC_PD_THRESHOLD=20

# ログディレクトリ（テンポラリファイル用）
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

ERRORS=()
WARNINGS=()

# スキップ状態を示す変数の初期化
complexity_skip=1
unused_skip=1
ipa_check_skip=1
uuid_check_skip=1
osv_scan_skip=1
license_check_skip=1
cocoapods_check_skip=1
swiftpm_check_skip=1

# 連想配列の代わりに通常の配列+関数で実装
# パッケージ名一覧
PACKAGES=("periphery" "osv-scanner" "license-plist" "pod")
# Brew名取得関数
get_brew_package() {
  local cmd="$1"
  case "$cmd" in
    periphery) echo "periphery" ;;
    osv-scanner) echo "osv-scanner" ;;
    license-plist) echo "licenseplist" ;;
    pod) echo "cocoapods" ;;
    *) echo "" ;;
  esac
}

# 推奨バージョン取得関数
get_recommended_version() {
  local cmd="$1"
  case "$cmd" in
    periphery) echo "2.12.0" ;;
    osv-scanner) echo "1.3.6" ;;
    license-plist) echo "3.24.6" ;;
    pod) echo "1.12.1" ;;
    *) echo "" ;;
  esac
}

# --- Helpers ----------------------------------------------
step(){ 
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\n\033[1;34m▶ %s\033[0m\n" "$*"
  fi
}
ok(){ 
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\033[0;32m[OK]\033[0m  %s\n" "$*"
  fi
}
warn(){ 
  WARNINGS+=("$*")
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\033[1;33m[WARN]\033[0m %s\n" "$*"
  fi
}
ng(){ 
  ERRORS+=("$*")
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\033[0;31m[NG]\033[0m  %s\n" "$*"
  fi
}
info(){ 
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\033[0;36m[INFO]\033[0m %s\n" "$*"
  fi
}
debug(){ 
  if [[ $SILENT_MODE -eq 0 ]]; then
    printf "\033[0;36m[DEBUG]\033[0m %s\n" "$*"
  fi
}

# Homebrewのインストール確認
check_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrewがインストールされていません。"
    echo "https://brew.sh/ からインストールしてください。"
    return 1
  fi
  return 0
}

# パッケージのバージョン取得
get_package_version() {
  local cmd="$1"
  local version=""
  
  # コマンドがnullまたは空の場合
  [[ -z "$cmd" ]] && return 1
  
  # コマンドが存在しない場合
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo ""
    return 1
  fi
  
  case "$cmd" in
    periphery)
      version=$(periphery version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
      ;;
    osv-scanner)
      version=$(osv-scanner --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
      ;;
    license-plist)
      version=$(license-plist --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
      ;;
    pod)
      version=$(pod --version 2>/dev/null || echo "")
      ;;
    *)
      version=""
      ;;
  esac
  
  echo "${version:-0.0.0}"
}

# バージョン比較
version_lt() {
  # v1 < v2 なら 0、そうでなければ 1 を返す
  local v1="$1"
  local v2="$2"
  
  # 空の値処理
  [[ -z "$v1" || -z "$v2" ]] && return 1
  
  # パッケージが新しい、または同じバージョンならfalse(1)を返す
  [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | head -n1)" != "$v2" ]]
}

# パッケージのインストール確認と必要に応じてインストール
install_package() {
  local cmd="$1"
  local brew_pkg=$(get_brew_package "$cmd")
  local recommended_version=$(get_recommended_version "$cmd")
  
  if [[ -z "$brew_pkg" ]]; then
    info "$cmd のHomebrew情報がありません"
    return 1
  fi
  
  # パッケージが既にインストールされているか確認
  if command -v "$cmd" >/dev/null 2>&1; then
    # バージョン確認とアップデート
    if [[ $UPDATE_DEPS -eq 1 && -n "$recommended_version" ]]; then
      local current_version=""
      current_version=$(get_package_version "$cmd")
      
      if [[ -n "$current_version" ]]; then
        if version_lt "$current_version" "$recommended_version"; then
          info "$cmd の現在のバージョン $current_version は推奨バージョン $recommended_version より古いです"
          
          if [[ $AUTO_YES -eq 1 ]]; then
            info "パッケージ $brew_pkg を更新します..."
            brew upgrade "$brew_pkg" || brew install "$brew_pkg"
            return $?
          else
            read -p "パッケージ $cmd を更新しますか？ (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              info "パッケージ $brew_pkg を更新します..."
              brew upgrade "$brew_pkg" || brew install "$brew_pkg"
              return $?
            fi
          fi
        else
          info "$cmd のバージョン $current_version は最新です"
        fi
      fi
    fi
    return 0
  fi
  
  # パッケージがインストールされていない場合
  if [[ $AUTO_YES -eq 1 ]]; then
    info "パッケージ $brew_pkg をインストールします..."
    brew install "$brew_pkg"
    if [[ $? -eq 0 ]]; then
      ok "$brew_pkg のインストールに成功しました"
      return 0
    else
      warn "$brew_pkg のインストールに失敗しました"
      return 1
    fi
  else
    read -p "パッケージ $cmd が見つかりません。Homebrewで $brew_pkg をインストールしますか？ (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      info "パッケージ $brew_pkg をインストールします..."
      if brew install "$brew_pkg"; then
        ok "$brew_pkg のインストールに成功しました"
        return 0
      else
        warn "$brew_pkg のインストールに失敗しました"
        return 1
      fi
    fi
  fi
  
  return 1
}

# --- 1) Dependencies --------------------------------------
step "依存ツール確認"
MISSING_DEPS=0
for cmd in swiftlint swiftformat jscpd jq grep find wc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    ng "missing dependency: $cmd"
    MISSING_DEPS=1
  fi
done

if [[ $MISSING_DEPS -eq 1 ]]; then
  warn "一部の依存ツールが見つかりません。該当する検証はスキップされます。"
fi

# --- 追加ツール確認 ----------------------------------------
step "追加ツール存在確認"
INSTALLED_PACKAGES=()
UPDATED_PACKAGES=()

for cmd in "${PACKAGES[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    info "missing dependency: $cmd"
    
    # Homebrewが利用可能かチェック
    if check_brew; then
      info "Homebrewを使用してインストールを試みます..."
      if install_package "$cmd"; then
        INSTALLED_PACKAGES+=("$cmd")
        info "$cmd のインストールに成功しました"
      else
        info "$cmd インストールをスキップしました。該当チェックは実行されません。"
      fi
    else
      info "Homebrewが見つからないため、$cmd のインストールをスキップします"
    fi
  elif [[ $UPDATE_DEPS -eq 1 ]]; then
    # 既存パッケージの更新チェック
    local current_version=""
    current_version=$(get_package_version "$cmd")
    
    # 推奨バージョン取得
    local recommended_version=$(get_recommended_version "$cmd")
    
    if [[ -n "$current_version" && -n "$recommended_version" ]]; then
      # バージョン比較
      if version_lt "$current_version" "$recommended_version"; then
        info "$cmd 更新チェック: $current_version → $recommended_version"
        if install_package "$cmd"; then
          UPDATED_PACKAGES+=("$cmd")
        fi
      else
        info "$cmd は最新バージョンです ($current_version)"
      fi
    elif [[ -n "$current_version" ]]; then
      info "$cmd のバージョンは $current_version ですが、推奨バージョンが未定義です"
    fi
  fi
done

# 新しくインストールされたパッケージがあれば表示
if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
  ok "インストールされた追加パッケージ: ${INSTALLED_PACKAGES[*]}"
fi

# 更新されたパッケージがあれば表示
if [[ ${#UPDATED_PACKAGES[@]} -gt 0 ]]; then
  ok "更新された追加パッケージ: ${UPDATED_PACKAGES[*]}"
fi

# --- 2) Duplication Check ---------------------------------
step "jscpd による重複コード検出"
# JSONレポートを一時ディレクトリに保存し、終了時に削除
TMP_JSON="$LOG_DIR/jscpd-report.json"

# コンソール出力のみを使用し、一時ファイルを後で削除
set +e
if [[ $SILENT_MODE -eq 1 ]]; then
  jscpd --min-lines 30 --reporters console --output "$LOG_DIR" . > "$LOG_DIR/jscpd-output.txt" 2>&1
else
  jscpd --min-lines 30 --reporters console --output "$LOG_DIR" . | tee "$LOG_DIR/jscpd-output.txt"
fi
JSCPD_EXIT=$?
set -e

# jscpdの出力から重複コード数を抽出
if [[ $JSCPD_EXIT -eq 0 ]]; then
  # 複数の出力パターンに対応
  if grep -q "Found [0-9]* clones\." "$LOG_DIR/jscpd-output.txt"; then
    dup_cnt=$(grep -o "Found [0-9]* clones\." "$LOG_DIR/jscpd-output.txt" | grep -o '[0-9]*' || echo "0")
  elif grep -q "Clones found:" "$LOG_DIR/jscpd-output.txt"; then
    dup_cnt=$(grep -o "Clones found: [0-9]*" "$LOG_DIR/jscpd-output.txt" | grep -o '[0-9]*' || echo "0")
  elif grep -q "Found [0-9]* clones" "$LOG_DIR/jscpd-output.txt"; then
    # "Found X clones" パターンに対応（末尾のピリオドなし）
    dup_cnt=$(grep -o "Found [0-9]* clones" "$LOG_DIR/jscpd-output.txt" | grep -o '[0-9]*' || echo "0")
  else
    # Clone found の行数をカウント
    dup_cnt=$(grep -c "Clone found" "$LOG_DIR/jscpd-output.txt" || echo "0")
  fi
  
  # 空文字列や非数値をチェック
  if [[ ! "$dup_cnt" =~ ^[0-9]+$ ]]; then
    dup_cnt=0
  fi
  
  if [ "$dup_cnt" -gt "$JSC_PD_THRESHOLD" ]; then
    ng "重複コード検出 ($dup_cnt 件) - 閾値 $JSC_PD_THRESHOLD 超過"
  elif [ "$dup_cnt" -gt 0 ]; then
    warn "重複コード検出 ($dup_cnt 件) - 閾値 $JSC_PD_THRESHOLD 以内"
  else
    ok "重複コードなし"
  fi
else
  dup_cnt=0
  ng "jscpd 実行エラー"
fi

# --- 3) SwiftFormat ---------------------------------------
step "swiftformat 実行 (デフォルト設定を使用)"
# 設定ファイルが存在する場合は一時的に退避
SWIFTFORMAT_CONFIG=".swiftformat"
SWIFTFORMAT_CONFIG_BACKUP="${SWIFTFORMAT_CONFIG}.backup"

if [[ -f "$SWIFTFORMAT_CONFIG" ]]; then
  mv "$SWIFTFORMAT_CONFIG" "$SWIFTFORMAT_CONFIG_BACKUP"
fi

# maxwidthオプションを使用して行の長さを指定
set +e
swiftformat . --swiftversion 5.9 --maxwidth 100 --quiet 2> "$LOG_DIR/swiftformat-errors.txt"
fmt_exit=$?
set -e

# 設定ファイルを元に戻す
if [[ -f "$SWIFTFORMAT_CONFIG_BACKUP" ]]; then
  mv "$SWIFTFORMAT_CONFIG_BACKUP" "$SWIFTFORMAT_CONFIG"
fi

if [[ $fmt_exit -eq 0 ]]; then
  fmt_err=0
  ok "swiftformat 完了"
else
  fmt_err=1
  ng "swiftformat エラー"
  # エラーの内容を表示
  if [[ $SILENT_MODE -eq 0 && -s "$LOG_DIR/swiftformat-errors.txt" ]]; then
    cat "$LOG_DIR/swiftformat-errors.txt"
  fi
fi

# --- 4) SwiftLint -----------------------------------------
step "SwiftLint 実行 (警告扱い、詳細オフ)"
set +e
SL_OUTPUT=$(swiftlint lint --quiet 2>"$LOG_DIR/swiftlint-errors.txt" || echo "")
SL_EXIT=$?
set -e

# エラーがあれば表示
if [[ $SILENT_MODE -eq 0 && -s "$LOG_DIR/swiftlint-errors.txt" ]]; then
  cat "$LOG_DIR/swiftlint-errors.txt"
fi

# .swiftlint.yml が存在しない場合も動作するように
if [[ $SL_EXIT -eq 0 || $SL_EXIT -eq 1 ]]; then
  # 出力が空でなければ違反があると判断
  if [[ -n "$SL_OUTPUT" ]]; then
    # 出力が JSON 形式かどうかを安全に確認
    if echo "$SL_OUTPUT" | grep -q '^[\[\{]' && echo "$SL_OUTPUT" | jq . >/dev/null 2>&1; then
      # JSON形式の場合
      sl_cnt=$(echo "$SL_OUTPUT" | jq 'length')
    else
      # JSON形式でない場合は行数をカウント
      sl_cnt=$(echo "$SL_OUTPUT" | grep -v '^$' | wc -l)
      sl_cnt=$(echo "$sl_cnt" | tr -d ' ')
    fi
  else
    sl_cnt=0
  fi
  
  if [[ $sl_cnt -eq 0 ]]; then
    ok "SwiftLint違反なし"
  else
    warn "SwiftLint違反 $sl_cnt 件"
    
    # 出力の形式に応じて表示
    if [[ $SILENT_MODE -eq 0 ]]; then
      if echo "$SL_OUTPUT" | grep -q '^[\[\{]' && echo "$SL_OUTPUT" | jq . >/dev/null 2>&1; then
        # JSON形式の場合
        echo "$SL_OUTPUT" | jq -r 'if type=="array" and length > 0 then .[0:10] | .[] | "\(.file):\(.line):\(.column): \(.reason)" else empty end' 2>/dev/null || echo "$SL_OUTPUT" | head -10
        if (( sl_cnt > 10 )); then
          echo "... 他 $(( sl_cnt - 10 )) 件"
        fi
      else
        # 通常出力の場合
        echo "$SL_OUTPUT" | head -10
        if (( sl_cnt > 10 )); then
          echo "... 他 $(( sl_cnt - 10 )) 件"
        fi
      fi
    fi
  fi
else
  sl_cnt=0
  warn "SwiftLint 実行エラーまたは設定ファイルがありません"
fi

# --- 5) ファイル行数統計 ----------------------------------
step "ファイル行数統計"
if [[ $SILENT_MODE -eq 0 ]]; then
  echo "Swift ファイル行数統計:"
  find . -name "*.swift" -not -path "*/\.build/*" -not -path "*/\Pods/*" -not -path "*/\build/*" -exec wc -l {} \; | sort -nr | head -10
fi

total_lines=$(find . -name "*.swift" -not -path "*/\.build/*" -not -path "*/\Pods/*" -not -path "*/\build/*" -exec cat {} \; | wc -l)
total_lines=$(echo "$total_lines" | tr -d ' ')
if [[ $SILENT_MODE -eq 0 ]]; then
  echo "合計行数: $total_lines"
fi

# --- 6) サイクロマティック複雑度 ------------------------------------
if command -v swiftlint >/dev/null 2>&1; then
  step "Cyclomatic Complexity (swiftlint)"
  complexity_skip=0
  CC_TMP=$(mktemp)
  # swiftlintでは直接複雑度のみ抽出するオプションがないので、通常のlintで複雑度違反をチェック
  swiftlint lint --quiet --only cyclomatic_complexity >"$CC_TMP" 2>/dev/null || true
  # 出力例: /path/to/file.swift:123:45: warning: Cyclomatic Complexity Violation: Function should have complexity 10 or less; currently complexity is 15 (cyclomatic_complexity)
  over_cnt=$(grep -c "Cyclomatic Complexity Violation:" "$CC_TMP" || echo 0)
  
  # 空文字列や非数値をチェック
  if [[ ! "$over_cnt" =~ ^[0-9]+$ ]]; then
    over_cnt=0
  fi
  
  if [ "$over_cnt" -gt 0 ]; then
    warn "複雑度 >10 の関数が $over_cnt 件見つかりました"
    if [[ $SILENT_MODE -eq 0 ]]; then
      grep "Cyclomatic Complexity Violation:" "$CC_TMP" | head -10
      if [ "$over_cnt" -gt 10 ]; then
        echo "... 他 $(( over_cnt - 10 )) 件"
      fi
    fi
  else
    ok "複雑度 OK (≤10)"
  fi
  rm "$CC_TMP"
else
  complexity_skip=1
  step "Cyclomatic Complexity (swiftlint)"
  info "swiftlint が見つからないためスキップします"
fi

# --- 7) 未使用コード・シンボル ---------------------------------------
if command -v periphery >/dev/null 2>&1; then
  step "Periphery (未使用コード解析)"
  unused_skip=0
  PERI_TMP=$(mktemp)
  # --strict でエラー終了するが、結果を取りたいので || true
  periphery scan --format text --workspace $(ls *.xcworkspace 2>/dev/null | head -1) --schemes $(xcodebuild -list -json | jq -r '.workspace.schemes[0]') >"$PERI_TMP" 2>/dev/null || true
  unused_cnt=$(grep -c "Unused" "$PERI_TMP" || echo 0)
  # 空文字列や非数値をチェック
  if [[ ! "$unused_cnt" =~ ^[0-9]+$ ]]; then
    unused_cnt=0
  fi
  
  if [ "$unused_cnt" -gt 0 ]; then
    warn "未使用コード/シンボル $unused_cnt 箇所"
    if [[ $SILENT_MODE -eq 0 ]]; then
      grep "Unused" "$PERI_TMP" | head -10
      if [ "$unused_cnt" -gt 10 ]; then
        echo "... 他 $(( unused_cnt - 10 )) 件"
      fi
    fi
  else
    ok "未使用コードなし"
  fi
  rm "$PERI_TMP"
else
  unused_skip=1
  step "Periphery (未使用コード解析)"
  info "periphery が見つからないためスキップします"
fi

# --- 8) IPA サイズ ----------------------------------------------------
if [[ -n "$IPA_PATH" && -f "$IPA_PATH" ]]; then
  step "IPA サイズチェック"
  ipa_check_skip=0
  ipa_mb=$(du -m "$IPA_PATH" | awk '{print $1}')
  if [[ $SILENT_MODE -eq 0 ]]; then
    echo "現在の IPA サイズ: ${ipa_mb}MB"
  fi
  if [[ -n "$BASELINE_MB" ]]; then
    # 数値チェック
    if [[ ! "$ipa_mb" =~ ^[0-9]+$ ]]; then
      ipa_mb=0
    fi
    if [[ ! "$BASELINE_MB" =~ ^[0-9]+$ ]]; then
      BASELINE_MB=0
    fi
    
    delta=$(( ipa_mb - BASELINE_MB ))
    if [ "$delta" -gt 5 ]; then
      warn "IPA サイズが基準より ${delta}MB 大きい (許容5MB)"
    else
      ok "IPA サイズ増分 OK (+${delta}MB)"
    fi
  fi
else
  ipa_check_skip=1
  step "IPA サイズチェック"
  info "IPA ファイルパスが指定されていないためスキップします"
fi

# --- 9) UUID シンボル重複 / Swift バージョン --------------------------
# 対象バイナリをビルド済み Debug-iphoneos/<App>.app/<App>
APP_BINARY=$(find build -name "*.app" -type d -maxdepth 2 2>/dev/null | head -1)
if [[ -n "$APP_BINARY" ]]; then
  step "dwarfdump --uuid (シンボル UUID 重複確認)"
  uuid_check_skip=0
  uuids=$(dwarfdump --uuid "$APP_BINARY/$(basename "$APP_BINARY" .app)" | awk '{print $2}')
  dup=$(echo "$uuids" | sort | uniq -d)
  if [[ -n "$dup" ]]; then
    warn "UUID 重複/競合の可能性: $dup"
  else
    ok "UUID 衝突なし"
  fi
else
  uuid_check_skip=1
  step "dwarfdump --uuid (シンボル UUID 重複確認)"
  info "ビルド済みアプリバイナリが見つからないためスキップします"
fi

# --- 10) 依存パッケージ脆弱性 (osv-scanner) ---------------------------
if command -v osv-scanner >/dev/null 2>&1 && [[ -f Podfile.lock || -f Package.resolved ]]; then
  step "osv-scanner 依存脆弱性チェック"
  osv_scan_skip=0
  OSV_TMP=$(mktemp)
  if [[ -f Podfile.lock ]]; then
    osv-scanner --lockfile Podfile.lock >"$OSV_TMP" 2>/dev/null || true
  else
    osv-scanner --lockfile Package.resolved >"$OSV_TMP" 2>/dev/null || true
  fi
  critical_cnt=$(grep -ci '"critical"' "$OSV_TMP" || echo 0)
  high_cnt=$(grep -ci '"high"' "$OSV_TMP" || echo 0)
  
  # 空文字列や非数値をチェック
  if [[ ! "$critical_cnt" =~ ^[0-9]+$ ]]; then
    critical_cnt=0
  fi
  if [[ ! "$high_cnt" =~ ^[0-9]+$ ]]; then
    high_cnt=0
  fi
  
  if [ "$critical_cnt" -gt 0 ] || [ "$high_cnt" -gt 0 ]; then
    warn "高～致命的脆弱性: critical=$critical_cnt, high=$high_cnt"
  else
    ok "高深刻度脆弱性なし"
  fi
  rm "$OSV_TMP"
else
  osv_scan_skip=1
  step "osv-scanner 依存脆弱性チェック"
  if ! command -v osv-scanner >/dev/null 2>&1; then
    info "osv-scanner が見つからないためスキップします"
  else
    info "依存関係ロックファイルが見つからないためスキップします"
  fi
fi

# --- 11) ライセンス互換性 (license-plist) -----------------------------
if command -v license-plist >/dev/null 2>&1; then
  step "license-plist (ライセンスチェック)"
  license_check_skip=0
  LICENSE_DIR=$(mktemp -d)
  license-plist --output-path "$LICENSE_DIR" --suppress-opening-directory >/dev/null 2>&1 || true
  ng_cnt=$(grep -Ril "GPL\|AGPL\|LGPL" "$LICENSE_DIR" | wc -l | tr -d ' ')
  
  # 空文字列や非数値をチェック
  if [[ ! "$ng_cnt" =~ ^[0-9]+$ ]]; then
    ng_cnt=0
  fi
  
  if [ "$ng_cnt" -gt 0 ]; then
    warn "非互換または警告ライセンス $ng_cnt 件"
  else
    ok "ライセンス OK"
  fi
  rm -rf "$LICENSE_DIR"
else
  license_check_skip=1
  step "license-plist (ライセンスチェック)"
  info "license-plist が見つからないためスキップします"
fi

# --- 12) 依存アップデート (CocoaPods / SwiftPM) -----------------------
step "依存ライブラリ更新状況"
# CocoaPods
if command -v pod >/dev/null 2>&1 && [[ -f Podfile ]]; then
  cocoapods_check_skip=0
  POD_TMP=$(mktemp)
  pod outdated --no-ansi >"$POD_TMP" 2>/dev/null || true
  major_up=$(grep -E '\([0-9]+\.[0-9]+\.[0-9]+ -> [1-9][0-9]*\.' "$POD_TMP" | wc -l | tr -d ' ')
  # 空文字列や非数値をチェック
  if [[ ! "$major_up" =~ ^[0-9]+$ ]]; then
    major_up=0
  fi
  
  if [ "$major_up" -gt 0 ]; then
    warn "CocoaPods major version 更新 $major_up 件"
    if [[ $SILENT_MODE -eq 0 ]]; then
      grep -E '\([0-9]+\.[0-9]+\.[0-9]+ -> [1-9][0-9]*\.' "$POD_TMP" | head -10
      if [ "$major_up" -gt 10 ]; then
        echo "... 他 $(( major_up - 10 )) 件"
      fi
    fi
  else
    ok "CocoaPods major 更新なし"
  fi
  rm "$POD_TMP"
else
  cocoapods_check_skip=1
  if ! command -v pod >/dev/null 2>&1; then
    info "pod が見つからないためスキップします"
  else
    info "Podfile が見つからないためスキップします"
  fi
fi

# SwiftPM
if grep -q "Package.swift" <<<"$(ls)"; then
  swiftpm_check_skip=0
  SP_TMP=$(swift package update --dry-run 2>/dev/null || echo "")
  # grepで処理を改善し、変数に値がない場合のエラーを防止
  major_up=$(echo "$SP_TMP" | grep -E 'up to.*[1-9][0-9]*\.[0-9]+\.[0-9]+' | wc -l | tr -d ' ')
  # 空文字列や非数値をチェック
  if [[ ! "$major_up" =~ ^[0-9]+$ ]]; then
    major_up=0
  fi
  
  if [ "$major_up" -gt 0 ]; then
    warn "SwiftPM major version 更新 $major_up 件"
    if [[ $SILENT_MODE -eq 0 ]]; then
      echo "$SP_TMP" | grep -E 'up to.*[1-9][0-9]*\.[0-9]+\.[0-9]+' | head -10
      if [ "$major_up" -gt 10 ]; then
        echo "... 他 $(( major_up - 10 )) 件"
      fi
    fi
  else
    ok "SwiftPM major 更新なし"
  fi
else
  swiftpm_check_skip=1
  info "Package.swift が見つからないためスキップします"
fi

# --- 13) コード品質統計 -----------------------------------
step "コード品質統計"
if [[ $SILENT_MODE -eq 0 ]]; then
  echo "  - 重複コードクローン数: $dup_cnt (閾値: $JSC_PD_THRESHOLD)"
  echo "  - SwiftFormat エラー有無: $fmt_err"
  echo "  - SwiftLint違反件数: $sl_cnt"
  echo "  - Swift ファイル総行数: $total_lines"
  
  # 追加された品質指標（実行された場合のみ表示）
  [[ $complexity_skip -eq 0 && -n "${over_cnt:-}" ]] && echo "  - 複雑度 > 10 の関数: $over_cnt 件"
  [[ $unused_skip -eq 0 && -n "${unused_cnt:-}" ]] && echo "  - 未使用コード/シンボル: $unused_cnt 件"
  [[ $osv_scan_skip -eq 0 && -n "${critical_cnt:-}" && -n "${high_cnt:-}" ]] && echo "  - 高深刻度脆弱性: critical=$critical_cnt, high=$high_cnt 件"
  [[ $license_check_skip -eq 0 && -n "${ng_cnt:-}" ]] && echo "  - 非互換ライセンス: $ng_cnt 件"
  [[ $ipa_check_skip -eq 0 && -n "${ipa_mb:-}" ]] && echo "  - IPA サイズ: ${ipa_mb}MB"
fi

# --- 14) Summary -------------------------------------------
step "全フェーズ結果サマリ"
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  if [[ $SILENT_MODE -eq 0 ]]; then
    echo "⚠️ 警告事項:"
    for w in "${WARNINGS[@]}"; do echo "  - $w"; done
  fi
fi

if [[ ${#ERRORS[@]} -eq 0 ]]; then
  if [[ $SILENT_MODE -eq 0 ]]; then
    ok "全フェーズ成功 🎉"
  fi
  # 非サイレントモードでなくても終了コードは必要
  exit 0
else
  if [[ $SILENT_MODE -eq 0 ]]; then
    echo "× 発生した問題一覧:"
    for e in "${ERRORS[@]}"; do echo "  - $e"; done
    echo "合計 ${#ERRORS[@]} 件の異常検出"
  fi
  # 非サイレントモードでなくても終了コードは必要
  exit ${#ERRORS[@]}
fi