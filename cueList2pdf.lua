-- PDF lib
PDF = {}
PDF.new = function()
	local pdf = {}       -- instance variable
	local page = {}      -- array of page descriptors
	local object = {}    -- array of object contents
	local xref_table_offset -- byte offset of xref table

	local catalog_obj    -- global catalog object
	local pages_obj      -- global pages object
	local procset_obj    -- global procset object

	--
	-- Private functions.
	--

	local add = function(obj)
		table.insert(object, obj)
		obj.number = #object
		return obj
	end

	local get_ref = function(obj)
		return string.format("%d 0 R", obj.number)
	end

	local write_object
	local write_direct_object
	local write_indirect_object

	write_object = function(fh, obj)
		if type(obj) == "table" and obj.datatype == "stream" then
			write_indirect_object(fh, obj)
		else
			write_direct_object(fh, obj)
		end
	end

	write_direct_object = function(fh, obj)
		if type(obj) ~= "table" then
			fh:write(obj .. "\n")
		elseif obj.datatype == "dictionary" then
			local k, v

			fh:write("<<\n")
			for k, v in pairs(obj.contents) do
				fh:write(string.format("/%s ", k))
				write_object(fh, v)
			end
			fh:write(">>\n")
		elseif obj.datatype == "array" then
			local v

			fh:write("[\n")
			for _, v in ipairs(obj.contents) do
				write_object(fh, v)
			end
			fh:write("]\n")
		elseif obj.datatype == "stream" then
			local len = 0

			if type(obj.contents) == "string" then
				len = string.len(obj.contents)
			else -- assume array
				local i, str

				for i, str in ipairs(obj.contents) do
					len = len + string.len(str) + 1
				end
			end

			fh:write(string.format("<< /Length %d >>\n", len))
			fh:write("stream\n")

			if type(obj.contents) == "string" then
				fh:write(obj.contents)
			else -- assume array
				local i, str

				for i, str in ipairs(obj.contents) do
					fh:write(str)
					fh:write("\n")
				end
			end

			fh:write("endstream\n")
		end
	end

	write_indirect_object = function(fh, obj)
		obj.offset = fh:seek()
		fh:write(string.format("%d %d obj\n", obj.number, 0))
		write_direct_object(fh, obj)
		fh:write("endobj\n")
	end

	local write_header = function(fh)
		fh:write("%PDF-1.0\n")
	end

	local write_body = function(fh)
		local i, obj

		for i, obj in ipairs(object) do
			write_indirect_object(fh, obj)
		end
	end

	local write_xref_table = function(fh)
		local i, obj

		xref_table_offset = fh:seek()
		fh:write("xref\n")
		fh:write(string.format("%d %d\n", 1, #object))
		for i, obj in ipairs(object) do
			fh:write(
				string.format("%010d %05d n \n", obj.offset, 0)
			)
		end
	end

	local write_trailer = function(fh)
		fh:write("trailer\n")
		fh:write("<<\n")
		fh:write(string.format("/Size %d\n", #object))
		fh:write("/Root " .. get_ref(catalog_obj) .. "\n")
		fh:write(">>\n")
		fh:write("startxref\n")
		fh:write(string.format("%d\n", xref_table_offset))
		fh:write("%%EOF\n")
	end

	--
	-- Instance methods.
	--

	pdf.new_font = function(pdf, tab)
		local subtype = tab.subtype or "Type1"
		local name = tab.name or "Helvetica"
		local weight = tab.weight or ""
		local font_obj = add {
			datatype = "dictionary",
			contents = {
				Type = "/Font",
				Subtype = "/" .. subtype,
				BaseFont = "/" .. name .. weight,
			}
		}
		return font_obj
	end


	pdf.new_page = function(pdf)
		local pg = {}  -- instance variable
		local contents = {} -- array of operation strings
		local used_font = {} -- fonts used on this page

		--
		-- Private functions.
		--

		local use_font = function(font_obj)
			local i, f

			for i, f in ipairs(used_font) do
				if font_obj == f then
					return "/F" .. i
				end
			end

			table.insert(used_font, font_obj)
			return "/F" .. #used_font
		end

		--
		-- Instance methods.
		--

		--
		-- Text functions.
		--

		pg.begin_text = function(pg)
			table.insert(contents, "BT")
		end

		pg.end_text = function(pg)
			table.insert(contents, "ET")
		end

		pg.set_font = function(pg, font_obj, size)
			table.insert(contents,
				string.format("%s %f Tf",
					use_font(font_obj), size)
			)
		end

		pg.set_text_pos = function(pg, x, y)
			table.insert(contents,
				string.format("%f %f Td", x, y)
			)
		end

		pg.show = function(pg, str)
			table.insert(contents,
				string.format("(%s) Tj", str)
			)
		end

		pg.set_char_spacing = function(pg, spc)
			table.insert(contents,
				string.format("%f Tc", spc)
			)
		end

		--
		-- Graphics - path drawing functions.
		--

		pg.moveto = function(pg, x, y)
			table.insert(contents,
				string.format("%f %f m", x, y)
			)
		end

		pg.lineto = function(pg, x, y)
			table.insert(contents,
				string.format("%f %f l", x, y)
			)
		end

		pg.curveto = function(pg, x1, y1, x2, y2, x3, y3)
			local str

			if x3 and y3 then
				str = string.format("%f %f %f %f %f %f c",
					x1, y1, x2, y2, x3, y3)
			else
				str = string.format("%f %f %f %f v",
					x1, y1, x2, y2)
			end

			table.insert(contents, str)
		end

		pg.rectangle = function(pg, x, y, w, h)
			table.insert(contents,
				string.format("%f %f %f %f re",
					x, y, w, h)
			)
		end

		--
		-- Graphics - colours.
		--

		pg.setgray = function(pg, which, gray)
			assert(which == "fill" or which == "stroke")
			assert(gray >= 0 and gray <= 1)
			if which == "fill" then
				table.insert(contents,
					string.format("%d g", gray)
				)
			else
				table.insert(contents,
					string.format("%d G", gray)
				)
			end
		end

		pg.setrgbcolor = function(pg, which, r, g, b)
			assert(which == "fill" or which == "stroke")
			assert(r >= 0 and r <= 1)
			assert(g >= 0 and g <= 1)
			assert(b >= 0 and b <= 1)
			if which == "fill" then
				table.insert(contents,
					string.format("%f %f %f rg", r, g, b)
				)
			else
				table.insert(contents,
					string.format("%f %f %f RG", r, g, b)
				)
			end
		end

		pg.setcmykcolor = function(pg, which, c, m, y, k)
			assert(which == "fill" or which == "stroke")
			assert(c >= 0 and c <= 1)
			assert(m >= 0 and m <= 1)
			assert(y >= 0 and y <= 1)
			assert(k >= 0 and k <= 1)
			if which == "fill" then
				table.insert(contents,
					string.format("%f %f %f %f k", c, m, y, k)
				)
			else
				table.insert(contents,
					string.format("%f %f %f %f K", c, m, y, k)
				)
			end
		end

		--
		-- Graphics - line options.
		--

		pg.setflat = function(pg, i)
			assert(i >= 0 and i <= 100)
			table.insert(contents,
				string.format("%d i", i)
			)
		end

		pg.setlinecap = function(pg, j)
			assert(j == 0 or j == 1 or j == 2)
			table.insert(contents,
				string.format("%d J", j)
			)
		end

		pg.setlinejoin = function(pg, j)
			assert(j == 0 or j == 1 or j == 2)
			table.insert(contents,
				string.format("%d j", j)
			)
		end

		pg.setlinewidth = function(pg, w)
			table.insert(contents,
				string.format("%d w", w)
			)
		end

		pg.setmiterlimit = function(pg, m)
			assert(m >= 1)
			table.insert(contents,
				string.format("%d M", m)
			)
		end

		pg.setdash = function(pg, array, phase)
			local str = ""
			local v

			for _, v in ipairs(array) do
				str = str .. v .. " "
			end

			table.insert(contents,
				string.format("[%s] %d d", str, phase)
			)
		end

		--
		-- Graphics - path-terminating functions.
		--

		pg.stroke = function(pg)
			table.insert(contents, "S")
		end

		pg.closepath = function(pg)
			table.insert(contents, "h")
		end

		pg.fill = function(pg)
			table.insert(contents, "f")
		end

		pg.newpath = function(pg)
			table.insert(contents, "n")
		end

		pg.clip = function(pg) -- no effect until next newpath
			table.insert(contents, "W")
		end

		--
		-- Graphics - state save/restore.
		--

		pg.save = function(pg)
			table.insert(contents, "q")
		end

		pg.restore = function(pg)
			table.insert(contents, "Q")
		end

		--
		-- Graphics - CTM functions.
		--
		pg.transform = function(pg, a, b, c, d, e, f) -- aka concat
			table.insert(contents,
				string.format("%f %f %f %f %f %f cm",
					a, b, c, d, e, f)
			)
		end

		pg.translate = function(pg, x, y)
			pg:transform(1, 0, 0, 1, x, y)
		end

		pg.scale = function(pg, x, y)
			if not y then y = x end
			pg:transform(x, 0, 0, y, 0, 0)
		end

		pg.rotate = function(pg, theta)
			local c, s = math.cos(theta), math.sin(theta)
			pg:transform(c, s, -1 * s, c, 0, 0)
		end

		pg.skew = function(pg, tha, thb)
			local tana, tanb = math.tan(tha), math.tan(thb)
			pg:transform(1, tana, tanb, 1, 0, 0)
		end

		pg.add = function(pg)
			local contents_obj, this_obj, resources
			local i, font_obj

			contents_obj = add {
				datatype = "stream",
				contents = contents
			}

			resources = {
				datatype = "dictionary",
				contents = {
					Font = {
						datatype = "dictionary",
						contents = {}
					},
					ProcSet = get_ref(procset_obj)
				}
			}

			for i, font_obj in ipairs(used_font) do
				resources.contents.Font.contents["F" .. i] =
					get_ref(font_obj)
			end

			this_obj = add {
				datatype = "dictionary",
				contents = {
					Type = "/Page",
					Parent = get_ref(pages_obj),
					Contents = get_ref(contents_obj),
					Resources = resources
				}
			}

			table.insert(pages_obj.contents.Kids.contents,
				get_ref(this_obj))
			pages_obj.contents.Count = pages_obj.contents.Count + 1
		end

		table.insert(page, pg)
		return pg
	end

	pdf.write = function(pdf, file)
		local fh

		if type(file) == "string" then
			fh = assert(io.open(file, "w"))
		else
			fh = file
		end

		write_header(fh)
		write_body(fh)
		write_xref_table(fh)
		write_trailer(fh)

		fh:close()
	end

	-- initialize... add a few objects that we know will exist.
	pages_obj = add {
		datatype = "dictionary",
		contents = {
			Type = "/Pages",
			Kids = {
				datatype = "array",
				contents = {}
			},
			Count = 0
		}
	}

	catalog_obj = add {
		datatype = "dictionary",
		contents = {
			Type = "/Catalog",
			Pages = get_ref(pages_obj)
		}
	}

	procset_obj = add {
		datatype = "array",
		contents = { "/PDF", "/Text" }
	}

	return pdf
end


-- ====================== START OF PLUGIN
local footerNotice = "GrandMA3 - CueList2PDF"
local errMsgNoUSBDevice = "Please connect a removable storage device to the system."

local xPosNumber = 20
local xPosPart = 60
local xPosName = 100
local xPosInfo = 200
local xPosFade = 530
local xPosTrig = 570

local yPosHeaderRow = 600
local yPosStageName = 770

local function Main(displayHandle, argument)
	require 'gma3_debug' ()
	debuggee.print("log", "start")

	local datetime = os.date("Created at: %d.%m.%Y %H:%M")
	local softwareVersion = Version()
	local host = HostType()
	local allSequences = DataPool().Sequences
	local allSequencesNotEmpty = {}

	for i = 1, #allSequences do
		local seq = DataPool().Sequences[i]
		local isValid = IsObjectValid(seq)
		if isValid then
			table.insert(allSequencesNotEmpty, seq)
		end
	end
	Printf("I found " .. #allSequences .. " sequences, with " .. #allSequencesNotEmpty .. " not empty")
	for i, seq in ipairs(allSequencesNotEmpty) do
		Printf(seq.Name)
	end


	--Utils
	local function toSeconds(fadeTime)
		local value = "-"
		if fadeTime > 0 then
			value = tostring(fadeTime / (256 ^ 3))
		elseif fadeTime == 0 or fadeTime == nil then
			value = "-"
		end
		return value
	end

	local function makeLine(cue)
		local part = cue:Children()[1]
		local cueName = "Cue " .. cue.No
		if cue.Name ~= nil then
			cueName = cue.Name
		end
		local partNo = "0"
		if part.Part ~= nil then
			partNo = part.Part
		end
		local inFade = "0"
		if part.CueInFade ~= nil then
			inFade = toSeconds(part.CueInFade)
		end
		local outFade = "0"
		if part.CueOutFade ~= nil then
			outFade = toSeconds(part.CueOutFade)
		end
	end

	-- ================ WELCOME POPUP =====================
	local showFileName = Root().manetsocket.showfile
	local fileNameSuggestion = os.date("%d-%m-%Y-%H-%M_" .. showFileName)
	local documentTitleSuggestion = showFileName .. " - Cue list"
	local seqSelector = {}
	for i, seq in ipairs(allSequencesNotEmpty) do
		seqSelector[seq.Name] = i
	end

	local selectors = {
		{ name = "Sequence", values = seqSelector, type = 1 },
	}

	-- Helper for assigning the drives in the list an ID
	local idCounter = 0

	-- Get currently connected storage devices
	local drives = Root().Temp.DriveCollect
	local usbConnected = false

	for _, drive in ipairs(drives) do
		idCounter = idCounter + 1
		if drive.drivetype ~= "OldVersion" and drive.drivetype == "Removeable" then
			-- At least one removeable storage device was found
			usbConnected = true
			table.insert(selectors, { name = "Drive", values = {}, type = 1 })
			selectors[2].values[drive.name] = idCounter
			selectors[2].selectedValue = idCounter
		end
	end

	-- If no removeable storage device was found, the plugin will warn
	local res = {}
	if usbConnected == false then
		res =
			MessageBox(
				{
					title = "Warning",
					message = "No USB drive detected, file will be saved to internal drive.",
					display = displayHandle.index,
					commands = { { value = 1, name = "Ok" }, { value = 2, name = "Cancel" } },
				}
			)
	else
		res.result = 1
	end

	if res.result == 2 then
		Printf("Export aborted by user.")
		return
	end

	local settings =
		MessageBox(
			{
				title = "Export cue list to PDF",
				message = "Please adjust these settings as needed.",
				display = displayHandle.index,
				inputs = {
					{ value = documentTitleSuggestion, name = "Document Title" },
					{ value = fileNameSuggestion,      name = "File name" },
					{ value = CurrentUser().name,      name = "Author" } }
				,
				selectors = selectors,
				commands = { { value = 1, name = "Export" }, { value = 2, name = "Cancel" } },
			}
		)

	-- Cancel
	if settings.result == 2 then
		Printf("Export aborted by user.")
		return
	end

	local selectedSequence
	local drivePath = ""

	for k, v in pairs(settings.selectors) do
		if k == "Sequence" then
			selectedSequence = allSequencesNotEmpty[v]
		end
		if k == "Drive" then
			drivePath = drives[v].path
		end
	end

	if selectedSequence == nil then
		ErrPrintf("The selected sequence could not be found.")
		return
	else
		Printf("You have selected Sequence " .. selectedSequence.Name)
	end



	-- ==================== GET CUE DATA ===================================
	-- Iterate through cues
	local cues = selectedSequence:Children()
	Printf("Sequence " .. selectedSequence.Name .. " contains " .. #cues .. " cues.")

	for i, cue in ipairs(cues) do
		if cue.No ~= nil then
			Printf(" at index " .. i .. " Cue number " .. cue.No .. " is called " .. cue.Name)
			if #cue:Children() > 1 then
				Printf("      This cue has multiple parts:")
				local parts = cue:Children()
				for j, part in ipairs(parts) do
					Printf("      " .. part.Part .. " " .. part.Name .. " inFade: " .. toSeconds(part.CueInFade))
				end
			else
				Printf("inFade: " .. toSeconds(cue:Children()[1].CueInFade))
				--exportData[i] = makeLine(cue)
			end
		end
		if cue.Name == "OffCue" then
			Printf(cue.Name .. " is the offcue")
		end
	end

	--============================= START PDF STUFF ===========================
	--Export data
	local documentTitle = settings.inputs["Document Title"]
	local fileName = settings.inputs["File name"]
	local author = settings.inputs["Author"]

	-- Create a new PDF document
	local p = PDF.new()

	local helv = p:new_font { name = "Helvetica" }
	local bold = p:new_font { name = "Helvetica", weight = "-Bold" }

	-- Table for holding all pages which will be created during the printing process
	local pages = {}

	-- Create the initial page
	local page = p:new_page()
	table.insert(pages, page)

	page:save()

	local textSize = 10
	local headerSize = 22

	function printElement(page, data, posX, posY, font, fontSize)
		if font ~= nil and fontSize ~= nil then
			page:begin_text()
			page:set_font(font, fontSize)
			page:set_text_pos(posX, posY)
			page:show(data)
			page:end_text()
		else --default to basic font and size
			page:begin_text()
			page:set_font(helv, textSize)
			page:set_text_pos(posX, posY)
			page:show(data)
			page:end_text()
		end
	end

	local function printSeparationLine(page, yPos, color)
		local r = 0
		local g = 0
		local b = 0
		if color ~= nil then
			r = color[1]
			g = color[2]
			b = color[3]
		end
		page:setrgbcolor("stroke", r, g, b)
		page:moveto(20, yPos - 5)
		page:lineto(590, yPos - 5)
		page:stroke()
	end

	local function tagRow(page, colorString, yPos)
		page:save()
		local color = {}
		color.r = 0
		color.g = 0
		color.b = 0
		if colorString == "blue" then
			color.b = 1
		elseif colorString == "red" then
			color.r = 1
		elseif colorString == "green" then
			color.g = 1
		end
		page:setrgbcolor("fill", color.r, color.g, color.b)
		page:newpath()
		page:moveto(10, yPos + 13)
		page:lineto(15, yPos + 13)
		page:lineto(15, yPos - 7)
		page:lineto(10, yPos - 7)
		page:lineto(10, yPos + 13)
		page:closepath()
		page:fill()
		page:restore()
	end

	local function printDocumentHeader(page)
		printElement(page, documentTitle, 20, 725, bold, headerSize)
		local versionString = "Software version: " .. softwareVersion .. ", Host: " .. host
		printElement(page, versionString, 20, 685)
		local showfileString = "Showfile: " .. Root().manetsocket.showfile
		printElement(page, showfileString, 20, 670)
		local sequenceString = "Sequence: " .. selectedSequence.Name
		printElement(page, sequenceString, 20, 655)
		local authorString = "Author: " .. author
		printElement(page, authorString, 20, 640)
		page:restore()
	end

	printDocumentHeader(page)

	function printTableHeader(page, yPos)
		printElement(page, "#", xPosNumber, yPos)
		printElement(page, "Part", xPosPart, yPos)
		printElement(page, "Name", xPosName, yPos)
		printElement(page, "Info", xPosInfo, yPos)
		printElement(page, "Fade", xPosFade, yPos)
		printElement(page, "Trig", xPosTrig, yPos)
		printSeparationLine(page, yPos)
	end

	printTableHeader(page, yPosHeaderRow)

	function getCuesForSequence(sequence)
		local returnTable = {}
		local allCues = selectedSequence:Children()
		for _, cue in ipairs(allCues) do
			table.insert(returnTable, cue)
		end
		return returnTable
	end

	function emptyIfNil(obj)
		if obj == nil then
			return "-"
		else
			return obj
		end
	end

	function cleanupCues(rawList)
		local cleanedList = {}
		for i, cue in ipairs(rawList) do
			if cue.Name == "OffCue" then
				-- skip
			elseif cue.Name == "CueZero" then
				-- skip
			else
				local cueObj = {}
				cueObj.number = cue.No / 1000
				cueObj.name = cue.Name
				cueObj.note = emptyIfNil(cue.Note)
				cueObj.trigType = emptyIfNil(cue.TrigType)
				cueObj.trigTime = toSeconds(cue.TrigTime)
				cueObj.parts = {}
				for i, part in ipairs(cue:Children()) do
					local partObj = {}
					partObj.name = emptyIfNil(part.Name)
					partObj.note = emptyIfNil(part.Note)
					partObj.number = emptyIfNil(part.Part)
					partObj.inFade = toSeconds(part.CueInFade)
					partObj.outFade = toSeconds(part.CueOutFade)
					partObj.inDelay = toSeconds(part.CueInDelay)
					partObj.outDelay = toSeconds(part.CueOutDelay)
					table.insert(cueObj.parts, partObj)
				end
				table.insert(cleanedList, cueObj)
			end
		end
		return cleanedList
	end

	local currentY = 570
	local currentPage = page
	local pageCount = 1
	local nextLine = 20

	local lastUniverse = 0
	local lastStage = nil

	local maxFixtureTypeNameLength = 45
	local maxFixtureNameLength = 32
	local maxStageNameLength = 80

	local function newpageIfNeeded()
		currentY = currentY - nextLine
		if currentY < 50 then
			local newPage = p:new_page()
			pageCount = pageCount + 1
			table.insert(pages, newPage)
			currentPage = newPage
			printTableHeader(currentPage, 750)
			currentY = 720
		end
	end

	local function printCueRow(page, cue)
		printElement(page, cue.number, xPosNumber, currentY)
		printElement(page, cue.name, xPosName, currentY)
		printElement(page, cue.note, xPosInfo, currentY)
		local isMultipart = #cue.parts > 1
		local isAutoTrig = cue.trigType ~= 0
		local part1 = cue.parts[1]
		local fadeString = part1.inFade .. "/" .. part1.outFade
		printElement(page, fadeString, xPosFade, currentY)
		if isAutoTrig then -- follow or time cues
			tagRow(page, "red", currentY)
			local trigType
			if cue.trigType == 2 then -- follow
				trigType = "F"
			elseif cue.trigType == 1 then -- time
				trigType = "T"
			end
			local trigString = trigType .. " " .. cue.trigTime
			printElement(page, trigString, xPosTrig, currentY)
		else -- go cues
			tagRow(page, "green", currentY)
			printElement(page, "Go", xPosTrig, currentY)
		end
		if isMultipart then -- multipart cues
			for i = 2, #cue.parts do
				local part = cue.parts[i]
				newpageIfNeeded()
				printElement(page, part.number, xPosPart, currentY)
				printElement(page, part.name, xPosName, currentY)
				printElement(page, part.note, xPosInfo, currentY)
				local fadeString = part.inFade .. "/" .. part.outFade
				printElement(page, fadeString, xPosFade, currentY)
				tagRow(page, "blue", currentY)
			end
		end

		local color = { 0.8, 0.8, 0.8 }
		printSeparationLine(page, currentY, color)
		newpageIfNeeded()
	end

	local cuesRaw = getCuesForSequence(selectedSequence)
	local cues = cleanupCues(cuesRaw)

	Printf("Clean list contains " .. #cues .. " cues")
	Printf("The first cue has number " .. cues[1].number .. " and name " .. cues[1].name)

	for i, cue in ipairs(cues) do
		printCueRow(currentPage, cue, currentY)
	end


	for k, v in pairs(pages) do
		-- Add pagination to the page
		v:begin_text()
		v:set_font(helv, textSize)
		v:set_text_pos(520, 10)
		v:show("Page " .. k .. "/" .. pageCount)
		v:end_text()

		-- Add the footer notice to the page
		v:begin_text()
		v:set_font(helv, textSize)
		v:set_text_pos(20, 10)
		v:show(footerNotice)
		v:end_text()

		-- Add the page to the document
		v:add()
	end

	local internalStoragePath = GetPath(Enums.PathType.Library) .. "/exports/" .. fileName .. ".pdf"
	local externalStoragePath = drivePath .. "/" .. fileName .. ".pdf"
	local storagePath
	if drivePath ~= "" then
		storagePath = externalStoragePath
	else
		storagePath = internalStoragePath
	end
	p:write(storagePath)
	Printf("PDF created successfully at " .. storagePath)
	-- ============================ END PDF STUFF =============================
end

return Main
