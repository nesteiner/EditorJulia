module EditorJulia

include("Terminal.jl")
include("Config.jl")
include("Row.jl")
include("cmds/Commands.jl")
include("Editor.jl")

include("cmds/echo.jl")
include("cmds/quit.jl")
include("cmds/help.jl")
include("cmds/open.jl")
include("cmds/save.jl")
function acorn(filename::String; rel::Bool=true)
    ed = Editor()

    openFile!(ed, filename)

    setStatusMessage!(ed, "HELP: ctrl-p: command mode | ctrl-q: quit | ctrl-s: save")

    REPL.Terminals.raw!(ed.terminal, true)


    try
        while !ed.quit
          refreshScreen!(ed)
          processKeypress(ed)
        end
    catch ex
      quit(ed, force=true)
      rethrow(ex) # Don't reset stacktrace
    end


    REPL.Terminals.raw!(ed.terminal, false)
end

function acorn()
  if length(ARGS) > 0
    filename = ARGS[1]
    acorn(filename, rel=false)
  else
    println("No filename detected.")
  end
end

export acorn

end # module

