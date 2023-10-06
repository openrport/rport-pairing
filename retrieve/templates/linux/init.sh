#!/bin/sh -e
MY_COMMAND="$0 $*"
exit_trap() {
  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then
    return 0
  fi
  echo ""
  echo "An error occurred."
  echo "Try running in debug mode with 'sh -x ${MY_COMMAND}'"
  echo "Ask for help on https://github.com/openrport/openrport-pairing/discussions/categories/help-needed "
  echo ""
}
trap exit_trap EXIT