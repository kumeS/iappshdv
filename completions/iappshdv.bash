#!/usr/bin/env bash
#
# iappshdv - Bash completion script
#

_iappshdv_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  
  # Main commands
  if [ $COMP_CWORD -eq 1 ]; then
    opts="setup verify build help version"
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
  fi
  
  # Subcommands
  case "${prev}" in
    setup)
      opts="prereqs env"
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
      ;;
    verify)
      opts="code security size all"
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
      ;;
    help)
      opts="setup verify build"
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
      ;;
    *)
      # Handle additional parameters
      case "${COMP_WORDS[1]}" in
        verify)
          if [ $COMP_CWORD -eq 3 ]; then
            # Project directory
            COMPREPLY=( $(compgen -d -- ${cur}) )
            return 0
          elif [ $COMP_CWORD -eq 4 ] && [ "${COMP_WORDS[2]}" = "size" ]; then
            # IPA file
            COMPREPLY=( $(compgen -f -X '!*.ipa' -- ${cur}) )
            return 0
          fi
          ;;
        build)
          if [ $COMP_CWORD -eq 2 ]; then
            # Project directory
            COMPREPLY=( $(compgen -d -- ${cur}) )
            return 0
          fi
          ;;
      esac
      ;;
  esac
  
  # Default to files and directories
  COMPREPLY=( $(compgen -f -- ${cur}) $(compgen -d -- ${cur}) )
  return 0
}

complete -F _iappshdv_completion iappshdv 