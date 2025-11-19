local macroStart = 1
local oscDestinationIP = "192.168.10.100"
local oscPort = 12000
local oscNumber = 1
local pageNumber = 2
local projectorPage
local findNextAvailableMacroNumber, makeOscCommand, makeOscCommand, makeLines,
createOSCMacro, generateProjectorMacros, setupLayout, assignRotaryEncoder,
assignButtonExecutor, findExecutor, executorString, macroCommandString

local OSC_COMMANDS = {
	{ name = "POWER ON",               command = "power,i,1" },
	{ name = "POWER OFF",              command = "power,i,0" },
	{ name = "SHUTTER CLOSE",          command = "shutter,i,1" },
	{ name = "SHUTTER OPEN",           command = "shutter,i,0" },
	{ name = "ZOOM+",                  command = "zoomIn,," },
	{ name = "ZOOM-",                  command = "zoomOut,," },
	{ name = "FOCUS FAR",              command = "focusFar,," },
	{ name = "FOCUS NEAR",             command = "focusNear,," },
	{ name = "CENTER LENS",            command = "centerLens,," },
	{ name = "LOCK LENS",              command = "lensLock,i,1" },
	{ name = "UNLOCK LENS",            command = "lensLock,i,0" },
	{ name = "LENS SHIFT UP",          command = "lensUp,," },
	{ name = "LENS SHIFT DOWN",        command = "lensDown,," },
	{ name = "LENS SHIFT LEFT",        command = "lensLeft,," },
	{ name = "LENS SHIFT RIGHT",       command = "lensRight,," },
	{ name = "TEST PATTERNS",          command = "testPattern,i,",  range = 12 },
	{ name = "INPUT",                  command = "input,i,",        range = 8 },
	{ name = "ASPECT RATIO",           command = "ratio,i,",        range = 9 },
	{ name = "ACTIVE WARP",            command = "activeWarp,i,",   range = 6 },
	{ name = "RESET ACTIVE WARP",      command = "resetWarp,," },
	{ name = "ACTIVATE WARP KEYSTONE", command = "activeWarp,i,1" },
	{ name = "ACTIVATE WARP 4CORNERS", command = "activeWarp,i,2" },
	{ name = "ACTIVATE WARP ROTATION", command = "activeWarp,i,3" },
	{ name = "V KEYSTONE +",           command = "keystoneV/up,," },
	{ name = "V KEYSTONE -",           command = "keystoneV/down,," },
	{ name = "H KEYSTONE +",           command = "keystoneH/up,," },
	{ name = "H KEYSTONE -",           command = "keystoneV/down,," },
	{ name = "ULX+",                   command = "cornerULX/up,," },
	{ name = "ULX-",                   command = "cornerULX/down,," },
	{ name = "ULY+",                   command = "cornerULY/up,," },
	{ name = "ULY-",                   command = "cornerULY/down,," },
	{ name = "URX+",                   command = "cornerURX/up,," },
	{ name = "URX-",                   command = "cornerURX/down,," },
	{ name = "URY+",                   command = "cornerURY/up,," },
	{ name = "URY-",                   command = "cornerURY/down,," },
	{ name = "LLX+",                   command = "cornerLLX/up,," },
	{ name = "LLX-",                   command = "cornerLLX/down,," },
	{ name = "LLY+",                   command = "cornerLLY/up,," },
	{ name = "LLY-",                   command = "cornerLLY/down,," },
	{ name = "LRX+",                   command = "cornerLRX/up,," },
	{ name = "LRX-",                   command = "cornerLRX/down,," },
	{ name = "LRY+",                   command = "cornerLRY/up,," },
	{ name = "LRY-",                   command = "cornerLRY/down,," },
	{ name = "ROTATION+",              command = "rotation/up,," },
	{ name = "ROTATION-",              command = "rotation/down,," }

}

