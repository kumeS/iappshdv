# iappshdv

A toolkit for automated quality verification and debugging in iOS/macOS application development.

## Project Purpose and Vision

iappshdv ("iOS Application Shell Development and Verification") is designed to streamline and standardize quality assurance processes in iOS and macOS application development. The project addresses common challenges faced by mobile development teams:

- Inconsistent code quality across team members and projects
- Difficulty maintaining security standards and dependency hygiene
- Time-consuming manual verification processes
- Challenges in establishing measurable quality metrics

By providing a unified command-line interface to industry-standard verification tools, iappshdv helps development teams:

1. **Improve Code Quality** - Consistent formatting, reduced duplication, and lower complexity
2. **Enhance Security** - Automated vulnerability scanning and license compliance checks
3. **Optimize Performance** - Size verification and binary validation
4. **Streamline Development** - Automated workflows and standardized metrics

### Development Roadmap

This project is being developed with the following milestones:

- **v0.1.0 (Current)**: Initial release with core functionality
- **v0.2.0 (Planned)**: Complete implementation of verification functions, improved error handling
- **v1.0.0 (Future)**: Full integration with CI/CD systems, comprehensive documentation, and extended compatibility

The long-term vision includes distribution via Homebrew, integration with popular iOS CI/CD pipelines, and expansion to cover additional quality metrics specific to the Apple development ecosystem.

## Key Features: The `verify all` Command

The core functionality of iappshdv is provided through the `verify all` command, which performs comprehensive verification of your iOS/macOS projects:

```bash
iappshdv verify all <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

### What `verify all` Does

This powerful command runs a complete suite of checks on your project:

1. **Code Quality Verification**
   - Duplicate code detection (jscpd)
   - Code formatting (swiftformat)
   - Static analysis (swiftlint)
   - File line statistics
   - Cyclomatic complexity analysis
   - Unused code detection (periphery)
   - TODO comment tracking

2. **Security Verification**
   - Dependency vulnerability scanning (osv-scanner)
   - License compatibility verification (licenseplist)
   - Dependency update status (CocoaPods/SwiftPM)

3. **Size Verification** (when IPA path is provided)
   - IPA size verification
   - Symbol UUID duplication checking

### Options

- `<project_folder>`: Target project directory (required)
- `[<ipa_path>]`: IPA file path (optional)
- `[<baseline_mb>]`: IPA size baseline in MB (optional)
- `-s|--silent`: Silent mode (suppress detailed output)
- `-y|--yes`: Auto-yes response (automatically approve interactive prompts)
- `-u|--update-deps`: Automatically update dependencies

### Example

```bash
iappshdv verify all ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

## Installation

### Using Homebrew (Coming Soon)

Installation via Homebrew is planned for a future update. This section will be updated once the feature has been verified and made available.

For more details on Homebrew installation, see [HOMEBREW.md](HOMEBREW.md).

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
  - `code`: Verify code quality only
  - `security`: Perform security checks only
  - `size`: Verify IPA size only
  - `all`: Run all verification checks (main function)

- `build`: Verify build

- `help`: Show help message
- `version`: Show version information

## Command Details and Options

### Setup Commands

```
iappshdv setup prereqs
```

Installs prerequisite tools needed for development (Xcode Command Line Tools, Homebrew, Xcode).

```
iappshdv setup env
```

Prepares the Mac environment for iOS development (XcodeGen, swift-format, SwiftLint).

### Verification Commands

Basic usage format:
```
iappshdv verify <subcommand> <project_folder> [options]
```

#### Specific Verification Subcommands

If you need to run only specific verification checks rather than the full suite, you can use:

Code quality verification:
```bash
iappshdv verify code ~/Projects/MyiOSApp
```

Security checks:
```bash
iappshdv verify security ~/Projects/MyiOSApp
```

IPA size verification (with 50MB baseline):
```bash
iappshdv verify size ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50
```

### Build Verification Command

```
iappshdv build <project_folder>
```

Verifies the build and detects errors.

- `<project_folder>`: Target project directory (required)

### Help and Version

Display help:
```bash
iappshdv help
```

Display help for a specific command:
```bash
iappshdv help verify
```

Display version information:
```bash
iappshdv version
```

## Examples and Workflow

### Initial Setup on a New Mac

```bash
# Install required tools
iappshdv setup prereqs

# Prepare the Mac environment
iappshdv setup env
```

### Project Verification Workflow

```bash
# Run the main full verification (recommended)
iappshdv verify all ~/Projects/MyiOSApp

# Run full verification including IPA size check (50MB baseline)
iappshdv verify all ~/Projects/MyiOSApp ~/Downloads/MyApp.ipa 50

# Run full verification in silent mode
iappshdv verify all ~/Projects/MyiOSApp -s

# Run full verification with auto-update for dependencies
iappshdv verify all ~/Projects/MyiOSApp -u

# Verify build (only if needed)
iappshdv build ~/Projects/MyiOSApp
```

## System Requirements

- macOS environment
- Basic development tools (most can be installed via the included setup scripts)

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
```

## Legacy Scripts

This project started as a collection of independent shell scripts. The following scripts are kept in the `legacy/` directory for reference:

### Environment Setup Scripts

#### `legacy/install_prereqs.sh`
Checks and installs required development tools for iOS/macOS development.

**Features:**
- Installs Xcode Command Line Tools if not already installed
- Sets up or updates Homebrew
- Installs or updates Xcode.app via Homebrew Cask
- Installs essential brew packages (coreutils, cocoapods, fastlane, carthage, swiftlint, swiftformat)

**Usage:**
```bash
./legacy/install_prereqs.sh
```

#### `legacy/prepare_mac_env.sh`
Prepares a Mac environment with necessary packages for iOS development.

**Features:**
- Installs Homebrew if not already installed
- Updates Homebrew to the latest version
- Installs or verifies XcodeGen (for project generation)
- Installs or verifies swift-format (for code formatting)
- Installs or verifies SwiftLint (for linting)

**Usage:**
```bash
./legacy/prepare_mac_env.sh
```

### Verification Scripts

#### `legacy/verify_debug_v2.sh` (Latest Version)
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
./legacy/verify_debug_v2.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

#### `legacy/verify_debug_v1.sh`
Previous version of the verification script with similar functionality to v2.

**Usage:**
```bash
./legacy/verify_debug_v1.sh <project_folder> [<ipa_path>] [<baseline_mb>] [-s|--silent] [-y|--yes] [-u|--update-deps]
```

#### `legacy/verify_debug_wbuild_v1.sh`
Verification script with additional build checking functionality.

**Features:**
- Includes all basic code quality checks
- Runs xcodebuild to detect build errors
- Lists any build errors found

**Usage:**
```bash
./legacy/verify_debug_wbuild_v1.sh <project_folder>
```

## Development Status

### Current Version

**Version:** 0.1.0 (Initial Release)

### Future Plans

#### Upcoming in v0.2.0
- Complete implementation of verification functions in verify.sh
- Improve error handling and reporting
- Add more comprehensive tests

#### Planned for v1.0.0
- Full implementation of all verification tools
- Comprehensive documentation
- Improved integration with CI/CD workflows
- Extended compatibility with different iOS/macOS project structures

