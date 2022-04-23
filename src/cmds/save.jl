function commandSave(editor::Editor, args::T) where T <: AbstractString
    saveFile(editor, args)
end

insertCommand!(:save, commandSave, help="save: save the file")