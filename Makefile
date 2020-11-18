
# Flags controlling the bibliography.
bib_flags = --citeproc --csl ieee.csl \
				    --bibliography paper.bib --bibliography wg21.bib

# Miscellanous rewrite filters
lua_flags = -L ref.lua

common_flags = -f markdown+citations -s -N $(bib_flags) $(lua_flags)
latex_flags = -t latex $(common_flags)
# docx_flags = -t docx $(common_flags) --reference-doc=$(docx_path)/style.docx

default: paper.pdf

# paper.docx: paper.md
# 	pandoc $(docx_flags) -o $@ $<

paper.pdf: paper.md
	pandoc $(latex_flags) -o $@ $<

.PHONY: clean paper.md

clean:
	 rm -f paper.docx paper.pdf
