#!/usr/bin/env python3
"""Build content/dictionary.txt, the kid dictionary, from Simple English Wiktionary.

Run this on a development machine, not on the Pi -- it downloads ~6MB and the
result is committed to the repo, so the Pi only ever reads a text file.

    ./tools/build-dictionary.py

Why Simple English Wiktionary and not a Debian dict package: WordNet's glosses
are written for lexicographers ("a small domesticated carnivorous mammal") and
GCIDE's are from 1913. Simple English Wiktionary is written by hand for people
learning English, so its definitions are whole sentences a child can read --
"A triangle is a shape that has three sides and three angles."

The output is deliberately a plain tab-separated text file rather than a dictd
database. It needs no daemon, no dict client and no network at lookup time; it
can be read, grepped and edited by hand; and a kid who gets curious can open
the dictionary itself and see that it is just words in a file.
"""

import gzip
import io
import json
import re
import sys
import urllib.request
from pathlib import Path

# Machine-readable extraction of simple.wiktionary.org, produced by wiktextract.
SOURCE_URL = "https://kaikki.org/simplewiktionary/English/kaikki.org-dictionary-English.jsonl.gz"

# Ships with the profanity list used to filter the word list.
BLOCKLIST_URL = (
    "https://raw.githubusercontent.com/LDNOOBW/"
    "List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en"
)

OUT_PATH = Path(__file__).resolve().parent.parent / "content" / "dictionary.txt"

# Wiktionary labels senses by category, so the source tells us which ones to
# drop. This catches what is labelled; it is not a guarantee that nothing
# objectionable remains, which is why the output is a text file you can grep.
BAD_CATEGORIES = re.compile(
    r"vulgar|offensiv|slang|\bsex\b|swear|profan|taboo|slur", re.I)

# Lowercase words only: this drops proper nouns, abbreviations and the entries
# whose titles are punctuation or non-Latin script.
WORD_SHAPE = re.compile(r"^[a-z][a-z'-]{1,24}$")

# Enough senses to be useful, few enough to read aloud without scrolling.
MAX_SENSES_PER_WORD = 3
MAX_GLOSS_CHARS = 300

HEADER = """\
# The Kid Computer dictionary
#
# Format: word <TAB> part of speech <TAB> definition
# One line per sense, sorted by word. Edit or delete lines freely; the lookup
# script reads this file directly and nothing needs rebuilding.
#
# Rebuild from source with tools/build-dictionary.py
#
# Definitions come from Simple English Wiktionary
# (https://simple.wiktionary.org), used under CC BY-SA 4.0. Text has been
# filtered and truncated; see tools/build-dictionary.py for exactly how.
# Derived text remains under CC BY-SA 4.0.
"""


def fetch(url):
  print(f"[dict] Downloading {url}", file=sys.stderr)
  with urllib.request.urlopen(url, timeout=120) as r:
    return r.read()


def clean_gloss(text):
  text = " ".join(text.split())
  if len(text) <= MAX_GLOSS_CHARS:
    return text
  # Prefer cutting at a sentence end so a truncated definition still reads
  # like a sentence rather than trailing off.
  cut = text.rfind(". ", 0, MAX_GLOSS_CHARS)
  return text[:cut + 1] if cut > 60 else text[:MAX_GLOSS_CHARS].rstrip() + "..."


def gloss_is_blocked(gloss, blocklist):
  """True if a definition mentions a blocked word.

  Filtering headwords is not enough: a kid looking up an innocent word should
  not meet one in the definition body. Matched whole-token and exact, so this
  cannot reject a definition for containing an innocent substring.
  """
  return bool(set(re.findall(r"[a-z']+", gloss.lower())) & blocklist)


def is_blocked(word, blocklist):
  if word in blocklist:
    return True
  # Hyphenated headwords need each part checked: a short blocked word as one
  # component would slip past both the exact and the prefix test below.
  if set(re.findall(r"[a-z']+", word)) & blocklist:
    return True
  # Catch inflections ("...s", "...ing") without matching mid-word, which is
  # how filters end up rejecting Scunthorpe. Only stems of 5+ characters, so
  # short entries cannot swallow innocent words.
  return any(word.startswith(b) for b in blocklist if len(b) >= 5)


def main():
  blocklist = {
      w.strip().lower()
      for w in fetch(BLOCKLIST_URL).decode("utf-8").splitlines() if w.strip()
  }
  print(f"[dict] {len(blocklist)} blocked words", file=sys.stderr)

  raw = fetch(SOURCE_URL)
  print("[dict] Filtering...", file=sys.stderr)

  words = {}
  skipped = {"proper-noun": 0, "shape": 0, "blocked": 0, "category": 0,
             "gloss": 0, "no-gloss": 0, "over-cap": 0}

  with gzip.open(io.BytesIO(raw), "rt", encoding="utf-8") as f:
    for line in f:
      entry = json.loads(line)
      word = entry["word"].lower()

      if entry.get("pos") == "name":
        skipped["proper-noun"] += 1
        continue
      if not WORD_SHAPE.match(word):
        skipped["shape"] += 1
        continue
      if is_blocked(word, blocklist):
        skipped["blocked"] += 1
        continue

      pos = entry.get("pos", "word")
      for sense in entry.get("senses", []):
        glosses = sense.get("glosses") or []
        if not glosses:
          skipped["no-gloss"] += 1
          continue

        categories = " ".join(
            c.get("name", "") for c in sense.get("categories", []))
        if BAD_CATEGORIES.search(categories):
          skipped["category"] += 1
          continue

        gloss = clean_gloss(glosses[0])
        if gloss_is_blocked(gloss, blocklist):
          skipped["gloss"] += 1
          continue

        senses = words.setdefault(word, [])
        if len(senses) >= MAX_SENSES_PER_WORD:
          skipped["over-cap"] += 1
          continue
        senses.append((pos, gloss))

  OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
  total = 0
  with OUT_PATH.open("w", encoding="utf-8") as out:
    out.write(HEADER)
    for word in sorted(words):
      for pos, gloss in words[word]:
        out.write(f"{word}\t{pos}\t{gloss}\n")
        total += 1

  size_mb = OUT_PATH.stat().st_size / 1e6
  print(f"[dict] Wrote {OUT_PATH}", file=sys.stderr)
  print(f"[dict] {len(words)} words, {total} definitions, {size_mb:.1f} MB",
        file=sys.stderr)
  print(f"[dict] Skipped: {skipped}", file=sys.stderr)


if __name__ == "__main__":
  main()
