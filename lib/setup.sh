#!/usr/bin/env bash
#
# iappshdv - iOS/macOS Application Development Helper and Verification Tool
#
# Setup functions for iappshdv
#

# Load common functions if not already loaded
if ! command -v log_info >/dev/null 2>&1; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/common.sh"
fi

# Setup prerequisites function
setup_prereqs() {
  log_section "Setting up prerequisites"
  
  # --- 1. Xcode Command Line Tools ---
  setup_xcode_command_line_tools
  
  # --- 2. Homebrew setup/update ---
  setup_homebrew
  
  # --- 3. Xcode.app (Cask) ---
  setup_xcode_app
  
  # --- 4. Brew packages ---
  install_brew_packages
  
  log_success "All prerequisites are installed and up-to-date!"
}

# Setup Xcode Command Line Tools
setup_xcode_command_line_tools() {
  log_info "Checking Xcode Command Line Tools..."
  
  if ! xcode-select -p >/dev/null 2>&1; then
    log_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    log_info "Please wait for the installation to complete and press Enter..."
    read -r
  else
    log_success "Xcode Command Line Tools already installed"
  fi
}

# Setup and update Homebrew
setup_homebrew() {
  log_info "Checking Homebrew..."
  
  if ! command_exists brew; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -d /opt/homebrew/bin ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  else
    log_success "Homebrew already installed"
  fi
  
  log_info "Updating Homebrew..."
  brew update
}

# Setup Xcode.app
setup_xcode_app() {
  log_info "Checking Xcode.app..."
  
  if brew list --cask xcode >/dev/null 2>&1; then
    if brew outdated --cask xcode >/dev/null 2>&1; then
      log_info "Upgrading Xcode..."
      brew upgrade --cask xcode
      sudo xcodebuild -license accept
    else
      log_success "Xcode.app is up-to-date"
    fi
  else
    log_info "Installing Xcode (this may take a while)..."
    brew install --cask xcode
    sudo xcodebuild -license accept
  fi
}

# Install or update brew packages
install_brew_packages() {
  log_info "Checking brew packages..."
  
  local BREW_PKGS=(
    coreutils    # GNU tools like timeout
    cocoapods    # CocoaPods
    fastlane     # Fastlane
    carthage     # Carthage
    swiftlint    # SwiftLint
    swiftformat  # SwiftFormat
  )
  
  for pkg in "${BREW_PKGS[@]}"; do
    install_or_update_brew_package "$pkg"
  done
}

# Install or update a single brew package
install_or_update_brew_package() {
  local pkg=$1
  
  if brew list "$pkg" >/dev/null 2>&1; then
    if brew outdated "$pkg" >/dev/null 2>&1; then
      log_info "Upgrading ${pkg}..."
      brew upgrade "$pkg"
    else
      log_success "${pkg} is up-to-date"
    fi
  else
    log_info "Installing ${pkg}..."
    brew install "$pkg"
  fi
}

# Prepare Mac environment
prepare_mac_env() {
  log_section "Preparing Mac environment"
  
  # 1) Ensure Homebrew is installed and updated
  setup_homebrew
  
  # 2) Install development tools
  install_dev_tools
  
  log_success "Mac environment preparation completed"
}

# Install development tools
install_dev_tools() {
  local DEV_TOOLS=(
    xcodegen      # Project generation
    swift-format  # Code formatting
    swiftlint     # Linting
  )
  
  for tool in "${DEV_TOOLS[@]}"; do
    install_or_update_brew_package "$tool"
  done
}

# Export functions
export -f setup_prereqs
export -f setup_xcode_command_line_tools
export -f setup_homebrew
export -f setup_xcode_app
export -f install_brew_packages
export -f install_or_update_brew_package
export -f prepare_mac_env
export -f install_dev_tools 