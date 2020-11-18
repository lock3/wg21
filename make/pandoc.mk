# The root of the document directory.
#
# FIXME: This path is relative to the file including it. It would be nice
# if we did an outward search for the root directory of the doc repository.
root = ..

# Top-level resources.
docx_path = $(root)/docx
bib_path = $(root)/bib
csl_path = $(root)/csl
lua_path = $(root)/lua

# Flags controlling the bibliography.
bib_flags = --citeproc --csl $(csl_path)/ieee.csl \
				    --bibliography paper.bib --bibliography $(bib_path)/wg21.bib

# Miscellanous rewrite filters
lua_flags = -L $(lua_path)/ref.lua

common_flags = -f markdown+citations -s -N $(bib_flags) $(lua_flags)

# Use this for compiling LaTex/PDF documents.
latex_flags = -t latex $(common_flags)

# Use this for compiling docx documents.
docx_flags = -t docx $(common_flags) --reference-doc=$(docx_path)/style.docx
