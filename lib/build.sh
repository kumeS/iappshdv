#!/usr/bin/env bash
#
# iappshdv - iOS/macOS Application Development Helper and Verification Tool
#
# Build verification functions for iappshdv
#

# Load common functions if not already loaded
if ! command -v log_info >/dev/null 2>&1; then
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  source "$SCRIPT_DIR/common.sh"
fi

# Main build verification function
verify_build() {
  local ARGS=$(parse_common_args "$@")
  local PROJECT_DIR=$(echo "$ARGS" | awk '{print $1}')
  
  if [ -z "$PROJECT_DIR" ]; then
    handle_error "Project directory is required."
  fi
  
  if ! is_valid_project_dir "$PROJECT_DIR"; then
    handle_error "Invalid project directory: $PROJECT_DIR"
  fi
  
  log_section "Starting build verification for project: $PROJECT_DIR"
  
  # Create temp directory for logs
  TEMP_DIR=$(get_temp_dir "iappshdv_build")
  log_info "Log files will be stored in: $TEMP_DIR"
  
  # Run build verification
  run_xcodebuild_check "$PROJECT_DIR"
  
  log_success "Build verification completed!"
}

# Run xcodebuild to detect errors
run_xcodebuild_check() {
  local PROJECT_DIR=$1
  
  log_info "Running xcodebuild to detect build errors..."
  
  # Check if it's a workspace or project
  local WORKSPACE=$(find "$PROJECT_DIR" -maxdepth 2 -name "*.xcworkspace" | grep -v "xcodeproj" | head -1)
  local PROJECT=$(find "$PROJECT_DIR" -maxdepth 2 -name "*.xcodeproj" | head -1)
  
  if [ -n "$WORKSPACE" ]; then
    log_info "Found workspace: $WORKSPACE"
    run_workspace_build "$WORKSPACE"
  elif [ -n "$PROJECT" ]; then
    log_info "Found project: $PROJECT"
    run_project_build "$PROJECT"
  else
    log_warning "No Xcode workspace or project found in $PROJECT_DIR"
    return 1
  fi
}

# Run build for a workspace
run_workspace_build() {
  local WORKSPACE=$1
  local BUILD_LOG="$TEMP_DIR/xcodebuild_workspace.log"
  
  # Check if it's a valid Xcode workspace with contents.xcworkspacedata
  if [ ! -f "$WORKSPACE/contents.xcworkspacedata" ]; then
    log_error "Invalid Xcode workspace: $WORKSPACE (missing contents.xcworkspacedata file)"
    log_info "This may be a test/dummy workspace structure or an incomplete workspace."
    return 1
  fi
  
  # Get schemes
  local SCHEMES=$(xcodebuild -list -workspace "$WORKSPACE" | grep -A 100 "Schemes:" | grep -v "Schemes:" | grep -v "^$" | sed 's/^[ \t]*//')
  
  if [ -z "$SCHEMES" ]; then
    log_warning "No schemes found in workspace: $WORKSPACE"
    return 1
  fi
  
  # Get first scheme
  local SCHEME=$(echo "$SCHEMES" | head -1)
  log_info "Using scheme: $SCHEME"
  
  # Run build
  log_info "Building workspace... This may take a while"
  xcodebuild clean build -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' | tee "$BUILD_LOG"
  
  # Process build log for errors
  process_build_log "$BUILD_LOG"
}

# Run build for a project
run_project_build() {
  local PROJECT=$1
  local BUILD_LOG="$TEMP_DIR/xcodebuild_project.log"
  
  # Check if it's a valid Xcode project with project.pbxproj
  if [ ! -f "$PROJECT/project.pbxproj" ]; then
    log_error "Invalid Xcode project: $PROJECT (missing project.pbxproj file)"
    log_info "This may be a test/dummy project structure or an incomplete project."
    return 1
  fi
  
  # Get schemes
  local SCHEMES=$(xcodebuild -list -project "$PROJECT" | grep -A 100 "Schemes:" | grep -v "Schemes:" | grep -v "^$" | sed 's/^[ \t]*//')
  
  if [ -z "$SCHEMES" ]; then
    log_warning "No schemes found in project: $PROJECT"
    return 1
  fi
  
  # Get first scheme
  local SCHEME=$(echo "$SCHEMES" | head -1)
  log_info "Using scheme: $SCHEME"
  
  # Run build
  log_info "Building project... This may take a while"
  xcodebuild clean build -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' | tee "$BUILD_LOG"
  
  # Process build log for errors
  process_build_log "$BUILD_LOG"
}

# Process build log to extract errors
process_build_log() {
  local BUILD_LOG=$1
  local ERROR_COUNT=0
  
  log_info "Processing build log..."
  
  # Extract errors
  local ERRORS=$(grep -n "error:" "$BUILD_LOG" | sort -u)
  local WARNING_COUNT=$(grep -c "warning:" "$BUILD_LOG")
  ERROR_COUNT=$(echo "$ERRORS" | grep -v "^$" | wc -l | tr -d ' ')
  
  # Create error summary file
  local ERROR_SUMMARY="$TEMP_DIR/build_errors.log"
  echo "$ERRORS" > "$ERROR_SUMMARY"
  
  if [ "$ERROR_COUNT" -gt 0 ]; then
    log_error "Build failed with $ERROR_COUNT errors and $WARNING_COUNT warnings."
    log_error "Error summary saved to: $ERROR_SUMMARY"
    
    # Display first 5 errors
    log_section "First 5 build errors"
    echo "$ERRORS" | head -5
    
    return 1
  else
    log_success "Build succeeded with $WARNING_COUNT warnings."
    return 0
  fi
}

# Export functions
export -f verify_build
export -f run_xcodebuild_check
export -f run_workspace_build
export -f run_project_build
export -f process_build_log 