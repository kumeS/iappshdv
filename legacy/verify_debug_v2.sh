#!/usr/bin/env bash
#
# verify_debug.sh - Code quality and repository sanity checks for Swift/SwiftUI (SwiftPM) projects
IFS=$'\n\t'
set -eo pipefail

# --- Argument parsing & directory setup -------------------
SILENT_MODE=0
AUTO_YES=0
UPDATE_DEPS=0
PROJECT_DIR=""
IPA_PATH=""
BASELINE_MB=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--silent)
      SILENT_MODE=1; shift ;;
    -y|--yes)
      AUTO_YES=1; shift ;;
    -u|--update-deps)
      UPDATE_DEPS=1; shift ;;
    -h|--help)
      echo "Usage: $0 <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]"
      exit 0 ;;
    -*)
      echo "Error: Unknown option $1"
      echo "Usage: $0 <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]"
      exit 1 ;;
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
      shift ;;
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

# --- Config -------------------------------------------------
JSC_PD_THRESHOLD=20  # Duplicate code threshold (warn if above)
LOG_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_DIR"' EXIT

ERRORS=()
WARNINGS=()

# Skip flags for optional checks
complexity_skip=1
unused_skip=1
ipa_check_skip=1
uuid_check_skip=1
osv_scan_skip=1
license_check_skip=1
cocoapods_check_skip=1
swiftpm_check_skip=1

# Tools to manage/install
PACKAGES=("periphery" "osv-scanner" "license-plist" "pod")

get_brew_package() {
  case "$1" in
    periphery) echo "periphery" ;;
    osv-scanner) echo "osv-scanner" ;;
    license-plist) echo "license-plist" ;;
    pod) echo "cocoapods" ;;
    *) echo "" ;;
  esac
}
get_recommended_version() {
  case "$1" in
    periphery) echo "2.12.0" ;;
    osv-scanner) echo "1.3.6" ;;
    license-plist) echo "3.24.6" ;;
    pod) echo "1.12.1" ;;
    *) echo "" ;;
  esac
}

# Helper output functions
step() { [[ $SILENT_MODE -eq 0 ]] && printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
ok()   { [[ $SILENT_MODE -eq 0 ]] && printf "\033[0;32m[OK]\033[0m  %s\n" "$*"; }
warn() { WARNINGS+=("$*"); [[ $SILENT_MODE -eq 0 ]] && printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { ERRORS+=("$*");  [[ $SILENT_MODE -eq 0 ]] && printf "\033[0;31m[ERROR]\033[0m %s\n" "$*"; }
info() { [[ $SILENT_MODE -eq 0 ]] && printf "\033[0;36m[INFO]\033[0m %s\n" "$*"; }
debug(){ [[ $SILENT_MODE -eq 0 ]] && printf "\033[0;36m[DEBUG]\033[0m %s\n" "$*"; }

check_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew not installed. Please install from https://brew.sh/"
    return 1
  fi
  return 0
}

get_package_version() {
  [[ -z "$1" ]] && return 1
  if ! command -v "$1" >/dev/null 2>&1; then
    echo ""; return 1
  fi
  case "$1" in
    periphery) version=$(periphery version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
    osv-scanner) version=$(osv-scanner --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
    license-plist) version=$(license-plist --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
    pod) version=$(pod --version 2>/dev/null) ;;
    *) version="" ;;
  esac
  echo "${version:-0.0.0}"
}
version_lt() {
  [[ -z "$1" || -z "$2" ]] && return 1
  [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]]
}

