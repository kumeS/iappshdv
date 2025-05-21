# iappshdv

iOS/macOSアプリケーション開発のための品質検証・デバッグ自動化ツールセット

## プロジェクトの目的とビジョン

iappshdv（「iOS Application Shell Development and Verification」）は、iOSおよびmacOSアプリケーション開発における品質保証プロセスを効率化し、標準化するために設計されています。このプロジェクトは、モバイル開発チームが直面する一般的な課題に対処します：

- チームメンバーやプロジェクト間でのコード品質の不一致
- セキュリティ基準と依存関係の衛生管理の困難さ
- 時間を要する手動検証プロセス
- 測定可能な品質指標の確立における課題

業界標準の検証ツールへの統一されたコマンドラインインターフェースを提供することで、iappshdvは開発チームに以下の利点をもたらします：

1. **コード品質の向上** - 一貫したフォーマット、重複の削減、複雑性の低減
2. **セキュリティの強化** - 自動化された脆弱性スキャンとライセンスコンプライアンスチェック
3. **パフォーマンスの最適化** - サイズ検証とバイナリ検証
4. **開発の効率化** - 自動化されたワークフローと標準化された指標

### 開発ロードマップ

このプロジェクトは以下のマイルストーンで開発が進められています：

- **v0.1.0（現在）**: 基本機能を備えた初期リリース
- **v0.2.0（計画中）**: 検証機能の完全実装、エラー処理の改善
- **v1.0.0（将来）**: CI/CDシステムとの完全統合、包括的なドキュメント、拡張された互換性

長期的なビジョンには、Homebrewを通じた配布、人気のあるiOS CI/CDパイプラインとの統合、Appleの開発エコシステムに特化した追加の品質指標のカバレッジ拡大が含まれています。

## 主な機能: `verify all` コマンド

iappshdvの中核機能は `verify all` コマンドを通じて提供されます。このコマンドはiOS/macOSプロジェクトの包括的な検証を実行します：

```bash
iappshdv verify all <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

### `verify all` の機能

このパワフルなコマンドは、プロジェクトに対して以下の総合的なチェックを実行します：

1. **コード品質検証**
   - コードの重複検出 (jscpd)
   - コードフォーマッティング (swiftformat)
   - 静的解析 (swiftlint)
   - ファイル行統計
   - 循環的複雑度分析
   - 未使用コード検出 (periphery)
   - TODOコメント追跡

2. **セキュリティ検証**
   - 依存関係の脆弱性スキャン (osv-scanner)
   - ライセンス互換性検証 (licenseplist)
   - 依存関係の更新状態確認 (CocoaPods/SwiftPM)

3. **サイズ検証** (IPAパスが提供されている場合)
   - IPAサイズ検証
   - シンボルUUID重複チェック

### オプション

- `<project_folder>`: 対象プロジェクトディレクトリ（必須）
- `[<ipa_path>]`: IPAファイルパス（オプション）
- `[<baseline_mb>]`: IPAサイズの基準値（MB単位、オプション）
- `-s|--silent`: サイレントモード（詳細な出力を抑制）
- `-y|--yes`: 自動確認応答（インタラクティブなプロンプトに自動的に承認）
- `-u|--update-deps`: 依存関係を自動的に更新

### 使用例

```bash
iappshdv verify all ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

## 概要

iappshdvは、iOS/macOSアプリ開発においてコード品質チェック、セキュリティスキャン、パフォーマンス検証、ビルド確認などを自動化するシェルスクリプトのセットです。シンプルなコマンドラインインターフェースを通じて様々な品質保証ツールを統合し、開発ワークフローを効率化します。

## インストール方法

### Homebrewを使用する方法（今後実装予定）

Homebrewを使ったインストールは将来のアップデートで計画されています。この機能が確認され利用可能になった時点で、このセクションは更新されます。

詳細なHomebrewインストール手順については [HOMEBREW.md](HOMEBREW.md) を参照してください。

### 手動インストール

1. リポジトリをクローン：
```bash
git clone https://github.com/username/iappshdv.git
cd iappshdv
```

2. `bin` ディレクトリをPATHに追加：
```bash
export PATH="$PATH:$(pwd)/bin"
```

3. メインスクリプトを実行可能にする：
```bash
chmod +x bin/iappshdv
```

## 使用方法

iappshdvは統一されたコマンドライン形式で利用できます：

```
iappshdv <command> [options]
```

### コマンド一覧

- `setup`: 開発環境のセットアップ
  - `prereqs`: 前提ツールのインストール
  - `env`: iOS開発用のMac環境準備

- `verify`: 検証ツールの実行
  - `code`: コード品質の検証のみ
  - `security`: セキュリティチェックのみ
  - `size`: IPAサイズの検証のみ
  - `all`: すべての検証チェックを実行（メイン機能）

- `build`: ビルド検証

- `help`: ヘルプメッセージの表示
- `version`: バージョン情報の表示

## コマンド詳細と引数の使用方法

### セットアップコマンド

```
iappshdv setup prereqs
```

開発に必要な前提ツール（Xcode Command Line Tools、Homebrew、Xcodeなど）をインストールします。

```
iappshdv setup env
```

iOS開発用のMac環境（XcodeGen、swift-format、SwiftLintなど）を準備します。

### 検証コマンド

基本的な使用形式：
```
iappshdv verify <subcommand> <project_folder> [options]
```

