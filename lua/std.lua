
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

-- Returns the first n character of `str`.
function first_chars(str, n)
  return string.sub(str.text, 1, n)
end

-- Returns the last n charactr of `str`.
function last_chars(str, n)
  return string.sub(str.text, #str.text - n, n)
end

--- Returns the substring without the first n characters.
function drop_first(str, n)
  str.text = string.sub(str.text, n + 1, #str.text)
end

--- Returns the substring without the last n characters.
function drop_last(str, n)
  str.text = string.sub(str.text, 1, #str.text - n)
end

-- Returns true if `first` starts with `mark`.
function starts_with_mark(first, mark)
  return first_chars(first, #mark) == mark
end

-- Returns true if `span` starts with the editing `mark`.
function starts_with(span, mark)
  return starts_with_mark(span.content[1], mark)
end

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

-- Rewrite the span by dropping the mark and inserting the class.
function transform_span(span, mark, xform)
  -- Strip the editing mark from the content.
  drop_first(span.content[1], #mark)

  -- Apply the transformation
  if xform == nil then
    return span
  end
  return xform(span)
end

-- Markup span as inserted.
function inserted(span)
  return latex_macro("added", span)
end

-- Markup span as deleted.
function deleted(span)
  return latex_macro("removed", span)
end

-- Transform spans of the form `[<k>text<k>]{}` where <k> is a formatting
-- mark into spans of the form `[text]`{.class=<c>} where <c> is the
-- corresponding class style. We currently support the following spans:
--
-- - [+text]{} becomes [text]{.ins} for inserted text
-- - [~text]{} becomes [text]{.del} for deleted text
-- - [^text]{} becomes [text]{.bnf} for grammar terms
function Span(s)
  ins = "+"
  del = "~"
  if starts_with(s, ins) then
    return transform_span(s, ins, inserted)
  elseif starts_with(s, del) then
    return transform_span(s, del, deleted)
  end
  return s
end

