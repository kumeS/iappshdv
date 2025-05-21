#compdef iappshdv
#
# iappshdv - Zsh completion script
#

_iappshdv() {
  local -a commands sub_commands
  local curcontext="$curcontext" state line
  
  _arguments -C \
    '1: :->command' \
    '2: :->subcommand' \
    '*: :->args'
  
  case $state in
    command)
      commands=(
        'setup:Setup development environment'
        'verify:Run verification tools'
        'build:Verify build'
        'help:Show help message'
        'version:Show version information'
      )
      _describe -t commands 'iappshdv commands' commands
      ;;
    subcommand)
      case $line[1] in
        setup)
          sub_commands=(
            'prereqs:Install prerequisite tools'
            'env:Prepare Mac environment for iOS development'
          )
          _describe -t sub_commands 'setup subcommands' sub_commands
          ;;
        verify)
          sub_commands=(
            'code:Verify code quality'
            'security:Perform security checks'
            'size:Verify IPA size'
            'all:Run all verification checks'
          )
          _describe -t sub_commands 'verify subcommands' sub_commands
          ;;
        help)
          sub_commands=(
            'setup:Show setup help'
            'verify:Show verify help'
            'build:Show build help'
          )
          _describe -t sub_commands 'help topics' sub_commands
          ;;
      esac
      ;;
    args)
      case $line[1] in
        verify)
          case $line[2] in
            size)
              if [ $CURRENT -eq 4 ]; then
                _path_files -g "*.ipa"
              else
                _path_files -/
              fi
              ;;
            *)
              _path_files -/
              ;;
          esac
          ;;
        build)
          _path_files -/
          ;;
      esac
      ;;
  esac
}

_iappshdv 