local function Main(displayHandle, argument)
	Printf("Plugin started")
	-- local networkInterfaces = Root().Interfaces
	-- local defaultInterface = networkInterfaces[2]
	-- defaultInterface:Children()[1]:Dump()
	-- interfaceIP = defaultInterface:Children()[1].ip
	-- Printf("interface ip is " .. interfaceIP)

	-- for i, interface in ipairs(networkInterfaces) do
	-- 	interfaceSelector[interface.name] = i
	-- end
	--config popup
	local settings =
		MessageBox(
			{
				title = "Setup projector control",
				message = "Please adjust these settings as needed.",
				display = displayHandle.index,
				inputs = {
					{ value = oscDestinationIP, name = "OSC Destination IP" },
					{ value = oscPort,          name = "Port" },
					-- { value = interfaceIP,      name = "Interface IP" },
					{ value = macroStart,       name = "Macro start index" },
					{ value = pageNumber,       name = "Page" }
				},
				-- selectors = {
				-- 	{ name = "Interface", values = interfaceSelector, selectedValue = 2, type = 0 }
				-- },
				states = {
					{ name = "Auto start index", state = false }
				},
				commands = {
					{ value = 1, name = "OK" },
					{ value = 2, name = "Cancel" }
				}
			}
		)

	-- Cancel
	if settings.result == 2 then
		Printf("Setup aborted by user.")
		return
	end

	-- setup OSC
	oscDestinationIP = settings.inputs["OSC Destination IP"]
	oscPort = settings.inputs["Port"]
	local oscBase = ShowData().OSCBase
	local oscInterface = oscBase:Append()
	oscInterface.Name = 'Projector Control'
	oscInterface.Port = oscPort
	oscInterface.DestinationIP = oscDestinationIP
	oscInterface.SendCommand = "Yes"
	oscInterface.Prefix = "projector"
	oscNumber = oscInterface.No
	Printf("Projector control will use OSC interface number " .. oscNumber)
	Printf("OSC IP: " .. oscDestinationIP .. " Port: " .. oscPort)

	--setup network port
	-- interfaceIP = settings.inputs["Interface IP"]
	-- local networkInterface = networkInterfaces[settings.selectors["Interface"]]
	-- local networkIP = networkInterface:Children()[1]
	-- networkIP.ip = interfaceIP
	-- networkIP:Dump()

	-- Printf("Using network interface " .. networkInterface.Name .. " with IP " .. interfaceIP .. " to send OSC data.")

	-- setup macros
	if (settings.states["Auto start index"]) then
		Printf("Finding start index...")
		macroStart = findNextAvailableMacroNumber()
	else
		macroStart = settings.inputs["Macro start index"]
	end
	Printf("Starting macros at index " .. macroStart)
	Printf("creating macros...")
	generateProjectorMacros()
	Printf("created projector macros")

	-- Setup layout
	pageNumber = settings.inputs["Page"]
	setupLayout(pageNumber)

	-- Setup recap
	local recapString = string.format("OSC will be sent using interface %s with destination %s:%s \n"
		.. "Macros have been generated starting at Macro %d \n"
		.. "Commands have been assigned to executors on page %d \n"
		.. "Commands for Power ON and OFF have not been mapped to any executors to ensure they're not accidentally triggered. \n"
		.. "Please make sure your connector configuration uses an IP range matching the OSC destination",
		oscNumber,
		oscDestinationIP,
		oscPort,
		macroStart,
		pageNumber
	)

	MessageBox(
		{
			title = "Setup complete",
			message = recapString,
			display = displayHandle.index,
			commands = {
				{ value = 1, name = "OK" }
			}
		}
	)
end

