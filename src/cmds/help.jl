function commandHelp(editor::Editor, args::T) where T <: AbstractString
    if args == ""
        setStatusMessage!(editor, "type help <command> for command specific help")
        return
    end

    if Base.isidentifier(args)
        setStatusMessage!(editor, "help: '$args' is not a valid command name")
        return
    end

    sym = Symbol(args)
    helptext = ""

    if configIsParams(sym)
        helptext = configDesc(sym)
    elseif sym in keys(COMMANDS)
        helptext = COMMANDS[sym].help
    end

    if helptext == ""
        setStatusMessage!(editor, "no help document for '$args'")
    else
        setStatusMessage!(editor, helptext)
    end
end

insertCommand!(:help, commandHelp, help="type help <command> for command specific help")