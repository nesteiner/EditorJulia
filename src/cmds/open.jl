function commandOpen(editor::Editor, args::T) where T <: AbstractString
    if args == ""
        openFile!(editor)
    else
        openFile!(editor, args)
    end
    
end

insertCommand!(:open, commandOpen, help="open: open a file")