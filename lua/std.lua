-- Supports transformations for standard editing conventions including:
--
-- Noting the addition of text via [text]{.add}
-- Noting the removal of text via [text]{.rem}
-- Writing grammar terms [term]{.bnf}
-- BNF block  using :::{.bnf}
--
-- In the case of BNF blocks, the content is a two-level unordered list that
-- mixes normal text (grammar terms) and code blocks. For
-- example:
--
--    :::{.bnf}
--    - primary-expression:
--      - `(` expression `)`
--    :::
--
-- Note that this module has a Code transform that ensures that inline code
-- remains upright and is not italicized in these environments.
--
-- TODO: Add support for added and removed divs. That's going to be trickier
-- because it has to has to style "additively" through all content. This might
-- be easy for Latex and HTML (maybe), but Word doesn't really additive
-- formatting.
--
-- TODO: Add support for paragraph numbers. Steal the formatting from the
-- C++ standard for its pnum and listnum attributes. This will be tricker in
-- MS word and HTML.

-- Untility functions

--- Recusively describe a table.
function dumpTable(table, depth)
  if (depth > 200) then
    print("Error: Depth > 200 in dumpTable()")
    return
  end
  for k,v in pairs(table) do
    if (type(v) == "table") then
      print(string.rep("  ", depth)..k.." :: "..type(v)..":")
      dumpTable(v, depth+1)
    else
      print(string.rep("  ", depth)..k.." :: "..type(v)..": ", v)
    end
  end
end

function dump(table)
  print("::"..type(table)..":")
  dumpTable(table, 1)
end  

-- Returns the the index of value in table or 0 if not present.
function find(table, value)
  for i, v in ipairs(table) do
    if v == value then
      return i
    end
  end
  return 0
end

--- Returns true if table contains value. Otherwise false.
function contains(table, value)
  if find(table, value) ~= 0 then
    return true
  end
  return false
end

-- Latex helpers

-- Apply a unary macro to a span of text. This flattens the contents of the
-- span, so the macro should apply to a sequence of Strs.
function latex_macro (macro, span)
  c = {}
  table.insert(c, pandoc.RawInline("latex", "\\"..macro.."{"))
  for i, v in ipairs(span.content) do
    c[i + 1] = v
  end
  table.insert(c, pandoc.RawInline("latex", "}"))
  return pandoc.Span(c)
end

-- Wrap the contents of `div` in the latex environemnt.
--
-- TODO: We probably propagate other attributes from the original div to the new
-- div. Same for spans above.
function latex_environment(env, div)
  c = {
    pandoc.Para(pandoc.RawInline("latex", "\\begin{"..env.."}")),
    div.content[1],
    pandoc.Para(pandoc.RawInline("latex", "\\end{"..env.."}"))
  }
  return pandoc.Div(c)
end

-- Styling functions

-- Returns a Span marked as an insertion, depending on the output format of the
-- document.
function make_insertion(span)
  if FORMAT:match "latex" then
    return latex_macro("added", span)
  end
  if FORMAT:match "docx" then
    span.attributes["custom-style"] = "Added Char"
    return span
  end
end

-- Returns a Span marked as an deletion, depending on the output format of the
-- document.
function make_deletion(span)
  if FORMAT:match "latex" then
    return latex_macro("removed", span)
  end
  if FORMAT:match "docx" then
    span.attributes["custom-style"] = "Removed Char"
    return span
  end
end

-- Returns a Span marked as a grammar term, depending on the output format of
-- the document.
function make_grammar_term(span)
  if FORMAT:match "latex" then
    return latex_macro("grammarterm", span)
  end
  if FORMAT:match "docx" then
    span.attributes["custom-style"] = "Grammar Char"
    return span
  end
end

-- Returns a Div enclosing a block of BNF declarations.
function make_grammar_spec(div)
  if FORMAT:match "latex" then
    return latex_environment("bnf", div)
  end
end

-- Filter functions

-- Transform spans of the form `[<k>text<k>]{}` where <k> is a formatting
-- mark into spans of the form `[text]`{.class=<c>} where <c> is the
-- corresponding class style. We currently support the following spans:
--
-- - [+text]{} becomes [text]{.ins} for inserted text
-- - [~text]{} becomes [text]{.del} for deleted text
-- - [^text]{} becomes [text]{.bnf} for grammar terms
function Span(span)
  if (contains(span.classes, "add")) then
      return make_insertion(span)
  elseif (contains(span.classes, "rem")) then
    return make_deletion(span)
  elseif (contains(span.classes, "bnf")) then
    return make_grammar_term(span)
  else
    return span
  end
end

-- Make sure that inline code is formatted correctly (i.e., not italicized)...
-- to the extent possible (e.g., BNF).
--
-- TODO: Verify the this works in different environments.
function Code(code)
  if FORMAT:match "latex" then
    c = {
      pandoc.RawInline("latex", "\\textnormal{"),
      code,
      pandoc.RawInline("latex", "}")
    }
    return pandoc.Span(c)
  end
  return code
end

function Div(div)
  if contains(div.classes, "bnf") then
    return make_grammar_spec(div)
  end
  return div
end
