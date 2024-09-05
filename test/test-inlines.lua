local pandoc = require 'pandoc'
local jog = require 'jog'

local function tag_or_type (x)
  return x.tag or pandoc.utils.type(x)
end

describe('Inlines traversal', function()
  describe('modifying strings', function()
    it('should allow destructive modifications', function()
      local inlns = pandoc.Inlines{pandoc.Str('test')}
      local result = jog(inlns, {Str = function(s) s.text = 'hi' end})
      assert.same(pandoc.Inlines{pandoc.Str('hi')}, result)
    end)

    it('should include the context', function()
      local inlns = pandoc.Inlines{pandoc.Str('test')}
      local fn = function (s, context)
        s.text = table.concat(context:map(tag_or_type), '->')
      end
      local result = jog(inlns, {Str = fn, context = true})
      local context_string = 'Inlines->Str'
      assert.same(pandoc.Inlines{pandoc.Str(context_string)}, result)
    end)
  end)
end)
