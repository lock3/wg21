include ../make/pandoc.mk

default: pdf

pdf: paper.pdf

paper.pdf: paper.md
	pandoc $(latex_flags) -o $@ $<

latex: paper.tex

paper.tex: paper.md
	pandoc $(latex_flags) -t latex -o $@ $<

docx: paper.docx

paper.docx: paper.md
	pandoc $(docx_flags) -o $@ $<

json: paper.json

paper.json: paper.md
	pandoc $(common_flags) -t json -o $@ $<


.PHONY: pdf docx json clean paper.md

clean:
	 rm -f paper.pdf paper.docx
