#!/usr/bin/env bash
set -euo pipefail

# Interactive dictionary loop. Asks for a word, looks it up in the local
# dictd server, and shows the definition. If the word isn't found, dict
# itself prints a list of nearby words.
#
# Press Enter on a blank line to quit back to the menu.

DB="wn"

print_header() {
  echo
  echo "    DICTIONARY"
  echo "    =========="
  echo
}

while true; do
  clear
  print_header
  echo "    Type a word, then press Enter."
  echo "    (Press Enter on an empty line to quit.)"
  echo

  read -r -p "    Word: " word || exit 0

  # Strip whitespace
  word="${word//[[:space:]]/}"

  if [[ -z "$word" ]]; then
    break
  fi

  clear
  print_header

  # Look up the word. On a hit, dict prints the definition; on a miss it
  # prints "perhaps you mean:" with nearby words on its own. The || true
  # keeps set -e from killing the loop on a miss (dict exits non-zero).
  #
  # --host localhost pins lookups to the local dictd daemon. Without it the
  # dict client falls back to its packaged public servers (dict.org), which
  # on an offline Pi means every miss hangs on a network timeout.
  dict --host localhost -d "$DB" -- "$word" || true

  echo
  echo
  read -r -p "    Press Enter to look up another word..."
done
