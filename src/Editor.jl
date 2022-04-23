import REPL
import Printf
mutable struct Cursor
    x::Int
    y::Int
    rx::Int
end

mutable struct Editor
    rowOffset      :: Int
    colOffset      :: Int
    width          :: Int
    height         :: Int

    filename       :: String
    statusMessage  :: String
    statusTime     :: Float64
    dirty          :: Bool
    quit           :: Bool

    cursor         :: Cursor
    rows           :: Rows
    terminal       :: REPL.Terminals.TTYTerminal

    params         :: Dict{Symbol, Dict{Symbol, Any}}
end

function Editor()
    Editor(
        0,
        0,
        0,
        0,
        "",
        "",
        0,
        false,
        false,
        Cursor(1, 1, 1),
        Rows(),
        REPL.Terminals.TTYTerminal(get(ENV, "TERM", "dumb"), stdin, stdout, stderr),
        Dict{Symbol, Dict{Symbol, Any}}()
    )
end

function expandPath(filename::String)
    if filename == ""
        return ""
    else
        return abspath(expanduser(filename))
    end
end

function openFile!(editor::Editor, filename::String)
    try
        filename = expandPath(filename)
        !isfile(filename) && open(filename, "w")

        file = open(filename, "r")
        clearRows!(editor.rows)
        for line in eachline(file)
            insertRow!(editor.rows, line)
        end

        editor.filename = filename
        editor.cursor.x = 1
        editor.cursor.y = 1
        editor.dirty = false

        close(file)
    catch Exception e
        setStatusMessage!(editor, "Cannot open file $filename")
        close(file)
    end
end

function openFile!(editor::Editor)
    if editor.dirty
        confirm = prompt(editor, "There are unsaved changes. Open another file? [y/n]: ")
        if confirm != "y"
            setStatusMessage!(editor, "Open aborted")
            return
        end
    end

    filename = prompt(editor, "Open file: ")
    filename = expandPath(filename)

    if filename != ""
        openFile!(editor, filename)
    else
        setStatusMessage!(editor, "Open aborted")
    end
    
end


function saveFile(editor::Editor)
    editorSave(ed, "")
end

function saveFile(editor::Editor, path::T) where T <: AbstractString
    prevFilename = editor.filename

    try
        if path == ""
            if editor.filename == ""
                editor.filename = prompt(editor, "save as: ")
                if editor.filename == ""
                    setStatusMessage!(editor, "save aborted")
                    return
                end
            end
        else
            editor.filename = expandPath(path)
        end

        f = open(editor.filename, "w")
        write(f, rowsToString(editor.rows))
        close(f)

        setStatusMessage!(editor, "file saved: $(editor.filename)")
        editor.dirty = false
    catch Exception
        setStatusMessage!("editor", "unable to save: $(editor.filename)")
        editor.filename = prevFilename
    end
end


function moveCursor(editor::Editor, key::UInt32)
    if key == ARROW_LEFT
        if editor.cursor.x > 1
            editor.cursor.x -= 1
        elseif editor.cursor.y > 1
            # At start of line, move to end of prev line
            editor.cursor.y -= 1
            editor.cursor.x = 1+length(editor.rows[editor.cursor.y].chars)
        end
    elseif key == ARROW_RIGHT
        onrow = editor.cursor.y <= length(editor.rows)
        if onrow && editor.cursor.x <= length(editor.rows[editor.cursor.y].chars)
            editor.cursor.x += 1
        elseif editor.cursor.y < length(editor.rows) && editor.cursor.x == 1 + length(editor.rows[editor.cursor.y].chars)
            # At end of line, move to next line
            editor.cursor.y += 1
            editor.cursor.x = 1
        end
    elseif key == ARROW_UP
        editor.cursor.y > 1 && (editor.cursor.y -= 1)
    elseif key == ARROW_DOWN
        editor.cursor.y < length(editor.rows) && (editor.cursor.y += 1)
    end

    rowlen = editor.cursor.y < length(editor.rows) + 1 ? length(editor.rows[editor.cursor.y].chars) + 1 : 1
    editor.cursor.x > rowlen && (editor.cursor.x = rowlen)
end

moveCursor(editor::Editor, key::Key) = moveCursor(editor, UInt32(key))

function scroll!(editor::Editor)
    cursor = editor.cursor
    cursor.rx = 1
    if cursor.y <= length(editor.rows)
        cursor.rx = renderX(editor.rows[cursor.y], cursor.x)
    end

    if cursor.y < editor.rowOffset+1
        editor.rowOffset = cursor.y-1
    end
    if cursor.y >= editor.rowOffset+1 + editor.height
        editor.rowOffset = cursor.y - editor.height
    end

    # Horizontal scrolling
    if cursor.rx < editor.colOffset+1
        editor.colOffset = cursor.rx-1
    end
    if cursor.rx >= editor.colOffset+1 + editor.width
        editor.colOffset = cursor.rx - editor.width
    end
