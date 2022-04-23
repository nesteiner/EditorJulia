function commandEcho(editor::Editor, args::String)
    setStatusMessage!(editor, args)
end

insertCommand!(:echo, commandEcho,
           help="echo <msg>: set the status message to <msg>")