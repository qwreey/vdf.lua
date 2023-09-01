

local module = {}
local find = string.find
local insert = table.insert
local concat = table.concat
local remove = table.remove
local format = string.format
local rep = string.rep
local gsub = string.gsub

do
    local escapeMap = {
        n = "\n";
        t = "\t";
        ["\\"] = "\\";
        ["\""] = "\"";
    }
    local stringUnicode = "^([%z\1-\127\194-\244][\128-\191]+)" -- op0
    local stringEscape = "^\\(.)"                             -- op1
    local stringClose = "^\""                                 -- op2
    local stringChars = "^([^\\\"]+)"                         -- op3
    function module.parseString(str,stringStart)
        local pos = stringStart+1
        local buffer = {}
        local lastPos = pos

        while true do
            local startAt,endAt,catch
            startAt,endAt,catch = find(str,stringUnicode,pos)
            local op = -1
            if not startAt then
                startAt,endAt,catch = find(str,stringEscape,pos)
            elseif op == -1 then
                op = 0
            end
            if not startAt then
                startAt,endAt,catch = find(str,stringClose,pos)
            elseif op == -1 then
                op = 1
            end
            if not startAt then
                startAt,endAt,catch = find(str,stringChars,pos)
            elseif op == -1 then
                op = 2
            end
            if startAt and op == -1 then op = 3 end

            if op == 0 then -- unicode char
                insert(buffer,catch)
                pos = endAt + 1
            elseif op == 1 then -- escape
                local char = escapeMap[catch]
                if not char then
                    error(("String Escape '%s' is not expected at position %d"):format(catch,pos))
                end
                insert(buffer,char)
                pos = endAt + 1
            elseif op == 2 then -- close
                return concat(buffer),endAt
            elseif op == 3 then -- ascii str
                insert(buffer,catch)
                pos = endAt + 1
            elseif op == -1 then
                error(("Unexpected token got at position %d"):format(pos))
            end

            if lastPos == pos then
                error("Infinity loop detected")
            end
            lastPos = pos
        end
    end
end

do
    local lineCommentRegex = "^[ \t]*//[^\n]*" -- 0
    local stackStart = "^[ \t\n]*{[ \t\n]*"    -- 1
    local stackEnd = "^[ \t\n]*}[ \t\n]*"    -- 1
    local stringStart = "^[ \t\n]*\""          -- 3

    function module.parse(str)
        local keyName
        local keyToggle = false
        local global = {}
        local blockStack = {}
        local current = global
        local pos = 1
        local length = #str
        local lastPos = pos

        while true do
            local startAt,endAt,catch
            startAt,endAt,catch = find(str,lineCommentRegex,pos)
            local op = -1
            if not startAt then
                startAt,endAt,catch = find(str,stackStart,pos)
            elseif op == -1 then
                op = 0
            end
            if not startAt then
                startAt,endAt,catch = find(str,stackEnd,pos)
            elseif op == -1 then
                op = 1
            end
            if not startAt then
                startAt,endAt,catch = find(str,stringStart,pos)
            elseif op == -1 then
                op = 2
            end
            if startAt and op == -1 then op = 3 end

            if op == 0 then -- lineCommentRegex
                pos = endAt + 1
            elseif op == 1 then -- stackStart
                if not keyToggle then
                    error("Unnamed stack is not supported")
                end
                keyToggle = false
                local lastCurrent = current
                current = {}
                lastCurrent[keyName] = current
                insert(blockStack,current)
                pos = endAt + 1
            elseif op == 2 then -- stackEnd
                remove(blockStack)
                current = blockStack[#blockStack] or global
                pos = endAt + 1
            elseif op == 3 then -- stringStart
                local parsedStr,parseEndAt = module.parseString(str,endAt)
                pos = parseEndAt + 1

                if keyToggle then
                    current[keyName] = parsedStr
                    keyToggle = false
                else
                    keyName = parsedStr
                    keyToggle = true
                end
            elseif op == -1 then
                error(("Unexpected token got at position %d"):format(pos))
            end

            -- end parsing
            if length <= pos then
                return global
            end
            if lastPos == pos then
                error("Infinite loop detected")
            end
            lastPos = pos
        end
    end
end

local function escapeString(str)
    str = gsub(str,"\\","\\\\")
    str = gsub(str,"\n","\\n")
    str = gsub(str,"\t","\\t")
    str = gsub(str,'"','\\"')
    return str
end

local function stringify(data,usingIndent,newline,depth,buffer)
    local indent = usingIndent and (rep(usingIndent,depth)) or ""
    for key,value in pairs(data) do
        local valueType = type(value)
        if valueType == "string" then
            insert(buffer,
                format('%s"%s" "%s"%s',
                    indent,
                    escapeString(key),
                    escapeString(value),
                    newline
                )
            )
        elseif valueType == "table" then
            insert(buffer,format('%s"%s"%s{%s',indent,escapeString(key),newline,newline))
            stringify(value,usingIndent,newline,depth+1,buffer)
            insert(buffer,format("%s}%s",indent,newline))
        else
            error(("Unsupported value type '%s'"):format(valueType))
        end
    end
end

function module.stringify(data,indent,disableNewline)
    if indent == nil or indent == true then
        indent = "  "
    end
    local newline = disableNewline and "" or "\n"
    local buffer = {}
    stringify(data,indent,newline,0,buffer)
    return concat(buffer)
end

return module
