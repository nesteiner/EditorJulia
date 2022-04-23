import Base:(==), convert

@enum Key begin
    BACKSPACE=127
    ARROW_LEFT=1000
    ARROW_RIGHT
    ARROW_UP
    ARROW_DOWN
    DEL_KEY
    HOME_KEY
    END_KEY
    PAGE_UP
    PAGE_DOWN
    S_ARROW_UP
    S_ARROW_DOWN
    S_ARROW_LEFT
    S_ARROW_RIGHT
    C_ARROW_UP
    C_ARROW_DOWN
    C_ARROW_LEFT
    C_ARROW_RIGHT
end


==(c::UInt32, k::Key) = c == UInt32(k)
==(k::Key, c::UInt32) = c == UInt32(k)
==(c::Char, k::Key)   = UInt32(c) == UInt32(k)
==(k::Key, c::Char)   = UInt32(c) == UInt32(k)
convert(UInt32, key::Key) = UInt32(key)
ctrlKey(c::Char) = UInt32(c) & 0x1f

import REPL.Terminals

readNextChar() = Char(read(stdin, 1) |> first)

function readKey()::UInt32
    c = readNextChar()

    # Escape characters
    if c == '\e'
        stdin.buffer.size < 3 && return '\e'
        esc_a = readNextChar()
        esc_b = readNextChar()

        if esc_a == '['
            if esc_b >= '0' && esc_b <= '9'
                stdin.buffer.size < 4 && return '\e'
                esc_c = readNextChar()

                if esc_c == '~'
                    if esc_b == '1'
                        return HOME_KEY
                    elseif esc_b == '4'
                        return END_KEY
                    elseif esc_b == '3'
                        return DEL_KEY
                    elseif esc_b == '5'
                        return PAGE_UP
                    elseif esc_b == '6'
                        return PAGE_DOWN
                    elseif esc_b == '7'
                        return HOME_KEY
                    elseif esc_b == '8'
                        return END_KEY
                    else
                        return '\e'
                    end
                elseif esc_c == ';'
                    stdin.buffer.size < 6 && return '\e'
                    esc_d = readNextChar()
                    esc_e = readNextChar()

                    if esc_d == '2'
                        # shift + arrorw
                        if esc_e == 'A'
                            return S_ARROW_UP
                        elseif esc_e == 'B'
                            return S_ARROW_DOWN
                        elseif esc_e == 'C'
                            return S_ARROW_RIGHT
                        elseif esc_e == 'D'
                            return S_ARROW_LEFT
                        else
                            return '\e'
                        end
                    elseif esc_d == '5'
                        # Ctrl + arrow
                        if esc_e == 'A'
                            return C_ARROW_UP
                        elseif esc_e == 'B'
                            return C_ARROW_DOWN
                        elseif esc_e == 'C'
                            return C_ARROW_RIGHT
                        elseif esc_e == 'D'
                            return C_ARROW_LEFT
                        else
                            return '\e'
                        end
                    end
                end
            else
                # Arrow keys
                if esc_b == 'A'
                    return ARROW_UP
                elseif esc_b == 'B'
                    return ARROW_DOWN
                elseif esc_b == 'C'
                    return ARROW_RIGHT
                elseif esc_b == 'D'
                    return ARROW_LEFT
                elseif esc_b == 'H'
                    return HOME_KEY
                elseif esc_b == 'F'
                    return END_KEY
                else
                    return '\e'
                end
            end
        elseif esc_a == 'O'
            if esc_a == 'H'
                return HOME_KEY
            elseif esc_a == 'F'
                return END_KEY
            end
        end

        return '\e'
    else
        return c;
    end
end

function printNextKey()
    term = Terminals.TTYTerminal(get(ENV, "TERM", "dumb"), stdin, stdout, stderr)
    Terminals.raw!(term, true)
    c = readNextKey()
    print("Code: $(UInt32(c)), Char: $(Char(c))")
    Terminals.raw!(term, true)
end


