--- jog.lua – walk the pandoc AST with context, and with inplace modification.
---
--- Copyright: © 2021–2024 Albert Krewinkel
--- License: MIT – see LICENSE for details

local List = require 'pandoc.List'

local debug_getmetatable = debug.getmetatable

--- Get the element type; like pandoc.utils.type, but faster.
local function ptype (x)
  local mt = debug_getmetatable(x)
  return mt and mt.__name:gsub('pandoc ', '') or type(x)
end

--- Checks whether the object is a list type.
local listy_type = {
  Blocks = true,
  Inlines = true,
  List = true,
}

--- Function to traverse the pandoc AST.
local jog

local function run_filter_function (fn, element, context)
  if fn == nil then
    return element
  end

  local result = fn(element, context)
  if result == nil then
    return element
  elseif ptype(result) == 'Inline' then
    return pandoc.Inlines{result}
  elseif ptype(result) == 'Block' then
    return pandoc.Blocks{result}
  else
    return result
  end
end

--- Set of Block and Inline tags that are leaf nodes.
local leaf_node_tags = {
  Code = true,
  CodeBlock = true,
  HorizontalRule = true,
  LineBreak = true,
  Math = true,
  RawBlock = true,
  RawInline = true,
  Space = true,
  SoftBreak = true,
  Str = true,
}

--- Set of Block and Inline tags that have nested items in `.contents` only.
local content_only_node_tags = {
  -- Blocks with Blocks content
  BlockQuote = true,
  Div = true,
  Header = true,
  -- Blocks with Inlines content
  Para = true,
  Plain = true,
  -- Blocks with List content
  LineBlock = true,
  BulletList = true,
  OrderedList = true,
  DefinitionList = true,
  -- Inlines with Inlines content
  Cite = true,
  Emph = true,
  Link = true,
  Quoted = true,
  SmallCaps = true,
  Span = true,
  Strikeout = true,
  Strong = true,
  Subscript = true,
  Superscript = true,
  Underline = true,
  -- Inline with Blocks content
  Note = true,
}

--- Partially applied version of `jog`.
local apply_jog = function (filter, context)
  return function (element)
    return jog(element, filter, context)
  end
end

--- Concatenate all items into the given target table.
local function concat_into(items, target)
  -- unset all numerical indices
  local orig_len = #target
  local pos = 0
  for _, sublist_or_element in ipairs(items) do
    local tp = ptype(sublist_or_element)
    if listy_type[tp] or tp == 'table' then
      for _, element in ipairs(sublist_or_element) do
        pos = pos + 1
        target[pos] = element
      end
    else
      pos = pos + 1
      target[pos] = sublist_or_element
    end
  end
  -- unset remaining indices if the new list is shorter than the old
  for i = pos + 1, orig_len do
    target[i] = nil
  end
end

--- Apply the filter on the nodes below the given element.
local function recurse (element, filter, context, tp)
  tp = tp or ptype(element)
  local tag = element.tag
  if leaf_node_tags[tag] then
    -- do nothing, cannot traverse any deeper
  elseif tp == 'table' then
    for key, value in pairs(element) do
      element[key] = jog(value, filter, context)
    end
  elseif content_only_node_tags[tag] or tp == 'Cell' then
    element.content = jog(element.content, filter, context)
  elseif tag == 'Image' then
    element.caption = jog(element.caption, filter, context)
  elseif tag == 'Table' then
    element.caption = jog(element.caption, filter, context)
    element.head    = jog(element.head, filter, context)
    element.bodies  = jog(element.bodies, filter, context)
    element.foot    = jog(element.foot, filter, context)
  elseif tag == 'Figure' then
    element.caption = jog(element.caption, filter, context)
    element.content = jog(element.content, filter, context)
  elseif tp == 'Meta' then
    for key, value in pairs(element) do
      element[key] = jog(value, filter, context)
    end
  elseif tp == 'Row' then
    element.cells    = jog(element.cells, filter, context)
  elseif List{'TableHead', 'TableFoot'}:includes(tp) then
    element.rows    = jog(element.rows, filter, context)
  elseif listy_type[tp] then
    local results = element:map(apply_jog(filter, context))
    concat_into(results, element)
  elseif tp == 'Pandoc' then
    element.meta = jog(element.meta, filter, context)
    element.blocks = jog(element.blocks, filter, context)
  else
    error("Don't know how to traverse " .. (element.t or tp))
  end
  return element
end

local non_joggable_types = {
  ['Attr'] = true,
  ['boolean'] = true,
  ['nil'] = true,
  ['number'] = true,
  ['string'] = true,
}

local function get_filter_function(element, filter)
  local tp = ptype(element)
  local result = nil
  if non_joggable_types[tp] or tp == 'table' then
    return nil
  elseif tp == 'Block' then
    return filter[element.t] or filter.Block
  elseif tp == 'Inline' then
    return filter[element.t] or filter.Inline
  else
    return filter[tp]
  end
end

jog = function (element, filter, context)
  context = context or List{}
  context:insert(element)
  local tp = ptype(element)
  local result = nil
  if non_joggable_types[tp] then
    result = element
  elseif tp == 'table' then
    result = recurse(element, filter, context, tp)
  else
    local fn = get_filter_function(element, filter)
    element = recurse(element, filter, context, tp)
    result = run_filter_function(fn, element, context)
  end

  context:remove() -- remove this element from the context
  return result
end

return jog
