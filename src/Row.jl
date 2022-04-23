mutable struct Row
  chars  ::String
  render ::String
end

Row(s::String) = Row(s, "")

const TAB_STOP = configGet(:tab_stop)
function updateRow!(row::Row)
  tabs = 0
  for c in row.chars
    c == '\t' && (tabs += 1)
  end

  updated = Vector{Char}(undef, length(row.chars) + tabs * (TAB_STOP - 1))
  idx = 1
  for i in 1:length(row.chars)
     if row.chars[i] == '\t'
        updated[idx] = ' '
        idx += 1
        while idx % TAB_STOP != 0;
            updated[idx] = ' ';
            idx += 1
            end
        else
        updated[idx] = row.chars[i]
        idx += 1
        end
  end

  row.render = join(updated[1:idx-1])
end

function renderX(row::Row, cx::Int)
  rx = 1
  for i in 1:cx - 1
    if row.chars[i] == '\t'
      rx += (TAB_STOP - 1) - (rx % TAB_STOP)
    end

    rx += 1
  end
    

  return rx
end

function charX(row::Row, rx::Int)
  cur_rx = 1
  cx = 1
  # for cx = 1:length(row.chars)
  while cx <= length(row.chars)
    if row.chars[cx] == '\t'
      cur_rx += (TAB_STOP - 1) - (cur_rx % TAB_STOP)
    end
    cur_rx += 1

    cur_rx > rx && return cx

    cx += 1
  end

  return cx
end

function insert(s::String, i::Int, c::Union{Char, String})
  if s == ""
    string(c)
  else
    string(s[1:i-1], c, s[i:end])
  end
end

function delete(s::String, i::Int)
  i < 1 || i > length(s) && return s
  string(s[1:i-1], s[i+1:end])
end

function insertChar!(row::Row, i::Int, c::Char)
  row.chars = insert(row.chars, i , c)
  updateRow!(row)
end

function insertTab!(row::Row, i::Int)
  numchars = 1
  t = '\t'

  if configGet(:expandtab)
    numchars = TAB_STOP - (i % TAB_STOP)
    t = repeat(" ", numchars)
  end
  
  row.chars = insert(row.chars, i, t)
  updateRow!(row)

  return numchars
end

function deleteChar!(row::Row, i::Int)
  row.chars = delete(row.chars, i)
  updateRow!(row)
end

function insertString!(row::Row, str::String)
  row.chars = string(row.chars, str)
  updateRow!(row)
end

Rows = Vector{Row}
function clearRows!(rows::Rows)
  while length(rows) > 0
    pop!(rows)
  end
end

function insertRow!(rows::Rows, s::String)
  row = Row(s)
  updateRow!(row)
  push!(rows, row)
end

function rowsToString(rows::Rows)
  join(map(row -> row.chars, rows), '\n')
end