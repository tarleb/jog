local pandoc = require 'pandoc'
local jog = require 'jog'

local function tag_or_type (x)
  return x.tag or pandoc.utils.type(x)
end

describe('Blocks traversal', function()
  describe('modifying strings', function()
    it('should allow destructive modifications', function()
      local blks = pandoc.Blocks{pandoc.Para('test')}
      local result = jog(blks, {Str = function(s) s.text = 'hi' end})
      assert.same(pandoc.Blocks{pandoc.Para('hi')}, result)
    end)

    it('should include the context', function()
      local blks = pandoc.Blocks{pandoc.Plain('test')}
      local fn = function (s, context)
        s.text = table.concat(context:map(tag_or_type), '->')
      end
      local result = jog(blks, {Str = fn, context = true})
      local context_string = 'Blocks->Plain->Inlines->Str'
      assert.same(pandoc.Blocks{pandoc.Plain(context_string)}, result)
    end)
  end)
end)
