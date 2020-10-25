
default: paper.pdf paper.docx

paper.docx: paper.md
	pandoc $< -s -o $@

paper.pdf: paper.md
	pandoc $< -s -o $@

.PHONY: clean paper.md

clean:
	 rm -f paper.docx paper.pdf
