local Json = {}

local function decodeError(text, index, message)
    error(string.format("Invalid JSON at byte %d: %s", index, message))
end

function Json.decode(text)
    local index = 1

    local function utf8Char(code)
        if code <= 0x7f then return string.char(code) end
        if code <= 0x7ff then
            return string.char(0xc0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
        end
        if code <= 0xffff then
            return string.char(
                0xe0 + math.floor(code / 0x1000),
                0x80 + (math.floor(code / 0x40) % 0x40),
                0x80 + (code % 0x40))
        end
        return string.char(
            0xf0 + math.floor(code / 0x40000),
            0x80 + (math.floor(code / 0x1000) % 0x40),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40))
    end

    local function skipSpace()
        local _, last = text:find("^[ \t\r\n]+", index)
        if last then index = last + 1 end
    end

    local parseValue

    local function parseString()
        index = index + 1
        local pieces = {}
        local start = index
        while index <= #text do
            local char = text:sub(index, index)
            if char == '"' then
                pieces[#pieces + 1] = text:sub(start, index - 1)
                index = index + 1
                return table.concat(pieces)
            end
            if char == "\\" then
                pieces[#pieces + 1] = text:sub(start, index - 1)
                local escape = text:sub(index + 1, index + 1)
                local values = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if escape == "u" then
                    local hex = text:sub(index + 2, index + 5)
                    local code = tonumber(hex, 16)
                    if not code then decodeError(text, index, "bad Unicode escape") end
                    local consumed = 6
                    if code >= 0xd800 and code <= 0xdbff and text:sub(index + 6, index + 7) == "\\u" then
                        local low = tonumber(text:sub(index + 8, index + 11), 16)
                        if not low or low < 0xdc00 or low > 0xdfff then
                            decodeError(text, index, "bad Unicode surrogate pair")
                        end
                        code = 0x10000 + ((code - 0xd800) * 0x400) + (low - 0xdc00)
                        consumed = 12
                    end
                    pieces[#pieces + 1] = utf8Char(code)
                    index = index + consumed
                elseif values[escape] then
                    pieces[#pieces + 1] = values[escape]
                    index = index + 2
                else
                    decodeError(text, index, "bad string escape")
                end
                start = index
            else
                index = index + 1
            end
        end
        decodeError(text, index, "unterminated string")
    end

    local function parseArray()
        index = index + 1
        skipSpace()
        local result = {}
        if text:sub(index, index) == "]" then index = index + 1; return result end
        while true do
            result[#result + 1] = parseValue()
            skipSpace()
            local char = text:sub(index, index)
            if char == "]" then index = index + 1; return result end
            if char ~= "," then decodeError(text, index, "expected ',' or ']'") end
            index = index + 1
            skipSpace()
        end
    end

    local function parseObject()
        index = index + 1
        skipSpace()
        local result = {}
        if text:sub(index, index) == "}" then index = index + 1; return result end
        while true do
            if text:sub(index, index) ~= '"' then decodeError(text, index, "expected object key") end
            local key = parseString()
            skipSpace()
            if text:sub(index, index) ~= ":" then decodeError(text, index, "expected ':'") end
            index = index + 1
            result[key] = parseValue()
            skipSpace()
            local char = text:sub(index, index)
            if char == "}" then index = index + 1; return result end
            if char ~= "," then decodeError(text, index, "expected ',' or '}'") end
            index = index + 1
            skipSpace()
        end
    end

    function parseValue()
        skipSpace()
        local char = text:sub(index, index)
        if char == '"' then return parseString() end
        if char == "[" then return parseArray() end
        if char == "{" then return parseObject() end
        if text:sub(index, index + 3) == "true" then index = index + 4; return true end
        if text:sub(index, index + 4) == "false" then index = index + 5; return false end
        if text:sub(index, index + 3) == "null" then index = index + 4; return nil end
        local numberText = text:sub(index):match("^-?%d+%.?%d*[eE]?[+-]?%d*")
        if numberText then
            local number = tonumber(numberText)
            if number ~= nil then index = index + #numberText; return number end
        end
        decodeError(text, index, "unexpected token")
    end

    local value = parseValue()
    skipSpace()
    if index <= #text then decodeError(text, index, "trailing content") end
    return value
end

return Json