install_package() {
  local cmd="$1"; local brew_pkg=$(get_brew_package "$cmd"); local recommended=$(get_recommended_version "$cmd")
  if [[ -z "$brew_pkg" ]]; then info "No brew package mapping for $cmd"; return 1; fi
  if command -v "$cmd" >/dev/null 2>&1; then
    if [[ $UPDATE_DEPS -eq 1 && -n "$recommended" ]]; then
      local current=$(get_package_version "$cmd")
      if [[ -n "$current" && $(version_lt "$current" "$recommended") -eq 0 ]]; then
        info "$cmd version $current is older than recommended $recommended"
        if [[ $AUTO_YES -eq 1 ]]; then
          info "Updating $brew_pkg..."
          brew upgrade "$brew_pkg" || brew install "$brew_pkg"
        else
          read -p "Update $cmd (brew $brew_pkg)? (y/n): " -n 1 -r; echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Updating $brew_pkg..."
            brew upgrade "$brew_pkg" || brew install "$brew_pkg"
          fi
        fi
      else
        info "$cmd is up to date ($current)"
      fi
    fi
    return 0
  fi
  # Install if missing
  if [[ $AUTO_YES -eq 1 ]]; then
    info "Installing $brew_pkg..."
    brew install "$brew_pkg" && ok "$brew_pkg installed" || { warn "$brew_pkg install failed"; return 1; }
  else
    read -p "$cmd not found. Install $brew_pkg via Homebrew? (y/n): " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      info "Installing $brew_pkg..."
      if brew install "$brew_pkg"; then ok "$brew_pkg installed"; else warn "$brew_pkg install failed"; return 1; fi
    fi
  fi
}

# --- 1) Dependencies ---------------------------------------
step "Checking basic dependencies"
MISSING_DEPS=0
for cmd in swiftlint swiftformat jscpd jq grep find wc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then err "Missing dependency: $cmd"; MISSING_DEPS=1; fi
done
if [[ $MISSING_DEPS -eq 1 ]]; then warn "Some checks will be skipped due to missing dependencies."; fi

# --- 2) Additional tools (Periphery, osv-scanner, license-plist, CocoaPods) ----
step "Checking additional code tools"
INSTALLED_PACKAGES=()
UPDATED_PACKAGES=()
for cmd in "${PACKAGES[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    info "Tool not found: $cmd"
    if check_brew; then
      info "Attempting to install $cmd via Homebrew..."
      if install_package "$cmd"; then INSTALLED_PACKAGES+=("$cmd"); ok "$cmd installed"; else info "Skipping $cmd installation"; fi
    else
      info "Homebrew not available; skipping $cmd installation"
    fi
  elif [[ $UPDATE_DEPS -eq 1 ]]; then
    local current=$(get_package_version "$cmd")
    local rec=$(get_recommended_version "$cmd")
    if [[ -n "$current" && -n "$rec" && $(version_lt "$current" "$rec") -eq 0 ]]; then
      info "$cmd update: $current -> $rec"
      if install_package "$cmd"; then UPDATED_PACKAGES+=("$cmd"); fi
    else
      info "$cmd is up to date ($current)"
    fi
  fi
