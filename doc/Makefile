# kidbook Makefile
# Builds a half-letter PDF and an imposed booklet PDF (letter paper, fold + staple)

TEX      := kidbook
PDF      := $(TEX).pdf
BOOKLET  := $(TEX)-booklet.pdf

LATEX    := pdflatex
LATEX_OPTS := -interaction=nonstopmode -halt-on-error

.PHONY: all pdf booklet clean distclean

all: booklet

pdf: $(PDF)

$(PDF): $(TEX).tex
	$(LATEX) $(LATEX_OPTS) $(TEX).tex
	$(LATEX) $(LATEX_OPTS) $(TEX).tex

# Requires pdfjam (TeX Live extra utils on many distros)
booklet: pdf
	pdfjam --booklet true --landscape --paper letterpaper $(PDF) -o $(BOOKLET)

clean:
	rm -f *.aux *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz

distclean: clean
	rm -f $(PDF) $(BOOKLET)
