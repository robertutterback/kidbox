#!/usr/bin/env bash
# Run every example program printed in the turtle book and render what the
# Logo ones draw. Two jobs in one pass, because they share the run:
#
#   1. Test: a program that errors, hangs, or produces no picture fails the
#      script. The book is only trustworthy if every listing actually works.
#   2. Figures: each Logo drawing is exported to doc/figures/<name>.pdf, and
#      each BASIC program's screen output to doc/figures/basic-<name>.txt,
#      for the book to include.
#
# Runs UCBLogo under Xvfb, so a desktop is not needed. Needs: ucblogo,
# pcbasic, xvfb-run, xdotool, ImageMagick, ghostscript, pdfcrop. Not meant
# for the Pi.
#
# A Logo program that reads the keyboard gets a <name>.keys file beside it
# listing the keys to press (xdotool key names, space separated).
#
# Usage: check-programs.sh [name ...]   run only the named programs
#        KEEP_WORK=1 check-programs.sh  leave the scratch directory behind
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGO_DIR="$ROOT/doc/programs/logo"
BASIC_DIR="$ROOT/doc/programs/basic"
FIG_DIR="$ROOT/doc/figures"
WORK="$(mktemp -d)"
if [[ -n "${KEEP_WORK:-}" ]]; then
  echo "scratch files in $WORK"
else
  trap 'rm -rf "$WORK"' EXIT
fi

