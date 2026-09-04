#!/usr/bin/env bash
set -euo pipefail

# Interactive dictionary loop. Asks for a word, finds it in the dictionary
# file, and shows what it means.
#
# The dictionary is a plain tab-separated text file (word, part of speech,
# definition), so a lookup is one pass of awk. No dictd daemon, no dict
# client, and nothing that can fall back to a network server on a miss --
# which is what the earlier dictd version did, hanging on every typo.
#
# Press Enter on a blank line to quit back to the menu.

DICT_FILE="$HOME/kidbox/dictionary.txt"

print_header() {
  echo
  echo "    DICTIONARY"
  echo "    =========="
  echo
}

if [[ ! -f "$DICT_FILE" ]]; then
  echo "The dictionary file is missing: $DICT_FILE"
  read -r -p "Press Enter to go back to the menu..."
  exit 1
fi

while true; do
  clear
  print_header
  echo "    Type a word, then press Enter."
  echo "    (Press Enter on an empty line to quit.)"
  echo

  read -r -p "    Word: " word || exit 0

  # Fold to the form the file uses: lowercase, no surrounding spaces.
  word="$(printf '%s' "$word" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

  if [[ -z "$word" ]]; then
    break
  fi

  clear
  print_header

  # Compared as a string, not a pattern, so a word with punctuation in it
  # cannot turn into a regex.
  found="$(awk -F'\t' -v w="$word" '$1 == w {
             printf "    %s (%s)\n", $1, $2
             printf "      %s\n\n", $3
           }' "$DICT_FILE")"

  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
  else
    echo "    \"$word\" is not in this dictionary."
    echo
    # Offer near misses so a typo still goes somewhere useful.
    near="$("$HOME/bin/dictionary-suggest.py" "$DICT_FILE" "$word" \
            | sed 's/^/      /')"
    if [[ -n "$near" ]]; then
      echo "    Did you mean one of these?"
      echo
      printf '%s\n' "$near"
      echo
    fi
  fi

  read -r -p "    Press Enter to look up another word..."
done
