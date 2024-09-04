local pandoc = require 'pandoc'
local jog = require 'jog'

local function tag_or_type (x)
  return x.tag or pandoc.utils.type(x)
end

describe('Block traversal', function()
  describe('modifying strings', function()
    it('should allow destructive modifications', function()
      local para = pandoc.Para('test')
      local result = jog(para, {Str = function(s) s.text = 'hi' end})
      assert.equals(pandoc.Para('hi'), result)
    end)

    it('should include the context', function()
      local plain = pandoc.Plain('test')
      local fn = function (s, context)
        s.text = table.concat(context:map(tag_or_type), '->')
      end
      local result = jog(plain, {Str = fn})
      assert.equals(pandoc.Plain('Plain->Inlines->Str'), result)
    end)
  end)

  describe('jogging across BulletList elements', function ()
    it('should not modify the element', function ()
      local bl = pandoc.BulletList{
        {pandoc.Para 'one', pandoc.Para 'two'},
        {pandoc.Para 'three'},
      }
      -- ensure that the filter traverses all elements
      local numstr = 0 -- number of Str elements
      local fn = function () numstr = numstr + 1 end
      local result = jog(bl, {Str = fn})
      assert.equals(3, numstr)

      -- The list should have stayed the same.
      assert.equals(bl, result)
    end)
  end)
end)