# With arguments, only those programs run.
ONLY=("$@")
wanted() {
  (( ${#ONLY[@]} == 0 )) && return 0
  local n
  for n in "${ONLY[@]}"; do [[ "$n" == "$1" ]] && return 0; done
  return 1
}

# Programs whose figure must be a screenshot of the real window rather than
# the EPS export: the export draws outlines only (no FILL) and ignores
# SETLABELHEIGHT.
SCREENSHOT=(fill name-sign)

failures=0
fail() { echo "FAIL  $*"; failures=$((failures + 1)); }

# Runs one Logo program inside Xvfb. Arguments: run file, log file, keys file
# or "", screenshot file or "". Starts Logo in the background so keys can be
# sent and the window photographed while the drawing is still up.
cat > "$WORK/run-one.sh" <<'WRAP'
#!/usr/bin/env bash
run="$1"; log="$2"; keys="$3"; shot="$4"
ucblogo "$run" >/dev/null 2>&1 &
pid=$!
if [[ -n "$keys" ]]; then
  win="$(xdotool search --sync --name "Berkeley Logo" | head -1)"
  sleep 1
  xdotool windowfocus --sync "$win"
  for k in $(cat "$keys"); do xdotool key --delay 120 "$k"; done
fi
# Wait for the marker line (up to a minute), then photograph if asked.
for _ in $(seq 600); do
  grep -qs '^CHECK-RESULT' "$log" && break
  sleep 0.1
done
if [[ -n "$shot" ]]; then
  sleep 0.5
  import -window root "$shot"
fi
wait "$pid"
WRAP
chmod +x "$WORK/run-one.sh"

# ---------------------------------------------------------------- Logo ----
for prog in "$LOGO_DIR"/*.lg; do
  name="$(basename "$prog" .lg)"
  wanted "$name" || continue
  log="$WORK/$name.log"
  eps="$WORK/$name.eps"

  keys=""
  [[ -f "$LOGO_DIR/$name.keys" ]] && keys="$LOGO_DIR/$name.keys"
  shot=""
  case " ${SCREENSHOT[*]} " in
    *" $name "*) shot="$WORK/$name.png" ;;
  esac

  # White background and black pen so the figures print well; the kid's
  # screen is set up by content/logo/welcome.lg instead. Everything the
  # program prints goes to the log, then a marker line carries the error
  # (an empty list when there was none). For a screenshot the turtle is
  # hidden (the EPS export never shows it either) and Logo lingers so the
  # wrapper can photograph the window.
  {
    echo 'setbg 7 setpc 0 cs'
    echo "openwrite \"$log"
    echo "setwrite \"$log"
    echo "catch \"error [load \"$prog]"
    echo 'print (list "CHECK-RESULT error)'
    echo 'setwrite []'
    echo "close \"$log"
    [[ -n "$shot" ]] && echo 'ht wait 240'
    echo "epspict \"$eps"
    echo 'bye'
  } > "$WORK/$name.run.lg"

  # GTK prefers Wayland when WAYLAND_DISPLAY is set (WSLg sets it), and
  # would then open the window on the desktop instead of in Xvfb.
  env -u WAYLAND_DISPLAY GDK_BACKEND=x11 \
    timeout 120 xvfb-run -a -s "-screen 0 1024x768x24" \
    "$WORK/run-one.sh" "$WORK/$name.run.lg" "$log" "$keys" "$shot" \
    >/dev/null 2>&1 || true

  if [[ ! -f "$log" ]] || ! grep -q '^CHECK-RESULT' "$log"; then
    fail "$name: did not finish (timeout or crash)"; continue
  fi
  result="$(grep '^CHECK-RESULT' "$log")"
  if [[ "$result" != "CHECK-RESULT []" ]]; then
    fail "$name: ${result#CHECK-RESULT }"; continue
  fi

  # Program output (if any) becomes a text figure.
  if grep -qv '^CHECK-RESULT' "$log"; then
    grep -v '^CHECK-RESULT' "$log" > "$FIG_DIR/$name.txt"
  fi

  # A stale figure in the other format would shadow the new one, since the
  # book includes figures without an extension.
  if [[ -n "$shot" ]]; then
    # The Logo window sits at +50+50 and is 820x430: a menu bar, then the
    # white canvas, then the black text pane. Cut out the canvas, shave off
    # the grey GTK frame around it (otherwise trim stops there and keeps
    # the whole white canvas), and trim the white around the drawing.
    convert "$shot" -crop 820x322+50+76 +repage -shave 6x6 +repage \
      -fuzz 3% -trim +repage -bordercolor white -border 12 "$FIG_DIR/$name.png"
    rm -f "$FIG_DIR/$name.pdf"
    echo "ok    $name -> figures/$name.png (screenshot)"
    continue
  fi
  rm -f "$FIG_DIR/$name.png"

  # A drawing becomes a PDF figure. Logo2PS paints the whole window with
  # the background colour first; drop that block so pdfcrop can find the
  # real bounding box, and so that a program which only prints (leaving
  # nothing but the background) is recognised as having no drawing.
  awk 'BEGIN{skip=0}
       /^gsave$/ && !done {skip=1}
       skip {if (/fill grestore$/) {skip=0; done=1}; next}
       {print}' "$eps" > "$WORK/$name.nobg.eps"
  if grep -qE 'lineto|arc$|\) show' "$WORK/$name.nobg.eps"; then
    gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -dEPSCrop \
      -o "$WORK/$name.full.pdf" "$WORK/$name.nobg.eps"
    pdfcrop --margins 6 "$WORK/$name.full.pdf" "$FIG_DIR/$name.pdf" >/dev/null
    echo "ok    $name -> figures/$name.pdf"
  else
    echo "ok    $name (no drawing)"
  fi
done

# --------------------------------------------------------------- BASIC ----
for prog in "$BASIC_DIR"/*.BAS; do
  name="$(basename "$prog" .BAS)"
  wanted "$name" || continue
  input="$BASIC_DIR/$name.in"
  args=()
  [[ -f "$input" ]] && args+=(--input="$input")

  # Screen output goes through PC-BASIC's own --output: when stdout is a
  # pipe or file, a program with several seconds of PLAY pauses came out
  # empty, while --output always had the lot.
  out="$WORK/$name.out"
  if ! timeout 120 pcbasic --interface=none --quit=True "${args[@]}" \
        --output="$out" --run="$prog" > "$WORK/$name.stderr" 2>&1; then
    fail "$name: pcbasic exited non-zero ($(head -1 "$WORK/$name.stderr"))"; continue
  fi
  tr -d '\r' < "$out" > "$FIG_DIR/basic-$name.txt"
  # GW-BASIC reports problems as e.g. "Syntax error in 30".
  if grep -qiE ' error( in [0-9]+)?$' "$FIG_DIR/basic-$name.txt"; then
    fail "$name: $(grep -iE ' error' "$FIG_DIR/basic-$name.txt" | head -1)"; continue
  fi
  echo "ok    $name -> figures/basic-$name.txt"
done

echo
if (( failures > 0 )); then
  echo "$failures program(s) failed"; exit 1
fi
echo "all programs ran cleanly"
