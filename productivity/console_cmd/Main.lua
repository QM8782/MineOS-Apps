
local GUI = require("GUI")
local system = require("System")
local keyboard = require("Keyboard")
local filesystem = require("Filesystem")
local screen = require("Screen")
local text = require("Text")

---------------------------------------------------------------------------------

local workspace, window, appMenu = system.addWindow(GUI.filledWindow(1, 1, 82, 28, 0x000000))

local display = window:addChild(GUI.object(2, 4, 1, 1))
local title = "Command Console"
--local titleObj = window:addChild(GUI.label(10, 2, display.width - 14, 1, 0xFFFFFF, "Command Console"))
local cursorX, cursorY = 1, 1
local lineFrom = 1
local lines = {}
local input = ""

display.draw = function(display)
    local function limit(s, limit, mode, noDots)
        local length = unicode.len(s)
        
        if length <= limit then
            return s
        elseif mode == "left" then
            if noDots then
                return unicode.sub(s, length - limit + 1, -1)
            else
                return "…" .. unicode.sub(s, length - limit + 2, -1)
            end
        elseif mode == "center" then
            local integer, fractional = math.modf(limit / 2)
            if fractional == 0 then
                return unicode.sub(s, 1, integer) .. "…" .. unicode.sub(s, -integer + 1, -1)
            else
                return unicode.sub(s, 1, integer) .. "…" .. unicode.sub(s, -integer, -1)
            end
        else
            if noDots then
                return unicode.sub(s, 1, limit)
            else
                return unicode.sub(s, 1, limit - 1) .. "…"
            end
        end
    end
    local function brailleChar(a, b, c, d, e, f, g, h)
	    return unicode.char(10240 + 128 * h + 64 * g + 32 * f + 16 * d + 8 * b + 4 * e + 2 * c + a)
    end


	local x, y = display.x, display.y
	for i = lineFrom, #lines do
		screen.drawText(x, y, 0xFFFFFF, lines[i])
		y = y + 1
	end

	screen.drawText(x, y, 0xFFFFFF, "> ")
	screen.drawText(x + 2, y, 0xFFFFFF, limit(input, display.width - 4, "left", true))
	-- 0x00A8FF
	screen.drawText(x + unicode.len(limit(input, display.width - 4, "left", true)) + 2, y, 0xFFFFFF, brailleChar(1,1,1,1,1,1,1,1))

	screen.drawText(window.x + 9, window.y + 1, 0xFFFFFF, limit(title, display.width - 14, "right"))
end