done
if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then ok "Installed: ${INSTALLED_PACKAGES[*]}"; fi
if [[ ${#UPDATED_PACKAGES[@]} -gt 0 ]]; then ok "Updated: ${UPDATED_PACKAGES[*]}"; fi

# --- 3) Configuration file checks --------------------------
step "Checking configuration files"
envs=($(find . -type f -iname ".env*" -maxdepth 4))
if [[ ${#envs[@]} -gt 1 ]]; then
  warn "Multiple .env files found:"
  for f in "${envs[@]}"; do echo "  $f"; done
fi
xcconfigs=($(find . -type f -iname "*.xcconfig" -maxdepth 4))
if [[ ${#xcconfigs[@]} -gt 1 ]]; then
  warn "Multiple .xcconfig files found:"
  for f in "${xcconfigs[@]}"; do echo "  $f"; done
fi
infos=($(find . -type f -iname "Info.plist" | grep -Ev "(Pods|Carthage|DerivedData|\\.build)"))
if [[ ${#infos[@]} -gt 1 ]]; then
  warn "Multiple Info.plist files found (potential conflict):"
  for f in "${infos[@]}"; do echo "  $f"; done
fi

# --- 4) Package manager checks -----------------------------
step "Checking package managers"
managers=()
[[ -f Podfile ]] && managers+=("CocoaPods")
([[ -f Cartfile ]] || [[ -f Cartfile.resolved ]]) && managers+=("Carthage")
[[ -f Package.swift ]] && managers+=("SwiftPM")
if [[ ${#managers[@]} -gt 1 ]]; then
  warn "Multiple package managers detected: ${managers[*]}"
fi

# --- 5) Unnecessary files/folders check --------------------
step "Checking for unnecessary files/folders"
for pattern in ".DS_Store" "*.xcuserdata" "*.xcuserdatad" ".build" "DerivedData" "node_modules"; do
  find . -type f -name "$pattern" -o -type d -name "$pattern" 2>/dev/null | while IFS= read -r p; do
    if [[ -z "$p" ]]; then continue; fi
    size=$(du -sm "$p" 2>/dev/null | cut -f1)
    [[ -z "$size" ]] && size=0
    if [[ "$size" -gt 50 ]]; then
      warn "Large '$pattern' found at '$p': ${size}MB"
    else
      warn "Unnecessary '$pattern' found at '$p': ${size}MB"
    fi
  done
done

# --- 6) Duplication Check (jscpd) --------------------------
step "Running jscpd duplicate code detection"
# Define duplication thresholds (percentages) for target formats
DUPLICATION_ERROR_THRESHOLD=15  # Percentage, e.g., 15% for Swift
DUPLICATION_WARN_THRESHOLD=5    # Percentage, e.g., 5% for Swift
TARGET_JSCPD_FORMATS=("swift") # Formats to evaluate strictly, e.g., ("swift" "javascript")

set +e
if [[ $SILENT_MODE -eq 1 ]]; then
  jscpd --min-lines 30 --reporters consoleSilent,json --output "$LOG_DIR" . >"$LOG_DIR/jscpd-output.txt" 2>&1
else
  jscpd --min-lines 30 --reporters console,json --output "$LOG_DIR" . | tee "$LOG_DIR/jscpd-output.txt"
fi
JSCPD_EXIT=$?
set -e

# Initialize overall summary variables (can still be useful for logging)
overall_dup_clones=0
overall_dup_lines_percentage=0
# overall_dup_tokens_percentage=0 # Tokens percentage is not used for main logic, can be omitted if not logged explicitly

if [[ -f "$LOG_DIR/jscpd-report.json" ]]; then
  # Remove debug output
  # Get overall statistics for logging
  overall_dup_clones_raw=$(jq '.statistics.total.clones // 0' "$LOG_DIR/jscpd-report.json" 2>/dev/null)
  overall_dup_clones=${overall_dup_clones_raw//[!0-9]/}
  [[ -z "$overall_dup_clones" ]] && overall_dup_clones=0
  
  overall_dup_lines_percentage_float=$(jq '.statistics.total.percentage // 0' "$LOG_DIR/jscpd-report.json" 2>/dev/null)
  overall_dup_lines_percentage=${overall_dup_lines_percentage_float%.*}
  [[ ! "$overall_dup_lines_percentage" =~ ^[0-9]+$ ]] && overall_dup_lines_percentage=0

  info "jscpd Overall: Clones: $overall_dup_clones, Duplicated Lines: $overall_dup_lines_percentage%"

  # Evaluate per-format statistics
  format_errors_found=0
  format_warnings_found=0

  for format_name in "${TARGET_JSCPD_FORMATS[@]}"; do
    # Use correct JSON paths based on jscpd's output structure 
    format_percentage_float=$(jq ".statistics.formats.\"$format_name\".total.percentage // 0" "$LOG_DIR/jscpd-report.json" 2>/dev/null)
    format_clones_raw=$(jq ".statistics.formats.\"$format_name\".total.clones // 0" "$LOG_DIR/jscpd-report.json" 2>/dev/null)
    
    # If total is not present, try direct access (jscpd versions may differ in JSON structure)
    if [[ "$format_percentage_float" == "0" || "$format_percentage_float" == "null" ]]; then
      format_percentage_float=$(jq ".statistics.formats.\"$format_name\".percentage // 0" "$LOG_DIR/jscpd-report.json" 2>/dev/null)
      format_clones_raw=$(jq ".statistics.formats.\"$format_name\".clones // 0" "$LOG_DIR/jscpd-report.json" 2>/dev/null)
    fi
    
    format_clones=${format_clones_raw//[!0-9]/}
    [[ -z "$format_clones" ]] && format_clones=0
    
    # Convert percentage float to integer
    format_percentage=${format_percentage_float%.*}
    [[ ! "$format_percentage" =~ ^[0-9]+$ ]] && format_percentage=0

    if [[ "$format_percentage" == "0" && "$format_clones" == "0" ]]; then
      info "jscpd ($format_name): No duplication data or format not found in report."
      continue
    fi

    info "jscpd ($format_name): Clones: $format_clones, Duplicated Lines: $format_percentage%"

    if [[ "$format_percentage" -gt "$DUPLICATION_ERROR_THRESHOLD" ]]; then
      err "High code duplication in $format_name: $format_percentage% duplicated lines (threshold > $DUPLICATION_ERROR_THRESHOLD%)"
      format_errors_found=1
    elif [[ "$format_percentage" -gt "$DUPLICATION_WARN_THRESHOLD" ]]; then
      warn "Moderate code duplication in $format_name: $format_percentage% duplicated lines (threshold > $DUPLICATION_WARN_THRESHOLD%)"
      format_warnings_found=1
    elif [[ "$format_clones" -gt "$JSC_PD_THRESHOLD" ]]; then # Check clone count if percentage is low
        warn "Duplicate code clones (count) in $format_name: $format_clones (>$JSC_PD_THRESHOLD), though lines percentage $format_percentage% is acceptable."
        format_warnings_found=1
    elif [[ "$format_clones" -gt 0 ]]; then
        info "Duplicate code clones in $format_name: $format_clones (lines: $format_percentage%) - within defined thresholds."
    else
      ok "No significant duplicate code detected in $format_name (lines: $format_percentage%, clones: $format_clones)"
    fi
  done
  
  # Overall assessment based on both format-specific and overall metrics
  if [[ $format_errors_found -eq 1 ]]; then
    err "Format-specific duplication exceeded error threshold. See details above."
  elif [[ $format_warnings_found -eq 1 ]]; then
    warn "Format-specific duplication exceeded warning threshold. See details above."
  elif [[ $overall_dup_clones -gt 0 && $overall_dup_lines_percentage -gt $DUPLICATION_ERROR_THRESHOLD ]]; then
    err "High overall code duplication: $overall_dup_lines_percentage% duplicated lines (threshold > $DUPLICATION_ERROR_THRESHOLD%), $overall_dup_clones clones found."
  elif [[ $overall_dup_clones -gt 0 && $overall_dup_lines_percentage -gt $DUPLICATION_WARN_THRESHOLD ]]; then
    warn "Moderate overall code duplication: $overall_dup_lines_percentage% duplicated lines (threshold > $DUPLICATION_WARN_THRESHOLD%), $overall_dup_clones clones found."
  elif [[ $overall_dup_clones -gt $JSC_PD_THRESHOLD ]]; then
    warn "Overall duplicate code clones (count): $overall_dup_clones (>$JSC_PD_THRESHOLD), though percentage checks passed."
  elif [[ $overall_dup_clones -gt 0 ]]; then
    info "Some duplicate code detected: $overall_dup_clones clones, $overall_dup_lines_percentage% lines - within thresholds."
  else
    ok "No duplicate code detected."
  fi

  # Update Code Quality Summary section too
  jscpd_summary_message="No significant duplicate code detected."
  if [[ $format_errors_found -eq 1 || ($overall_dup_clones -gt 0 && $overall_dup_lines_percentage -gt $DUPLICATION_ERROR_THRESHOLD) ]]; then
    jscpd_summary_message="HIGH CODE DUPLICATION DETECTED ($overall_dup_lines_percentage%), exceeding threshold of $DUPLICATION_ERROR_THRESHOLD%."
  elif [[ $format_warnings_found -eq 1 || ($overall_dup_clones -gt 0 && $overall_dup_lines_percentage -gt $DUPLICATION_WARN_THRESHOLD) ]]; then
    jscpd_summary_message="Moderate code duplication ($overall_dup_lines_percentage%), exceeding threshold of $DUPLICATION_WARN_THRESHOLD%."
  elif [[ $overall_dup_clones -gt $JSC_PD_THRESHOLD ]]; then
    jscpd_summary_message="Duplicate code clones: $overall_dup_clones (above threshold of $JSC_PD_THRESHOLD)."
  elif [[ $overall_dup_clones -gt 0 ]]; then
    jscpd_summary_message="Some code duplication: $overall_dup_clones clones, $overall_dup_lines_percentage% - within acceptable limits."
  fi
  
else
  err "jscpd-report.json not found. Cannot perform detailed duplication analysis."
  if [[ $JSCPD_EXIT -ne 0 && $JSCPD_EXIT -ne 1 ]]; then
    err "jscpd execution error (exit code $JSCPD_EXIT). Check $LOG_DIR/jscpd-output.txt"
  else
    overall_dup_clones_text=$(grep -Eo "Found [0-9]+ clones" "$LOG_DIR/jscpd-output.txt" | grep -Eo "[0-9]+" || echo 0)
    overall_dup_clones=${overall_dup_clones_text:-0}
    [[ ! "$overall_dup_clones" =~ ^[0-9]+$ ]] && overall_dup_clones=0
    if [[ "$overall_dup_clones" -gt "$JSC_PD_THRESHOLD" ]]; then
        warn "Duplicate code clones (overall console parse): $overall_dup_clones (>$JSC_PD_THRESHOLD)"
    elif [[ "$overall_dup_clones" -gt 0 ]]; then
        warn "Duplicate code clones (overall console parse): $overall_dup_clones"
    else
        ok "No duplicate code detected (overall console parse)."
    fi
  fi
fi

# --- 7) SwiftFormat ---------------------------------------
step "Running swiftformat (max width 100)"
SWFCONFIG=".swiftformat"
SWFBU=".swiftformat.backup"
[[ -f "$SWFCONFIG" ]] && mv "$SWFCONFIG" "$SWFBU"
set +e
swiftformat . --swiftversion 5.9 --maxwidth 100 --quiet 2>"$LOG_DIR/swiftformat-errors.txt"
fmt_exit=$?
set -e
[[ -f "$SWFBU" ]] && mv "$SWFBU" "$SWFCONFIG"
if [[ $fmt_exit -eq 0 ]]; then
  ok "swiftformat completed"
else
  err "swiftformat reported issues"
  [[ $SILENT_MODE -eq 0 ]] && cat "$LOG_DIR/swiftformat-errors.txt"
fi

# --- 8) SwiftLint -----------------------------------------
step "Running SwiftLint (warnings only)"
set +e
SL_OUTPUT=$(swiftlint lint --quiet 2>"$LOG_DIR/swiftlint-errors.txt" || echo "")
SL_EXIT=$?
set -e
if [[ $SILENT_MODE -eq 0 && -s "$LOG_DIR/swiftlint-errors.txt" ]]; then
  # Convert absolute paths to relative in error log
  sed "s|$(pwd)/||g" "$LOG_DIR/swiftlint-errors.txt" | tee "$LOG_DIR/swiftlint-errors-relative.txt"
fi
if [[ $SL_EXIT -eq 0 || $SL_EXIT -eq 1 ]]; then
  if [[ -n "$SL_OUTPUT" ]]; then
    if echo "$SL_OUTPUT" | grep -q '^\['; then
      sl_cnt=$(echo "$SL_OUTPUT" | jq '. | length')
    else
      sl_cnt=$(echo "$SL_OUTPUT" | grep -vc '^$')
    fi
  else
    sl_cnt=0
  fi
  if [[ $sl_cnt -eq 0 ]]; then
    ok "No SwiftLint violations"
  else
    warn "SwiftLint violations: $sl_cnt"
    if [[ $SILENT_MODE -eq 0 ]]; then
      # Get current working directory with trailing slash for path conversion
      CWD=$(pwd)/
      if echo "$SL_OUTPUT" | grep -q '^\['; then
        # For JSON output, convert paths in jq output
        echo "$SL_OUTPUT" | jq -r ".[0:10][] | (.file | sub(\"$CWD\"; \"\")) + \":\(.line):\(.column): \(.reason)\""
        (( sl_cnt > 10 )) && echo "... ($(( sl_cnt - 10 )) more)"
      else
        # For text output, use sed to convert absolute paths to relative
        echo "$SL_OUTPUT" | sed "s|$CWD||g" | head -10
        (( sl_cnt > 10 )) && echo "... ($(( sl_cnt - 10 )) more)"
      fi
    fi
  fi
else
  sl_cnt=0
  warn "SwiftLint error or no config found"
fi

# --- 9) File line count ----------------------------------
step "Swift file line count"
if [[ $SILENT_MODE -eq 0 ]]; then
  echo "Top 10 longest Swift files (lines):"
  find . -name "*.swift" -not -path "*/.build/*" -not -path "*/Pods/*" -not -path "*/build/*" \
    -exec wc -l {} \; | sort -nr | head -10
fi
total_lines=$(find . -name "*.swift" -not -path "*/.build/*" -not -path "*/Pods/*" -not -path "*/build/*" -exec cat {} + | wc -l | tr -d ' ')
[[ $SILENT_MODE -eq 0 ]] && echo "Total Swift lines: $total_lines"

# --- 10) Cyclomatic Complexity ---------------------------
if command -v swiftlint >/dev/null 2>&1; then
  step "Cyclomatic complexity (swiftlint)"
  complexity_skip=0
  CC_TMP=$(mktemp)
  swiftlint lint --quiet --only cyclomatic_complexity >"$CC_TMP" 2>/dev/null || true
  over_cnt=$(grep -c "Cyclomatic Complexity Violation:" "$CC_TMP" || echo 0)
  [[ ! "$over_cnt" =~ ^[0-9]+$ ]] && over_cnt=0
  if [ "$over_cnt" -gt 0 ]; then
    warn "High cyclomatic complexity functions: $over_cnt"
    if [[ $SILENT_MODE -eq 0 ]]; then
      grep "Cyclomatic Complexity Violation:" "$CC_TMP" | head -10
      (( over_cnt > 10 )) && echo "... ($(( over_cnt - 10 )) more)"
    fi
  else
    ok "Cyclomatic complexity OK (<=10)"
  fi
  rm "$CC_TMP"
else
  complexity_skip=1
  step "Cyclomatic complexity (swiftlint)"
  info "swiftlint not found; skipping complexity check"
fi

# --- 11) Unused Code (Periphery) --------------------------
if command -v periphery >/dev/null 2>&1; then
  step "Periphery (unused code analysis)"
  unused_skip=0
  PERI_TMP=$(mktemp)
  periphery scan --format text >"$PERI_TMP" 2>/dev/null || true
  unused_cnt=$(grep -c "Unused" "$PERI_TMP" || echo 0)
  [[ ! "$unused_cnt" =~ ^[0-9]+$ ]] && unused_cnt=0
  if [ "$unused_cnt" -gt 0 ]; then
    warn "Unused code/symbols: $unused_cnt"
    if [[ $SILENT_MODE -eq 0 ]]; then
      grep "Unused" "$PERI_TMP" | head -10
      (( unused_cnt > 10 )) && echo "... ($(( unused_cnt - 10 )) more)"
    fi
  else
    ok "No unused code detected"
  fi
  rm "$PERI_TMP"
else
  unused_skip=1
  step "Periphery (unused code analysis)"
  info "periphery not installed; skipping unused code check"
fi

# --- 12) IPA Size Check -----------------------------------
if [[ -n "$IPA_PATH" && -f "$IPA_PATH" ]]; then
  step "IPA size check"
  ipa_check_skip=0
  ipa_mb=$(du -m "$IPA_PATH" | awk '{print $1}')
  [[ $SILENT_MODE -eq 0 ]] && echo "Current IPA size: ${ipa_mb}MB"
  if [[ -n "$BASELINE_MB" ]]; then
    delta=$((ipa_mb - BASELINE_MB))
    if [ "$delta" -gt 5 ]; then
      warn "IPA is larger by ${delta}MB (baseline +5MB)"
    else
      ok "IPA size change OK (+${delta}MB)"
    fi
  fi
else
  ipa_check_skip=1
  step "IPA size check"
  info "No IPA path provided; skipping IPA size check"
fi

# --- 13) UUID Symbol Check -------------------------------
APP_BINARY=$(find . -type f -path "*/build/*.app/*" 2>/dev/null | head -1)
if [[ -n "$APP_BINARY" ]]; then
  step "UUID symbol check"
  uuid_check_skip=0
  uuids=$(dwarfdump --uuid "$APP_BINARY" | awk '{print $2}')
  dup_uuid=$(echo "$uuids" | sort | uniq -d)
  if [[ -n "$dup_uuid" ]]; then
    warn "Duplicate UUIDs found: $dup_uuid"
  else
    ok "No duplicate UUIDs"
  fi
else
  uuid_check_skip=1
  step "UUID symbol check"
  info "No built app binary found; skipping UUID check"
fi

# --- 14) Dependency Vulnerability (osv-scanner) ------------
if command -v osv-scanner >/dev/null 2>&1 && ([[ -f Podfile.lock ]] || [[ -f Package.resolved ]]); then
  step "OSV vulnerability scan"
  osv_scan_skip=0
  OSV_TMP=$(mktemp)
  if [[ -f Podfile.lock ]]; then
    osv-scanner --lockfile Podfile.lock >"$OSV_TMP" 2>/dev/null || true
  else
    osv-scanner --lockfile Package.resolved >"$OSV_TMP" 2>/dev/null || true
  fi
  critical_cnt=$(grep -ci '"critical"' "$OSV_TMP" || echo 0)
  high_cnt=$(grep -ci '"high"' "$OSV_TMP" || echo 0)
  [[ ! "$critical_cnt" =~ ^[0-9]+$ ]] && critical_cnt=0
  [[ ! "$high_cnt" =~ ^[0-9]+$ ]] && high_cnt=0
  if [ "$critical_cnt" -gt 0 ] || [ "$high_cnt" -gt 0 ]; then
    warn "Vulnerabilities found (critical=$critical_cnt, high=$high_cnt)"
  else
    ok "No high/critical vulnerabilities"
  fi
  rm "$OSV_TMP"
else
  osv_scan_skip=1
  step "OSV vulnerability scan"
  if ! command -v osv-scanner >/dev/null 2>&1; then
    info "osv-scanner not installed; skipping vulnerability scan"
  else
    info "No lockfile found; skipping vulnerability scan"
  fi
fi

# --- 15) License Compatibility (license-plist) -------------
step "License compatibility check"
if command -v license-plist >/dev/null 2>&1; then
  LP_CONFIG_PATHS=(".license-plist.yml" "license_plist.yml")
  LP_CONFIG_FOUND=0
  for cfg_path in "${LP_CONFIG_PATHS[@]}"; do
    if [[ -f "$cfg_path" ]]; then
      LP_CONFIG_FOUND=1
      break
    fi
  done

  if [[ $LP_CONFIG_FOUND -eq 0 ]]; then
    warn "No license-plist config found (.license-plist.yml or license_plist.yml). Skipping license check."
    license_check_skip=1
  else
    license_check_skip=0
    set +e
    mkdir -p "$LOG_DIR/licenses"
    lp_output=$(license-plist --output-path "$LOG_DIR/licenses" --quiet 2>"$LOG_DIR/lp-error.txt")
    lp_exit=$?
    set -e

    if [[ -s "$LOG_DIR/lp-error.txt" ]]; then
        warn "license-plist execution error. See details below:"
        if [[ $SILENT_MODE -eq 0 ]]; then
            cat "$LOG_DIR/lp-error.txt"
        fi
    fi

    if compgen -G "$LOG_DIR/licenses/*.html" > /dev/null; then
      gpl_found=$(grep -iE '(GPL|Affero)' "$LOG_DIR/licenses/"*.html || echo "")
      if [[ -n "$gpl_found" ]]; then
        err "GPL/Affero license detected. Check license compatibility."
        [[ $SILENT_MODE -eq 0 ]] && echo "$gpl_found" | head -5
      else
        ok "No GPL/Affero licenses found"
      fi
    else
      warn "No license files generated by license-plist. Check config or dependencies."
    fi
  fi
else
  license_check_skip=1
  info "license-plist not installed; skipping license check"
fi

# --- 16) Dependency Updates (CocoaPods / SwiftPM) ----------
step "Dependency update check"
# CocoaPods
if command -v pod >/dev/null 2>&1 && [[ -f Podfile ]]; then
  cocoapods_check_skip=0
  POD_TMP=$(mktemp)
  pod outdated --no-ansi >"$POD_TMP" 2>/dev/null || true
  pod_major=$(grep -E '\([0-9]+\.[0-9]+\.[0-9]+ -> [1-9][0-9]*\.' "$POD_TMP" | wc -l | tr -d ' ')
  [[ ! "$pod_major" =~ ^[0-9]+$ ]] && pod_major=0
  if [ "$pod_major" -gt 0 ]; then
    warn "CocoaPods major updates available: $pod_major"
    [[ $SILENT_MODE -eq 0 ]] && (grep -E '\([0-9]+\.[0-9]+\.[0-9]+ -> [1-9][0-9]*\.' "$POD_TMP" | head -10; (( pod_major > 10 )) && echo "... ($(( pod_major - 10 )) more)")
  else
    ok "No CocoaPods major updates"
  fi
  rm "$POD_TMP"
else
  cocoapods_check_skip=1
  if ! command -v pod >/dev/null 2>&1; then
    info "pod not installed; skipping CocoaPods update check"
  elif [[ ! -f Podfile ]]; then
    info "Podfile missing; skipping CocoaPods update check"
  fi
fi
# SwiftPM
if [[ -f Package.swift ]]; then
  swiftpm_check_skip=0
  SP_TMP=$(swift package update --dry-run 2>/dev/null || echo "")
  sp_major=$(echo "$SP_TMP" | grep -E 'up to.*[1-9][0-9]*\.[0-9]+\.[0-9]+' | wc -l | tr -d ' ')
  [[ ! "$sp_major" =~ ^[0-9]+$ ]] && sp_major=0
  if [ "$sp_major" -gt 0 ]; then
    warn "SwiftPM major updates available: $sp_major"
    [[ $SILENT_MODE -eq 0 ]] && (echo "$SP_TMP" | grep -E 'up to.*[1-9][0-9]*\.[0-9]+\.[0-9]+' | head -10; (( sp_major > 10 )) && echo "... ($(( sp_major - 10 )) more)")
  else
    ok "No SwiftPM major updates"
  fi
else
  swiftpm_check_skip=1
  info "Package.swift not found; skipping SwiftPM update check"
fi

# --- 17) Code Quality Summary -----------------------------
step "Code Quality Summary"
if [[ $SILENT_MODE -eq 0 ]]; then
  # Display jscpd results with proper context
  if [[ -n "$jscpd_summary_message" ]]; then
    echo "  - Code duplication: $jscpd_summary_message"
  else
    echo "  - Overall duplicate code clones: $overall_dup_clones (threshold for count: $JSC_PD_THRESHOLD)"
  fi
  echo "  - SwiftFormat status code: $fmt_exit"
  echo "  - SwiftLint issues: $sl_cnt"
  echo "  - Total Swift lines: $total_lines"
  [[ $complexity_skip -eq 0 ]] && echo "  - Cyclomatic complexity >10: $over_cnt"
  [[ $unused_skip -eq 0 ]]   && echo "  - Unused code/symbols: $unused_cnt"
  [[ $osv_scan_skip -eq 0 ]] && echo "  - Vulnerabilities (crit/high): $critical_cnt/$high_cnt"
  [[ $license_check_skip -eq 0 ]] && echo "  - GPL/LGPL licenses: $gpl_cnt"
  [[ $ipa_check_skip -eq 0 ]] && echo "  - IPA size: ${ipa_mb:-N/A}MB"
fi

# --- 18) Final Summary ------------------------------------
step "Overall Results"
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  [[ $SILENT_MODE -eq 0 ]] && { echo "⚠️ Warnings:"; for w in "${WARNINGS[@]}"; do echo "  - $w"; done; }
fi
if [[ ${#ERRORS[@]} -eq 0 ]]; then
  [[ $SILENT_MODE -eq 0 ]] && ok "All checks passed! 🎉"
  exit 0
else
  [[ $SILENT_MODE -eq 0 ]] && { echo "✖️ Errors:"; for e in "${ERRORS[@]}"; do echo "  - $e"; done; echo "Total ${#ERRORS[@]} errors."; }
  exit ${#ERRORS[@]}
fi
