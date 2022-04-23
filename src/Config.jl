mutable struct Parameter{T}
  value     ::  T
  validate  ::  Union{Function, Nothing}
  desc      ::  String
end

validate(p::Parameter) = isnothing(p.validate) ? true : p.validate(p.value)

function set!(p::Parameter, x)
  old_val = p.value

    # Correct type?
  try
      p.value = x
  catch Exception
      p.value = old_val
      throw(ArgumentError("Invalid parameter assignment: $x"))
  end

  # Valid?
  if !validate(p)
      p.value = old_val
      throw(ArgumentError("Invalid parameter assignmnt: $x"))
  end
end

const CONFIG = Dict{Symbol, Parameter}()

function configSet!(sym::Symbol, x)
  # Check if parameter exists
    if !(sym in keys(CONFIG))
        throw(ArgumentError("No parameter named $sym"))
    end

    p = CONFIG[sym]
    set!(p, x)

    CONFIG[sym] = p
end

configGet(sym::Symbol) = CONFIG[sym].value
configDesc(sym::Symbol) = CONFIG[sym].desc
configIsParam(sym::Symbol) = sym in keys(CONFIG)

KEY_BINDING = Dict{UInt32, String}()

function removeKeyBinding!(c::Char)
  delete!(KEY_BINDING, UInt32(c) & 0x1f)
end

function setKeyBinding!(c::Char, s::String)
  KEY_BINDING[UInt32(c) & 0x1f] = s
end

function getKeyBinding(c::Char)
  get(KEY_BINDING, UInt32(c) & 0x1f, "")
end

isKeyBound(c::Char) = (UInt32(c) & 0x1f) in keys(KEY_BINDING)

CONFIG[:tab_stop] = Parameter{Int}(4, n-> n > 0 && n <= 16, "visual size of a tab in number of spaces")
CONFIG[:expandtab] = Parameter{Bool}(false, nothing, "if true, use spaces instead of tabs when pressing <tab>")
CONFIG[:status_fullpath] = Parameter{Bool}(false, nothing, "show full path to current file")

setKeyBinding!('s', "save")
setKeyBinding!('o', "open")
setKeyBinding!('f', "find")
setKeyBinding!('q', "quit")

