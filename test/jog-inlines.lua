local pandoc = require 'pandoc'
local jog = require 'jog'

local function tag_or_type (x)
  return x.tag or pandoc.utils.type(x)
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
end)
