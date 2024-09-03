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

local function recurse (element, filter, context)
  local tag = element.tag
  local tp = ptype(element)
  if leaf_node_tags[tag] then
    -- do nothing, can traverse any deeper
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
  elseif tp == 'Row' then
    element.cells    = jog(element.cells, filter, context)
  elseif List{'TableHead', 'TableFoot'}:includes(tp) then
    element.rows    = jog(element.rows, filter, context)
  else
    error("Don't know how to traverse " .. (element.t or tp))
  end
  return element
end

--- Checks whether the object is a list type or a plain table
local function is_listish (x)
  local tp = ptype(x)
  return tp == 'Blocks'
    or tp == 'Inlines'
    or tp == 'List'
    or tp == 'table'
end

--- Concatenate all items into the given target table.
local function concat_into(items, target)
  -- unset all numerical indices
  local orig_len = #target
  local pos = 0
  for _, sublist_or_element in ipairs(items) do
    if is_listish(sublist_or_element) then
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

--- Partially applied version of `jog`; 
local apply_jog = function (filter, context)
  return function (element)
    return jog(element, filter, context)
  end
end

local non_joggable_types = {
  ['Attr'] = true,
  ['boolean'] = true,
  ['nil'] = true,
  ['number'] = true,
  ['string'] = true,
}

jog = function (element, filter, context)
  context = context or List{}
  context:insert(element)
  local tp = ptype(element)
  local result = nil
  if non_joggable_types[tp] then
    result = element
  elseif tp == 'table' then
    for key, value in pairs(element) do
      element[key] = jog(value, filter, context)
    end
    result = element
  elseif tp == 'Block' then
    element = recurse(element, filter, context)
    local fn = filter[element.t] or filter.Block
    result = run_filter_function(fn, element, context)
  elseif tp == 'Blocks' then
    element = element:map(apply_jog(filter, context))
    result = run_filter_function(filter.Blocks, element, context)
  elseif tp == 'Inline' then
    element = recurse(element, filter, context)
    local fn = filter[element.t] or filter.Inline
    result = run_filter_function(fn, element, context)
  elseif tp == 'Inlines' then
    local results = element:map(apply_jog(filter, context))
    concat_into(results, element)
    result = run_filter_function(filter.Inlines, element, context)
  elseif tp == 'List' then
    element = element:map(apply_jog(filter, context))
    result = run_filter_function(filter.List,element, context)
  elseif tp == 'Meta' then
    for key, value in pairs(element) do
      element[key] = jog(value, filter, context)
    end
    result = run_filter_function(filter.Meta, element, context)
  elseif tp == 'Pandoc' then
    element.meta = jog(element.meta, filter, context)
    element.blocks = jog(element.blocks, filter, context)
    result = run_filter_function(filter.Pandoc, element, context)
  elseif List{'TableHead', 'TableFoot', 'Row', 'Cell'}:includes(tp) then
    element = recurse(element, filter, context)
    result = run_filter_function(filter[tp:gsub('^pandoc ', '')], element, context)
  else
    warn("Don't know how to handle element ", tostring(element),
         ' of type ', tp, '\n')
    result = element
  end

  context:remove() -- remove this element from the context
  return result
end

return jog
