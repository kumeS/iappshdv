# Homebrew Installation Guide for iappshdv

This document provides instructions for installing iappshdv using Homebrew.

## Installation

### Option 1: Install from Tap (Recommended)

```bash
# Add the tap repository
brew tap username/tap

# Install iappshdv
brew install username/tap/iappshdv
```

### Option 2: Install directly from URL

```bash
brew install --build-from-source https://raw.githubusercontent.com/username/homebrew-tap/master/Formula/iappshdv.rb
```

## Post-Installation Setup

After installing iappshdv, you should run the setup commands to install required dependencies:

```bash
# Install prerequisites (Xcode Command Line Tools, Homebrew packages)
iappshdv setup prereqs

# Prepare Mac environment for iOS development
iappshdv setup env
```

## Updating

To update iappshdv to the latest version:

```bash
brew update
brew upgrade iappshdv
```

## Uninstalling

To uninstall iappshdv:

```bash
brew uninstall iappshdv
```

## Troubleshooting

If you encounter issues with the installation:

1. Update Homebrew:
   ```bash
   brew update
   ```

2. Try reinstalling:
   ```bash
   brew uninstall iappshdv
   brew install username/tap/iappshdv
   ```

3. Check dependency issues:
   ```bash
   brew doctor
   ```

## For Maintainers: Creating a New Release

1. Update the version in relevant files
2. Tag a new release on GitHub
3. Update the Formula with the new URL and SHA256 checksum
4. Push the updated Formula to the homebrew-tap repository

## License

iappshdv is licensed under the MIT License. See the LICENSE file for details. 