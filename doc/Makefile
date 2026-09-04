# kidbox books
# Each book builds to a half-letter PDF and an imposed booklet PDF (letter
# paper, fold + staple).

BOOKS    := kidbook turtlebook

LATEX    := pdflatex
LATEX_OPTS := -interaction=nonstopmode -halt-on-error

.PHONY: all pdf booklet check clean distclean

all: booklet

pdf: $(BOOKS:=.pdf)
booklet: $(BOOKS:=-booklet.pdf)

# Three passes: the table of contents grows on the second pass and shifts
# every page number, so cross-references settle only on the third.
%.pdf: %.tex
	$(LATEX) $(LATEX_OPTS) $*.tex
	$(LATEX) $(LATEX_OPTS) $*.tex
	$(LATEX) $(LATEX_OPTS) $*.tex

# kidbook's whole look lives in a separate style file.
kidbook.pdf: kidstyle.sty

# The turtle book pulls its listings and pictures in from these directories.
turtlebook.pdf: $(wildcard programs/*/*) $(wildcard figures/*)

# Requires pdfjam (TeX Live extra utils on many distros)
%-booklet.pdf: %.pdf
	pdfjam --booklet true --landscape --paper letterpaper $< -o $@

# Run every program in programs/ and regenerate figures/ from them.
# Needs Xvfb, ucblogo and pcbasic on this machine; see the script.
check:
	../tools/check-programs.sh

clean:
	rm -f *.aux *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz

distclean: clean
	rm -f $(BOOKS:=.pdf) $(BOOKS:=-booklet.pdf)
