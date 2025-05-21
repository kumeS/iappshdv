#!/usr/bin/env bash
set -euo pipefail

#===================================================
# prepare_mac_env.sh
#  - Mac 環境に必要なパッケージを Homebrew で一括インストール
#  - XcodeGen, swift-format, SwiftLint を準備
#===================================================

# 1) Homebrew がなければインストール
if ! command -v brew >/dev/null 2>&1; then
  echo "▶ Homebrew が見つかりませんでした。インストール中…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "▶ Homebrew が既にインストールされています。"
fi

# 2) Homebrew を最新化
echo "▶ Homebrew を更新中…"
brew update

# 3) XcodeGen のインストール（プロジェクト生成用）
if ! brew list xcodegen >/dev/null 2>&1; then
  echo "▶ xcodegen をインストール中…"
  brew install xcodegen
else
  echo "▶ xcodegen は既にインストール済みです。"
fi

# 4) swift-format のインストール（コード整形用）
if ! brew list swift-format >/dev/null 2>&1; then
  echo "▶ swift-format をインストール中…"
  brew install swift-format
else
  echo "▶ swift-format は既にインストール済みです。"
fi

# 5) SwiftLint のインストール（Lint 実行用）
if ! brew list swiftlint >/dev/null 2>&1; then
  echo "▶ SwiftLint をインストール中…"
  brew install swiftlint
else
  echo "▶ SwiftLint は既にインストール済みです。"
fi

echo "✅ Mac 環境のパッケージ準備が完了しました。"
