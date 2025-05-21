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

## Usage

Each script accepts command-line arguments to perform verification on the specified project directory:

```
./sh/verify_debug_v2.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

### Parameters
- `<project_folder>`: Target project directory
- `<ipa_path>`: IPA file path (optional)
- `<baseline_mb>`: IPA size baseline in MB (optional)
- `-s|--silent`: Silent mode (suppress detailed output)
- `-y|--yes`: Auto-yes response (automatically approve interactive prompts)
- `-u|--update-deps`: Automatically update dependencies

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

