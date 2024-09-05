local pandoc = require 'pandoc'
local List   = require 'pandoc.List'
local jog    = require 'jog'

--- Return the tag (e.g., `Str`) or type (e.g. `Meta`) of an element.
local function tag_or_type (x)
  return x.t or pandoc.utils.type(x)
end

describe('topdown traversals', function ()
  it('changes the traversal order', function ()
    local seen = List{}
    local filter = {
      traverse = 'topdown',
      Inline = function (inln)
        seen:insert(inln)
      end
    }
    local input = pandoc.Inlines(pandoc.Emph('hallo'))
    jog(input, filter)
    assert.same(List{'Emph', 'Str'}, seen:map(tag_or_type))
  end)

  it('stops the traversal if the second return value is `false`', function ()
    local seen = List{}
    local filter = {
      traverse = 'topdown',
      Inline = function (inln)
        seen:insert(inln)
        return inln, false
      end
    }
    local input = pandoc.Inlines(pandoc.Emph('hallo'))
    jog(input, filter)
    assert.same(List{'Emph'}, seen:map(tag_or_type))
  end)
end)
