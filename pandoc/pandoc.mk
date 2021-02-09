## Pandoc make support
##
## This paper defines a bunch of flags that can be used to generate various
## flavors of output from a Markdown file.
##
## If the variable `main` is defined, this also creates a bunch of targets to
## enable uses like `make pdf` or `make docx`. The name `main` is the root name
## of the file, without extension, for which output is generated. This supports
## the following output formats.
##
##    - pdf
##    - docx
##    - tex (LaTeX)
##    - latex (same)
##    - json
##
## The tex, latex, and json targets are useful for debugging.
##
## This Makefile supports multisource builds in a kind of clumsy way. To
## start, we always assume that an input file `x.md` produces out of e.g.,
## `x.pdf`. In a multisource build, we need to provide a list of additional
## markdown files to be included with the top-level input. This can be done
## by defining the variable `parts`, which lists the files to be concatenated
## with the top-level input.
##
## Note that multisource builds need to be considered carefully because pandoc
## just concatenates the files. Your top-level input can't provide an outline
## for content to be injected (sadly)

# The root of the document directory. We assume this is installed in a
# subdirectory of the root.
file := $(realpath $(lastword $(MAKEFILE_LIST)))
path := $(realpath $(shell dirname $(file)))

# Top-level resources.
latex_path = $(path)/latex
docx_path = $(path)/docx
csl_path = $(path)/csl
lua_path = $(path)/lua

# Flags controlling citation. Use IEEE citation style by default.
bib_flags = --citeproc --csl $(csl_path)/ieee.csl

# LUA filters for common editing requirements. The lua_scripts variable is
# used for build rule dependencies.
lua_scripts = \
	$(lua_path)/ref.lua \
	$(lua_path)/std.lua
lua_flags = -L $(lua_path)/ref.lua -L $(lua_path)/std.lua

# Pandoc flags
pandoc_flags = -f markdown+citations+bracketed_spans+fenced_divs+escaped_line_breaks+multiline_tables

# Common flags
common_flags =  $(pandoc_flags) -s -N $(bib_flags) $(lua_flags)

# Use this for compiling LaTex/PDF documents.
latex_template = $(latex_path)/default.tex
latex_flags = -t latex --template ${latex_template} $(common_flags)

# Use this for compiling docx documents.
docx_style = $(docx_path)/style.docx
docx_flags = -t docx --reference-doc=$(docx_style) $(common_flags)

# Common build patterns.

%.pdf: %.md $(parts) $(latex_template) $(lua_scripts)
	pandoc $(latex_flags) -o $@ $< $(parts)

%.tex: %.md $(parts) $(latex_template) $(lua_scripts)
	pandoc $(latex_flags) -o $@ $< $(parts)

%.latex: %.tex

%.docx: %.md $(parts) $(docx_style) $(lua_scripts)
	pandoc $(docx_flags) -o $@ $< $(parts)

%.json: %.md $(parts) $(lua_scripts)
	pandoc $(common_flags) -t json -o $@ $< $(parts)

# Generate default phony targets.
ifdef main
.PHONY: pdf docx tex latex json
pdf: $(main).pdf
docx: $(main).docx
tex: $(main).tex
latex: $(main).tex
json: $(main).json

# Generate common output files to be removed with clean. Different tools
# can produce lots of different output. Try to clean up as much as possible.
pdf_files := $(main).pdf
docx_files := $(main).docx
pdflatex_tex_files := $(main).tex $(main).aux $(main).log
vscode_tex_files := $(main).fls $(main).fdb_latexmk $(main).synctex.gz
tex_files := $(pdflatex_tex_files) $(vscode_tex_files)
json_files := $(main).json
all_files := $(pdf_files) $(docx_files) $(tex_files) $(json_files)
endif

# Generate a default clean target.
.PHONY: clean
clean:
	rm -f $(all_files)

# Reset the default goal so it's determined by the including file.
.DEFAULT_GOAL :=
