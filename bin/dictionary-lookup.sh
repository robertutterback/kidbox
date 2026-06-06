#!/usr/bin/env bash
set -euo pipefail

# Interactive dictionary loop. Asks for a word, looks it up in the local
# dictd server (gcide database), and shows the definition. If the word
# isn't found, suggests similar words using Levenshtein distance.
#
# Press Enter on a blank line to quit back to the menu.

DB="gcide"

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

  # Look up the word
  if output="$(dict -d "$DB" -- "$word" 2>/dev/null)" && [[ -n "$output" ]]; then
    printf '%s\n' "$output" | more
  else
    echo "    \"$word\" was not found."
    echo
    echo "    Did you mean one of these words?"
    echo
    suggestions="$(dict -m -s lev -d "$DB" -- "$word" 2>/dev/null \
                   | grep -E '^[[:space:]]*'"$DB"':' \
                   | sed -E 's/^[[:space:]]*'"$DB"':[[:space:]]*//' \
                   | head -20)"
    if [[ -n "$suggestions" ]]; then
      printf '%s\n' "$suggestions" | sed 's/^/        /'
    else
      echo "        (no similar words found)"
    fi
  fi

  echo
  echo
  read -r -p "    Press Enter to look up another word..."
done