-- UTILS
function findNextAvailableMacroNumber()
	local allMacrosNotEmpty = {}
	local allMacros = #DataPool().Macros
	Printf("Show has already " .. allMacros .. " Macros")
	for i = 1, #DataPool().Macros do
		local macro = DataPool().Macros[i]
		local isValid = IsObjectValid(macro)
		if isValid then
			table.insert(allMacrosNotEmpty, macro)
		end
	end
	Printf("But only " .. #allMacrosNotEmpty .. " valid ones")
	if #allMacrosNotEmpty == 0 then
		return 1
	else
		return allMacrosNotEmpty[#allMacrosNotEmpty].No + 1
	end
end

function generateProjectorMacros()
	for i, macro in ipairs(OSC_COMMANDS) do
		createOSCMacro(macroStart + i - 1, macro.name, macro.command, macro.range)
	end
end

function createOSCMacro(number, name, command, range)
	local macroRoot = DataPool().Macros
	local newOSCMacro = macroRoot:Create(number)
	newOSCMacro:Set("Name", name)
	makeLines(newOSCMacro, command, range)
	-- newOSCMacro:Set("CLI", false)
	-- newOSCMacro:Set("Appearance", "ScreenConfig")
end

function makeLines(macro, command, range)
	if range == nil or range == 1 then
		local line = macro:Insert(1)
		line:Set("Command", makeOscCommand(command))
	else
		for i = 1, range do
			local line = macro:Insert(i)
			line:Set("Command", makeOscCommand(command .. i - 1))
			line:Set("Wait", "Go")
		end
	end
end

function makeOscCommand(command)
	return string.format('SendOSC %d "/%s"', oscNumber, command)
end

function setupLayout(pageNumber)
	projectorPage = DataPool().Pages:Create(tonumber(pageNumber))

	-- Functions on knobs
	assignRotaryEncoder(401, "ZOOM", "ZOOM-", "ZOOM+")
	assignButtonExecutor(301, "CENTER LENS")
	assignRotaryEncoder(402, "FOCUS", "FOCUS NEAR", "FOCUS FAR")
	assignButtonExecutor(302, "LOCK LENS")
	assignRotaryEncoder(403, "LENS SHIFT V", "LENS SHIFT DOWN", "LENS SHIFT UP")
	assignRotaryEncoder(404, "LENS SHIFT H", "LENS SHIFT LEFT", "LENS SHIFT RIGHT")
	assignRotaryEncoder(405, "VERT KEYSTONE", "V KEYSTONE -", "V KEYSTONE +")
	assignRotaryEncoder(305, "HOR KEYSTONE", "H KEYSTONE -", "H KEYSTONE +")

	assignRotaryEncoder(406, "CORNER ULX", "ULX-", "ULX+")
	assignRotaryEncoder(407, "CORNER ULY", "ULY-", "ULY+")
	assignRotaryEncoder(408, "CORNER URX", "URX-", "URX+")
	assignRotaryEncoder(409, "CORNER URY", "URY-", "URY+")
	assignRotaryEncoder(306, "CORNER LLX", "LLX-", "LLX+")
	assignRotaryEncoder(307, "CORNER LLY", "LLY-", "LLY+")
	assignRotaryEncoder(308, "CORNER LRX", "LRX-", "LRX+")
	assignRotaryEncoder(309, "CORNER LRY", "LRY-", "LRY+")

	assignRotaryEncoder(411, "ROTATION", "ROTATION-", "ROTATION+")

	-- Functions on buttons
	assignButtonExecutor(101, "SHUTTER OPEN")
	assignButtonExecutor(102, "SHUTTER CLOSE")

	assignButtonExecutor(106, "TEST PATTERNS")
	assignButtonExecutor(107, "INPUT")
	assignButtonExecutor(108, "ASPECT RATIO")
	assignButtonExecutor(109, "ACTIVE WARP")

	assignButtonExecutor(111, "ACTIVATE WARP KEYSTONE")
	assignButtonExecutor(112, "ACTIVATE WARP 4CORNERS")
	assignButtonExecutor(113, "ACTIVATE WARP ROTATION")
	assignButtonExecutor(115, "RESET ACTIVE WARP")
end

function assignRotaryEncoder(execNumber, label, commandLeft, commandRight)
	local cmdLeftString = macroCommandString(commandLeft)
	local cmdRightString = macroCommandString(commandRight)
	local execString = executorString(execNumber);
	local cmd = string.format("Store Page %s \"%s\"", execString, label)
	Cmd(cmd)
	local newEncoder = findExecutor(execNumber)

	if newEncoder ~= nil then
		--newEncoder:Dump()
		newEncoder:Set("EncoderLeftCommand", cmdLeftString)
		newEncoder:Set("EncoderLeftAddExec", "No")
		newEncoder:Set("EncoderLeftUseCustomCommand", "Yes")
		newEncoder:Set("EncoderRightCommand", cmdRightString)
		newEncoder:Set("EncoderRightAddExec", "No")
		newEncoder:Set("EncoderRightUseCustomCommand", "Yes")
		newEncoder:Set("Key", "Empty")
	else
		Printf("No encoder there")
	end
end

function assignButtonExecutor(executorNumber, command)
	local cmdString = macroCommandString(command)
	local executorString = executorString(executorNumber)
	local cmd = string.format("Assign %s At Page %s", cmdString, executorString)
	Cmd(cmd)
end

function macroCommandString(command)
	return string.format("Macro \"%s\"", command)
end

function executorString(execNumber)
	return string.format("%d.%d", pageNumber, execNumber)
end

function findExecutor(number)
	local allExecs = projectorPage:Children()
	for i = 1, #allExecs do
		local exec = allExecs[i]
		if tonumber(exec.index) == number then
			return exec
		end
	end
end

return Main
