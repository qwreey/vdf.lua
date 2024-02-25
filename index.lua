

local module = {}
local find = string.find
local insert = table.insert
local concat = table.concat
local remove = table.remove
local format = string.format
local rep = string.rep
local gsub = string.gsub
local sub = string.sub

do
	local escapeMap = {
		n = "\n";
		t = "\t";
		["\\"] = "\\";
		["\""] = "\"";
	}
	local stringUnicode = "^([%z\1-\127\194-\244][\128-\191]+)" -- op0
	local stringEscape = "^\\(.)"                             -- op1
	local stringClose = "^\""                                 -- op2 "^\""
	local stringChars = "^([^\\\"]+)"
	local stringCloseWithoutQuotes = "^%s+"
	local stringCharsWithoutQuotes = "^([^\\%s]+)"                   -- op3 "^([^\\\"]+)"
	function module.parseString(str,stringStart,quotes)
		local pos = stringStart+1
		local buffer = {}
		local lastPos = pos

		local strClose = quotes and stringClose or stringCloseWithoutQuotes
		local strChars = quotes and stringChars or stringCharsWithoutQuotes

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
				startAt,endAt,catch = find(str,strClose,pos)
			elseif op == -1 then
				op = 1
			end
			if not startAt then
				startAt,endAt,catch = find(str,strChars,pos)
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
				if sub(str,pos,pos) == "" then
					return concat(buffer),endAt-1
				end
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
	local booleanMap = {
		["true"]=true;
		["false"]=false;
	}
	local lineCommentRegex = "^[ \t]*//[^\n]*" -- 0
	local stackStart = "^[ \t\n]*{[ \t\n]*"    -- 1
	local stackEnd = "^[ \t\n]*}[ \t\n]*"    -- 1
	local stringStart = "^[ \t\n]*\""          -- 3
	local stringStartWithoutQuotes = "^[ \t\n]*" --4

	function module.parse(str,config)
		local keyName
		local keyToggle = false
		local global = {}
		local blockStack = {}
		local current = global
		local currentKey
		local pos = 1
		local length = #str
		local lastPos = pos
		local includes = {}

		while true do
			local startAt,endAt
			startAt,endAt = find(str,lineCommentRegex,pos)
			local op = -1
			if not startAt then
				startAt,endAt = find(str,stackStart,pos)
			elseif op == -1 then
				op = 0
			end
			if not startAt then
				startAt,endAt = find(str,stackEnd,pos)
			elseif op == -1 then
				op = 1
			end
			if not startAt then
				startAt,endAt = find(str,stringStart,pos)
			elseif op == -1 then
				op = 2
			end
			if startAt and op == -1 then op = 3 end

			if not startAt then
				startAt,endAt = find(str,stringStartWithoutQuotes,pos)
			elseif op == -1 then
				op = 2
			end
			if startAt and op == -1 then op = 4 end

			if op == 0 then -- lineCommentRegex
				pos = endAt + 1
			elseif op == 1 then -- stackStart
				if not keyToggle then
					error("Unnamed stack is not supported")
				end
				keyToggle = false
				local lastCurrent = current
				current = {}
				currentKey = keyName
				lastCurrent[keyName] = current
				--print("is there included header?",includes[keyName]~=nil)
				local header = includes[keyName]
				if header then
					for k,v in pairs(header) do
						current[k] = v
					end
				end
				insert(blockStack,current)
				pos = endAt + 1
			elseif op == 2 then -- stackEnd
				remove(blockStack)
				current = blockStack[#blockStack] or global
				pos = endAt + 1
			elseif op == 3 or op == 4 then -- stringStart
				local parsedStr,parseEndAt = module.parseString(str,endAt,op == 3 and true or false)
				pos = parseEndAt + 1
				if keyToggle then
					if keyName == "#include" or keyName == "#base" then
						if config.path then
							local pathSeparator = package.config:sub(1, 1)
							local file = io.open(config.path == "" and parsedStr or config.path..pathSeparator..parsedStr)
							if file then
								local vdfHeader = file:read("*a")
								file:close()
								for k,v in pairs(module.parse(vdfHeader)) do
									includes[k] = v
								end
							end
						end
						if config.pathInstance then
							local moduleScript = config.pathInstance:FindFirstChild(parsedStr)
							if moduleScript then
								local vdfHeader = require(moduleScript)
								for k,v in pairs(module.parse(vdfHeader)) do
									includes[k] = v
								end
							end
						end
					end
					if config and config.strict then
						local header = includes[currentKey]
						if header then
							if not header[keyName] then
								error(format("invalid key '%s'",keyName))
							end
						end
					end
					local value = parsedStr
					if config and config.autoType then
						local number = tonumber(parsedStr)
						if number then
							value = number
						end
						local boolean = booleanMap[value]
						if boolean then
							value = boolean
						end
					end
					current[keyName] = value
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
				global["#include"] = nil
				global["#base"] = nil
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
