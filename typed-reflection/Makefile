include ../make/pandoc.mk

default: pdf

pdf: paper.pdf

paper.pdf: paper.md
	pandoc $(latex_flags) -o $@ $<

docx: paper.docx

paper.docx: paper.md
	pandoc $(docx_flags) -o $@ $<

.PHONY: pdf docx clean paper.md

clean:
	 rm -f paper.pdf paper.docx