end

function drawRows!(editor::Editor, buffer::IOBuffer)
    for y = 1:editor.height
        filerow = y + editor.rowOffset
        y != 1 && write(buffer, "\r\n")

        write(buffer, "\e[K") # Clear line
        if filerow > length(editor.rows)
            if y == div(editor.height, 3) && editor.width > 40 && length(editor.rows) == 0
                msg = "Acorn Editor"
                padding = div(editor.width - length(msg), 2)
                if padding > 0
                    write(buffer, "~")
                    padding -= 1
                end
                while (padding -= 1) > 0
                    write(buffer, " ")
                end
                write(buffer, msg)
            else
                write(buffer, "~");
            end
        else
            len = length(editor.rows[filerow].render) - editor.colOffset
            len = clamp(len, 0, editor.width)
            write(buffer, editor.rows[filerow].render[1+editor.colOffset : editor.colOffset + len])
        end
    end
    # Write a newline to prepare for status bar
    write(buffer, "\r\n");
end

function drawStatusBar!(editor::Editor, buffer::IOBuffer)
    write(buffer, "\e[7m") # invert colors
    col = 1

    # left padding
    write(buffer, ' ')
    col += 1

    # filename
    filename = configGet(:status_fullpath) ? expandPath(editor.filename) : splitdir(editor.filename)[2]
    filestatus = string(filename, editor.dirty ? " *" : "")

    for i = 1:min(div(editor.width,2), length(filestatus))
        write(buffer, filestatus[i])
        col += 1
    end

    linenum = string(editor.cursor.y)

    while col < editor.width - length(linenum)
        write(buffer, ' ')
        col += 1
    end

    write(buffer, linenum, ' ')

    write(buffer, "\e[m") # uninvert colors

    # make line for message bar
    write(buffer, "\r\n")
    # write(buffer, "\n")
end

function drawStatusMessage!(editor::Editor, buffer::IOBuffer)
    write(buffer, "\e[K")
    if time() - editor.statusTime < 5.0
        write(buffer, editor.statusMessage[1:min(editor.width, length(editor.statusMessage))])
    end
end

function setStatusMessage!(editor::Editor, msg::String)
    editor.statusMessage = msg
    editor.statusTime = time()
end


function refreshScreen!(editor::Editor)
    # Update terminal size
    editor.height = REPL.Terminals.height(editor.terminal) - 2 # status + msg bar = 2
    editor.height -= 1
    editor.width = REPL.Terminals.width(editor.terminal)

    scroll!(editor)

    buffer = IOBuffer()

    write(buffer, "\e[?25l") # ?25l: Hide cursor
    write(buffer, "\e[H")    # H: Move cursor to top left

    drawRows!(editor, buffer)
    drawStatusBar!(editor, buffer)
    drawStatusMessage!(editor, buffer)

    Printf.@printf(buffer, "\e[%d;%dH", editor.cursor.y-editor.rowOffset,
                   editor.cursor.rx-editor.colOffset)

    write(buffer, "\e[?25h") # ?25h: Show cursor

    write(stdout, String(take!(buffer)))
end

function prompt(editor::Editor, prompt::String;
                      callback=nothing,
                      buffer::String="",
                      showcursor::Bool=true)
    while true
        statusmsg = string(prompt, buffer)
        setStatusMessage!(editor, string(prompt, buffer))
        refreshScreen!(editor)

        if showcursor
            # Position the cursor at the end of the line
            Printf.@printf(stdout, "\x1b[%d;%dH", 999, length(statusmsg)+1)
        end

        c = Char(readKey())

        if c == '\e'
            setStatusMessage!(editor, "")
            !isnothing(callback) && callback(editor, buffer, c)
            return ""
        elseif c == '\r'
            if length(buffer) != 0
                setStatusMessage!(editor, "")
                !isnothing(callback) && callback(editor, buffer, c)
                return buffer
            end
        elseif UInt32(c) == BACKSPACE && length(buffer) > 0
            buffer = buffer[1:end-1]
        elseif !iscntrl(c) && UInt32(c) < 128
            buffer = string(buffer, c)
        end

        !isnothing(callback) && callback(editor, buffer, c)
    end
end

