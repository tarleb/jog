--- jog.lua – walk the pandoc AST with context, and with inplace modification.
---
--- Copyright: © 2021–2024 Albert Krewinkel
--- License: MIT – see LICENSE for details

local List = require 'pandoc.List'

local debug_getmetatable = debug.getmetatable

--- Get the element type; like pandoc.utils.type, but faster.
local function ptype (x)
  local mt = debug_getmetatable(x)
  if mt then
    local name = mt.__name
    return name or type(x)
  else
    return type(x)
  end
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
  end
  local tp = ptype(result)
  if tp == 'Inline' then
    return pandoc.Inlines{result}
  elseif tp == 'Block' then
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
  elseif tp == 'TableHead' or tp == 'TableFoot' then
    element.rows    = jog(element.rows, filter, context)
  elseif tp == 'Blocks' or tp == 'Inlines' then
    local pos = 0
    local item_index = 1
    local filtered_items = element:map(function (x)
        return jog(x, filter, context)
    end)
    local sublist_or_element = filtered_items[item_index]
    while sublist_or_element ~= nil do
      local tp = ptype(sublist_or_element)
      if listy_type[tp] or tp == 'table' then
        local subelement_index = 1
        local subsubelement = sublist_or_element[subelement_index]
        while subsubelement ~= nil do
          pos = pos + 1
          element[pos] = subsubelement
          subelement_index = subelement_index + 1
          subsubelement = sublist_or_element[subelement_index]
        end
      else
        pos = pos + 1
        element[pos] = sublist_or_element
      end
      item_index = item_index + 1
      sublist_or_element = filtered_items[item_index]
    end
    -- unset remaining indices if the new list is shorter than the old
    pos = pos + 1
    while element[pos] do
      element[pos] = nil
      pos = pos + 1
    end
  elseif tp == 'List' then
    local i, item = 1, element[1]
    while item do
      element[i] = jog(item, filter, context)
      i, item = i+1, element[i+1]
    end
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

local function get_filter_function(element, filter, tp)
  local result = nil
  if non_joggable_types[tp] or tp == 'table' then
    return nil
  elseif tp == 'Block' then
    return filter[element.tag] or filter.Block
  elseif tp == 'Inline' then
    return filter[element.tag] or filter.Inline
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
    local fn = get_filter_function(element, filter, tp)
    element = recurse(element, filter, context, tp)
    result = run_filter_function(fn, element, context)
  end

  context:remove() -- remove this element from the context
  return result
end

--- Add `jog` as a method to all pandoc AST elements
-- This uses undocumented features and might break!
local function add_method(funname)
  funname = funname or 'jog'
  pandoc.Space()          -- init metatable 'Inline'
  pandoc.HorizontalRule() -- init metatable 'Block'
  pandoc.Meta{}           -- init metatable 'Pandoc'
  pandoc.Pandoc{}         -- init metatable 'Pandoc'
  pandoc.Blocks{}         -- init metatable 'Blocks'
  pandoc.Inlines{}        -- init metatable 'Inlines'
  pandoc.Cell{}           -- init metatable 'pandoc Cell'
  pandoc.Row{}            -- init metatable 'pandoc Row'
  pandoc.TableHead{}      -- init metatable 'pandoc TableHead'
  pandoc.TableFoot{}      -- init metatable 'pandoc TableFoot'
  local reg = debug.getregistry()
  List{
    'Block', 'Inline', 'Pandoc',
    'pandoc Cell', 'pandoc Row', 'pandoc TableHead', 'pandoc TableFoot'
  }:map(
    function (name)
      if reg[name] then
        reg[name].methods[funname] = jog
      end
    end
       )
  for name in pairs(listy_type) do
    if reg[name] then
      reg[name][funname] = jog
    end
  end
  if reg['Meta'] then
    reg['Meta'][funname] = jog
  end
end

local mt = {
  __call = function (_, ...)
    return jog(...)
  end
}

local M = setmetatable({}, mt)
M.jog = jog
M.add_method = add_method

return M
