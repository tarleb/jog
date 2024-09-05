jog
===

Traverse the pandoc AST; just like `walk`, but with element
context and modified semantics.

Features
--------

- **Mutability semantics**: Jog embraces mutability. It is not
  necessary to `return` a new element, modifications to the
  element are kept automatically.

  A filter to convert all strings to uppercase

  ``` lua
  { Str = function (str)
      str.text = str.text:upper()
      return str
    end
  }
  ```

  could be written without the `return` when using `jog`

  ``` lua
  { Str = function (str)
      str.text = str.text:upper()
    end
  }
  ```

- **Context**: Filter functions sometimes depend on the context in
  which the element is seen. Jog allows to enable element contexts
  by setting the `context` field in the filter to `true`. The
  context, i.e., a list of all parent element, is passed to the
  filter function as a second argument.

  E.g., the below filter prints the type of all context elements
  to stdout:

  ``` lua
  local jog = require 'jog'

  --- Return the tag (e.g., `Str`) or type (e.g. `Meta`) of an element.
  local function tag_or_type (x)
      return x.t or pandoc.utils.type(x)
  end

  -- Lua filter to print the context of all Str elements.
  local print_context = {
    context = true,                 -- enable element contexts
    Str = function (inln, context)
      print(table.concat(context:map(tag_or_type), ', '))
    end
  }
  function Pandoc (doc)
    return jog(doc, print_context)
  end
  ```

  Running the above code on the Markdown document `Let's *jog*!`
  would yield

  ```
  Pandoc, Blocks, Para, Inlines, Str
  Pandoc, Blocks, Para, Inlines, Emph, Inlines, Str
  ```

- **More elements to filter on**: Beside the normal `walk` filter
  functions, `jog` also supports filtering on `List` elements and
  on table objects such as `Cell`, `Row`, `TableHead`,
  `TableFoot`.

  ``` lua
  -- count table cells
  local ncells = 0
  local cellcounter = {
    Cell = function (cell)
      ncells = ncells + 1
    end
  }
  jog(my_table, cellcounter)
  -- `ncells` now contains the number of cells
  ```

Usage
-----

Download [`jog.lua`][joglua] and place where pandoc's Lua
interpreter can find it. After that it can be *require*d as any
other Lua library:

``` lua
local jog = require 'jog'
```

The library defines a function `jog` to traverse a given object:

``` lua
jog.jog(ast_element, filter)
```

For convenience, the library object itself can also be used as a
function, meaning the above can be shortened to `jog(ast_element,
filter)`.

### Adding `jog` methods to AST objects

Run `jog.add_method([method_name])` to add a `jog` method to all
"joggable" pandoc AST Lua objects:

``` lua
local jog = require 'jog'
jog.add_method()
pandoc.Pandoc{'Test'}:jog(my_filter)
```

[joglua]: https://raw.githubusercontent.com/tarleb/jog/main/jog.lua

### Configuration

How to trot along the AST can be configured by setting fields in
the filter.

- `context`: setting this to a truthy value will pass the element
  context as a second argument to all filter functions.

  Example:

  ``` lua
  local filter = {
    context = true,
    Inline = function (inln, context)
      -- ...
    end,
  }
  ```

- `traverse`: sets the traversal order. The normal traversal is
  *depth-first*. Set this to `topdown` to let nodes closer to the
  root be filtered first. Filter functions can return `false` as a
  second return value to signal to jog that it should not act on
  subelements below the current node.

  Example:

  ``` lua
  local filter = {
    traverse = 'topdown',
    Inline = function (inln, context)
      -- ...
      return inln, false   -- don't filter the subelements
    end,
  }
  ```
