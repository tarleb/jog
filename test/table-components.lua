local pandoc = require 'pandoc'
local utils  = require 'pandoc.utils'
local List   = require 'pandoc.List'
local jog    = require 'jog'

local stringify = utils.stringify

local function make_sample_table()
  local simptbl = pandoc.SimpleTable(
    '', {'AlignDefault'}, {0}, {'col1'}, {{'x'}, {'y'}}
  )
  return utils.from_simple_table(simptbl)
end

describe('filtering of table components', function ()
  it('allows to filter on table cells', function ()
    local seen = List{}
    local filter = {
      Cell = function (cell)
        seen:insert(stringify(cell.content))
      end
    }
    jog(make_sample_table(), filter)
    assert.same(List{'col1', 'x', 'y'}, seen)
  end)

  it('allows to filter table rows', function ()
    local nrows = 0
    local filter = {
      Row = function (_)
        nrows = nrows + 1
      end
    }
    jog(make_sample_table(), filter)
    assert.same(3, nrows)
  end)

  it('allows to filter table heads', function ()
    local nrows = 0
    local filter = {
    TableHead = function (th)
      nrows = #th.rows
    end
    }
    jog(make_sample_table(), filter)
    assert.same(1, nrows)
  end)

  it('allows to filter table foots', function ()
    local nrows
    local filter = {
    TableFoot = function (tf)
      nrows = #tf.rows
    end
    }
    jog(make_sample_table(), filter)
    assert.same(0, nrows)
  end)
end)
