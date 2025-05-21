#!/usr/bin/env bash
#
# iappshdv - iOS/macOS Application Development Helper and Verification Tool
#
# Common functions for all iappshdv scripts
#

# Exit on error by default
set -e

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[0;37m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Paths
export IAPPSHDV_CONFIG_DIR="$HOME/.iappshdv"
export IAPPSHDV_CONFIG_FILE="$IAPPSHDV_CONFIG_DIR/config"

# Make sure the config directory exists
if [ ! -d "$IAPPSHDV_CONFIG_DIR" ]; then
  mkdir -p "$IAPPSHDV_CONFIG_DIR"
fi

# Load user configuration if it exists
if [ -f "$IAPPSHDV_CONFIG_FILE" ]; then
  source "$IAPPSHDV_CONFIG_FILE"
fi

# Default settings
DEFAULT_SILENT_MODE=false
DEFAULT_AUTO_YES=false
DEFAULT_UPDATE_DEPS=false

# Log functions
log_info() {
  if [ "${SILENT_MODE:-$DEFAULT_SILENT_MODE}" = "true" ]; then
    # サイレントモードでは何も出力しない
    return 0
  fi
  echo -e "${BLUE}INFO:${NC} $1"
}

log_success() {
  echo -e "${GREEN}SUCCESS:${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

log_error() {
  echo -e "${RED}ERROR:${NC} $1" >&2
}

log_section() {
  if [ "${SILENT_MODE:-$DEFAULT_SILENT_MODE}" = "true" ]; then
    # サイレントモードでは何も出力しない
    return 0
  fi
  echo -e "\n${BOLD}${PURPLE}==== $1 ====${NC}\n"
}

# Error handling
handle_error() {
  log_error "$1"
  exit "${2:-1}"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if a directory is a valid project directory
is_valid_project_dir() {
  local dir=$1
  
  if [ ! -d "$dir" ]; then
    return 1
  fi
  
  # Check for common iOS/macOS project files
  if [ -d "$dir/Pods" ] || [ -d "$dir/Carthage" ] || [ -f "$dir/Package.swift" ] || \
     [ -f "$dir/Podfile" ] || [ -f "$dir/Cartfile" ] || \
     [ -d "$dir/xcodeproj" ] || [ -d "$dir/xcworkspace" ]; then
    return 0
  else
    # Look one level deeper for Xcode project files
    find "$dir" -maxdepth 1 -type d -name "*.xcodeproj" -o -name "*.xcworkspace" | grep -q .
    return $?
  fi
}

# Get temporary directory for logs
get_temp_dir() {
  local prefix=${1:-"iappshdv"}
  mktemp -d "/tmp/${prefix}.XXXXXXXX"
}

# Parse common script arguments
parse_common_args() {
  # Default values
  export SILENT_MODE=$DEFAULT_SILENT_MODE
  export AUTO_YES=$DEFAULT_AUTO_YES
  export UPDATE_DEPS=$DEFAULT_UPDATE_DEPS
  
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      -s|--silent)
        export SILENT_MODE=true
        shift
        ;;
      -y|--yes)
        export AUTO_YES=true
        shift
        ;;
      -u|--update-deps)
        export UPDATE_DEPS=true
        shift
        ;;
      *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
  done
  
  # Restore positional parameters
  set -- "${POSITIONAL[@]}"
  
  # Return the remaining positional parameters
  echo "$@"
}

# Confirm action
confirm_action() {
  local message="${1:-Are you sure you want to continue?}"
  
  if [ "$AUTO_YES" = "true" ]; then
    return 0
  fi
  
  read -p "$message [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Check OS compatibility
check_macos() {
  if [[ "$(uname)" != "Darwin" ]]; then
    handle_error "This script is designed to run on macOS only."
  fi
}

# Initialize environment
init_environment() {
  check_macos
  
  # Create config directory if it doesn't exist
  if [ ! -d "$IAPPSHDV_CONFIG_DIR" ]; then
    mkdir -p "$IAPPSHDV_CONFIG_DIR"
  fi
}

# Export variables
export SILENT_MODE
export DEFAULT_SILENT_MODE
export AUTO_YES
export DEFAULT_AUTO_YES
export UPDATE_DEPS
export DEFAULT_UPDATE_DEPS

# Export functions
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_section
export -f handle_error
export -f command_exists
export -f is_valid_project_dir
export -f get_temp_dir
export -f parse_common_args
export -f confirm_action
export -f check_macos
export -f init_environment

# Initialize environment
init_environment 