# iappshdv 

A collection of shell scripts for automating quality verification and debugging in iOS/macOS application development.

## Project Concept

The iappshdv project is being developed with the concept of "iOS app development by shell script" at its core. We're excited about the future development of this project and look forward to your continued interest and support.

## Overview

This project provides a comprehensive set of shell scripts designed to help iOS/macOS developers automate code quality checks, security scanning, performance validation, and build verification. It streamlines the development workflow by integrating various quality assurance tools into simple command-line interfaces.

## Key Features

### Environment Setup
- Development tool installation and updates (Xcode Command Line Tools, Homebrew, Xcode.app)
- Mac development environment preparation (XcodeGen, swift-format, SwiftLint)

### Code Quality Checks
- Duplicate code detection (jscpd)
- Code formatting (swiftformat)
- Static analysis (swiftlint)
- File line statistics
- Cyclomatic complexity analysis
- Unused code detection (periphery)
- TODO comment tracking

### Security Checks
- Dependency vulnerability scanning (osv-scanner)
- License compatibility verification (licenseplist)
- Dependency update status (CocoaPods/SwiftPM)

### Performance Validation
- IPA size verification
- Symbol UUID duplication checking (dwarf information validation)

### Build Verification
- Error detection and listing via xcodebuild

## Script Details

### Environment Setup Scripts

#### `sh/install_prereqs.sh`
Checks and installs required development tools for iOS/macOS development.

**Features:**
- Installs Xcode Command Line Tools if not already installed
- Sets up or updates Homebrew
- Installs or updates Xcode.app via Homebrew Cask
- Installs essential brew packages (coreutils, cocoapods, fastlane, carthage, swiftlint, swiftformat)

**Usage:**
```bash
./sh/install_prereqs.sh
```

#### `sh/prepare_mac_env.sh`
Prepares a Mac environment with necessary packages for iOS development.

**Features:**
- Installs Homebrew if not already installed
- Updates Homebrew to the latest version
- Installs or verifies XcodeGen (for project generation)
- Installs or verifies swift-format (for code formatting)
- Installs or verifies SwiftLint (for linting)

**Usage:**
```bash
./sh/prepare_mac_env.sh
```

### Verification Scripts

#### `sh/verify_debug_v2.sh` (Latest Version)
The most recent and comprehensive code quality verification script.

**Features:**
- Duplicate code detection (jscpd)
- Code formatting (swiftformat)
- Static analysis (swiftlint)
- File line statistics
- Cyclomatic complexity analysis
- Unused code detection (periphery)
- IPA size verification
- Symbol UUID duplication checking
- Dependency vulnerability scanning (osv-scanner)
- License compatibility checking (licenseplist)
- Dependency update status verification (CocoaPods/SwiftPM)

**Usage:**
```bash
./sh/verify_debug_v2.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

**Parameters:**
- `<project_folder>`: Target project directory
- `<ipa_path>`: IPA file path (optional)
- `<baseline_mb>`: IPA size baseline in MB (optional)
- `-s|--silent`: Silent mode (suppress detailed output)
- `-y|--yes`: Auto-yes response (automatically approve interactive prompts)
- `-u|--update-deps`: Automatically update dependencies

#### `sh/verify_debug_v1.sh`
Previous version of the verification script with similar functionality to v2.

**Usage:**
```bash
./sh/verify_debug_v1.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

#### `sh/verify_debug_wbuild_v1.sh`
Verification script with additional build checking functionality.

**Features:**
- Includes all basic code quality checks
- Runs xcodebuild to detect build errors
- Lists any build errors found

**Usage:**
```bash
./sh/verify_debug_wbuild_v1.sh <project_folder>
```

**Parameters:**
- `<project_folder>`: Target project directory

## Example Workflow

1. Initial setup on a new Mac:
```bash
./sh/install_prereqs.sh
./sh/prepare_mac_env.sh
```

2. Verify an iOS project:
```bash
./sh/verify_debug_v2.sh ~/Projects/MyiOSApp
```

3. Verify an iOS project including IPA size check:
```bash
./sh/verify_debug_v2.sh ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

4. Verify with build checks:
```bash
./sh/verify_debug_wbuild_v1.sh ~/Projects/MyiOSApp
```

## Technical Highlights
- Implemented in Bash for macOS environments
- Leverages Homebrew for automated tool installation and updates
- Uses temporary directories for log file management
- Collects errors and warnings for comprehensive final summary
- Flexible error level configuration based on conditions
- Dependency version management with recommended version updates

## Future Plans

While currently a collection of iOS development shell scripts, the future vision includes:
1. Integrating these scripts into a unified pipeline
2. Publishing as a Homebrew package
3. Making the toolset accessible to all Mac users for easier iOS/macOS development quality assurance

## Requirements
- macOS environment
- Basic development tools (most can be installed via the included setup scripts)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

