
default: paper.pdf paper.docx

paper.docx: paper.md
	pandoc $< -s -o $@

bib_flags=-C --csl ieee.csl --bibliography paper.bib --bibliography wg21.bib
lua_flags=-L ref.lua
pandoc_latexflags=-f markdown+citations -t latex -s -N ${bib_flags} ${lua_flags}

paper.pdf: paper.md
	pandoc $< ${pandoc_latexflags} -o $@

.PHONY: clean paper.md

clean:
	 rm -f paper.docx paper.pdf
