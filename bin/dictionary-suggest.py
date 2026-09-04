#!/usr/bin/env python3
"""Suggest dictionary words close to a misspelling.

    dictionary-suggest.py <dictionary-file> <word>

Prints one suggestion per line, closest first.

Prefix matching alone is not enough here: a child who types "elefant" or
"dinasaur" has the start right and a vowel wrong, so the useful suggestion is
the one a letter or two away, not the one that shares the most letters up
front. That means edit distance, which difflib does well enough.

Candidates are narrowed to the same first letter and a similar length before
scoring, which keeps a miss fast on a Pi -- roughly a thousand comparisons
instead of fifty thousand.
"""

import difflib
import sys

MAX_SUGGESTIONS = 8
LENGTH_WINDOW = 3
MIN_SIMILARITY = 0.6


def main():
  if len(sys.argv) != 3:
    sys.exit(f"usage: {sys.argv[0]} <dictionary-file> <word>")

  dict_file, word = sys.argv[1], sys.argv[2].lower()
  if not word:
    return

  candidates = set()
  with open(dict_file, encoding="utf-8") as f:
    for line in f:
      if line.startswith("#"):
        continue
      entry = line.split("\t", 1)[0]
      if entry[:1] == word[:1] and abs(len(entry) - len(word)) <= LENGTH_WINDOW:
        candidates.add(entry)

  for match in difflib.get_close_matches(
      word, candidates, n=MAX_SUGGESTIONS, cutoff=MIN_SIMILARITY):
    print(match)


if __name__ == "__main__":
  main()