#### 個別の検証サブコマンド

全機能の検証ではなく、特定の検証のみを実行する必要がある場合は、以下のコマンドを使用できます：

コード品質検証：
```bash
iappshdv verify code ~/Projects/MyiOSApp
```

セキュリティチェック：
```bash
iappshdv verify security ~/Projects/MyiOSApp
```

IPAサイズ検証（50MBを基準に）：
```bash
iappshdv verify size ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

### ビルド検証コマンド

```
iappshdv build <project_folder>
```

ビルドを検証し、エラーを検出します。

- `<project_folder>`: 対象プロジェクトディレクトリ（必須）

### ヘルプとバージョン

ヘルプを表示：
```bash
iappshdv help
```

特定のコマンドのヘルプを表示：
```bash
iappshdv help verify
```

バージョン情報を表示：
```bash
iappshdv version
```

## 実行例とワークフロー

### 新しいMacでの初期設定

```bash
# 必要なツールのインストール
iappshdv setup prereqs

# Mac環境の準備
iappshdv setup env
```

### プロジェクト検証ワークフロー

```bash
# メインの包括的検証を実行（推奨）
iappshdv verify all ~/Projects/MyiOSApp

# IPAサイズチェック（50MBを基準値として）を含む包括的検証
iappshdv verify all ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50

# サイレントモードで包括的検証を実行
iappshdv verify all ~/Projects/MyiOSApp -s

# 依存関係の自動更新を含む包括的検証
iappshdv verify all ~/Projects/MyiOSApp -u

# ビルド検証（必要な場合のみ）
iappshdv build ~/Projects/MyiOSApp
```

## システム要件

- macOS環境
- 基本的な開発ツール（ほとんどは付属のセットアップスクリプトでインストール可能）

## プロジェクト構造

```
iappshdv/
├── bin/                # 実行可能なコマンド
│   └── iappshdv       # メインコマンド
├── lib/                # ライブラリ関数
│   ├── common.sh      # 共通関数
│   ├── setup.sh       # セットアップ関連関数
│   ├── verify.sh      # 検証関連関数
│   └── build.sh       # ビルド関連関数
├── completions/        # シェル補完
│   ├── iappshdv.bash  # Bash補完
│   └── iappshdv.zsh   # Zsh補完
├── Formula/            # Homebrew formula
│   └── iappshdv.rb    # Formula定義
└── legacy/             # レガシーおよび開発ファイル
```

## レガシースクリプトについて

このプロジェクトは元々独立したシェルスクリプトのコレクションとして始まりました。以下のスクリプトは`legacy/`ディレクトリに保存され、参照用に維持されています：

### 環境セットアップスクリプト

#### `legacy/install_prereqs.sh`
iOS/macOS開発に必要なツールをインストールします。

**機能:**
- Xcode Command Line Toolsのインストール
- Homebrewのセットアップまたは更新
- Homebrewを通じたXcode.appのインストールまたは更新
- 必須brewパッケージ（coreutils, cocoapods, fastlane, carthage, swiftlint, swiftformat）のインストール

**使用法:**
```bash
./legacy/install_prereqs.sh
```

#### `legacy/prepare_mac_env.sh`
iOS開発に必要なパッケージをMac環境に準備します。

**機能:**
- Homebrewのインストール確認
- Homebrewの最新版への更新
- XcodeGen（プロジェクト生成用）のインストールまたは確認
- swift-format（コードフォーマット用）のインストールまたは確認
- SwiftLint（リント用）のインストールまたは確認

**使用法:**
```bash
./legacy/prepare_mac_env.sh
```

### 検証スクリプト

#### `legacy/verify_debug_v2.sh`（最新バージョン）
最も新しく包括的なコード品質検証スクリプトです。

**機能:**
- コードの重複検出 (jscpd)
- コードフォーマッティング (swiftformat)
- 静的解析 (swiftlint)
- ファイル行統計
- 循環的複雑度分析
- 未使用コード検出 (periphery)
- IPAサイズ検証
- シンボルUUID重複チェック
- 依存関係の脆弱性スキャン (osv-scanner)
- ライセンス互換性検証 (licenseplist)
- 依存関係の更新状態確認 (CocoaPods/SwiftPM)

**使用法:**
```bash
./legacy/verify_debug_v2.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

#### `legacy/verify_debug_v1.sh`
v2と同様の機能を持つ以前のバージョンの検証スクリプトです。

**使用法:**
```bash
./legacy/verify_debug_v1.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

#### `legacy/verify_debug_wbuild_v1.sh`
追加のビルドチェック機能を持つ検証スクリプトです。

**機能:**
- 基本的なコード品質チェックの実行
- xcodebuildによるビルドエラーの検出
- 検出されたビルドエラーのリスト化

**使用法:**
```bash
./legacy/verify_debug_wbuild_v1.sh <project_folder>
```

## 開発状況

### 現在のバージョン

**バージョン:** 0.1.0（初期リリース）

### 今後の予定

#### v0.2.0での予定
- verify.shの検証機能の完全実装
- エラーハンドリングとレポートの改善
- より包括的なテストの追加

#### v1.0.0での予定
- すべての検証ツールの完全実装
- 包括的なドキュメント
- CI/CDワークフローとの連携改善
- 様々なiOS/macOSプロジェクト構造との互換性拡張 