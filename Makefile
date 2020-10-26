
default: paper.pdf paper.docx

paper.docx: paper.md
	pandoc $< -s -o $@

pandoc_latexflags=-f markdown -t latex -s -N -L ref.lua

paper.pdf: paper.md
	pandoc $< ${pandoc_latexflags} -o $@

.PHONY: clean paper.md

clean:
	 rm -f paper.docx paper.pdf
