#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# install_prereqs.sh
#
# 事前に必要なツールをチェックし、
# - 未インストールならインストール
# - 既にインストール済みかつ更新があれば最新版にアップデート
# を行います。
# ==============================================================================

# --- 1. Xcode Command Line Tools ---
if ! xcode-select -p >/dev/null 2>&1; then
  echo "🛠️  Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "インストールが終わったら Enter を押してください..."
  read -r
else
  echo "✅  Xcode Command Line Tools already installed"
fi

# --- 2. Homebrew の導入・更新 ---
if ! command -v brew >/dev/null 2>&1; then
  echo "🍺  Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

echo "🔄  Updating Homebrew..."
brew update

# --- 3. Xcode.app （Cask） ---
if brew list --cask xcode >/dev/null 2>&1; then
  if brew outdated --cask xcode >/dev/null 2>&1; then
    echo "⬆️  Upgrading Xcode..."
    brew upgrade --cask xcode
    sudo xcodebuild -license accept
  else
    echo "✅  Xcode.app is up-to-date"
  fi
else
  echo "📦  Installing Xcode (this may take a while)..."
  brew install --cask xcode
  sudo xcodebuild -license accept
fi

# --- 4. Brew パッケージ群 ---
BREW_PKGS=(
  coreutils    # timeout コマンド（GNU）
  cocoapods    # CocoaPods
  fastlane     # Fastlane
  carthage     # Carthage
  swiftlint    # SwiftLint
  swiftformat  # SwiftFormat
)

for pkg in "${BREW_PKGS[@]}"; do
  if brew list "$pkg" >/dev/null 2>&1; then
    if brew outdated "$pkg" >/dev/null 2>&1; then
      echo "⬆️  Upgrading ${pkg}..."
      brew upgrade "$pkg"
    else
      echo "✅  ${pkg} is up-to-date"
    fi
  else
    echo "📦  Installing ${pkg}..."
    brew install "$pkg"
  fi
done

echo "🎉  All prerequisites are installed and up-to-date!"
