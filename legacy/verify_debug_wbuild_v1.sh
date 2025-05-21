#!/usr/bin/env bash
# ============================================================
# verify_code_quality.sh (v30 – ビルドチェック機能追加版)
#   - 重複コード検出 (jscpd：コンソール出力のみ)
#   - コード整形 (swiftformat：デフォルト設定を使用)
#   - 静的解析 (swiftlint：違反件数を警告表示、詳細オフ)
#   - ファイル行数統計 (長いファイルの特定)
#   - TODOコメント検出 (未解決のタスクの特定)
#   - xcodebuildでのビルドチェック (追加: ビルドエラーの検出と一覧表示)
#   ※ 全フェーズ実行 → 最終サマリ & exit code
# Usage: verify_code_quality.sh <project_folder>
# ============================================================

IFS=$'\n\t'
set -euo pipefail

# --- 引数チェック & ディレクトリ移動 ------------------------
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project_folder>"
  exit 1
fi
PROJECT_DIR="$1"
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

# --- Helpers ----------------------------------------------
step(){ printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
ok()  { printf "\033[0;32m[OK]\033[0m  %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; WARNINGS+=("$*"); }
ng()  { printf "\033[0;31m[NG]\033[0m  %s\n" "$*"; ERRORS+=("$*"); }
debug(){ printf "\033[0;36m[DEBUG]\033[0m %s\n" "$*"; }

# --- 1) Dependencies --------------------------------------
step "依存ツール確認"
MISSING_DEPS=0
for cmd in swiftlint swiftformat jscpd jq grep find wc xcodebuild; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    ng "missing dependency: $cmd"
    MISSING_DEPS=1
  fi
done

if [[ $MISSING_DEPS -eq 1 ]]; then
  warn "一部の依存ツールが見つかりません。該当する検証はスキップされます。"
fi

# --- 2) Duplication Check ---------------------------------
step "jscpd による重複コード検出"
# JSONレポートを一時ディレクトリに保存し、終了時に削除
TMP_JSON="$LOG_DIR/jscpd-report.json"

# コンソール出力のみを使用し、一時ファイルを後で削除
set +e
jscpd --min-lines 30 --reporters console --output "$LOG_DIR" . > "$LOG_DIR/jscpd-output.txt" 2>&1
JSCPD_EXIT=$?
set -e

# jscpdの出力結果をコンソールに表示
cat "$LOG_DIR/jscpd-output.txt"

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
  
  if [[ -z "$dup_cnt" ]]; then
    dup_cnt=0
  fi
  
  if (( dup_cnt > JSC_PD_THRESHOLD )); then
    ng "重複コード検出 ($dup_cnt 件) - 閾値 $JSC_PD_THRESHOLD 超過"
  elif (( dup_cnt > 0 )); then
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
  cat "$LOG_DIR/swiftformat-errors.txt"
fi

# --- 4) SwiftLint -----------------------------------------
step "SwiftLint 実行 (警告扱い、詳細オフ)"
set +e
SL_OUTPUT=$(swiftlint lint --quiet 2>"$LOG_DIR/swiftlint-errors.txt" || echo "")
SL_EXIT=$?
set -e

# エラーがあれば表示
if [[ -s "$LOG_DIR/swiftlint-errors.txt" ]]; then
  cat "$LOG_DIR/swiftlint-errors.txt"
fi

# .swiftlint.yml が存在しない場合も動作するように
if [[ $SL_EXIT -eq 0 || $SL_EXIT -eq 1 ]]; then
  # 出力が空でなければ違反があると判断
  if [[ -n "$SL_OUTPUT" ]]; then
    # 出力が JSON 形式かどうかを安全に確認
    if echo "$SL_OUTPUT" | grep -q '^[\{\[]' && echo "$SL_OUTPUT" | jq . >/dev/null 2>&1; then
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
    if echo "$SL_OUTPUT" | grep -q '^[\{\[]' && echo "$SL_OUTPUT" | jq . >/dev/null 2>&1; then
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
else
  sl_cnt=0
  warn "SwiftLint 実行エラーまたは設定ファイルがありません"
fi

# --- 5) ファイル行数統計 ----------------------------------
step "ファイル行数統計"
echo "Swift ファイル行数統計:"
find . -name "*.swift" -not -path "*/\.build/*" -not -path "*/Pods/*" -not -path "*/build/*" -exec wc -l {} \; | sort -nr | head -10

total_lines=$(find . -name "*.swift" -not -path "*/\.build/*" -not -path "*/Pods/*" -not -path "*/build/*" -exec cat {} \; | wc -l)
total_lines=$(echo "$total_lines" | tr -d ' ')
echo "合計行数: $total_lines"

# --- 6) TODOコメント検出 ----------------------------------
step "TODOコメント検出"
set +e
# デバッグのためエラー出力を有効化し、grepの終了コードも確認
echo "DEBUG: Running grep for TODOs..."
TODO_COMMENTS_OUTPUT=$(grep -r "TODO\|FIXME\|HACK\|XXX" --include="*.swift" . | grep -v "build/" || echo "GREP_EMPTY_RESULT")
GREP_EXIT_CODE=$?
echo "DEBUG: grep exit code: $GREP_EXIT_CODE"
echo "DEBUG: TODO_COMMENTS_OUTPUT raw output:"
echo "$TODO_COMMENTS_OUTPUT"
set -e

if [[ "$TODO_COMMENTS_OUTPUT" == "GREP_EMPTY_RESULT" ]]; then
  TODO_COMMENTS=""
else
  TODO_COMMENTS="$TODO_COMMENTS_OUTPUT"
fi

echo "DEBUG: TODO_COMMENTS after processing:"
echo "$TODO_COMMENTS" # この行で内容を確認

if [[ -z "$TODO_COMMENTS" ]]; then
  TODO_COUNT=0
else
  # 確実に改行区切りでカウントするためにヒアドキュメントを使用
  TODO_COUNT=$(echo "$TODO_COMMENTS" | wc -l)
  TODO_COUNT=$(echo "$TODO_COUNT" | tr -d ' ') # trim whitespace
fi

echo "DEBUG: TODO_COUNT: $TODO_COUNT"

if [[ "$TODO_COUNT" -gt 0 ]]; then
  warn "未解決のTODOコメント: $TODO_COUNT 件"
  echo "$TODO_COMMENTS" | head -10
  if [[ "$TODO_COUNT" -gt 10 ]]; then
    echo "... 他 $(( TODO_COUNT - 10 )) 件"
  fi
else
  ok "未解決のTODOコメントなし"
fi

# --- 7) xcodebuildでのビルドチェック -------------------
step "xcodebuild ビルドチェック"

# Xcodeプロジェクトまたはワークスペースの検索
# ワークスペースファイルを検索 (.xcodeproj内のものは除外)
WORKSPACE=$(find . -maxdepth 2 -name "*.xcworkspace" -not -path "./*.xcodeproj/*" | head -1)
# プロジェクトファイルを検索 (ディレクトリタイプを指定)
XCODEPROJ=$(find . -maxdepth 2 -name "*.xcodeproj" -type d | head -1)

if [[ -z "$XCODEPROJ" && -z "$WORKSPACE" ]]; then
  warn "Xcodeプロジェクト/ワークスペースが見つかりません"
  build_err_cnt=0
else
  # ビルド設定の準備
  BUILD_LOG="$LOG_DIR/xcodebuild.log"
  ERROR_LOG="$LOG_DIR/xcodebuild-errors.log"
  
  # シミュレータ情報の取得
  debug "利用可能なシミュレータを確認中..."
  set +e
  SIMULATORS=$(xcrun simctl list devices available -j 2>/dev/null)
  SIMULATOR_SUCCESS=$?
  set -e
  
  # デフォルトのデスティネーション
  DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=latest"
  
  # シミュレータ一覧が取得できた場合、利用可能なものを選択
  if [[ $SIMULATOR_SUCCESS -eq 0 && -n "$SIMULATORS" ]]; then
    debug "シミュレータ情報の解析中..."
    # jqで最新のiOSシミュレータを検索
    if echo "$SIMULATORS" | jq -e '.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.isAvailable==true) | .udid' >/dev/null 2>&1; then
      # 最新のiOS + iPhone シミュレータのUDIDを取得
      SIM_UDID=$(echo "$SIMULATORS" | jq -r '.devices | .[] | .[] | select(.name? | contains("iPhone")) | select(.isAvailable == true) | .udid' | head -1)
      
      if [[ -n "$SIM_UDID" ]]; then
        # シミュレータが見つかった場合、UDIDでデスティネーションを指定
        DESTINATION="platform=iOS Simulator,id=$SIM_UDID"
        debug "使用するシミュレータUDID: $SIM_UDID"
      else
        debug "利用可能なiPhoneシミュレータが見つかりませんでした。デフォルトのデスティネーションを使用します。"
      fi
    else
      debug "jqによるシミュレータ解析に失敗しました。デフォルトのデスティネーションを使用します。"
    fi
  else
    debug "simctl でシミュレータ情報を取得できませんでした。デフォルトのデスティネーションを使用します。"
  fi
  
  # ビルド設定
  BUILD_CONFIG="Debug"
  BUILD_ACTION="build"
  
  # ワークスペースまたはプロジェクトでビルド
  if [[ -n "$WORKSPACE" ]]; then
    debug "ワークスペース: $WORKSPACE を検出しました"
    
    # 利用可能なスキームを取得
    set +e
    SCHEMES_RAW=$(xcodebuild -workspace "$WORKSPACE" -list 2>"$LOG_DIR/schemes-error.log")
    SCHEMES_EXIT=$?
    set -e
    
    if [[ $SCHEMES_EXIT -ne 0 ]]; then
      debug "ワークスペーススキームの取得に失敗しました。エラーログ:"
      cat "$LOG_DIR/schemes-error.log"
      SCHEME=""
    else
      # スキーム名を抽出 (より堅牢な方法)
      SCHEME_LINE=$(echo "$SCHEMES_RAW" | awk '/Schemes:/{flag=1; next} flag && NF{print; exit}')
      SCHEME=$(echo "$SCHEME_LINE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//') # 前後の空白を除去

      if [[ -z "$SCHEME" ]]; then
        debug "通常のスキーム抽出に失敗しました。ターゲット名を試します。"
        TARGET_LINE=$(echo "$SCHEMES_RAW" | awk '/Targets:/{flag=1; next} flag && NF{print; exit}')
        SCHEME=$(echo "$TARGET_LINE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

        if [[ -z "$SCHEME" ]]; then
          warn "ワークスペーススキームが見つかりませんでした"
        else
          debug "ターゲット名からスキームを使用: $SCHEME"
        fi
      else
        debug "使用するスキーム: $SCHEME"
      fi
    fi
    
    # スキームが見つかった場合、ビルド実行
    if [[ -n "$SCHEME" ]]; then
      printf "ワークスペース: %s、スキーム: %s、デスティネーション: %s でビルドします\n" "$WORKSPACE" "$SCHEME" "$DESTINATION"
      debug "DEBUG: Value of WORKSPACE before build: [$WORKSPACE]"
      debug "DEBUG: Value of SCHEME before build: [$SCHEME]"
      debug "DEBUG: Value of DESTINATION before build: [$DESTINATION]"
      
      set +e
      # ビルド実行コマンド
      xcodebuild -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$BUILD_CONFIG" \
        -destination "$DESTINATION" \
        $BUILD_ACTION \
        OTHER_SWIFT_FLAGS="-D DEBUG" \
        COMPILER_INDEX_STORE_ENABLE=NO \
        > "$BUILD_LOG" 2>&1
      
      BUILD_EXIT=$?
      set -e
      
      debug "ビルド終了 (exit code: $BUILD_EXIT)"
    else
      warn "有効なスキームが見つからないため、ビルドをスキップします"
      BUILD_EXIT=1
    fi
  elif [[ -n "$XCODEPROJ" ]]; then
    debug "プロジェクト: $XCODEPROJ を検出しました"
    
    # 利用可能なスキームを取得
    echo "DEBUG: Listing schemes for project $XCODEPROJ..."
    set +e
    SCHEMES_RAW=$(xcodebuild -project "$XCODEPROJ" -list) # エラー出力を直接確認
    SCHEMES_EXIT=$?
    echo "DEBUG: xcodebuild -list exit code: $SCHEMES_EXIT"
    echo "DEBUG: SCHEMES_RAW output:"
    echo "$SCHEMES_RAW"
    set -e
    
    if [[ $SCHEMES_EXIT -ne 0 ]]; then
      debug "プロジェクトスキームの取得に失敗しました。"
      SCHEME=""
    else
      # スキーム名を抽出 (より堅牢な方法)
      SCHEME_LINE=$(echo "$SCHEMES_RAW" | awk '/Schemes:/{flag=1; next} flag && NF{print; exit}')
      SCHEME=$(echo "$SCHEME_LINE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//') # 前後の空白を除去

      if [[ -z "$SCHEME" ]]; then
        debug "通常のスキーム抽出に失敗しました。ターゲット名を試します。"
        TARGET_LINE=$(echo "$SCHEMES_RAW" | awk '/Targets:/{flag=1; next} flag && NF{print; exit}')
        SCHEME=$(echo "$TARGET_LINE" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

        if [[ -z "$SCHEME" ]]; then
          warn "プロジェクトスキームまたはターゲットが見つかりませんでした"
        else
          debug "ターゲット名からスキームを使用: $SCHEME"
        fi
      else
        debug "使用するスキーム: $SCHEME"
      fi
    fi
    
    # スキームが見つかった場合、ビルド実行
    if [[ -n "$SCHEME" ]]; then
      printf "プロジェクト: %s、スキーム: %s、デスティネーション: %s でビルドします\n" "$XCODEPROJ" "$SCHEME" "$DESTINATION"
      debug "DEBUG: Value of XCODEPROJ before build: [$XCODEPROJ]"
      debug "DEBUG: Value of SCHEME before build: [$SCHEME]"
      debug "DEBUG: Value of DESTINATION before build: [$DESTINATION]"
      
      set +e
      # ビルド実行コマンド
      xcodebuild -project "$XCODEPROJ" \
        -scheme "$SCHEME" \
        -configuration "$BUILD_CONFIG" \
        -destination "$DESTINATION" \
        $BUILD_ACTION \
        OTHER_SWIFT_FLAGS="-D DEBUG" \
        COMPILER_INDEX_STORE_ENABLE=NO \
        > "$BUILD_LOG" 2>&1
      
      BUILD_EXIT=$?
      set -e
      
      debug "ビルド終了 (exit code: $BUILD_EXIT)"
    else
      warn "有効なスキームが見つからないため、ビルドをスキップします"
      BUILD_EXIT=1
    fi
  else
    warn "Xcodeプロジェクト/ワークスペースが見つかりません"
    BUILD_EXIT=1
  fi
  
  # ビルドログの解析と結果表示
  if [[ -f "$BUILD_LOG" ]]; then
    # エラーパターンの検出 (xcodebuildの様々なエラーパターンに対応)
    set +e
    grep -E "(error:|fatal error:|undefined symbol|cannot find|linker command failed|Build failed|Command failed|Swift Compiler Error)" "$BUILD_LOG" > "$ERROR_LOG" 2>/dev/null || true
    
    # エラー行のコンテキストも含めて抽出 (エラー行の前後5行)
    grep -n -E "(error:|fatal error:|undefined symbol|cannot find|linker command failed|Build failed|Command failed|Swift Compiler Error)" "$BUILD_LOG" | \
    while IFS=: read -r line_number rest; do
      start_line=$((line_number > 5 ? line_number - 5 : 1))
      end_line=$((line_number + 5))
      sed -n "${start_line},${end_line}p" "$BUILD_LOG" >> "$LOG_DIR/build-errors-context.log"
      echo "-----------------------------------" >> "$LOG_DIR/build-errors-context.log"
    done
    set -e
    
    # エラー件数カウント
    build_err_cnt=$(grep -c -E "(error:|fatal error:|undefined symbol|cannot find|linker command failed|Build failed|Command failed|Swift Compiler Error)" "$BUILD_LOG" || echo "0")
    
    # 実際のソースコードエラー行を抽出
    SOURCE_ERRORS_LOG="$LOG_DIR/source-errors.log"
    grep -E ":[0-9]+:[0-9]+: error:" "$BUILD_LOG" > "$SOURCE_ERRORS_LOG" 2>/dev/null || true
    source_err_cnt=$(grep -c "" "$SOURCE_ERRORS_LOG" || echo "0")
    
    # ビルド結果の表示
    if [[ $BUILD_EXIT -eq 0 && $build_err_cnt -eq 0 ]]; then
      ok "ビルド成功"
    else
      ng "ビルドエラー: $build_err_cnt 件"
      
      # エラー情報の表示
      if [[ $source_err_cnt -gt 0 ]]; then
        echo "ソースコードエラー ($source_err_cnt 件):"
        cat "$SOURCE_ERRORS_LOG" | head -10
        if [[ $source_err_cnt -gt 10 ]]; then
          echo "... 他 $(( source_err_cnt - 10 )) 件のソースエラー"
        fi
        echo ""
      fi
      
      if [[ -s "$ERROR_LOG" ]]; then
        echo "ビルドエラー詳細:"
        cat "$ERROR_LOG" | head -20
        if [[ $build_err_cnt -gt 20 ]]; then
          echo "... 他 $(( build_err_cnt - 20 )) 件のエラー"
        fi
      fi
      
      if [[ -s "$LOG_DIR/build-errors-context.log" ]]; then
        echo ""
        echo "エラーコンテキスト (抜粋):"
        head -20 "$LOG_DIR/build-errors-context.log"
        echo "詳細なビルドログは $BUILD_LOG で確認できます。"
      fi
    fi
  else
    build_err_cnt=0
    warn "ビルドログが生成されませんでした"
  fi
fi

# --- 8) Bug Statistics ------------------------------------
step "コード品質統計"
echo "  - 重複コードクローン数: $dup_cnt (閾値: $JSC_PD_THRESHOLD)"
echo "  - SwiftFormat エラー有無: $fmt_err"
echo "  - SwiftLint違反件数: $sl_cnt"
echo "  - TODOコメント件数: $TODO_COUNT"
echo "  - ビルドエラー件数: $build_err_cnt"
echo "  - Swift ファイル総行数: $total_lines"

# --- 9) Summary -------------------------------------------
step "全フェーズ結果サマリ"
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "⚠️ 警告事項:"
  for w in "${WARNINGS[@]}"; do echo "  - $w"; done
fi

if [[ ${#ERRORS[@]} -eq 0 ]]; then
  ok "全フェーズ成功 🎉"
  exit 0
else
  echo "× 発生した問題一覧:"
  for e in "${ERRORS[@]}"; do echo "  - $e"; done
  echo "合計 ${#ERRORS[@]} 件の異常検出"
  exit ${#ERRORS[@]}
fi