function commandQuit(ed::Editor, args::String)
    quit(ed, force=strip(args) == "!")
end

insertCommand!(:quit, commandQuit,
           help="quit [!]: quit acorn. run 'quit !' to force quit")