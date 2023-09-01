# vdf.lua

This is a Lua implementation of [KeyValues](https://developer.valvesoftware.com/wiki/KeyValues) from valvesoftware.

# usages

## parse(str:string)

parsing VDF string into lua table structure

Preview:
```lua
local vdf = require("vdf")
local data = vdf.parse([[
"a"
{
  "key" "value"
}
]])
print(data.a.key) -- prints 'value'
```

## stringify(data:table,indent:string?,disableNewline:boolean?)

### pram1 data:table

lua table structure which should converted into VDF format

### pram2 indent:string? (default: "  ")

An indent-based string that is repeated based on its depth.
If you don't want to indent, provide a false

## pram3 disableNewline:boolean?

By default, stringify uses newlines, but if you don't want to, you can disable them by providing true

Preview:
```lua
local vdf = require("vdf")
local data = { item = { value = "5000", element = "true" } }
print(vdf.stringify(data))
--[[
it prints

"item"
{
  "value" "5000"
  "element" "true"
}
]]
```
