-- Appropriated from Stack Overflow:
-- https://stackoverflow.com/questions/54128461/how-to-use-latex-section-numbers-in-pandoc-cross-reference

local make_sections = (require 'pandoc.utils').make_sections
local section_numbers = {}

function populate_section_numbers (doc)
  function populate (elements)
    for _, el in pairs(elements) do
      if el.t == 'Div' and el.attributes.number then
        section_numbers['#' .. el.attr.identifier] = el.attributes.number
        populate(el.content)
      end
    end
  end

  populate(make_sections(true, nil, doc.blocks))
end

function resolve_section_ref (link)
  if #link.content > 0 or link.target:sub(1, 1) ~= '#' then
    return nil
  end
  local number = section_numbers[link.target];
  if number == nil then
    print("warning: unresolved reference", link.target)
    return pandoc.Str("Unresolved reference");
  end
  return pandoc.Link({pandoc.Str(number)}, link.target, link.title, link.attr)
end

return {
  {Pandoc = populate_section_numbers},
  {Link = resolve_section_ref}
}