# TODO 
function processKeypress(editor::Editor)
    c = readKey();
    cursor = editor.cursor

    @error "c is $c"

    if c == UInt32('\e') # Esc
        setStatusMessage!(editor, "Press ctrl-q to quit")
    elseif c == ctrlKey('p')
        runCommand(editor)
    elseif (c == ARROW_LEFT
            || c == ARROW_UP
            || c == ARROW_RIGHT
            || c == ARROW_DOWN)
        moveCursor(editor, c)
    elseif c == PAGE_UP || c == PAGE_DOWN
        lines = editor.height
        while (lines-=1) > 0
            moveCursor(editor, c == PAGE_UP ? ARROW_UP : ARROW_DOWN)
        end
    elseif c == HOME_KEY
        cursor.x = 0
    elseif c == END_KEY
        cursor.y < length(editor.rows) && (cursor.x = length(editor.rows[cursor.y].chars))
    elseif c == UInt32('\r')
        insertNewline!(editor)
    elseif c == BACKSPACE
        deleteChar!(editor)
    elseif c == DEL_KEY
        moveCursor(editor, ARROW_RIGHT)
        deleteChar!(editor)
    elseif c == ctrlKey('l')
        # Refresh screen
        return
    elseif iscntrl(Char(c)) && isKeyBound(Char(c))
        runCommand(editor, getKeyBinding(Char(c)))
    elseif c == UInt32('\t')
        insertTab!(editor)
    elseif !iscntrl(Char(c)) && c < 1000
        # Chars above 1000 are a ::Key, see src/terminal.jl
        insertChar!(editor, c)
    end
end

function insertChar!(editor::Editor, c::UInt32)
    editor.cursor.y == length(editor.rows)+1 && insertRow!(editor.rows, "")
    insertChar!(editor.rows[editor.cursor.y], editor.cursor.x, Char(c))
    editor.cursor.x += 1
    editor.dirty = true
end

function insertTab!(editor::Editor)
    # The cursor is able to move beyond the last row
    editor.cursor.y == length(editor.rows)+1 && insertRow!(editor.rows, "")

    # Insert character(s) into the row data
    mv_fwd = insertTab!(editor.rows[editor.cursor.y], editor.cursor.x)

    editor.cursor.x += mv_fwd

    editor.dirty = true
end

function deleteChar!(editor::Editor)
    editor.cursor.y == length(editor.rows)+1 && return
    editor.cursor.x == 1 && editor.cursor.y == 1 && return

    if editor.cursor.x > 1
        deleteChar!(editor.rows[editor.cursor.y], editor.cursor.x -1)
        editor.cursor.x -= 1
        editor.dirty = true
    else
        # Move cursor to end of prev line
        editor.cursor.x = 1+length(editor.rows[editor.cursor.y-1].chars)
        insertRow!(editor.rows[editor.cursor.y-1], editor.rows[editor.cursor.y].chars)
        deleteRow!(editor, editor.cursor.y)
        editor.cursor.y -= 1
    end
end

function insertRow!(editor::Editor, i::Int, str::T) where T <: AbstractString
    row = Row(str)
    updateRow!(row)
    insert!(editor.rows, i, row)
end

function insertNewline!(editor::Editor)
    if editor.cursor.x == 1
        insertRow!(editor, editor.cursor.y, "")
    else
        row = editor.rows[editor.cursor.y]
        before = row.chars[1:editor.cursor.x-1]
        after = row.chars[editor.cursor.x:end]
        insertRow!(editor, editor.cursor.y + 1, after)
        row.chars = before
        updateRow!(row)
    end
    
    editor.cursor.y += 1
    editor.cursor.x = 1
end

function deleteRow!(editor::Editor, i::Int)
    i < 1 || i > length(editor.rows) && return
    deleteat!(editor.rows, i)
    editor.dirty = true
end

function quit(editor::Editor; force::Bool = false)
    if !force && editor.dirty
        setStatusMessage!(editor,
                          "File has unsaved changes. Save changes or use <ctrl-p>'quit !' to quit anyway.")
    else
        write(stdout, "\e[2J")
        write(stdout, "\e[H")
        editor.quit = true
        !isinteractive() && exit(0)
    end

    
end

function runCommand(editor::Editor)
    cmd = prompt(editor, "> ")
    runCommand(editor, strip(cmd))
end

function runCommand(editor::Editor, command_str::T) where T <: AbstractString
    cmd_arr = split(command_str, ' ', limit = 2)

    # Get the command
    cmd = strip(cmd_arr[1])


    # Blank, do nothing
    cmd == "" && return

    # Command must be a valid identifier
    if !Base.isidentifier(cmd)
        setStatusMessage!(editor, "'$cmd' is not a valid command name")
        return
    end

    cmd_sym = Symbol(cmd)

    # Get arguments if there are any
    args = ""
    if length(cmd_arr) > 1
        args = cmd_arr[2]
    end

    # If the command exists, run it
    if cmd_sym in keys(COMMANDS)
        # join(args): convert Substring to String
        runCommand(COMMANDS[cmd_sym], editor, join(args))
    else
        setStatusMessage!(editor, "'$cmd_sym' is not a valid command")
    end
end

function runCommand(c::Command, ed::Editor, args::T) where T <: AbstractString
    c.cmd(ed, args)
end