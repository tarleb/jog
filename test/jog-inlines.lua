local pandoc = require 'pandoc'
local jog = require 'jog'

local function tag_or_type (x)
  return x.tag or pandoc.utils.type(x)
end

local function deepclone_list (x)
  local new = x:map(function (item) return item:clone() end)
  return setmetatable(new, getmetatable(x))
end

describe('Inline traversal', function()
  describe('modifying strings', function()
    it('should allow destructive modifications', function()
      local emph = pandoc.Emph('test')
      local result = jog(emph, {Str = function(s) s.text = 'hi' end})
      assert.equals(pandoc.Emph('hi'), result)
    end)

    it('should include the context', function()
      local strong = pandoc.Strong('test')
      local fn = function (s, context)
        s.text = table.concat(context:map(tag_or_type), '->')
      end
      local result = jog(strong, {Str = fn})
      assert.equals(pandoc.Strong('Strong->Inlines->Str'), result)
    end)
  end)

  describe('Inlines lists', function ()
    local sample = pandoc.Inlines{
      'This', pandoc.Space(), 'is', pandoc.Space(), pandoc.Emph('pandoc!')
    }

    it('does not modify the list with a read-only filter', function ()
      local numstr = 0 -- number of Str elements
      local fn = function () numstr = numstr + 1 end
      local result = jog(deepclone_list(sample), {Str = fn})
      assert.equals(sample, result)
      -- make sure the filter function ran
      assert.equals(numstr, 3)
    end)

    it('works if the Inline function returns an element', function ()
      local numInline = 0 -- number of Inline elements
      local fn = function (inln)
        numInline = numInline + 1
        return inln
      end
      local result = jog(deepclone_list(sample), {Inline = fn})
      -- There are six Inline elements in the `sample` object
      assert.equals(numInline, 6)
      assert.equals(sample, result)
    end)

    it('works if the Inline function returns a table', function ()
         local numInline = 0 -- number of Inline elements
         local fn = function (inln)
           numInline = numInline + 1
           return {inln}
         end
         local result = jog(deepclone_list(sample), {Inline = fn})
         -- There are six Inline elements in the `sample` object
         assert.equals(numInline, 6)
         assert.equals(sample, result)
    end)

    it('works if the Inline function returns a List', function ()
         local numInline = 0 -- number of Inline elements
         local fn = function (inln)
           numInline = numInline + 1
           return pandoc.List{inln}
         end
         local result = jog(deepclone_list(sample), {Inline = fn})
         -- There are six Inline elements in the `sample` object
         assert.equals(numInline, 6)
         assert.equals(sample, result)
    end)

    it('works if the Inline function returns an Inlines list', function ()
      local numInline = 0 -- number of Inline elements
      local fn = function (inln)
        numInline = numInline + 1
        return pandoc.Inlines{inln}
      end
      local result = jog(deepclone_list(sample), {Inline = fn})
      -- There are six Inline elements in the `sample` object
      assert.equals(numInline, 6)
      assert.equals(sample, result)
    end)
  end)
end)
