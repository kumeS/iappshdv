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

## Installation

### Using Homebrew (Recommended)

You can install iappshdv using Homebrew:

```bash
# Add the tap repository
brew tap username/tap

# Install iappshdv
brew install username/tap/iappshdv
```

For detailed installation instructions, see [HOMEBREW.md](HOMEBREW.md).

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/username/iappshdv.git
cd iappshdv
```

2. Add the `bin` directory to your PATH:
```bash
export PATH="$PATH:$(pwd)/bin"
```

3. Make the main script executable:
```bash
chmod +x bin/iappshdv
```

## Usage

iappshdv provides a unified command-line interface for all functionality:

```
iappshdv <command> [options]
```

### Commands

- `setup`: Setup development environment
  - `prereqs`: Install prerequisite tools
  - `env`: Prepare Mac environment for iOS development

- `verify`: Run verification tools
  - `code`: Verify code quality
  - `security`: Perform security checks
  - `size`: Verify IPA size
  - `all`: Run all verification checks

- `build`: Verify build

- `help`: Show help message
- `version`: Show version information

### Examples

1. Initial setup on a new Mac:
```bash
iappshdv setup prereqs
iappshdv setup env
```

2. Verify an iOS project:
```bash
iappshdv verify all ~/Projects/MyiOSApp
```

3. Verify only code quality:
```bash
iappshdv verify code ~/Projects/MyiOSApp
```

4. Verify an iOS project including IPA size check:
```bash
iappshdv verify size ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

5. Verify with build checks:
```bash
iappshdv build ~/Projects/MyiOSApp
```

For more information on each command, use:
```bash
iappshdv help <command>
```

## Requirements
- macOS environment
- Basic development tools (most can be installed via the included setup scripts)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Development Status

### Current Version

**Version:** 0.1.0 (Initial Release)

### Recent Updates

- Implemented unified command structure with a modular approach
- Consolidated functionality into separate library modules (common.sh, setup.sh, verify.sh, build.sh)
- Added shell completions for bash and zsh
- Created Homebrew Formula for easy distribution
- Added test environment in 'apptest' directory with intentional code issues for verification testing

### Roadmap

#### Upcoming in v0.2.0
- Complete implementation of verification functions in verify.sh
- Improve error handling and reporting
- Add more comprehensive tests

#### Planned for v1.0.0
- Full implementation of all verification tools
- Comprehensive documentation
- Improved integration with CI/CD workflows
- Extended compatibility with different iOS/macOS project structures

## Project Structure

```
iappshdv/
├── bin/                # Executable commands
│   └── iappshdv       # Main command
├── lib/                # Library functions
│   ├── common.sh      # Common functions
│   ├── setup.sh       # Setup related functions
│   ├── verify.sh      # Verification related functions
│   └── build.sh       # Build related functions
├── completions/        # Shell completions
│   ├── iappshdv.bash  # Bash completion
│   └── iappshdv.zsh   # Zsh completion
├── Formula/            # Homebrew formula
│   └── iappshdv.rb    # Formula definition
└── legacy/             # Legacy and development files
    ├── docs/           # Development documentation
    │   ├── dev.txt        # Development guidelines (in Japanese)
    │   └── 250521_summary.txt # Development summary
    ├── install_prereqs.sh     # Legacy installation script
    ├── prepare_mac_env.sh     # Legacy environment preparation script
    ├── verify_debug_v1.sh     # Legacy verification script v1
    ├── verify_debug_v2.sh     # Legacy verification script v2
    └── verify_debug_wbuild_v1.sh # Legacy verification with build script
```

## Development vs. Installation

When installing via Homebrew, only the necessary files for execution are installed:
- Executable command (`bin/iappshdv`)
- Library functions (`lib/*`)
- Completions
- Documentation (README.md, HOMEBREW.md)

The entire `legacy/` directory is excluded from installation, keeping the installed package lightweight and focused on the current implementation.