window.addLine = function(window, value)
	local value = text.wrap(value, display.width)
	local numbers = {}
	for i = 1, #value do
		table.insert(numbers, #lines + 1)
		table.insert(lines, value[i])

		if #lines - lineFrom + 1 > display.height - 1 then
			lineFrom = lineFrom + 1
		end
	end
	return numbers
end

window.setLine = function(number, value)
	local value = text.limit(value, display.width, "left", true)
	if lines[number] then
		lines[number] = value
	end
end

local function sConcat(...)
	local arg = {...}
	local t
	if type(arg[1]) == "table" then t = arg[1] else t = arg end
	local s = ""
	for k, v in pairs(t) do
		s = s .. v
		if k == #t then else
			s = s .. " "
		end
	end
    return s
end

local addDispLine = function(...) return window:addLine(...) end

local setDispLine = function(...) return window:setLine(...) end

---------------------------------------------------------------------------------

-- Two types of command line arguments:
--[[

    -c=foobar
    --c foobar

]]--

--test
local cla = {};
local arguments = {};
local prettyprint = function(colour, ...)
    -- Checks if a value exists within a table
    --colour = colour or "white";
    local function hasIndex(t, l)
        for k, value in pairs(t) do
            if (tostring(k):lower() == tostring(l):lower()) then
                return true, value end;
        end
        
        return false
    end;

    --local lastTextColour = term.getTextColour()
    --assert(hasIndex(colours, colour) or table.find(colours, colour), ("invalid color '%s'"):format(colour)) 

    --term.setTextColour(term.isColour and (select(2, hasIndex(colours, colour)) or colour) or colours.white); --sloppy, but not as if I could do anythin better
    --print(sConcat(...));
    --term.setTextColour(lastTextColour);
    --return;
	return sConcat(...)
end

local _type = type;
local function type(default)
    return tonumber(default) and (tostring(default):match("%d%.%d+") and "float" or "int") or _type(default) end;

-- too lazy to make an arguments[name] function check or whatever so i'll do it the copy and paste way
function cla.String(name, default, description)
    if (type(default) ~= "string") then
        error(("type mismatch: expected %s, got %s for function String"):format("string", type(default)), 2) end;
    
    if (arguments[name]) then
        return error(("argument %s is already defined as a command-line argument"):format(name), 2) end;
    
    arguments[name] = {name = name, value = default, type = "string", description = description};
end

function cla.Boolean(name, default, description)
    if (type(default) ~= "boolean") then
        error(("type mismatch: expected %s, got %s for function Boolean"):format("boolean", type(default)), 2) end;
    
    if (arguments[name]) then
        return error(("argument %s is already defined as a command-line argument"):format(name), 2) end;
    
    arguments[name] = {name = name, value = default, type = "boolean", description = description};
end

function cla.Float(name, default, description)
    if (type(default) ~= "float" and type(default) ~= "int") then 
        --ints can be floats but floats cant be int, sad wiggleroom i cant excuse
        -- since i cant take "4.0" literally without it being automatically coerced.. sadge.
        error(("type mismatch: expected %s, got %s for function Float"):format("float", type(default)), 2) end;
    
    if (arguments[name]) then
        return error(("argument %s is already defined as a command-line argument"):format(name), 2) end;
    
    arguments[name] = {name = name, value = default, type = "float", description = description};
end

function cla.Integer(name, default, description)
    if (type(default) ~= "int") then
        error(("type mismatch: expected %s, got %s for function Integer"):format("integer", type(default)), 2) end;
    
    if (arguments[name]) then
        return error(("argument %s is already defined as a command-line argument"):format(name), 2) end;
    
    arguments[name] = {name = name, value = default, type = "integer", description = description};
end

-- Valueless  arguments such as:
-- ./importer.lua --foo 
-- It's essentially an interfaced cla.Boolean value except that by its presence
-- it immediately sets its own value to true rather than it being explicitly defined
-- by the user.
-- Therefore:
-- ./importer.lua --foo, ./importer.lua --foo true, and ./importer.lua -foo=true are synonyumous.
function cla.Valueless(name, description)
    arguments[name] = {name = name, value = false, type = "valueless", description = description};
end

--shell.tokenize eats quotation marks, so we'll have to make do with 'true' and 'false' unfortunately.
local function determineTrueType(argument)
    return (tostring(argument):match("%b''") and "string") or (tonumber(argument) and (tostring(argument):match("^%d%.%d+") and "float" or "integer")) 
            or ((argument:lower() == "true" or argument:lower() == "false") and "boolean")
            or "string";
end

--The reason we need an iterator here is becasue this (fortunately and unfortunately)
--isn't Lua 5.0 where we can modify the iterator of a numerical for loop.
--man. Lua should have pointers. :troll:
local function args(callingArguments)
    local currentIndex = 1;

    local function _itr() --iterator functions should really be outside the iterator factory but it looks ugly (and its stateful) soooo ...
        local stringifiedIndex = tostring(callingArguments[currentIndex])
        local isDoubleArgument, isSingleArgument = stringifiedIndex:match("^%-%-(%S+)"), stringifiedIndex:match("^%-(%S+)");
        
        if (not callingArguments[currentIndex]) then
            return end;
        
        if (not isDoubleArgument and not isSingleArgument) then
            currentIndex = currentIndex + 1 return {error = true, reason = 'exist', name = stringifiedIndex} end;

        local datumTemplate = {name = (isDoubleArgument or isSingleArgument), error = false, reason = "", flagtype = isDoubleArgument and 2 or 1}
        --stringifiedIndex:match("^%-(%S+)%s?=%s?(%S+)"); to check the value for single-dash args
        if (isDoubleArgument) then -- Instead of going "all or nothing," we can use the opportunity to print the description of the flag.
            -- Check if the double argument is valid.
            -- If it isn't, return a table with a {error = true, data = {}} value.
            -- If it is, then simply return an {error = false, data = {}} value.
    
            local argumentTemplate = arguments[isDoubleArgument]
            if (not argumentTemplate) then
                currentIndex = currentIndex + 1
                datumTemplate.error, datumTemplate.reason = true, "exist" return datumTemplate end;

            local Value;
            if (arguments[isDoubleArgument].type == "valueless") then
                Value = true;
                currentIndex = currentIndex + 1;
            else 
                Value = callingArguments[currentIndex + 1];
                -- If the next value is a flag, then that's no good. Use anchor to make sure that '--foo' and "" isn't detected.
                if (tostring(Value):match("^%-%-") or tostring(Value):match("^%-%S+%=")) then
                    datumTemplate.error, datumTemplate.reason = true, "valueless"
                    currentIndex = currentIndex + 1
                    return datumTemplate
                end;

                currentIndex = currentIndex + 2;
            end

            if (not Value) then
                datumTemplate.error, datumTemplate.reason = true, "valueless"
                return datumTemplate;
            end

            if (argumentTemplate.type ~= "valueless" and arguments[isDoubleArgument].type ~= determineTrueType(Value)) then
                datumTemplate.error, datumTemplate.reason  = true, "type" 
                return datumTemplate;
            end;
            
            datumTemplate.value = Value;
         elseif (isSingleArgument) then
            --lookahead 2 tokens ughh
            local doesIndexHaveEquals = stringifiedIndex:match("^-(%S+)=$");
            local isIndexComplete = stringifiedIndex:match("^%-%S+=(%S*)$")
            local nextIndexValue = tostring(callingArguments[currentIndex+1]):match("=(%S+)");
            --If "equals" is present, then that means that we can lookahead one index to check if the value is present.
            -- If equals is not present, then we have to look ahead 1 to see the equals, and another to find the value.

            local Value;
            if (doesIndexHaveEquals) then
                local ci = currentIndex;

                isSingleArgument = doesIndexHaveEquals;
                datumTemplate.name = doesIndexHaveEquals
                Value = callingArguments[currentIndex + 1];
                currentIndex = ci + 2; --wowie, switch-case would be pretty useful here

                if (tostring(Value):match("^%-%-") or tostring(Value):match("^%-%S+%=")) then
                    currentIndex = ci + 1;
                    datumTemplate.error, datumTemplate.reason = true, "valueless"
                    return datumTemplate
                end;

            elseif (isIndexComplete) then
                isSingleArgument = stringifiedIndex:match("^%-(%S-)=")
                Value = isIndexComplete
                currentIndex = currentIndex + 1;

                datumTemplate.name = isSingleArgument;
            elseif (nextIndexValue) then
                Value = nextIndexValue;
                currentIndex = currentIndex + 2
            elseif (callingArguments[currentIndex + 1] == "=" and callingArguments[currentIndex + 2]) then
                print'b'
                Value = callingArguments[currentIndex+2]
                currentIndex = currentIndex + 3;
            end

            if (not arguments[isSingleArgument]) then
                datumTemplate.error, datumTemplate.reason = true, "exist" 
                currentIndex = currentIndex + 1;
                return datumTemplate;
            else datumTemplate.value = Value end;

            if ((not Value) or (#Value == 0)) and arguments[isSingleArgument].type ~= "valueless" then
                datumTemplate.error, datumTemplate.reason = true, "valueless"
                currentIndex = currentIndex + 1;
                return datumTemplate;
            end
            
            if (arguments[isSingleArgument].type == "valueless") then
                Value = true 
                datumTemplate.value = Value 
                currentIndex = currentIndex + 1;
            end

            if (arguments[isSingleArgument].type ~= "valueless" and arguments[isSingleArgument].type ~= determineTrueType(Value)) then
                datumTemplate.error, datumTemplate.reason = true, "type" 
                currentIndex = currentIndex + 1;
            end
            --wow, i really should've just put currentIndex + 1, but c'est la vie
        else currentIndex = currentIndex + 1 end;

        if (not datumTemplate.error) then 
            datumTemplate.reason = nil end;
        return datumTemplate;
    end

    return _itr, callingArguments, currentIndex;
end
-- ^ all this. just to set some variable to true :troll:
-- Returns the Levenshtein distance between the two given strings
function unicode.levenshtein(str1, str2)
	local len1 = unicode.len(str1)
	local len2 = unicode.len(str2)
	local matrix = {}
	local cost = 0
	
        -- quick cut-offs to save time
	if (len1 == 0) then
		return len2
	elseif (len2 == 0) then
		return len1
	elseif (str1 == str2) then
		return 0
	end
	
        -- initialise the base matrix values
	for i = 0, len1, 1 do
		matrix[i] = {}
		matrix[i][0] = i
	end
	for j = 0, len2, 1 do
		matrix[0][j] = j
	end
	
        -- actual Levenshtein algorithm
	for i = 1, len1, 1 do
		for j = 1, len2, 1 do
			if (str1:byte(i) == str2:byte(j)) then
				cost = 0
			else
				cost = 1
			end
			
			matrix[i][j] = math.min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
	end
	
        -- return the last value - this is the Levenshtein distance
	return matrix[len1][len2]
end

function cla.parse(callingArguments)
    local didError = false;
	local addTextLine = addDispLine

    for datum in args(callingArguments) do
        if (not datum.error) then
            arguments[datum.name].value = datum.value
            arguments[datum.name].modified = arguments[datum.name].default ~= datum.value;
        else
            if (datum.reason == "exist") then
                addTextLine(("flag %s does not exist\n"):format(datum.name));
            else
                addTextLine(("./%s %s:"):format(select(2, pcall(function() error("　", 1) end)):match("%S-.lua"), ("%s"):format(datum.flagtype == 2 and "--" or "-") .. datum.name));
                addTextLine(("\t\t" .. arguments[datum.name].type))
                addTextLine(("\t\t%s\n"):format(arguments[datum.name].description or "no description"))
            end
            didError = true;
        end;
    end

    return arguments, didError
end;

---------------------------------------------------------------------------------

local parallel = {}

local function create(...)
    local tFns = table.pack(...)
    local tCos = {}
    for i = 1, tFns.n, 1 do
        local fn = tFns[i]
        if type(fn) ~= "function" then
            error("bad argument #" .. i .. " (function expected, got " .. type(fn) .. ")", 3)
        end

        tCos[i] = coroutine.create(fn)
    end

    return tCos
end

local function runUntilLimit(_routines, _limit)
    local count = #_routines
    if count < 1 then return 0 end
    local living = count

    local tFilters = {}
    local eventData = { n = 0 }
    while true do
        for n = 1, count do
            local r = _routines[n]
            if r then
                if tFilters[r] == nil or tFilters[r] == eventData[1] or eventData[1] == "terminate" then
                    local ok, param = coroutine.resume(r, table.unpack(eventData, 1, eventData.n))
                    if not ok then
                        error(param, 0)
                    else
                        tFilters[r] = param
                    end
                    if coroutine.status(r) == "dead" then
                        _routines[n] = nil
                        living = living - 1
                        if living <= _limit then
                            return n
                        end
                    end
                end
            end
        end
        for n = 1, count do
            local r = _routines[n]
            if r and coroutine.status(r) == "dead" then
                _routines[n] = nil
                living = living - 1
                if living <= _limit then
                    return n
                end
            end
        end
        eventData = table.pack(os.pullSignal())
    end
end

function parallel.waitForAny(...)
    local routines = create(...)
    return runUntilLimit(routines, #routines - 1)
end

function parallel.waitForAll(...)
    local routines = create(...)
    return runUntilLimit(routines, 0)
end


---------------------------------------------------------------------------------

function sleep(nTime)
    local deadline, eventData = computer.uptime() + nTime
	while computer.uptime() < deadline do
		eventData = { computer.pullSignal(deadline - computer.uptime()) }
	end
end

local function getApps()
    local function formatAppName(s)
        local r = s
        r = r:lower()
        r = r:gsub(" ", "_")
        r = r:gsub("%(", "")
        r = r:gsub("%)", "")
        r = r:gsub("%[", "")
        r = r:gsub("%]", "")
        r = r:gsub("%{", "")
        r = r:gsub("%}", "")
        return r
    end
	local t = {}
	for k, v in pairs(filesystem.list("/Applications/")) do
		t[formatAppName(filesystem.hideExtension(filesystem.name("/Applications/"..v)))] = "/Applications/"..v
	end
	return t
end

local function tokenise(...)
    local sLine = table.concat({ ... }, " ")
    local tWords = {}
    local bQuoted = false
    for match in string.gmatch(sLine .. "\"", "(.-)\"") do
        if bQuoted then
            table.insert(tWords, match)
        else
            for m in string.gmatch(match, "[^ \t]+") do
                table.insert(tWords, m)
            end
        end
        bQuoted = not bQuoted
    end
    return tWords
end
local tokenize = tokenise

---------------------------------------------------------------------------------

local sysAppList = getApps()

local aboutLogo = {
	"....###..#...#.####.................",
	"...#...#.##.##.#...#................",
	"...#.....#.#.#.#...#...for MineOS...",
	"...#...#.#...#.#...#................",
	"....###..#...#.####.................",
}

local commands = {
    -- ["example"] = function(args)
    --
    -- end,
    ["about"] = function(args)
        addDispLine(" ")
		for k, v in pairs(aboutLogo) do
			addDispLine(v)
		end
		addDispLine(" ")
		addDispLine("Command Console for MineOS")
		addDispLine("Copyright (C) 2024 QuickMuffin8782")
		addDispLine("Distributed under the GNU General Public License 3.0")
		addDispLine(" ")
    end,
    -- ["flash"] = function(args)
    --     if not args[1] then
	-- 		addDispLine("Please enter a valid path to flash the EEPROM to.")
	-- 	elseif args[1] == "-luna" then
	-- 	end
    -- end,
    ["title"] = function(args)
        if not args[1] then
			title = "Command Console"
		else
			local txt = args
			table.remove(txt, 1)
			title = sConcat(txt)
		end
    end,
}

local function helpDesc(...)
    local ret = {...}
    if type(ret[1]) == "table" then
        return ret[1]
    else
        return ret
    end
end
local commmandsHelp = {
    -- ["example"] = helpDesc(
    --     {
    --         "Line 1",
    --         "Line 2",
    --         "Line 3",
    --     }
    -- ),
    ["title"] = helpDesc(
        {
            "Changes the title of the window.",
            "Usage: title [text: name (leave blank for default)]",
        }
    ),
    ["about"] = helpDesc(
        {
            "Gives the information about this command line"
        }
    ),
    ["help"] = helpDesc(
        {
            "Shows this screen output.",
            "Usage: help [command name]"
        }
    )
}

local function parseCmd(...)
    local args = {...}
	local cmd = args[1]
	local cmdArgs = args
    table.remove(cmdArgs, 1)
    for cmdName, cmdFunc in pairs(commands) do
        if cmdName == cmd then
            if type(cmdFunc) == "function" then
                cmdFunc(cmdArgs)
                return
            else
                addDispLine("The command was not properly created. Check the documentation for details on this error code: EXT-201")
                return
            end
        end
    end
    if cmd == "help" then
        if cmdArgs[1] then
            for cmdName, cmdDesc in pairs(commmandsHelp) do
                if cmdArgs[1] == cmdName then
                    addDispLine("/---Command information-"..string.rep("-", 80 - 25) .. "\\")
                    addDispLine("|."..text.limit(cmdName, 76, nil, true)..string.rep(".", 76 - unicode.wlen(cmdName)) .. ".|")
                    addDispLine("|"..string.rep("-", 78).."|")
                    for k, v in pairs(cmdDesc) do
                        addDispLine("|."..text.limit(v, 76, nil, true)..string.rep(".", 76 - unicode.wlen(text.limit(v, 76, nil, true))) .. ".|")
                    end
                    addDispLine("\\"..string.rep("-", 78).."/")
                    return
                end
            end
            addDispLine("Couldn't find a result of documentation for \""..cmdArgs[1].."\".")
            return
        end
        addDispLine("Commands available:")
        local t = "| "
        i = 0
        for k, v in pairs(commands) do
            i = i + 1
            t = t .. k
            if i == (#commands) then else
                t = t .. " | "
            end
        end
        addDispLine(t)
        return
    end
	for appCmdName, appPath in pairs(sysAppList) do
		if cmd == appCmdName then
			if filesystem.exists(appPath .. "Main.lua") then
				addDispLine("Launched \""..filesystem.hideExtension(filesystem.name(appPath)).."\" into the desktop environment.")
				system.execute(appPath .. "Main.lua")
			else
				addDispLine("The app is missing a critical file to launch.")
				addDispLine("Critical file: Main.lua")
				addDispLine("Please report this to the developers of that application.")
			end
			return
		end
	end
	addDispLine("Unrecognized command: "..cmd)
end

local function runCmd(...)
    local args = {...}
	if #args > 0 then
		local tWords = tokenize(...)
		local scmd = tWords[1]
		local cmd = (scmd and scmd:lower() or "")
		if cmd then
			--addDispLine(tWords)
			if cmd == "ls" or cmd == "list" then
				addDispLine("The directory method is not yet here and is in full developement. Check back later.")
			elseif cmd == "apps" then
				addDispLine("Installed apps:")
				for appName, appDir in pairs(sysAppList) do
					addDispLine("  - "..appName.." ("..appDir..")")
				end
			else
				parseCmd(table.unpack(tWords))
			end
		end
	end
end

---------------------------------------------------------------------------------

appMenu:addItem("About").onTouch = function()
    addDispLine("> about")
    runCmd("about")
end

---------------------------------------------------------------------------------

local overrideWindowEventHandler = window.eventHandler
window.eventHandler = function(workspace, window, ...)
	local e = {...}

	if e[1] == "scroll" then
		lineFrom = lineFrom + (e[5] > 0 and -1 or 1)

		if lineFrom < 1 then
			lineFrom = 1
		elseif lineFrom > #lines then
			lineFrom = #lines
		end

		workspace:draw()

	elseif e[1] == "key_down" and GUI.focusedObject == window then
		-- Return
		if e[4] == 28 then

			window:addLine("> " .. text.limit(input, display.width - 3, "left", true))
			local cmd = input
            runCmd(cmd)
			input = ""
			
		
		-- Backspace
		elseif e[4] == 14 then
			input = unicode.sub(input, 1, -2)
		-- Printable character
		elseif not keyboard.isControl(e[3]) then
			input = input .. unicode.char(e[3])
		end

		workspace:draw()
	end

	overrideWindowEventHandler(workspace, window, ...)
end

window.onResize = function(newWidth, newHeight)
	window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
	display.width, display.height = newWidth - 2, newHeight - 3
end

---------------------------------------------------------------------------------

window.onResize(window.width, window.height)

return window