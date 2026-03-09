local addonName, MethodDungeonTools = ...
_G["MethodDungeonTools"] = MethodDungeonTools

-- Initialize core tables early for dungeon data files
MethodDungeonTools.dungeonEnemies = {}
MethodDungeonTools.dungeonBosses = {}
MethodDungeonTools.dungeonTotalCount = {}
MethodDungeonTools.dungeonMaps = {}
MethodDungeonTools.dungeonList = {
	{ text = "Ан'кахет: Старое Королевство", value = 1 },
	{ text = "Драк'Тарон", value = 2 },
	{ text = "Чертоги молний", value = 3 },
	{ text = "Бастионы адского пламени", value = 4 },
	{ text = "Гробницы маны", value = 5 },
	{ text = "Кузня крови", value = 6 },
	{ text = "Узилище", value = 7 },
	{ text = "Крепость Утгард", value = 8 },
}
MethodDungeonTools.dungeonSubLevels = {
	[1] = { { text = "1-й ярус", value = 1 } },
	[2] = { { text = "1-й ярус", value = 1 }, { text = "2-й ярус", value = 2 } },
	[3] = { { text = "1-й ярус", value = 1 }, { text = "2-й ярус", value = 2 } },
	[4] = { { text = "1-й ярус", value = 1 } },
	[5] = { { text = "1-й ярус", value = 1 } },
	[6] = { { text = "1-й ярус", value = 1 } },
	[7] = { { text = "1-й ярус", value = 1 } },
	[8] = {
		{ text = "1-й ярус", value = 1 },
		{ text = "2-й ярус", value = 2 },
		{ text = "3-й ярус", value = 3 },
	},
}

local Dialog = LibStub("LibDialog-1.0")
local dropDownLib, _ = LibStub("PhanxConfig-Dropdown")
local AceGUI = LibStub("AceGUI-3.0")

-- Local polyfills to avoid global namespace/metatable corruption
function MethodDungeonTools:SetColorTexture(texture, r, g, b, a)
	if texture.SetColorTexture then
		texture:SetColorTexture(r, g, b, a)
	else
		texture:SetTexture("Interface\\Buttons\\WHITE8X8")
		texture:SetVertexColor(r, g, b, a or 1)
	end
end

function MethodDungeonTools:SetDisplayInfo(model, id, isNpcId, modelPath)
	if modelPath and model.SetModel then
		model:SetModel(modelPath)
		if model.SetLight then
			model:SetLight(1, 0, 0, -0.707, -0.707, 0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8)
		end
	elseif model.SetCreature then
		model:SetCreature(id)
	end

	-- Camera 0 = reset, then Z=-2.5 zooms out to show full body regardless of DBC camera preset
	if model.SetCamera then
		model:SetCamera(0)
	end
	if model.SetModelScale then
		model:SetModelScale(1)
	end
	if model.SetPosition then
		model:SetPosition(0, 0, -2)
	end
	if model.SetFacing then
		model:SetFacing(0)
	end
end

function MethodDungeonTools:AceGUI_Create(...)
	local widget = AceGUI:Create(...)
	if widget then
		widget.EnableResize = widget.EnableResize or function() end
		widget.DisableButton = widget.DisableButton or function() end
		if not widget.SetFocus then
			widget.SetFocus = function(self)
				local f = self.editbox or self.frame
				if f and f.SetFocus then
					f:SetFocus()
				end
			end
		end
		if not widget.HighlightText then
			widget.HighlightText = function(self, ...)
				local f = self.editbox or self.frame
				if f and f.HighlightText then
					f:HighlightText(...)
				end
			end
		end
		if not widget.GetText then
			widget.GetText = function(self)
				local f = self.editbox or self.frame
				if f and f.GetText then
					return f:GetText()
				end
				return ""
			end
		end
		if not widget.SetText then
			widget.SetText = function(self, text)
				local f = self.editbox or self.frame
				if f and f.SetText then
					f:SetText(text)
				end
			end
		end
	end
	return widget
end

-- Polyfill for MouseIsOver
if not MouseIsOver then
	function MouseIsOver(frame)
		if not frame then
			return false
		end
		return frame:IsMouseOver()
	end
end

-- Polyfill for Encounter Journal (missing in 3.3.0)
if not EJ_GetCreatureInfo then
	function EJ_GetCreatureInfo()
		return nil
	end
end

-- Polyfill for C_Timer
if not C_Timer then
	C_Timer = {
		After = function(duration, callback)
			local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
			if AceTimer then
				return AceTimer:ScheduleTimer(callback, duration)
			end
		end,
	}
end

local mainFrameStrata = "HIGH"
local sizex = 840
local sizey = 555
local buttonTextFontSize = 12
local methodColor = "|cFFF49D38"

local db
local MDT_SHARE_PREFIX = "MDTSHARE"
local MDT_SHARE_MAX_CHUNK = 220
local icon = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("MethodDungeonTools", {
	type = "data source",
	text = "Method Dungeon Tools",
	icon = "Interface\\AddOns\\" .. addonName .. "\\Textures\\MethodMinimap.tga",
	OnClick = function(button, buttonPressed)
		if buttonPressed == "RightButton" then
			if db.minimap.lock then
				icon:Unlock("MethodDungeonTools")
			else
				icon:Lock("MethodDungeonTools")
			end
		else
			MethodDungeonTools:ShowInterface()
		end
	end,
	OnTooltipShow = function(tooltip)
		if not tooltip or not tooltip.AddLine then
			return
		end
		tooltip:AddLine(methodColor .. "Method Dungeon Tools|r")
		tooltip:AddLine("Click to toggle AddOn Window")
		tooltip:AddLine("Right-click to lock Minimap Button")
	end,
})

-- Made by: Nnogga - Tarren Mill <Method>, 2017

SLASH_METHODDUNGEONTOOLS1 = "/mplus"
SLASH_METHODDUNGEONTOOLS2 = "/mdt"
SLASH_METHODDUNGEONTOOLS3 = "/methoddungeontools"

--LUA API
local pi, tinsert = math.pi, table.insert

function MethodDungeonTools:ToggleDevMode()
	db.devMode = not db.devMode
	if db.devMode then
		print("|cFF00FF00[MDT]|r DevMode ENABLED. Right-click enemies for context menu.")
	else
		print("|cFF00FF00[MDT]|r DevMode DISABLED. Right-click enemies for Enemy Info.")
	end
end

function SlashCmdList.METHODDUNGEONTOOLS(cmd, editbox)
	local rqst, arg = strsplit(" ", cmd)
	if rqst == "devmode" then
		MethodDungeonTools:ToggleDevMode()
	elseif rqst == "remove" then
		--
	else
		MethodDungeonTools:ShowInterface()
	end
end

MethodDungeonTools.pendingSharedPresets = MethodDungeonTools.pendingSharedPresets or {}
MethodDungeonTools.incomingSharedPresets = MethodDungeonTools.incomingSharedPresets or {}
MethodDungeonTools.currentShareRequest = nil

function MethodDungeonTools:GetCurrentPresetExportString()
	return MethodDungeonTools:TableToString(
		db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]],
		true
	)
end

function MethodDungeonTools:GetShareChannel()
	if IsInRaid and IsInRaid() then
		return "RAID"
	end
	if IsInGroup and IsInGroup() then
		return "PARTY"
	end
	if GetNumPartyMembers and GetNumPartyMembers() > 0 then
		return "PARTY"
	end
	if GetRealNumRaidMembers and GetRealNumRaidMembers() > 0 then
		return "RAID"
	end
	if IsInGuild and IsInGuild() then
		return "GUILD"
	end
	return nil
end

function MethodDungeonTools:SendAddonComm(prefix, payload, channel, target)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		return C_ChatInfo.SendAddonMessage(prefix, payload, channel, target)
	elseif SendAddonMessage then
		return SendAddonMessage(prefix, payload, channel, target)
	end
	return false
end

function MethodDungeonTools:RegisterShareComm()
	if self.shareCommFrame then
		return
	end

	if RegisterAddonMessagePrefix then
		pcall(RegisterAddonMessagePrefix, MDT_SHARE_PREFIX)
	end

	self.shareCommFrame = CreateFrame("Frame")
	self.shareCommFrame:RegisterEvent("CHAT_MSG_ADDON")
	self.shareCommFrame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
		if event == "CHAT_MSG_ADDON" then
			MethodDungeonTools:HandleShareComm(prefix, message, channel, sender)
		end
	end)
end

function MethodDungeonTools:GenerateShareId()
	return tostring(time()) .. tostring(math.random(1000, 9999))
end

function MethodDungeonTools:OpenReceivedPresetDialog(sender, importString)
	self.currentShareRequest = {
		sender = sender,
		importString = importString,
	}

	local popupText =
		string.format("Игрок %s поделился маршрутом", sender or "неизвестно")
	if StaticPopup_Show then
		StaticPopup_Show("METHOD_DUNGEON_TOOLS_IMPORT_SHARE", popupText)
		return
	end

	print("|cFF00FF00[MDT]|r " .. popupText)
	print("|cFF00FF00[MDT]|r Открой MDT и импортируй строку вручную.")
end

function MethodDungeonTools:AcceptSharedPreset()
	local request = self.currentShareRequest
	if not request or not request.importString then
		print("|cFFFF0000[MDT]|r Нет маршрута для импорта.")
		return
	end

	local newPreset = MethodDungeonTools:StringToTable(request.importString, true)
	if MethodDungeonTools:ValidateImportPreset(newPreset) then
		MethodDungeonTools:ImportPreset(newPreset)
		print(
			"|cFF00FF00[MDT]|r Маршрут от "
				.. (request.sender or "неизвестно")
				.. " импортирован."
		)
	else
		print(
			"|cFFFF0000[MDT]|r Получен некорректный маршрут от "
				.. (request.sender or "неизвестно")
				.. "."
		)
	end
	self.currentShareRequest = nil
end

function MethodDungeonTools:DeclineSharedPreset()
	if self.currentShareRequest and self.currentShareRequest.sender then
		print("|cFFFFFF00[MDT]|r Маршрут от " .. self.currentShareRequest.sender .. " отклонён.")
	end
	self.currentShareRequest = nil
end

function MethodDungeonTools:HandleShareComm(prefix, message, channel, sender)
	if prefix ~= MDT_SHARE_PREFIX or not message or sender == UnitName("player") then
		return
	end

	local cmd, shareId, arg1, arg2 = strsplit("|", message)
	if not cmd or not shareId then
		return
	end

	if cmd == "START" then
		local totalChunks = tonumber(arg2) or 0
		self.incomingSharedPresets[shareId] = {
			sender = arg1 or sender,
			totalChunks = totalChunks,
			chunks = {},
		}
	elseif cmd == "DATA" then
		local data = self.incomingSharedPresets[shareId]
		if not data then
			return
		end
		local chunkIndex = tonumber(arg1)
		local chunkData = arg2 or ""
		if chunkIndex then
			data.chunks[chunkIndex] = chunkData
		end
	elseif cmd == "END" then
		local data = self.incomingSharedPresets[shareId]
		if not data then
			return
		end
		local parts = {}
		for i = 1, data.totalChunks do
			if not data.chunks[i] then
				print(
					"|cFFFF0000[MDT]|r Не удалось получить все части маршрута от "
						.. (data.sender or sender)
						.. "."
				)
				self.incomingSharedPresets[shareId] = nil
				return
			end
			parts[#parts + 1] = data.chunks[i]
		end
		local importString = table.concat(parts, "")
		self.incomingSharedPresets[shareId] = nil
		self:OpenReceivedPresetDialog(data.sender or sender, importString)
	end
end

function MethodDungeonTools:ShareCurrentPreset()
	local channel = self:GetShareChannel()
	if not channel then
		print(
			"|cFFFFFF00[MDT]|r Для отправки маршрута нужно быть в группе, рейде или гильдии."
		)
		return
	end

	local export = self:GetCurrentPresetExportString()
	if not export or export == "" then
		print("|cFFFF0000[MDT]|r Не удалось подготовить маршрут к отправке.")
		return
	end

	local shareId = self:GenerateShareId()
	local senderName = UnitName("player") or "Unknown"
	local totalChunks = math.ceil(string.len(export) / MDT_SHARE_MAX_CHUNK)

	self:SendAddonComm(MDT_SHARE_PREFIX, "START|" .. shareId .. "|" .. senderName .. "|" .. totalChunks, channel)
	for i = 1, totalChunks do
		local startPos = ((i - 1) * MDT_SHARE_MAX_CHUNK) + 1
		local chunk = string.sub(export, startPos, startPos + MDT_SHARE_MAX_CHUNK - 1)
		self:SendAddonComm(MDT_SHARE_PREFIX, "DATA|" .. shareId .. "|" .. i .. "|" .. chunk, channel)
	end
	self:SendAddonComm(MDT_SHARE_PREFIX, "END|" .. shareId, channel)

	print("|cFF00FF00[MDT]|r Маршрут отправлен в канал: " .. channel)
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["METHOD_DUNGEON_TOOLS_IMPORT_SHARE"] = {
	text = "%s",
	button1 = "Принять",
	button2 = "Отклонить",
	OnAccept = function()
		MethodDungeonTools:AcceptSharedPreset()
	end,
	OnCancel = function()
		MethodDungeonTools:DeclineSharedPreset()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local initFrames
-------------------------
--- Saved Variables  ----
-------------------------
local defaultSavedVars = {
	global = {
		devMode = false,
		currentDungeonIdx = 1,
		currentDifficulty = 15,
		xoffset = 0,
		yoffset = -150,
		anchorFrom = "TOP",
		anchorTo = "TOP",
		tooltipInCorner = false,
		minimap = {
			hide = false,
		},
		presets = {
			[1] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[2] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[3] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[4] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[5] = {
				[1] = { text = "Default", value = {} },
				--[[
				 --preset
					[1] = { --pull 1
						[1] = {1,2}, --wandering shellback
						[3] = {1,2},	 --warrior
					},
					[2] = { --pull 2
						[1] = {3},
						[3] = {4},
					},
					[3] = { --pull 3
						[1] = {8},
						[3] = {4,5},
					},
				]]
				[2] = { text = "<New Preset>", value = 0 },
			},
			[6] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[7] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[8] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[9] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[10] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[11] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[12] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[13] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
			[14] = {
				[1] = { text = "Default", value = {} },
				[2] = { text = "<New Preset>", value = 0 },
			},
		},
		currentPreset = {
			[1] = 1,
			[2] = 1,
			[3] = 1,
			[4] = 1,
			[5] = 1,
			[6] = 1,
			[7] = 1,
			[8] = 1,
			[9] = 1,
			[10] = 1,
			[11] = 1,
			[12] = 1,
			[13] = 1,
			[14] = 1,
		},
		MobDataTally = {},
	},
}

-- Init db
do
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(self, event, ...)
		return MethodDungeonTools[event](self, ...)
	end)

	function MethodDungeonTools.ADDON_LOADED(self, addon)
		if addon == "MethodDungeonTools" then
			db = LibStub("AceDB-3.0"):New("MethodDungeonToolsDB", defaultSavedVars).global
			db.devMode = false -- always start with devMode off; use /mdt devmode to enable
			initFrames()
			icon:Register("MethodDungeonTools", LDB, db.minimap)
			if not db.minimap.hide then
				icon:Show("MethodDungeonTools")
			end
			MethodDungeonTools:RegisterShareComm()
			Dialog:Register("MethodDungeonToolsPosCopyDialog", {
				text = "Pos Copy",
				width = 500,
				editboxes = {
					{
						width = 484,
						on_escape_pressed = function(self, data)
							self:GetParent():Hide()
						end,
					},
				},
				on_show = function(self, data)
					self.editboxes[1]:SetText(data.pos)
					self.editboxes[1]:HighlightText()
					self.editboxes[1]:SetFocus()
				end,
				buttons = {
					{ text = CLOSE },
				},
				show_while_dead = true,
				hide_on_escape = true,
			})
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end

local dungeonBossButtons
local dungeonEnemyBlips
local numDungeonEnemyBlips = 0
local tooltip
local tooltipLastShown
local dungeonEnemyBlipMouseoverHighlight
local dungeonEnemiesSelected = {}
-- MethodDungeonTools.dungeonTotalCount = {} -- Initialized at the top now

-- MethodDungeonTools.dungeonMaps = { -- Initialized at the top now
MethodDungeonTools.dungeonMaps = {
	[1] = {
		[0] = "Ahnkahet",
		[1] = "Ahnkahet1_",
	},
	[2] = {
		[0] = "DrakTharonKeep",
		[1] = "DrakTharonKeep1_",
		[2] = "DrakTharonKeep2_",
	},
	[3] = {
		[0] = "HallsOfLightning",
		[1] = "HallsOfLightning1_",
		[2] = "HallsOfLightning2_",
	},
	[4] = {
		[0] = "HellfireRamparts",
		[1] = "HellfireRamparts1_",
	},
	[5] = {
		[0] = "ManaTombs",
		[1] = "ManaTombs1_",
	},
	[6] = {
		[0] = "TheBloodFurnace",
		[1] = "TheBloodFurnace1_",
	},
	[7] = {
		[0] = "TheSlavePens",
		[1] = "TheSlavePens1_",
	},
	[8] = {
		[0] = "UtgardeKeep",
		[1] = "UtgardeKeep1_",
		[2] = "UtgardeKeep2_",
		[3] = "UtgardeKeep3_",
	},
}
-- MethodDungeonTools.dungeonBosses = {} -- Initialized at top
-- MethodDungeonTools.dungeonEnemies = {} -- Initialized at top

function MethodDungeonTools:ShowInterface()
	if self.main_frame:IsShown() then
		MethodDungeonTools:HideInterface()
	else
		self.main_frame:Show()
		MethodDungeonTools:UpdateToDungeon(db.currentDungeonIdx)
		if self.main_frame.HelpButton then
			self.main_frame.HelpButton:Show()
		end
	end
end

function MethodDungeonTools:HideInterface()
	self.main_frame:Hide()
	if self.main_frame.HelpButton then
		self.main_frame.HelpButton:Hide()
	end
end

function MethodDungeonTools:CreateMenu()
	-- Close button
	self.main_frame.closeButton = CreateFrame("Button", "CloseButton", self.main_frame, "UIPanelCloseButton")
	self.main_frame.closeButton:ClearAllPoints()
	self.main_frame.closeButton:SetPoint("BOTTOMRIGHT", self.main_frame, "TOPRIGHT", 240, -2)
	self.main_frame.closeButton:SetScript("OnClick", function()
		MethodDungeonTools:HideInterface()
	end)
	--self.main_frame.closeButton:SetSize(32, h);
end

function MethodDungeonTools:MakeTopBottomTextures(frame)
	frame:SetMovable(true)

	if frame.topPanel == nil then
		frame.topPanel = CreateFrame("Frame", "MethodDungeonToolsTopPanel", frame)
		frame.topPanelTex = frame.topPanel:CreateTexture(nil, "BACKGROUND")
		frame.topPanelTex:SetAllPoints()
		frame.topPanelTex:SetDrawLayer("ARTWORK", -5)
		MethodDungeonTools:SetColorTexture(frame.topPanelTex, 0, 0, 0, 0.7)

		frame.topPanelString = frame.topPanel:CreateFontString("MethodDungeonTools name")
		frame.topPanelString:SetFont("Fonts\\FRIZQT__.TTF", 20)
		frame.topPanelString:SetTextColor(1, 1, 1, 1)
		frame.topPanelString:SetJustifyH("CENTER")
		frame.topPanelString:SetJustifyV("CENTER")
		frame.topPanelString:SetWidth(600)
		frame.topPanelString:SetHeight(20)
		frame.topPanelString:SetText("Method Dungeon Tools")
		frame.topPanelString:ClearAllPoints()
		frame.topPanelString:SetPoint("CENTER", frame.topPanel, "CENTER", 0, 0)
		frame.topPanelString:Show()

		frame.topPanelLogo = frame.topPanel:CreateTexture(nil, "HIGH", nil, 7)
		frame.topPanelLogo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Textures\\Method.tga")
		frame.topPanelLogo:SetWidth(24)
		frame.topPanelLogo:SetHeight(24)
		frame.topPanelLogo:SetPoint("RIGHT", frame.topPanelString, "LEFT", 183, 0)
		frame.topPanelLogo:Show()
	end

	frame.topPanel:ClearAllPoints()
	frame.topPanel:SetSize(frame:GetWidth(), 30)
	frame.topPanel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)

	frame.topPanel:EnableMouse(true)
	frame.topPanel:RegisterForDrag("LeftButton")
	frame.topPanel:SetScript("OnDragStart", function(self, button)
		frame:SetMovable(true)
		frame:StartMoving()
	end)
	frame.topPanel:SetScript("OnDragStop", function(self, button)
		frame:StopMovingOrSizing()
		frame:SetMovable(false)
		local from, _, to, x, y = MethodDungeonTools.main_frame:GetPoint()
		db.anchorFrom = from
		db.anchorTo = to
		db.xoffset, db.yoffset = x, y
	end)

	if frame.bottomPanel == nil then
		frame.bottomPanel = CreateFrame("Frame", "MethodDungeonToolsBottomPanel", frame)
		frame.bottomPanelTex = frame.bottomPanel:CreateTexture(nil, "BACKGROUND")
		frame.bottomPanelTex:SetAllPoints()
		frame.bottomPanelTex:SetDrawLayer("ARTWORK", -5)
		MethodDungeonTools:SetColorTexture(frame.bottomPanelTex, 0, 0, 0, 0.7)
	end

	frame.bottomPanel:ClearAllPoints()
	frame.bottomPanel:SetSize(frame:GetWidth(), 30)
	frame.bottomPanel:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)

	frame.bottomPanel:EnableMouse(true)
	frame.bottomPanel:RegisterForDrag("LeftButton")
	frame.bottomPanel:SetScript("OnDragStart", function(self, button)
		frame:SetMovable(true)
		frame:StartMoving()
	end)
	frame.bottomPanel:SetScript("OnDragStop", function(self, button)
		frame:StopMovingOrSizing()
		frame:SetMovable(false)
		local from, _, to, x, y = MethodDungeonTools.main_frame:GetPoint()
		db.anchorFrom = from
		db.anchorTo = to
		db.xoffset, db.yoffset = x, y
	end)
end

function MethodDungeonTools:MakeSidePanel(frame)
	if frame.sidePanel == nil then
		frame.sidePanel = CreateFrame("Frame", "MethodDungeonToolsSidePanel", frame)
		frame.sidePanelTex = frame.sidePanel:CreateTexture(nil, "BACKGROUND")
		frame.sidePanelTex:SetAllPoints()
		frame.sidePanelTex:SetDrawLayer("ARTWORK", -5)
		MethodDungeonTools:SetColorTexture(frame.sidePanelTex, 0, 0, 0, 0.7)
		frame.sidePanelTex:Show()
	end

	frame.sidePanel:ClearAllPoints()
	frame.sidePanel:SetSize(250, frame:GetHeight() + (frame.topPanel:GetHeight() * 2))
	frame.sidePanel:SetPoint("TOPLEFT", frame.topPanel, "TOPRIGHT", -1, 0)

	frame.sidePanelTopString = frame.sidePanel:CreateFontString("MethodDungeonToolsSidePanelTopText")
	frame.sidePanelTopString:SetFont("Fonts\\FRIZQT__.TTF", 20)
	frame.sidePanelTopString:SetTextColor(1, 1, 1, 1)
	frame.sidePanelTopString:SetJustifyH("CENTER")
	frame.sidePanelTopString:SetJustifyV("TOP")
	frame.sidePanelTopString:SetWidth(200)
	frame.sidePanelTopString:SetHeight(500)
	frame.sidePanelTopString:SetText("")
	frame.sidePanelTopString:ClearAllPoints()
	frame.sidePanelTopString:SetPoint("CENTER", frame.sidePanel, "CENTER", 0, -40 - 30)
	frame.sidePanelTopString:Show()
	frame.sidePanelTopString:Hide()

	frame.sidePanelString = frame.sidePanel:CreateFontString("MethodDungeonToolsSidePanelText")
	frame.sidePanelString:SetFont("Fonts\\FRIZQT__.TTF", 10)
	frame.sidePanelString:SetTextColor(1, 1, 1, 1)
	frame.sidePanelString:SetJustifyH("LEFT")
	frame.sidePanelString:SetJustifyV("TOP")
	frame.sidePanelString:SetWidth(200)
	frame.sidePanelString:SetHeight(500)
	frame.sidePanelString:SetText("")
	frame.sidePanelString:ClearAllPoints()
	frame.sidePanelString:SetPoint("TOPLEFT", frame.sidePanel, "TOPLEFT", 33, -120 - 30 - 25)
	frame.sidePanelString:Hide()

	frame.sidePanel.WidgetGroup = MethodDungeonTools:AceGUI_Create("SimpleGroup")
	frame.sidePanel.WidgetGroup:SetWidth(245)
	frame.sidePanel.WidgetGroup:SetHeight(frame:GetHeight() + (frame.topPanel:GetHeight() * 2) - 31)
	frame.sidePanel.WidgetGroup:SetPoint("TOP", frame.sidePanel, "TOP", 3, -31)
	frame.sidePanel.WidgetGroup:SetLayout("Flow")

	frame.sidePanel.WidgetGroup.frame:SetFrameStrata(mainFrameStrata)
	frame.sidePanel.WidgetGroup.frame:Hide()

	--dirty hook to make widgetgroup show/hide
	local originalShow, originalHide = frame.Show, frame.Hide
	function frame:Show(...)
		frame.sidePanel.WidgetGroup.frame:Show()
		return originalShow(self, ...)
	end
	function frame:Hide(...)
		frame.sidePanel.WidgetGroup.frame:Hide()
		if MethodDungeonTools.pullTooltip then
			MethodDungeonTools.pullTooltip:Hide()
		end
		return originalHide(self, ...)
	end

	local buttonWidth = 80

	---new profile,rename,export,delete
	frame.sidePanelNewButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelNewButton:SetText("Создать")
	frame.sidePanelNewButton:SetWidth(buttonWidth)
	--button fontInstance
	local fontInstance = CreateFont("MDTButtonFont")
	fontInstance:CopyFontObject(frame.sidePanelNewButton.frame:GetNormalFontObject())
	local fontName, height = fontInstance:GetFont()
	fontInstance:SetFont(fontName, 10)
	frame.sidePanelNewButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelNewButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelNewButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelNewButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:OpenNewPresetDialog()
	end)

	frame.sidePanelRenameButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelRenameButton:SetWidth(130)
	frame.sidePanelRenameButton:SetText("Переименовать")
	frame.sidePanelRenameButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelRenameButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelRenameButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelRenameButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:HideAllDialogs()
		local currentPresetName = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].text
		MethodDungeonTools.main_frame.RenameFrame:Show()
		MethodDungeonTools.main_frame.RenameFrame.RenameButton:SetDisabled(true)
		MethodDungeonTools.main_frame.RenameFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
		MethodDungeonTools.main_frame.RenameFrame.Editbox:SetText(currentPresetName)
		MethodDungeonTools.main_frame.RenameFrame.Editbox:HighlightText(0, string.len(currentPresetName))
		MethodDungeonTools.main_frame.RenameFrame.Editbox:SetFocus()
	end)

	frame.sidePanelImportButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelImportButton:SetText("Импорт")
	frame.sidePanelImportButton:SetWidth(buttonWidth)
	frame.sidePanelImportButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelImportButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelImportButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelImportButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:OpenImportPresetDialog()
	end)

	frame.sidePanelExportButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelExportButton:SetText("Экспорт")
	frame.sidePanelExportButton:SetWidth(buttonWidth)
	frame.sidePanelExportButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelExportButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelExportButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelExportButton:SetCallback("OnClick", function(widget, callbackName, value)
		local export = MethodDungeonTools:GetCurrentPresetExportString()
		MethodDungeonTools:HideAllDialogs()
		MethodDungeonTools.main_frame.ExportFrame:Show()
		MethodDungeonTools.main_frame.ExportFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
		MethodDungeonTools.main_frame.ExportFrameEditbox:SetText(export)
		MethodDungeonTools.main_frame.ExportFrameEditbox:HighlightText(0, string.len(export))
		MethodDungeonTools.main_frame.ExportFrameEditbox:SetFocus()
	end)

	frame.sidePanelShareButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelShareButton:SetText("Поделиться")
	frame.sidePanelShareButton:SetWidth(110)
	frame.sidePanelShareButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelShareButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelShareButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelShareButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:ShareCurrentPreset()
	end)

	frame.sidePanelDeleteButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelDeleteButton:SetText("Удалить")
	frame.sidePanelDeleteButton:SetWidth(buttonWidth)
	frame.sidePanelDeleteButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelDeleteButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelDeleteButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelDeleteButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:HideAllDialogs()
		frame.DeleteConfirmationFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
		local currentPresetName = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].text
		frame.DeleteConfirmationFrame.label:SetText("Delete " .. currentPresetName .. "?")
		frame.DeleteConfirmationFrame:Show()
	end)

	frame.sidePanelClearButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.sidePanelClearButton:SetText("Очистить")
	frame.sidePanelClearButton:SetWidth(buttonWidth)
	frame.sidePanelClearButton.frame:SetNormalFontObject(fontInstance)
	frame.sidePanelClearButton.frame:SetHighlightFontObject(fontInstance)
	frame.sidePanelClearButton.frame:SetDisabledFontObject(fontInstance)
	frame.sidePanelClearButton:SetCallback("OnClick", function(widget, callbackName, value)
		MethodDungeonTools:HideAllDialogs()
		frame.ClearConfirmationFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
		local currentPresetName = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].text
		frame.ClearConfirmationFrame.label:SetText("Clear " .. currentPresetName .. "?")
		frame.ClearConfirmationFrame:Show()
	end)

	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelNewButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelImportButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelExportButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelShareButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelRenameButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelClearButton)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelDeleteButton)

	-- Defensive check: Ensure preset structure exists before accessing Affixes
	if not db.presets[db.currentDungeonIdx] or type(db.presets[db.currentDungeonIdx]) ~= "table" then
		db.presets[db.currentDungeonIdx] = {}
	end
	if not db.currentPreset[db.currentDungeonIdx] then
		db.currentPreset[db.currentDungeonIdx] = 1
	end
	local curPresetIdx = db.currentPreset[db.currentDungeonIdx]
	if
		not db.presets[db.currentDungeonIdx][curPresetIdx]
		or type(db.presets[db.currentDungeonIdx][curPresetIdx]) ~= "table"
	then
		db.presets[db.currentDungeonIdx][curPresetIdx] = { text = "Default", value = {} }
	end
	if type(db.presets[db.currentDungeonIdx][curPresetIdx].value) ~= "table" then
		db.presets[db.currentDungeonIdx][curPresetIdx].value = {}
	end

	-- removed redundant <New Preset> logic here, now handled in EnsureDBTables

	-- local breakLine = MethodDungeonTools:AceGUI_Create("Label")
	-- breakLine:SetFullWidth(true)
	-- breakLine:SetText(" ")
	-- frame.sidePanel:AddChild(breakLine)

	--Tyranical/Fortified toggle
	frame.sidePanelFortifiedCheckBox = MethodDungeonTools:AceGUI_Create("CheckBox")
	frame.sidePanelFortifiedCheckBox:SetLabel("Укрепленный")
	frame.sidePanelFortifiedCheckBox.text:SetTextHeight(10)
	frame.sidePanelFortifiedCheckBox:SetWidth(120)
	frame.sidePanelFortifiedCheckBox:SetHeight(15)
	if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix then
		if
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix == "fortified"
		then
			frame.sidePanelFortifiedCheckBox:SetValue(true)
		end
	end
	frame.sidePanelFortifiedCheckBox:SetImage("Interface\\ICONS\\ability_toughness")
	frame.sidePanelFortifiedCheckBox:SetCallback("OnValueChanged", function(widget, callbackName, value)
		if value == true then
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix = "fortified"
		elseif value == false then
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix = "tyrannical"
		end
		frame.sidePanelTyrannicalCheckBox:SetValue(not value)
	end)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelFortifiedCheckBox)

	frame.sidePanelTyrannicalCheckBox = MethodDungeonTools:AceGUI_Create("CheckBox")
	frame.sidePanelTyrannicalCheckBox:SetLabel("Тираник")
	frame.sidePanelTyrannicalCheckBox.text:SetTextHeight(10)
	frame.sidePanelTyrannicalCheckBox:SetWidth(110)
	frame.sidePanelTyrannicalCheckBox:SetHeight(15)
	if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix then
		if
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix == "tyrannical"
		then
			frame.sidePanelTyrannicalCheckBox:SetValue(true)
		end
	end
	frame.sidePanelTyrannicalCheckBox:SetImage("Interface\\ICONS\\achievement_boss_archaedas")
	frame.sidePanelTyrannicalCheckBox:SetCallback("OnValueChanged", function(widget, callbackName, value)
		if value == true then
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix = "tyrannical"
		elseif value == false then
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix = "fortified"
		end
		frame.sidePanelFortifiedCheckBox:SetValue(not value)
	end)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelTyrannicalCheckBox)

	-- frame.sidePanelTeemingCheckBox = MethodDungeonTools:AceGUI_Create("CheckBox")
	-- frame.sidePanelTeemingCheckBox:SetLabel("Teeming")
	-- frame.sidePanelTeemingCheckBox.text:SetTextHeight(10)
	-- frame.sidePanelTeemingCheckBox:SetWidth(90)
	-- frame.sidePanelTeemingCheckBox:SetHeight(15)
	-- frame.sidePanelTeemingCheckBox:SetDisabled(false)

	-- if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming then
	-- 	if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming == true then frame.sidePanelTeemingCheckBox:SetValue(true) end
	-- end
	-- frame.sidePanelTeemingCheckBox:SetImage("Interface\\ICONS\\spell_nature_massteleport")
	-- frame.sidePanelTeemingCheckBox:SetCallback("OnValueChanged",function(widget,callbackName,value)
	-- 	db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming = value
	-- 	MethodDungeonTools:UpdateMap()
	--     MethodDungeonTools:ReloadPullButtons()
	-- end)
	-- frame.sidePanel.WidgetGroup:AddChild(frame.sidePanelTeemingCheckBox)

	-- Force a line break
	local lineBreak = MethodDungeonTools:AceGUI_Create("Label")
	lineBreak:SetFullWidth(true)
	frame.sidePanel.WidgetGroup:AddChild(lineBreak)

	--Difficulty Selection
	frame.sidePanel.DifficultySliderLabel = MethodDungeonTools:AceGUI_Create("Label")
	frame.sidePanel.DifficultySliderLabel:SetText(" Lvl: ")
	frame.sidePanel.DifficultySliderLabel:SetWidth(35)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanel.DifficultySliderLabel)

	frame.sidePanel.DifficultySlider = MethodDungeonTools:AceGUI_Create("Slider")
	frame.sidePanel.DifficultySlider:SetSliderValues(1, 35, 1)
	frame.sidePanel.DifficultySlider:SetWidth(195) --240
	frame.sidePanel.DifficultySlider:SetValue(db.currentDifficulty)
	frame.sidePanel.DifficultySlider:SetCallback("OnValueChanged", function(widget, callbackName, value)
		local difficulty = tonumber(value)
		db.currentDifficulty = difficulty or db.currentDifficulty
	end)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanel.DifficultySlider)

	frame.sidePanel.middleLine = MethodDungeonTools:AceGUI_Create("Heading")
	frame.sidePanel.middleLine:SetWidth(240)
	frame.sidePanel.WidgetGroup:AddChild(frame.sidePanel.middleLine)
	frame.sidePanel.WidgetGroup.frame:SetFrameLevel(7)

	--progress bar
	frame.sidePanel.ProgressBar = CreateFrame("Frame", nil, frame.sidePanel)
	frame.sidePanel.ProgressBar:SetSize(200, 20)
	frame.sidePanel.ProgressBar.Bar = CreateFrame("StatusBar", nil, frame.sidePanel.ProgressBar)
	frame.sidePanel.ProgressBar.Bar:SetAllPoints()
	frame.sidePanel.ProgressBar.Bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.sidePanel.ProgressBar.Bar.Label =
		frame.sidePanel.ProgressBar.Bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.sidePanel.ProgressBar.Bar.Label:SetPoint("CENTER")
	frame.sidePanel.ProgressBar.Bar.Icon = frame.sidePanel.ProgressBar.Bar:CreateTexture() -- Dummy for icon calls
	frame.sidePanel.ProgressBar.Bar.IconBG = frame.sidePanel.ProgressBar.Bar:CreateTexture() -- Dummy for icon calls

	frame.sidePanel.ProgressBar:Show()
	frame.sidePanel.ProgressBar:SetPoint("TOP", frame.sidePanel.WidgetGroup.frame, "BOTTOM", -10, 5)
	MethodDungeonTools:Progressbar_SetValue(frame.sidePanel.ProgressBar, 50, 205, 205)
end

---Progressbar_SetValue
---Sets the value/progress/color of the count progressbar to the apropriate data
function MethodDungeonTools:Progressbar_SetValue(self, pullCurrent, totalCurrent, totalMax)
	local percent = (totalCurrent / totalMax) * 100
	if percent >= 102 then
		if totalCurrent - totalMax > 8 then
			self.Bar:SetStatusBarColor(1, 0, 0, 1)
		else
			self.Bar:SetStatusBarColor(0, 1, 0, 1)
		end
	elseif percent >= 100 then
		self.Bar:SetStatusBarColor(0, 1, 0, 1)
	else
		self.Bar:SetStatusBarColor(0.26, 0.42, 1)
	end
	self.Bar:SetValue(percent)
	self.Bar.Label:SetText(pullCurrent .. "% (" .. totalCurrent .. "/" .. totalMax .. "%) ")
	self.AnimValue = percent
end

function MethodDungeonTools:OnPan(cursorX, cursorY)
	local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
	local dx = scrollFrame.cursorX - cursorX
	local dy = cursorY - scrollFrame.cursorY
	if abs(dx) >= 1 or abs(dy) >= 1 then
		scrollFrame.moved = true
		local x = max(0, dx + scrollFrame.x)
		x = min(x, scrollFrame.maxX)
		scrollFrame:SetHorizontalScroll(x)
		local y = max(0, dy + scrollFrame.y)
		y = min(y, scrollFrame.maxY)
		scrollFrame:SetVerticalScroll(y)
	end
end

--Update list of selected Enemies shown in side panel
function MethodDungeonTools:UpdateEnemiesSelected()
	local teeming = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
	local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	table.wipe(dungeonEnemiesSelected)

	for enemyIdx, clones in pairs(preset.value.pulls[preset.value.currentPull]) do
		local enemyData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx][enemyIdx]
		if enemyData then
			for k, cloneIdx in pairs(clones) do
				local enemyName = enemyData["name"]
				local count = enemyData["count"]
				if not dungeonEnemiesSelected[enemyName] then
					dungeonEnemiesSelected[enemyName] = {}
				end
				dungeonEnemiesSelected[enemyName].count = count
				dungeonEnemiesSelected[enemyName].quantity = dungeonEnemiesSelected[enemyName].quantity or 0
				dungeonEnemiesSelected[enemyName].quantity = dungeonEnemiesSelected[enemyName].quantity + 1
			end
		end
	end

	local sidePanelStringText = ""
	local newLineString = ""
	local currentTotalCount = 0
	for enemyName, v in pairs(dungeonEnemiesSelected) do
		sidePanelStringText = sidePanelStringText
			.. newLineString
			.. v.quantity
			.. "x "
			.. enemyName
			.. "("
			.. v.count * v.quantity
			.. ")"
		newLineString = "\n"
		currentTotalCount = currentTotalCount + (v.count * v.quantity)
	end
	sidePanelStringText = sidePanelStringText .. newLineString .. newLineString .. "Count: " .. currentTotalCount
	self.main_frame.sidePanelString:SetText(sidePanelStringText)

	local grandTotal = 0
	for pullIdx, pull in pairs(preset.value.pulls) do
		for enemyIdx, clones in pairs(pull) do
			local enemyData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx][enemyIdx]
			if enemyData and enemyData["clones"] then
				for k, v in pairs(clones) do
					if enemyData["clones"][v] then
						local isCloneTeeming = enemyData["clones"][v].teeming
						if teeming == true or ((isCloneTeeming and isCloneTeeming == false) or not isCloneTeeming) then
							grandTotal = grandTotal + enemyData.count
						end
					end
				end
			end
		end
	end
	--self.main_frame.sidePanelTopString:SetText("Method Dungeon Tools")

	--count up to and including the currently selected pull
	local pullCurrent = 0
	for pullIdx, pull in pairs(preset.value.pulls) do
		if pullIdx <= db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentPull then
			for enemyIdx, clones in pairs(pull) do
				local dungeonData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
				local enemyData = dungeonData and dungeonData[enemyIdx] or nil
				if enemyData and enemyData["clones"] then
					for k, v in pairs(clones) do
						if enemyData["clones"][v] then
							local isCloneTeeming = enemyData["clones"][v].teeming
							if
								teeming == true
								or ((isCloneTeeming and isCloneTeeming == false) or not isCloneTeeming)
							then
								pullCurrent = pullCurrent + enemyData.count
							end
						end
					end
				end
			end
		else
			break
		end
	end
	local totalCountData = MethodDungeonTools.dungeonTotalCount[db.currentDungeonIdx] or { teeming = 100, normal = 100 }
	MethodDungeonTools:Progressbar_SetValue(
		MethodDungeonTools.main_frame.sidePanel.ProgressBar,
		pullCurrent,
		grandTotal,
		teeming == true and totalCountData.teeming or totalCountData.normal
	)
end

function MethodDungeonTools:AddOrRemoveEnemyBlipToCurrentPull(i, add, ignoreGrouped)
	local pull = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentPull
	local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	preset.value.pulls = preset.value.pulls or {}
	preset.value.pulls[pull] = preset.value.pulls[pull] or {}
	preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx] = preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx]
		or {}
	if add == true then
		local found = false
		for k, v in pairs(preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx]) do
			if v == dungeonEnemyBlips[i].cloneIdx then
				found = true
			end
		end
		if found == false then
			tinsert(preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx], dungeonEnemyBlips[i].cloneIdx)
		end
		--make sure this pull is the only one that contains this npc clone (no double dipping)
		for pullIdx, p in pairs(preset.value.pulls) do
			if pullIdx ~= pull and p[dungeonEnemyBlips[i].enemyIdx] then
				for k, v in pairs(p[dungeonEnemyBlips[i].enemyIdx]) do
					if v == dungeonEnemyBlips[i].cloneIdx then
						tremove(preset.value.pulls[pullIdx][dungeonEnemyBlips[i].enemyIdx], k)
						MethodDungeonTools:UpdatePullButtonNPCData(pullIdx)
						--print("Removing "..dungeonEnemyBlips[i].name.." "..dungeonEnemyBlips[i].cloneIdx.." from pull"..pullIdx)
					end
				end
			end
		end
	elseif add == false then
		for k, v in pairs(preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx]) do
			if v == dungeonEnemyBlips[i].cloneIdx then
				tremove(preset.value.pulls[pull][dungeonEnemyBlips[i].enemyIdx], k)
			end
		end
	end
	--linked npcs
	if not ignoreGrouped then
		for idx = 1, numDungeonEnemyBlips do
			if dungeonEnemyBlips[i].g and dungeonEnemyBlips[idx].g == dungeonEnemyBlips[i].g and i ~= idx then
				MethodDungeonTools:AddOrRemoveEnemyBlipToCurrentPull(idx, add, true)
			end
		end
	end
	MethodDungeonTools:UpdatePullButtonNPCData(pull)
	MethodDungeonTools:UpdateDungeonEnemies()
end

MethodDungeonTools.pullColors = {
	{ 1, 0.4, 0.4 }, -- Red
	{ 0.4, 1, 0.4 }, -- Green
	{ 0.4, 0.4, 1 }, -- Blue
	{ 1, 1, 0.4 }, -- Yellow
	{ 1, 0.4, 1 }, -- Magenta
	{ 0.4, 1, 1 }, -- Cyan
	{ 1, 0.64, 0 }, -- Orange
	{ 0.64, 0.16, 0.16 }, -- Brown
	{ 0.5, 0.5, 0.5 }, -- Gray
	{ 1, 0.75, 0.79 }, -- Pink
	{ 0.5, 0, 0.5 }, -- Purple
	{ 0, 0.5, 0.5 }, -- Teal
}

---UpdateEnemyBlipSelection
---Colors blips according to their assigned pull, or unselected color
function MethodDungeonTools:UpdateEnemyBlipSelection(i, forceDeselect, ignoreLinked, pullIdx)
	local r, g, b, a = 0, 1, 0, 1

	local dungeonData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
	local enemyData = dungeonData and dungeonData[dungeonEnemyBlips[i].enemyIdx] or nil
	local scale = enemyData and enemyData.scale or 1
	local baseSize = 10 * scale

	if not pullIdx then
		if forceDeselect and forceDeselect == true then
			dungeonEnemyBlips[i].selected = false
		else
			dungeonEnemyBlips[i].selected = not dungeonEnemyBlips[i].selected
		end

		--select/deselect linked npcs
		if not ignoreLinked then
			for idx = 1, numDungeonEnemyBlips do
				if dungeonEnemyBlips[i].g and dungeonEnemyBlips[idx].g == dungeonEnemyBlips[i].g and i ~= idx then
					if forceDeselect and forceDeselect == true then
						dungeonEnemyBlips[idx].selected = false
					else
						dungeonEnemyBlips[idx].selected = dungeonEnemyBlips[i].selected
					end
				end
			end
		end
	end
end

local lastModelId
local cloneOffset = 0

function MethodDungeonTools:ZoomMap(delta, resetZoom)
	local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
	local oldScrollH = scrollFrame:GetHorizontalScroll()
	local oldScrollV = scrollFrame:GetVerticalScroll()

	-- get the mouse position on the frame, with 0,0 at top left
	local cursorX, cursorY = GetCursorPosition()
	local relativeFrame = UIParent
	local frameX = cursorX / relativeFrame:GetScale() - scrollFrame:GetLeft()
	local frameY = scrollFrame:GetTop() - cursorY / relativeFrame:GetScale()
	local oldScale = MethodDungeonTools.main_frame.mapPanelFrame:GetScale()
	local newScale = oldScale + delta * 0.3
	newScale = max(1, newScale)
	newScale = min(2.2, newScale)
	if resetZoom then
		newScale = 1
	end
	MethodDungeonTools.main_frame.mapPanelFrame:SetScale(newScale)

	if newScale == 1 then
		scrollFrame.maxX = 0
		scrollFrame.maxY = 0
	elseif newScale > 1.2 and newScale < 1.4 then
		scrollFrame.maxX = 192
		scrollFrame.maxY = 131
	elseif newScale > 1.5 and newScale < 1.7 then
		scrollFrame.maxX = 313
		scrollFrame.maxY = 211
	elseif newScale > 1.8 and newScale < 2 then
		scrollFrame.maxX = 396
		scrollFrame.maxY = 266
	elseif newScale > 2.1 and newScale < 2.3 then
		scrollFrame.maxX = 453
		scrollFrame.maxY = 305
	end
	scrollFrame.zoomedIn = abs(MethodDungeonTools.main_frame.mapPanelFrame:GetScale() - 1) > 0.02

	--frameX = 420
	--frameY = 555/2

	if newScale == 1 then
	elseif newScale > 1.2 and newScale < 1.4 then
		frameX = frameX - 105
		frameY = frameY - 58
	elseif newScale > 1.5 and newScale < 1.7 then
		frameX = frameX - 245
		frameY = frameY - 165
	elseif newScale > 1.8 and newScale < 2 then
		frameX = frameX - 355
		frameY = frameY - 245
	elseif newScale > 2.1 and newScale < 2.3 then
		frameX = frameX - 455
		frameY = frameY - 345
	end

	-- figure out new scroll values
	local scaleChange = newScale / oldScale
	local newScrollH = scaleChange * (frameX + oldScrollH) - frameX
	local newScrollV = scaleChange * (frameY + oldScrollV) - frameY

	--[[
    if newScale == 1 then

    elseif newScale > 1.2 and newScale < 1.4 then
        newScrollH = newScrollH - 30
    elseif newScale > 1.5 and newScale < 1.7 then
        newScrollH = newScrollH - 50
    elseif newScale > 1.8 and newScale < 2 then

    end
    ]]

	-- clamp scroll values
	newScrollH = min(newScrollH, scrollFrame.maxX)
	newScrollH = max(0, newScrollH)
	newScrollV = min(newScrollV, scrollFrame.maxY)
	newScrollV = max(0, newScrollV)
	-- set scroll values

	scrollFrame:SetHorizontalScroll(newScrollH)
	scrollFrame:SetVerticalScroll(newScrollV)
end

---ActivatePullTooltip
---
function MethodDungeonTools:ActivatePullTooltip(pull)
	local pullTooltip = MethodDungeonTools.pullTooltip

	pullTooltip.currentPull = pull
	pullTooltip:Show()
end

---UpdatePullTooltip
---Updates the tooltip which is being displayed when a pull is mouseovered
function MethodDungeonTools:UpdatePullTooltip(tooltip)
	if not tooltip then
		return
	end
	local frame = MethodDungeonTools.main_frame
	if not (frame and frame.sidePanel and frame.sidePanel.pullButtonsScrollFrame) then
		tooltip:Hide()
		return
	end
	if not MouseIsOver(frame.sidePanel.pullButtonsScrollFrame.frame) then
		tooltip:Hide()
	elseif frame.sidePanel.newPullButton and MouseIsOver(frame.sidePanel.newPullButton.frame) then
		tooltip:Hide()
	else
		if
			frame.sidePanel.newPullButtons
			and tooltip.currentPull
			and frame.sidePanel.newPullButtons[tooltip.currentPull]
		then
			for k, v in pairs(frame.sidePanel.newPullButtons[tooltip.currentPull].enemyPortraits) do
				if MouseIsOver(v) then
					if v:IsShown() then
						tooltip.Model:Show()
						local modelPath = v.enemyData.modelPath
						local modelId = v.enemyData.displayId or v.enemyData.id
						local isNpcId = (v.enemyData.displayId == nil)
						local cacheId = modelPath or modelId
						if tooltip.Model.lastModelId ~= cacheId then
							if tooltip.Model.ClearModel then
								tooltip.Model:ClearModel()
							end
							MethodDungeonTools:SetDisplayInfo(tooltip.Model, modelId, isNpcId, modelPath)
							if tooltip.Model.SetModelScale then
								tooltip.Model:SetModelScale(0.6)
							end
							tooltip.Model.lastModelId = cacheId
						end
						--topString
						local newLine = "\n"
						local text = v.enemyData.name .. " x" .. v.enemyData.quantity .. newLine
						text = text .. "Level " .. v.enemyData.level .. " " .. v.enemyData.creatureType .. newLine
						--ViragDevTool_AddData(v.enemyData)
						local fortified = false
						local boss = false
						if
							db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix
						then
							if
								db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix
								== "fortified"
							then
								fortified = true
							end
						end
						local tyrannical = not fortified
						local health = MethodDungeonTools:CalculateEnemyHealth(
							boss,
							fortified,
							tyrannical,
							v.enemyData.baseHealth,
							db.currentDifficulty
						)
						text = text .. MethodDungeonTools:FormatEnemyHealth(health) .. " HP" .. newLine
						text = text
							.. "Enemy Forces: "
							.. v.enemyData.count
							.. " ("
							.. v.enemyData.count * v.enemyData.quantity
							.. ")"
						tooltip.topString:SetText(text)
						tooltip.topString:Show()
					else
						--model
						tooltip.Model:Hide()
						--topString
						tooltip.topString:Hide()
					end
					break
				end
			end
			local countEnemies = 0
			for k, v in pairs(frame.sidePanel.newPullButtons[tooltip.currentPull].enemyPortraits) do
				if v:IsShown() then
					countEnemies = countEnemies + 1
				end
			end
			if countEnemies == 0 then
				tooltip:Hide()
				return
			end
			local pullForces = MethodDungeonTools:CountForces(tooltip.currentPull, true)
			local totalForces = MethodDungeonTools:CountForces(tooltip.currentPull, false)
			local totalForcesMax = MethodDungeonTools:IsCurrentPresetTeeming()
					and MethodDungeonTools.dungeonTotalCount[db.currentDungeonIdx].teeming
				or MethodDungeonTools.dungeonTotalCount[db.currentDungeonIdx].normal
			text = string.format(
				MethodDungeonTools.pullTooltip.botString.defaultText,
				pullForces,
				totalForces,
				totalForcesMax
			)
			tooltip.botString:SetText(text)
			tooltip.botString:Show()
		end
	end
end

---CountForces
---Counts total selected enemy forces in the current preset up to pull
function MethodDungeonTools:CountForces(currentPull, currentOnly)
	--count up to and including the currently selected pull
	local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	local pullCurrent = 0
	for pullIdx, pull in pairs(preset.value.pulls) do
		if not currentOnly or (currentOnly and pullIdx == currentPull) then
			if pullIdx <= currentPull then
				for enemyIdx, clones in pairs(pull) do
					local enemyData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx][enemyIdx]
					if enemyData and enemyData["clones"] then
						for k, v in pairs(clones) do
							if enemyData["clones"][v] then
								local isCloneTeeming = enemyData["clones"][v].teeming
								if
									MethodDungeonTools:IsCurrentPresetTeeming()
									or ((isCloneTeeming and isCloneTeeming == false) or not isCloneTeeming)
								then
									pullCurrent = pullCurrent + enemyData.count
								end
							end
						end
					end
				end
			else
				break
			end
		end
	end
	return pullCurrent
end

function MethodDungeonTools:IsCurrentPresetTeeming()
	return db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
end

function MethodDungeonTools:UpdateContextMenu(cursorX, cursorY)
	MethodDungeonTools.contextMenuList = {}
	if db.devMode then
		tinsert(MethodDungeonTools.contextMenuList, {
			text = "Copy Position",
			notCheckable = true,
			func = function()
				local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
				local relativeFrame = UIParent
				local mapPanelFrame = MethodDungeonTools.main_frame.mapPanelFrame
				local mapScale = mapPanelFrame:GetScale()
				local scrollH = scrollFrame:GetHorizontalScroll()
				local scrollV = scrollFrame:GetVerticalScroll()
				local frameX = (cursorX / relativeFrame:GetScale()) - scrollFrame:GetLeft()
				local frameY = scrollFrame:GetTop() - (cursorY / relativeFrame:GetScale())
				frameX = (frameX / mapScale) + scrollH
				frameY = (frameY / mapScale) + scrollV

				local teeming = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
						and ",teeming=true"
					or ""
				local group = db.currentDifficulty

				local cloneIdx = 1
				local targetName = UnitName("target")
				local dungeonData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
				if targetName and dungeonData then
					for k, v in pairs(dungeonData) do
						if v["name"] == targetName then
							for k, v in pairs(v["clones"]) do
								cloneIdx = cloneIdx + 1
							end
							break
						end
					end
				end

				local activeDialog = Dialog:ActiveDialog("MethodDungeonToolsPosCopyDialog")
				if activeDialog then
					cloneOffset = cloneOffset + 1
					local position = "["
						.. cloneIdx + cloneOffset
						.. "] = {x = "
						.. frameX
						.. ",y = "
						.. -frameY
						.. ",sublevel="
						.. db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
						.. ",g="
						.. group
						.. teeming
						.. "},"
					activeDialog.editboxes[1]:SetText(activeDialog.editboxes[1]:GetText() .. "\n			" .. position)
				else
					cloneOffset = 0
					local position = "["
						.. cloneIdx + cloneOffset
						.. "] = {x = "
						.. frameX
						.. ",y = "
						.. -frameY
						.. ",sublevel="
						.. db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
						.. ",g="
						.. group
						.. teeming
						.. "},"
					Dialog:Spawn("MethodDungeonToolsPosCopyDialog", { pos = position })
				end
			end,
		})
		tinsert(MethodDungeonTools.contextMenuList, {
			text = "Copy Patrol Waypoint",
			notCheckable = true,
			func = function()
				local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
				local relativeFrame = UIParent
				local mapPanelFrame = MethodDungeonTools.main_frame.mapPanelFrame
				local mapScale = mapPanelFrame:GetScale()
				local scrollH = scrollFrame:GetHorizontalScroll()
				local scrollV = scrollFrame:GetVerticalScroll()
				local frameX = (cursorX / relativeFrame:GetScale()) - scrollFrame:GetLeft()
				local frameY = scrollFrame:GetTop() - (cursorY / relativeFrame:GetScale())
				frameX = (frameX / mapScale) + scrollH
				frameY = (frameY / mapScale) + scrollV
				local teeming = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
						and ",teeming=true"
					or ""
				local group = db.currentDifficulty

				local cloneIdx = 1
				local targetName = UnitName("target")
				if targetName then
					for k, v in pairs(MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]) do
						if v["name"] == targetName then
							for k, v in pairs(v["clones"]) do
								cloneIdx = cloneIdx + 1
							end
							break
						end
					end
				end

				local activeDialog = Dialog:ActiveDialog("MethodDungeonToolsPosCopyDialog")
				if activeDialog then
					cloneOffset = cloneOffset + 1
					local position = "["
						.. cloneIdx + cloneOffset
						.. "] = {x = "
						.. frameX
						.. ",y = "
						.. -frameY
						.. "},"
					activeDialog.editboxes[1]:SetText(activeDialog.editboxes[1]:GetText() .. "\n			" .. position)
				else
					cloneOffset = 0
					local position = "["
						.. cloneIdx + cloneOffset
						.. "] = {x = "
						.. frameX
						.. ",y = "
						.. -frameY
						.. "},"
					Dialog:Spawn("MethodDungeonToolsPosCopyDialog", { pos = position })
				end
			end,
		})
		tinsert(MethodDungeonTools.contextMenuList, {
			text = "Create new NPC from Target here",
			notCheckable = true,
			func = function()
				local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
				local relativeFrame = UIParent
				local mapPanelFrame = MethodDungeonTools.main_frame.mapPanelFrame
				local mapScale = mapPanelFrame:GetScale()
				local scrollH = scrollFrame:GetHorizontalScroll()
				local scrollV = scrollFrame:GetVerticalScroll()
				local frameX = (cursorX / relativeFrame:GetScale()) - scrollFrame:GetLeft()
				local frameY = scrollFrame:GetTop() - (cursorY / relativeFrame:GetScale())
				frameX = (frameX / mapScale) + scrollH
				frameY = (frameY / mapScale) + scrollV

				local id
				local guid = UnitGUID("target")
				if guid then
					if guid:find("-") then
						id = select(6, strsplit("-", guid))
					else
						id = tonumber(guid:sub(-12, -9), 16)
					end
				end
				if id then
					local newIdx = 1
					for enemyIdx, data in pairs(MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]) do
						newIdx = newIdx + 1
					end
					local name = UnitName("target")
					local health = UnitHealthMax("target") .. "*nerfMultiplier"
					local level = UnitLevel("target")
					local creatureType = UnitCreatureType("target")
					local x, y = frameX, -frameY
					local sublevel =
						db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
					local s = string.format(
						'[%s] = {\n        ["name"] = "%s",\n        ["health"] = %s,\n        ["level"] = %s,\n        ["creatureType"] = "%s",\n        ["id"] = %s,\n        ["count"] = XXX,\n        ["scale"] = 1,\n        ["color"] = {r=1,g=1,b=1,a=0.8},\n        ["clones"] = {\n            [1] = {x = %s,y = %s,sublevel=%s},\n        },\n    },',
						newIdx,
						name,
						health,
						level,
						creatureType,
						id,
						x,
						y,
						sublevel
					)

					lastDialog = Dialog:Spawn("MethodDungeonToolsPosCopyDialog", { pos = s })
				end
			end,
		})
		tinsert(MethodDungeonTools.contextMenuList, {
			text = "Create new Boss from Target here",
			notCheckable = true,
			func = function()
				local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
				local relativeFrame = UIParent
				local mapPanelFrame = MethodDungeonTools.main_frame.mapPanelFrame
				local mapScale = mapPanelFrame:GetScale()
				local scrollH = scrollFrame:GetHorizontalScroll()
				local scrollV = scrollFrame:GetVerticalScroll()
				local frameX = (cursorX / relativeFrame:GetScale()) - scrollFrame:GetLeft()
				local frameY = scrollFrame:GetTop() - (cursorY / relativeFrame:GetScale())
				frameX = (frameX / mapScale) + scrollH
				frameY = (frameY / mapScale) + scrollV

				local id
				local guid = UnitGUID("target")
				if guid then
					if guid:find("-") then
						id = select(6, strsplit("-", guid))
					else
						id = tonumber(guid:sub(-12, -9), 16)
					end
				end
				if id then
					local encounterID
					for i = 1, 10000 do
						local id, name, description, displayInfo, iconImage = EJ_GetCreatureInfo(1, i)
						if name == UnitName("target") then
							encounterID = i
							break
						end
					end

					if encounterID then
						local name = UnitName("target")
						local health = UnitHealthMax("target")
						local level = UnitLevel("target")
						local creatureType = UnitCreatureType("target")
						local x, y = frameX, -frameY
						local s = string.format(
							'[1] = {\n            ["name"] = "%s",\n            ["health"] = %s,\n            ["encounterID"] = %s,\n            ["level"] = %s,\n            ["creatureType"] = "%s",\n            ["id"] = %s,\n            ["x"] = %s,\n            ["y"] = %s,\n        },',
							name,
							health,
							encounterID,
							level,
							creatureType,
							id,
							x,
							y
						)

						Dialog:Spawn("MethodDungeonToolsPosCopyDialog", { pos = s })
					end
				end
			end,
		})
		tinsert(MethodDungeonTools.contextMenuList, {
			text = " ",
			notClickable = 1,
			notCheckable = 1,
			func = nil,
		})
	end
end

function MethodDungeonTools:MakeMapTexture(frame)
	local cursorX, cursorY
	MethodDungeonTools:UpdateContextMenu(0, 0)

	-- Scroll Frame
	if frame.scrollFrame == nil then
		frame.scrollFrame = CreateFrame("ScrollFrame", "MethodDungeonToolsScrollFrame", frame)
		frame.scrollFrame:ClearAllPoints()
		frame.scrollFrame:SetSize(840, 555)
		frame.scrollFrame:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)

		-- Enable mousewheel scrolling
		frame.scrollFrame:EnableMouseWheel(true)
		frame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
			MethodDungeonTools:ZoomMap(delta)
		end)

		--PAN
		frame.scrollFrame:EnableMouse(true)
		frame.scrollFrame:SetScript("OnMouseDown", function(self, button)
			local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
			if button == "LeftButton" and scrollFrame.zoomedIn and not IsControlKeyDown() then
				scrollFrame.panning = true
				local x, y = GetCursorPosition()
				scrollFrame.cursorX = x
				scrollFrame.cursorY = y
				scrollFrame.x = scrollFrame:GetHorizontalScroll()
				scrollFrame.y = scrollFrame:GetVerticalScroll()
				scrollFrame.moved = false
			end
		end)

		frame.scrollFrame:SetScript("OnMouseUp", function(self, button)
			local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
			if button == "LeftButton" then
				frame.contextDropdown:Hide()
				if scrollFrame.panning then
					scrollFrame.panning = false
				end
				--handle clicks on enemy blips
				if MouseIsOver(MethodDungeonToolsScrollFrame) then
					for i = 1, numDungeonEnemyBlips do
						if dungeonEnemyBlips[i] and MouseIsOver(dungeonEnemyBlips[i]) then
							local isCTRLKeyDown = IsControlKeyDown()
							local isShiftKeyDown = IsShiftKeyDown()
							if isShiftKeyDown then
								-- 1. Create the pull entry in DB first
								MethodDungeonTools:PresetsAddPull()
								local newPullIdx = 0
								for _ in
									pairs(
										db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls
									)
								do
									newPullIdx = newPullIdx + 1
								end
								-- 2. Set it as current in the DB
								db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentPull =
									newPullIdx
								-- 3. Add the NPC to this new pull (this also handles linked NPCs)
								MethodDungeonTools:AddOrRemoveEnemyBlipToCurrentPull(i, true, isCTRLKeyDown)
								-- 4. Reload UI (buttons and map blips)
								MethodDungeonTools:ReloadPullButtons()
								MethodDungeonTools:SetSelectionToPull(newPullIdx, true)
								MethodDungeonTools:UpdateEnemiesSelected()
								MethodDungeonTools:UpdateDungeonEnemies()
								break
							else
								-- Normal click handling
								MethodDungeonTools:AddOrRemoveEnemyBlipToCurrentPull(
									i,
									not dungeonEnemyBlips[i].selected,
									isCTRLKeyDown
								)
								MethodDungeonTools:UpdateEnemyBlipSelection(i, nil, isCTRLKeyDown)
								MethodDungeonTools:UpdateEnemiesSelected()
								MethodDungeonTools:UpdateDungeonEnemies()
								break
							end
						end
					end
				end
			elseif (button == "RightButton") and MouseIsOver(MethodDungeonToolsScrollFrame) then
				local clickedBlip = nil
				if numDungeonEnemyBlips then
					for i = 1, numDungeonEnemyBlips do
						if dungeonEnemyBlips[i] and MouseIsOver(dungeonEnemyBlips[i]) then
							clickedBlip = i
							break
						end
					end
				end

				if clickedBlip and not db.devMode then
					MethodDungeonTools:ShowEnemyInfoFrame(clickedBlip)
				else
					cursorX, cursorY = GetCursorPosition()
					MethodDungeonTools:UpdateContextMenu(cursorX, cursorY)
					if L_EasyMenu then
						L_EasyMenu(
							MethodDungeonTools.contextMenuList,
							frame.contextDropdown,
							"cursor",
							0,
							-15,
							"MENU",
							5
						)
					elseif EasyMenu then
						EasyMenu(MethodDungeonTools.contextMenuList, frame.contextDropdown, "cursor", 0, -15, "MENU", 5)
					end
					frame.contextDropdown:Show()
				end
			end
		end)

		frame.scrollFrame:SetScript("OnHide", function()
			tooltipLastShown = nil
			tooltip.Model:Hide()
			tooltip:Hide()
		end)

		frame.scrollFrame:SetScript("OnUpdate", function(self, button)
			local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
			local cursorX, cursorY = GetCursorPosition()
			local relativeFrame = UIParent --UIParent
			local mapPanelFrame = MethodDungeonTools.main_frame.mapPanelFrame
			local mapScale = mapPanelFrame:GetScale()
			local scrollH = scrollFrame:GetHorizontalScroll()
			local scrollV = scrollFrame:GetVerticalScroll()
			local frameX = (cursorX / relativeFrame:GetScale()) - scrollFrame:GetLeft()
			local frameY = scrollFrame:GetTop() - (cursorY / relativeFrame:GetScale())
			frameX = (frameX / mapScale) + scrollH
			frameY = (frameY / mapScale) + scrollV
			if db.devMode then
				if MouseIsOver(scrollFrame) then
					MethodDungeonTools.main_frame.CoordinateDisplay:SetText(
						string.format("X: %.2f, Y: %.2f", frameX, -frameY)
					)
					MethodDungeonTools.main_frame.CoordinateDisplay:Show()
				else
					MethodDungeonTools.main_frame.CoordinateDisplay:Hide()
				end
			else
				MethodDungeonTools.main_frame.CoordinateDisplay:Hide()
			end

			-- Always show the Clear Lines button
			MethodDungeonTools.main_frame.GridToggle:Show()

			-- Drawing Tool logic everywhere!
			if IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
				if not scrollFrame.isDrawing then
					scrollFrame.isDrawing = true
					scrollFrame.lastDrawX = frameX
					scrollFrame.lastDrawY = -frameY

					-- Draw an immediate dot at the click position
					local line = mapPanelFrame:CreateTexture(nil, "OVERLAY")
					line:SetTexture("Interface\\Buttons\\WHITE8X8")
					line:SetVertexColor(1, 0, 0, 0.8) -- Red dot
					DrawLine(
						line,
						MethodDungeonTools.main_frame.mapPanelTile1,
						frameX,
						-frameY,
						frameX + 2,
						-frameY + 2,
						3,
						1,
						"TOPLEFT"
					)
					line:Show()
					table.insert(MethodDungeonTools.DevDrawLines, line)
				else
					-- Only draw if we moved a bit to save textures
					local dist = math.sqrt((frameX - scrollFrame.lastDrawX) ^ 2 + (-frameY - scrollFrame.lastDrawY) ^ 2)
					if dist > 5 then
						local line = mapPanelFrame:CreateTexture(nil, "OVERLAY")
						line:SetTexture("Interface\\Buttons\\WHITE8X8")
						line:SetVertexColor(1, 0, 0, 0.8) -- Red lines
						DrawLine(
							line,
							MethodDungeonTools.main_frame.mapPanelTile1,
							scrollFrame.lastDrawX,
							scrollFrame.lastDrawY,
							frameX,
							-frameY,
							2,
							1,
							"TOPLEFT"
						)
						line:Show()
						table.insert(MethodDungeonTools.DevDrawLines, line)

						scrollFrame.lastDrawX = frameX
						scrollFrame.lastDrawY = -frameY
					end
				end
			else
				scrollFrame.isDrawing = false
			end

			if scrollFrame.panning then
				local x, y = GetCursorPosition()
				MethodDungeonTools:OnPan(x, y)
			end

			local mouseoverBlip
			if MouseIsOver(MethodDungeonToolsScrollFrame) and dungeonEnemyBlips then
				-- Prevent tooltips if hovering the Enemy Info window
				local isOverInfo = MethodDungeonTools.EnemyInfoFrame
					and MethodDungeonTools.EnemyInfoFrame:IsShown()
					and MouseIsOver(MethodDungeonTools.EnemyInfoFrame)
				if not isOverInfo then
					for i = 1, numDungeonEnemyBlips do
						if MouseIsOver(dungeonEnemyBlips[i]) then
							mouseoverBlip = i
							break
						end
					end
				end
			end
			local mouseOverBoss
			--handle mouseover on bosses
			if MouseIsOver(MethodDungeonToolsScrollFrame) and dungeonBossButtons then
				local isOverInfo = MethodDungeonTools.EnemyInfoFrame
					and MethodDungeonTools.EnemyInfoFrame:IsShown()
					and MouseIsOver(MethodDungeonTools.EnemyInfoFrame)
				if not isOverInfo then
					for k, v in pairs(dungeonBossButtons) do
						if MouseIsOver(v) then
							mouseoverBlip = nil
							mouseOverBoss = k
							break
						end
					end
				end
			end
			if mouseOverBoss then
				local data =
					MethodDungeonTools.dungeonBosses[db.currentDungeonIdx][db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel][mouseOverBoss]
				if data then
					local fortified = false
					local boss = true
					if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix then
						if
							db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix
							== "fortified"
						then
							fortified = true
						end
					end
					local tyrannical = not fortified
					local health = MethodDungeonTools:CalculateEnemyHealth(
						boss,
						fortified,
						tyrannical,
						data.health,
						db.currentDifficulty
					)
					tooltip.String:SetText(
						"\n\n" .. data.name .. "\nБосс\n" .. MethodDungeonTools:FormatEnemyHealth(health) .. " HP"
					)
					tooltip.String:Show()
					tooltip:Show()
					if db.tooltipInCorner then
						tooltip:SetPoint("BOTTOMRIGHT", MethodDungeonTools.main_frame, "BOTTOMRIGHT", 0, 0)
						tooltip:SetPoint(
							"TOPLEFT",
							MethodDungeonTools.main_frame,
							"BOTTOMRIGHT",
							-tooltip.mySizes.x,
							tooltip.mySizes.y
						)
					else
						tooltip:SetPoint("TOPLEFT", dungeonBossButtons[mouseOverBoss], "BOTTOMRIGHT", 10, 0)
						tooltip:SetPoint(
							"BOTTOMRIGHT",
							dungeonBossButtons[mouseOverBoss],
							"BOTTOMRIGHT",
							10 + tooltip.mySizes.x,
							-tooltip.mySizes.y
						)
					end
					local modelPath = data.modelPath
					local id = data.displayId or data.id
					local isNpcId = (data.displayId == nil)
					local cacheId = modelPath or id
					if cacheId then
						tooltip.Model:Show()
						if tooltip.Model.lastModelId ~= cacheId then
							if tooltip.Model.ClearModel then
								tooltip.Model:ClearModel()
							end
							MethodDungeonTools:SetDisplayInfo(tooltip.Model, id, isNpcId, modelPath)
							tooltip.Model.lastModelId = cacheId
						end
					else
						tooltip.Model:ClearModel()
						tooltip.Model:Hide()
					end
					tooltipLastShown = GetTime()
				end
			elseif mouseoverBlip then
				local data = dungeonEnemyBlips[mouseoverBlip]
				local fortified = false
				local boss = false
				if db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix then
					if
						db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix
						== "fortified"
					then
						fortified = true
					end
				end
				local tyrannical = not fortified
				local health = MethodDungeonTools:CalculateEnemyHealth(
					boss,
					fortified,
					tyrannical,
					data.health,
					db.currentDifficulty
				)
				local group = data.g and " (G " .. data.g .. ")" or ""
				tooltip.String:SetText(
					data.name
						.. " "
						.. data.cloneIdx
						.. group
						.. "\nLvl "
						.. data.level
						.. " "
						.. data.creatureType
						.. "\n"
						.. MethodDungeonTools:FormatEnemyHealth(health)
						.. " HP\n"
						.. "Получаемые %: "
						.. data.count
						.. "%"
				)
				tooltip.String:Show()
				tooltip:Show()
				if db.tooltipInCorner then
					tooltip:SetPoint("BOTTOMRIGHT", MethodDungeonTools.main_frame, "BOTTOMRIGHT", 0, 0)
					tooltip:SetPoint(
						"TOPLEFT",
						MethodDungeonTools.main_frame,
						"BOTTOMRIGHT",
						-tooltip.mySizes.x,
						tooltip.mySizes.y
					)
				else
					--check for bottom clipping
					tooltip:SetPoint("TOPLEFT", dungeonEnemyBlips[mouseoverBlip], "BOTTOMRIGHT", 30, 0)
					tooltip:SetPoint(
						"BOTTOMRIGHT",
						dungeonEnemyBlips[mouseoverBlip],
						"BOTTOMRIGHT",
						30 + tooltip.mySizes.x,
						-tooltip.mySizes.y
					)
					local bottomOffset = 0
					local rightOffset = 0
					local tooltipBottom = tooltip:GetBottom()
					local mainFrameBottom = MethodDungeonTools.main_frame:GetBottom()
					if tooltipBottom < mainFrameBottom then
						bottomOffset = tooltip.mySizes.y
					end
					--right side clipping
					local tooltipRight = tooltip:GetRight()
					local mainFrameRight = MethodDungeonTools.main_frame:GetRight()
					if tooltipRight > mainFrameRight then
						rightOffset = -(tooltip.mySizes.x + 60)
					end

					tooltip:SetPoint(
						"TOPLEFT",
						dungeonEnemyBlips[mouseoverBlip],
						"BOTTOMRIGHT",
						30 + rightOffset,
						bottomOffset
					)
					tooltip:SetPoint(
						"BOTTOMRIGHT",
						dungeonEnemyBlips[mouseoverBlip],
						"BOTTOMRIGHT",
						30 + tooltip.mySizes.x + rightOffset,
						-tooltip.mySizes.y + bottomOffset
					)
				end
				local modelPath = dungeonEnemyBlips[mouseoverBlip].modelPath
				local id = dungeonEnemyBlips[mouseoverBlip].displayId or dungeonEnemyBlips[mouseoverBlip].id
				local isNpcId = (dungeonEnemyBlips[mouseoverBlip].displayId == nil)
				local cacheId = modelPath or id
				if cacheId then
					tooltip.Model:Show()
					if tooltip.Model.lastModelId ~= cacheId then
						if tooltip.Model.ClearModel then
							tooltip.Model:ClearModel()
						end
						MethodDungeonTools:SetDisplayInfo(tooltip.Model, id, isNpcId, modelPath)
						tooltip.Model.lastModelId = cacheId
					end
				else
					tooltip.Model:ClearModel()
					tooltip.Model:Hide()
				end

				lastMouseoverBlip = mouseoverBlip
				tooltipLastShown = GetTime()
				if dungeonEnemyBlipMouseoverHighlight then
					dungeonEnemyBlipMouseoverHighlight:SetPoint(
						"TOPLEFT",
						dungeonEnemyBlips[mouseoverBlip],
						"TOPLEFT",
						0,
						0
					)
					dungeonEnemyBlipMouseoverHighlight:SetPoint(
						"BOTTOMRIGHT",
						dungeonEnemyBlips[mouseoverBlip],
						"BOTTOMRIGHT",
						-1,
						0
					)
					dungeonEnemyBlipMouseoverHighlight:Show()
				end

				--check if blip is in a patrol but not the "leader"
				if data.patrolFollower then
					for blipIdx, blip in pairs(dungeonEnemyBlips) do
						if blip:IsShown() and blip.g and data.g then
							if blip.g == data.g and blip.patrol then
								mouseoverBlip = blipIdx
							end
						end
					end
				end

				--display patrol waypoints and lines
				for idx, blip in pairs(dungeonEnemyBlips) do
					if blip.patrol then
						if idx == mouseoverBlip and blip.patrolActive then
							for patrolIdx, waypointBlip in ipairs(blip.patrol) do
								if waypointBlip.isActive then
									waypointBlip:Show()
									waypointBlip.line:Show()
								end
							end
							if blip.patrolIndicator then
								blip.patrolIndicator:Show()
							end
							if blip.patrolIndicator2 and blip.patrolIndicator2.active then
								blip.patrolIndicator2:Show()
							end
						else
							for patrolIdx, waypointBlip in ipairs(blip.patrol) do
								waypointBlip:Hide()
								waypointBlip.line:Hide()
							end
							if blip.patrolIndicator then
								blip.patrolIndicator:Hide()
							end
							if blip.patrolIndicator2 then
								blip.patrolIndicator2:Hide()
							end
						end
					end
				end
			elseif tooltipLastShown and GetTime() - tooltipLastShown > 0.2 then
				tooltipLastShown = nil
				--GameTooltip:Hide()
				tooltip.Model:Hide()
				tooltip:Hide()
				tooltip.Model.lastModelId = nil
				if dungeonEnemyBlipMouseoverHighlight then
					dungeonEnemyBlipMouseoverHighlight:Hide()
				end
				--hide all patrol waypoints and facing indicators
				if dungeonEnemyBlips then
					for blipIdx, blip in pairs(dungeonEnemyBlips) do
						if blip.patrol then
							for patrolIdx, waypointBlip in ipairs(blip.patrol) do
								waypointBlip:Hide()
								waypointBlip.line:Hide()
							end
							if blip.patrolIndicator then
								blip.patrolIndicator:Hide()
							end
							if blip.patrolIndicator2 then
								blip.patrolIndicator2:Hide()
							end
						end
					end
				end
			end

			--mouseover pull button
			--[[

			elseif mouseOverPullButton then
				--tooltip.String:Show()
				--tooltip:Show()
				--tooltipLastShown = GetTime()


			local mouseOverPullButton
			if MouseIsOver(MethodDungeonTools.main_frame.sidePanel.pullButtonsScrollFrame.frame) then
				for idx,_ in pairs(MethodDungeonTools.main_frame.sidePanel.newPullButtons) do
					mouseOverPullButton = idx
					break
				end
			end

			]]

			if MethodDungeonTools.pullTooltip then
				MethodDungeonTools:UpdatePullTooltip(MethodDungeonTools.pullTooltip)
			end
		end)

		if frame.mapPanelFrame == nil then
			frame.mapPanelFrame = CreateFrame("Frame", "MethodDungeonToolsMapPanelFrame", frame.scrollFrame)
			frame.mapPanelFrame:SetSize(856, 642)
			frame.mapPanelFrame:Show()
		end

		--mouseover glow tex
		do
			if not dungeonEnemyBlipMouseoverHighlight then
				dungeonEnemyBlipMouseoverHighlight = MethodDungeonTools.main_frame.mapPanelFrame:CreateTexture(
					"MethodDungeonToolsDungeonEnemyBlipMouseoverHighlight",
					"BACKGROUND"
				)
				dungeonEnemyBlipMouseoverHighlight:SetDrawLayer("ARTWORK", 4)
				dungeonEnemyBlipMouseoverHighlight:SetTexture("Interface\\MINIMAP\\TRACKING\\Target")
				dungeonEnemyBlipMouseoverHighlight:SetVertexColor(1, 1, 1, 1)
				dungeonEnemyBlipMouseoverHighlight:SetWidth(10)
				dungeonEnemyBlipMouseoverHighlight:SetHeight(10)
				dungeonEnemyBlipMouseoverHighlight:Hide()
			end
		end

		--create up to 25 tiles and set the scrollchild
		for i = 1, 25 do
			frame["mapPanelTile" .. i] =
				frame.mapPanelFrame:CreateTexture("MethodDungeonToolsmapPanelTile" .. i, "BACKGROUND")
			frame["mapPanelTile" .. i]:SetDrawLayer("ARTWORK", 0)
			frame["mapPanelTile" .. i]:SetSize(sizex / 4 + 4, sizex / 4 + 4)
		end

		-- Helper to position tiles based on columns
		function MethodDungeonTools:PositionMapTiles(columns)
			columns = columns or 4
			local tileSize = sizex / columns
			for i = 1, 25 do
				local tile = frame["mapPanelTile" .. i]
				tile:ClearAllPoints()
				tile:SetSize(tileSize + 4, tileSize + 4)
				if i == 1 then
					tile:SetPoint("TOPLEFT", frame.mapPanelFrame, "TOPLEFT", 1, 0)
				else
					if (i - 1) % columns == 0 then
						tile:SetPoint("TOPLEFT", frame["mapPanelTile" .. (i - columns)], "BOTTOMLEFT")
					else
						tile:SetPoint("TOPLEFT", frame["mapPanelTile" .. (i - 1)], "TOPRIGHT")
					end
				end
			end
		end
		MethodDungeonTools:PositionMapTiles(4) -- Default
		frame.scrollFrame:SetScrollChild(frame.mapPanelFrame)
	end
end

local function round(number, decimals)
	return (("%%.%df"):format(decimals)):format(number)
end
function MethodDungeonTools:CalculateEnemyHealth(boss, fortified, tyrannical, baseHealth, level)
	local mult = 1
	if boss == false and fortified == true then
		mult = 1.2
	end
	if boss == true and tyrannical == true then
		mult = 1.4
	end
	mult = round((1.1 ^ (level - 1)) * mult, 2)
	return round(mult * baseHealth, 0)
end

function MethodDungeonTools:FormatEnemyHealth(amount)
	amount = tonumber(amount)
	if amount < 1000 then
		return ""
	end
	if amount < 10000 then
		return string.sub(amount, 1, 1) .. "k"
	end --1k
	if amount < 100000 then
		return string.sub(amount, 1, 2) .. "k"
	end --10k
	if amount < 1000000 then
		return string.sub(amount, 1, 3) .. "k"
	end --100k
	if amount < 10000000 then
		return string.sub(amount, 1, 1) .. "." .. string.sub(amount, 2, 3) .. "m"
	end --1.11m
	if amount < 100000000 then
		return string.sub(amount, 1, 2) .. "." .. string.sub(amount, 3, 4) .. "m"
	end --11.11m
	if amount < 1000000000 then
		return string.sub(amount, 1, 3) .. "." .. string.sub(amount, 4, 5) .. "m"
	end --111.11m
	return string.sub(amount, 1, 1) .. "." .. string.sub(amount, 2, 3) .. "b" --1.11b
end

function MethodDungeonTools:DisplayEncounterInformation(encounterID)

	--print(db.currentDungeonIdx)
end

function MethodDungeonTools:MakeDungeonBossButtons(frame)
	if not dungeonBossButtons then
		dungeonBossButtons = {}
		for i = 1, 10 do
			dungeonBossButtons[i] = CreateFrame("Button", "MethodDungeonToolsBossButton" .. i, frame.mapPanelFrame)
			dungeonBossButtons[i]:SetSize(18, 18) -- Base size for the icon
			dungeonBossButtons[i]:SetFrameLevel(frame.mapPanelFrame:GetFrameLevel() + 20)
			dungeonBossButtons[i]:RegisterForClicks("LeftButtonUp", "RightButtonUp")

			-- The Skull Icon Layer
			dungeonBossButtons[i].bgImage = dungeonBossButtons[i]:CreateTexture(nil, "ARTWORK")
			dungeonBossButtons[i].bgImage:SetAllPoints(dungeonBossButtons[i])
			dungeonBossButtons[i].bgImage:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")

			dungeonBossButtons[i]:SetScript("OnClick", nil)
			dungeonBossButtons[i]:Hide()
		end
	end
end

function MethodDungeonTools:UpdateDungeonBossButtons()
	if dungeonBossButtons then
		for i = 1, #dungeonBossButtons do
			dungeonBossButtons[i]:Hide()
			local bossData = MethodDungeonTools.dungeonBosses[db.currentDungeonIdx]
			local subLevel =
				db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
			if bossData and bossData[subLevel] and bossData[subLevel][i] then
				local data = bossData[subLevel][i]
				dungeonBossButtons[i].tooltipTitle = data["name"]
				local encounterID = data["encounterID"]

				dungeonBossButtons[i]:Show()
				dungeonBossButtons[i]:SetScript("OnClick", function(self, button)
					if MouseIsOver(MethodDungeonToolsScrollFrame) then
						if button == "RightButton" then
							MethodDungeonTools:ShowEnemyInfoFrame(nil, i)
						else
							MethodDungeonTools:DisplayEncounterInformation(encounterID)
						end
					end
				end)
				dungeonBossButtons[i]:SetPoint(
					"CENTER",
					MethodDungeonTools.main_frame.mapPanelTile1,
					"TOPLEFT",
					data["x"],
					data["y"]
				)
			end
		end
	end
end

local patrolColor = { r = 0, g = 0.5, b = 1, a = 0.8 }

function MethodDungeonTools:UpdateDungeonEnemies()
	if not dungeonEnemyBlips then
		dungeonEnemyBlips = {}
	end
	for k, v in pairs(dungeonEnemyBlips) do
		v:Hide()
		if v.colorOverlay then
			v.colorOverlay:Hide()
		end
		if v.pullCircle then
			v.pullCircle:Hide()
		end
		if v.patrolIndicator then
			v.patrolIndicator:Hide()
		end
		if v.fontString then
			v.fontString:Hide()
		end
	end
	local idx = 1
	if MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx] then
		local enemies = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
		for enemyIdx, data in pairs(enemies) do
			for cloneIdx, clone in pairs(data["clones"]) do
				--check sublevel
				if
					(
						clone.sublevel
						and clone.sublevel
							== db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
					)
					or (
						not clone.sublevel
						and db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
							== 1
					)
				then
					--check for teeming
					local teeming =
						db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
					if (teeming == true) or (teeming == false and ((not clone.teeming) or clone.teeming == false)) then
						if not dungeonEnemyBlips[idx] then
							dungeonEnemyBlips[idx] = CreateFrame(
								"Button",
								"MethodDungeonToolsDungeonEnemyBlip" .. idx,
								MethodDungeonTools.main_frame.mapPanelFrame
							)
							dungeonEnemyBlips[idx]:SetFrameLevel(5)
							dungeonEnemyBlips[idx]:EnableMouse(false)

							dungeonEnemyBlips[idx].texture = dungeonEnemyBlips[idx]:CreateTexture(nil, "ARTWORK")
							dungeonEnemyBlips[idx].texture:SetAllPoints()

							dungeonEnemyBlips[idx].selected = false
							dungeonEnemyBlips[idx].fontString = dungeonEnemyBlips[idx]:CreateFontString(
								"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "Text",
								"OVERLAY",
								"GameFontHighlightSmall"
							)
							local font, size = dungeonEnemyBlips[idx].fontString:GetFont()
							dungeonEnemyBlips[idx].fontName = font
							dungeonEnemyBlips[idx].fontString:SetFont(font, 9, "OUTLINE")
							dungeonEnemyBlips[idx].fontString:SetPoint("CENTER", dungeonEnemyBlips[idx], "CENTER", 0, 0)
							dungeonEnemyBlips[idx].fontString:SetJustifyH("CENTER")
						end
						dungeonEnemyBlips[idx].count = data["count"]
						dungeonEnemyBlips[idx].name = data["name"]
						dungeonEnemyBlips[idx].color = data["color"]

						dungeonEnemyBlips[idx].cloneIdx = cloneIdx
						dungeonEnemyBlips[idx].enemyIdx = enemyIdx
						dungeonEnemyBlips[idx].id = data["id"]
						dungeonEnemyBlips[idx].displayId = data["displayId"]
						dungeonEnemyBlips[idx].npcId = data["npcId"]
						dungeonEnemyBlips[idx].modelPath = data["modelPath"]
						dungeonEnemyBlips[idx].g = clone.g
						dungeonEnemyBlips[idx].sublevel = clone.sublevel or 1
						dungeonEnemyBlips[idx].creatureType = data["creatureType"]
						dungeonEnemyBlips[idx].health = data["health"]
						dungeonEnemyBlips[idx].level = data["level"]

						-- Create color background border if it doesn't exist
						if not dungeonEnemyBlips[idx].colorOverlay then
							local colorOverlay = dungeonEnemyBlips[idx]:CreateTexture(
								"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "ColorOverlay",
								"OVERLAY"
							)
							colorOverlay:SetDrawLayer("OVERLAY", 7)
							colorOverlay:SetTexture(
								"Interface\\AddOns\\" .. addonName .. "\\Textures\\Circle_Border.tga"
							)
							colorOverlay:SetPoint("CENTER", dungeonEnemyBlips[idx], "CENTER", 0, 0)
							dungeonEnemyBlips[idx].colorOverlay = colorOverlay
						else
							-- Ensure it stays on top even if reused
							dungeonEnemyBlips[idx].colorOverlay:SetDrawLayer("OVERLAY", 7)
						end

						-- Semi-transparent filled circle tinted with pull color
						if not dungeonEnemyBlips[idx].pullCircle then
							local pullCircle = dungeonEnemyBlips[idx]:CreateTexture(
								"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "PullCircle",
								"OVERLAY"
							)
							pullCircle:SetDrawLayer("OVERLAY", 3)
							pullCircle:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Textures\\Circle_White.tga")
							pullCircle:SetPoint("CENTER", dungeonEnemyBlips[idx], "CENTER", 0, 0)
							pullCircle:Hide()
							dungeonEnemyBlips[idx].pullCircle = pullCircle
						end

						-- Fetch spell icon if available
						local iconTex = "Interface\\AddOns\\" .. addonName .. "\\Textures\\Circle_White.tga"
						local hasSpellIcon = false

						local spellIdForIcon = nil
						if data.iconId ~= nil then
							if data.iconId ~= "" then
								spellIdForIcon = data.iconId
							end
						elseif data.spells and data.spells[1] then
							spellIdForIcon = data.spells[1]
						end

						if spellIdForIcon then
							local _, _, icon = GetSpellInfo(spellIdForIcon)
							if icon then
								iconTex = icon
								hasSpellIcon = true
							end
						end

						dungeonEnemyBlips[idx].texture:SetTexture(iconTex)

						if hasSpellIcon then
							-- Crop spell icon to remove its inherent black border so it feels fully circular
							dungeonEnemyBlips[idx].texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
						else
							dungeonEnemyBlips[idx].texture:SetTexCoord(0, 1, 0, 1)
						end

						if not dungeonEnemyBlips[idx].outline then
							dungeonEnemyBlips[idx].outline = dungeonEnemyBlips[idx]:CreateTexture(
								"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "Outline",
								"OVERLAY"
							)
							dungeonEnemyBlips[idx].outline:SetDrawLayer("OVERLAY", 1)
							dungeonEnemyBlips[idx].outline:SetTexture(
								"Interface\\AddOns\\" .. addonName .. "\\Textures\\Circle_White.tga"
							)
							dungeonEnemyBlips[idx].outline:SetVertexColor(1, 1, 1, 1)
							dungeonEnemyBlips[idx].outline:Hide()
						else
							dungeonEnemyBlips[idx].outline:SetDrawLayer("OVERLAY", 1)
						end
						dungeonEnemyBlips[idx]:SetWidth(10 * data["scale"])
						dungeonEnemyBlips[idx]:SetHeight(10 * data["scale"])
						-- The thicker generated ring size requires a 1.6x multiplier for perfect crop
						dungeonEnemyBlips[idx].colorOverlay:SetWidth(16 * data["scale"])
						dungeonEnemyBlips[idx].colorOverlay:SetHeight(16 * data["scale"])
						if dungeonEnemyBlips[idx].pullCircle then
							dungeonEnemyBlips[idx].pullCircle:SetWidth(10 * data["scale"])
							dungeonEnemyBlips[idx].pullCircle:SetHeight(10 * data["scale"])
						end
						dungeonEnemyBlips[idx]:SetPoint(
							"CENTER",
							MethodDungeonTools.main_frame.mapPanelTile1,
							"TOPLEFT",
							clone.x,
							clone.y
						)
						dungeonEnemyBlips[idx].outline:SetPoint("CENTER", dungeonEnemyBlips[idx], "CENTER", 0, 0)
						dungeonEnemyBlips[idx].outline:SetWidth((10 * data["scale"]) * 1.3)
						dungeonEnemyBlips[idx].outline:SetHeight((10 * data["scale"]) * 1.3)

						--color patrol
						dungeonEnemyBlips[idx].patrolFollower = nil
						dungeonEnemyBlips[idx].texture:SetVertexColor(1, 1, 1, 1) -- Reset icon color

						if clone.patrol then
							dungeonEnemyBlips[idx].color = patrolColor
						else
							--iterate over all enemies again to find if this npc is linked to a patrol
							for _, patrolCheckData in pairs(enemies) do
								for _, patrolCheckClone in pairs(patrolCheckData["clones"]) do
									--check sublevel
									if
										(
											patrolCheckClone.sublevel
											and patrolCheckClone.sublevel
												== db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
										)
										or (
											not patrolCheckClone.sublevel
											and db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
												== 1
										)
									then
										--check for teeming
										local patrolCheckDataTeeming =
											db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
										if
											(patrolCheckDataTeeming == true)
											or (
												patrolCheckDataTeeming == false
												and (not patrolCheckClone.teeming or patrolCheckClone.teeming == false)
											)
										then
											if clone.g and patrolCheckClone.g then
												if clone.g == patrolCheckClone.g and patrolCheckClone.patrol then
													dungeonEnemyBlips[idx].color = patrolColor
													dungeonEnemyBlips[idx].patrolFollower = true
												end
											end
										end
									end
								end
							end
						end

						local r, g, b =
							dungeonEnemyBlips[idx].color.r,
							dungeonEnemyBlips[idx].color.g,
							dungeonEnemyBlips[idx].color.b

						-- Check if this enemy is in a pull, color the border accordingly
						local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
						dungeonEnemyBlips[idx].pullIdx = nil
						for pullIdx, pullData in pairs(preset.value.pulls) do
							if pullData[enemyIdx] then
								for _, cIdx in pairs(pullData[enemyIdx]) do
									if cIdx == cloneIdx then
										local colorIdx = (pullIdx % #MethodDungeonTools.pullColors) + 1
										if colorIdx == 0 then
											colorIdx = 1
										end
										local pColor = MethodDungeonTools.pullColors[colorIdx]
										r, g, b = pColor[1], pColor[2], pColor[3]
										dungeonEnemyBlips[idx].pullIdx = pullIdx
										break
									end
								end
							end
						end

						-- Force the circular border to be 100% fully opaque regardless of the database value
						dungeonEnemyBlips[idx].colorOverlay:SetVertexColor(r, g, b, 1.0)

						-- Semi-transparent pull color circle on top of icon
						if dungeonEnemyBlips[idx].pullCircle then
							if dungeonEnemyBlips[idx].pullIdx then
								dungeonEnemyBlips[idx].pullCircle:SetVertexColor(r, g, b, 0.4)
								dungeonEnemyBlips[idx].pullCircle:Show()
							else
								dungeonEnemyBlips[idx].pullCircle:Hide()
							end
						end

						dungeonEnemyBlips[idx]:Show()
						dungeonEnemyBlips[idx].colorOverlay:Show()

						if dungeonEnemyBlips[idx].fontString then
							dungeonEnemyBlips[idx].fontString:Hide()
						end

						--clear patrol flag
						if dungeonEnemyBlips[idx].patrol then
							dungeonEnemyBlips[idx].patrolActive = nil
						end

						--patrol waypoints/lines
						if clone.patrol then
							if clone.patrolFacing then
								if not dungeonEnemyBlips[idx].patrolIndicator then
									dungeonEnemyBlips[idx].patrolIndicator =
										MethodDungeonTools.main_frame.mapPanelFrame:CreateTexture(
											"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "PatrolIndicator",
											"BACKGROUND"
										)
								end
								dungeonEnemyBlips[idx].patrolIndicator:SetDrawLayer("ARTWORK", 6)
								dungeonEnemyBlips[idx].patrolIndicator:SetTexture(
									"Interface\\MINIMAP\\ROTATING-MINIMAPGROUPARROW"
								)
								dungeonEnemyBlips[idx].patrolIndicator:SetWidth(18)
								dungeonEnemyBlips[idx].patrolIndicator:SetHeight(18)
								dungeonEnemyBlips[idx].patrolIndicator:SetVertexColor(1, 1, 1, 0.8)
								local xoffset = clone.patrolFacing < 2 / 4 * pi and -0.5 or 0
								dungeonEnemyBlips[idx].patrolIndicator:SetPoint(
									"BOTTOM",
									dungeonEnemyBlips[idx],
									"CENTER",
									xoffset,
									-9.5
								)
								dungeonEnemyBlips[idx].patrolIndicator:SetRotation(clone.patrolFacing, 0.5, 0.8)
								dungeonEnemyBlips[idx].patrolIndicator:Hide()
							end

							if clone.patrolFacing2 then
								if not dungeonEnemyBlips[idx].patrolIndicator2 then
									dungeonEnemyBlips[idx].patrolIndicator2 =
										MethodDungeonTools.main_frame.mapPanelFrame:CreateTexture(
											"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "PatrolIndicator2",
											"BACKGROUND"
										)
								end
								dungeonEnemyBlips[idx].patrolIndicator2:SetDrawLayer("ARTWORK", 6)
								dungeonEnemyBlips[idx].patrolIndicator2:SetTexture(
									"Interface\\MINIMAP\\ROTATING-MINIMAPGROUPARROW"
								)
								dungeonEnemyBlips[idx].patrolIndicator2:SetWidth(18)
								dungeonEnemyBlips[idx].patrolIndicator2:SetHeight(18)
								dungeonEnemyBlips[idx].patrolIndicator2:SetVertexColor(1, 1, 1, 0.8)
								local xoffset = clone.patrolFacing2 < 2 / 4 * pi and -0.5 or 0
								dungeonEnemyBlips[idx].patrolIndicator2:SetPoint(
									"BOTTOM",
									dungeonEnemyBlips[idx],
									"CENTER",
									xoffset,
									-9.5
								)
								dungeonEnemyBlips[idx].patrolIndicator2:SetRotation(clone.patrolFacing2, 0.5, 0.8)
								dungeonEnemyBlips[idx].patrolIndicator2:Hide()
								dungeonEnemyBlips[idx].patrolIndicator2.active = true
							elseif dungeonEnemyBlips[idx].patrolIndicator2 then
								dungeonEnemyBlips[idx].patrolIndicator2.active = nil
							end

							dungeonEnemyBlips[idx].patrol = dungeonEnemyBlips[idx].patrol or {}
							local firstWaypointBlip
							local oldWaypointBlip

							for k, v in pairs(dungeonEnemyBlips[idx].patrol) do
								v.isActive = false
							end

							for patrolIdx, waypoint in ipairs(clone.patrol) do
								if not dungeonEnemyBlips[idx].patrol[patrolIdx] then
									dungeonEnemyBlips[idx].patrol[patrolIdx] =
										MethodDungeonTools.main_frame.mapPanelFrame:CreateTexture(
											"MethodDungeonToolsDungeonEnemyBlip" .. idx .. "Patrol" .. patrolIdx,
											"BACKGROUND"
										)
								end
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetDrawLayer("ARTWORK", 5)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetTexture(
									"Interface\\Worldmap\\X_Mark_64Grey"
								)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetWidth(10 * 0.4)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetHeight(10 * 0.4)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetVertexColor(0, 0.2, 0.5, 0.6)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:SetPoint(
									"CENTER",
									MethodDungeonTools.main_frame.mapPanelTile1,
									"TOPLEFT",
									waypoint.x,
									waypoint.y
								)
								dungeonEnemyBlips[idx].patrol[patrolIdx]:Hide()
								dungeonEnemyBlips[idx].patrol[patrolIdx].isActive = true

								if not dungeonEnemyBlips[idx].patrol[patrolIdx].line then
									dungeonEnemyBlips[idx].patrol[patrolIdx].line =
										MethodDungeonTools.main_frame.mapPanelFrame:CreateTexture(
											"MethodDungeonToolsDungeonEnemyBlip"
												.. idx
												.. "Patrol"
												.. patrolIdx
												.. "line",
											"BACKGROUND"
										)
								end
								dungeonEnemyBlips[idx].patrol[patrolIdx].line:SetDrawLayer("ARTWORK", 5)
								dungeonEnemyBlips[idx].patrol[patrolIdx].line:SetTexture(
									"Interface\\AddOns\\" .. addonName .. "\\Textures\\Square_White"
								)
								dungeonEnemyBlips[idx].patrol[patrolIdx].line:SetVertexColor(0, 0.2, 0.5, 0.6)
								dungeonEnemyBlips[idx].patrol[patrolIdx].line:Hide()

								--connect 2 waypoints
								if oldWaypointBlip then
									local startPoint, startRelativeTo, startRelativePoint, startX, startY =
										dungeonEnemyBlips[idx].patrol[patrolIdx]:GetPoint()
									local endPoint, endRelativeTo, endRelativePoint, endX, endY =
										oldWaypointBlip:GetPoint()
									DrawLine(
										dungeonEnemyBlips[idx].patrol[patrolIdx].line,
										MethodDungeonTools.main_frame.mapPanelTile1,
										startX,
										startY,
										endX,
										endY,
										1,
										1,
										"TOPLEFT"
									)
									dungeonEnemyBlips[idx].patrol[patrolIdx].line:Hide()
								else
									firstWaypointBlip = dungeonEnemyBlips[idx].patrol[patrolIdx]
								end
								oldWaypointBlip = dungeonEnemyBlips[idx].patrol[patrolIdx]
							end
							--connect last 2 waypoints
							if firstWaypointBlip and oldWaypointBlip then
								local startPoint, startRelativeTo, startRelativePoint, startX, startY =
									firstWaypointBlip:GetPoint()
								local endPoint, endRelativeTo, endRelativePoint, endX, endY = oldWaypointBlip:GetPoint()
								DrawLine(
									firstWaypointBlip.line,
									MethodDungeonTools.main_frame.mapPanelTile1,
									startX,
									startY,
									endX,
									endY,
									1,
									1,
									"TOPLEFT"
								)
								firstWaypointBlip.line:Hide()
							end
							dungeonEnemyBlips[idx].patrolActive = true
						end

						idx = idx + 1
					end
				end
			end
		end
	end
	numDungeonEnemyBlips = idx - 1
end

function MethodDungeonTools:HideAllDialogs()
	MethodDungeonTools.main_frame.presetCreationFrame:Hide()
	MethodDungeonTools.main_frame.presetImportFrame:Hide()
	MethodDungeonTools.main_frame.ExportFrame:Hide()
	MethodDungeonTools.main_frame.RenameFrame:Hide()
	MethodDungeonTools.main_frame.ClearConfirmationFrame:Hide()
	MethodDungeonTools.main_frame.DeleteConfirmationFrame:Hide()
end

function MethodDungeonTools:OpenImportPresetDialog(importText)
	MethodDungeonTools:HideAllDialogs()
	MethodDungeonTools.main_frame.presetImportFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
	MethodDungeonTools.main_frame.presetImportFrame:Show()
	if importText then
		MethodDungeonTools.main_frame.presetImportBox:SetText(importText)
	else
		MethodDungeonTools.main_frame.presetImportBox:SetText("")
	end
	MethodDungeonTools.main_frame.presetImportBox:SetFocus()
end

function MethodDungeonTools:OpenNewPresetDialog()
	MethodDungeonTools:HideAllDialogs()
	local presetList = {}
	local countPresets = 0
	for k, v in pairs(db.presets[db.currentDungeonIdx]) do
		if v.text ~= "<New Preset>" then
			table.insert(presetList, k, v.text)
			countPresets = countPresets + 1
		end
	end
	table.insert(presetList, 1, "Empty")
	MethodDungeonTools.main_frame.PresetCreationDropDown:SetList(presetList)
	MethodDungeonTools.main_frame.PresetCreationDropDown:SetValue(1)
	MethodDungeonTools.main_frame.PresetCreationEditbox:SetText("Preset " .. countPresets + 1)
	MethodDungeonTools.main_frame.presetCreationFrame:SetPoint("CENTER", MethodDungeonTools.main_frame, "CENTER", 0, 50)
	MethodDungeonTools.main_frame.presetCreationFrame:SetStatusText("")
	MethodDungeonTools.main_frame.presetCreationFrame:Show()
	MethodDungeonTools.main_frame.presetCreationCreateButton:SetDisabled(false)
	local editbox = MethodDungeonTools.main_frame.PresetCreationEditbox
	if editbox then
		if editbox.SetFocus then
			editbox:SetFocus()
		elseif editbox.editbox and editbox.editbox.SetFocus then
			editbox.editbox:SetFocus()
		end
		if editbox.HighlightText then
			editbox:HighlightText(0, 50)
		elseif editbox.editbox and editbox.editbox.HighlightText then
			editbox.editbox:HighlightText(0, 50)
		end
	end
	MethodDungeonTools.main_frame.presetImportBox:SetText("")
end

function MethodDungeonTools:UpdateSidePanelCheckBoxes()
	local frame = MethodDungeonTools.main_frame
	local affix = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentAffix
	frame.sidePanelTyrannicalCheckBox:SetValue(affix ~= "fortified")
	frame.sidePanelFortifiedCheckBox:SetValue(affix == "fortified")

	-- local teeming = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
	-- frame.sidePanelTeemingCheckBox:SetValue(teeming)
	-- local teemingEnabled = MethodDungeonTools.dungeonTotalCount[db.currentDungeonIdx].teemingEnabled
	-- frame.sidePanelTeemingCheckBox:SetDisabled(not teemingEnabled)
end

function MethodDungeonTools:CreateDungeonPresetDropdown(frame)
	-- Dungeon Preset Dropdown using LibUIDropDownMenu
	local presetDD = CreateFrame("Frame", "MDTDungeonPresetDropdown", frame, "L_UIDropDownMenuTemplate")
	presetDD:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, -5)
	presetDD:SetFrameLevel(20)
	presetDD:SetSize(180, 20)
	presetDD:EnableMouse(false)
	_G[presetDD:GetName() .. "Button"]:EnableMouse(true)
	frame.DungeonPresetDropdown = presetDD

	L_UIDropDownMenu_Initialize(presetDD, function(self, level)
		local presets = db.presets[db.currentDungeonIdx] or {}
		for presetIdx, preset in ipairs(presets) do
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = preset.text
			info.value = presetIdx
			info.checked = (presetIdx == db.currentPreset[db.currentDungeonIdx])
			info.func = function()
				if preset.value == 0 then
					MethodDungeonTools:OpenNewPresetDialog()
					MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(true)
				else
					if presetIdx == 1 then
						MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(true)
					else
						MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(false)
					end
					db.currentPreset[db.currentDungeonIdx] = presetIdx
					MethodDungeonTools:UpdateMap()
				end
				L_UIDropDownMenu_SetSelectedValue(MethodDungeonTools.main_frame.DungeonPresetDropdown, presetIdx)
			end
			L_UIDropDownMenu_AddButton(info, level)
		end
	end)
	L_UIDropDownMenu_SetWidth(presetDD, 130)
end

function MethodDungeonTools:CreateDungeonSelectDropdown(frame)
	-- Sublevel Dropdown using LibUIDropDownMenu
	local sublevelDD = CreateFrame("Frame", "MDTDungeonSublevelDropdown", frame, "L_UIDropDownMenuTemplate")
	sublevelDD:SetPoint("TOPLEFT", frame.topPanel, "TOPLEFT", -15, -54)
	sublevelDD:SetFrameLevel(20)
	sublevelDD:SetSize(180, 20)
	sublevelDD:EnableMouse(false)
	_G[sublevelDD:GetName() .. "Button"]:EnableMouse(true)
	frame.DungeonSublevelSelectDropdown = sublevelDD

	L_UIDropDownMenu_Initialize(sublevelDD, function(self, level)
		local sublevels = MethodDungeonTools.dungeonSubLevels[db.currentDungeonIdx] or {}
		for _, entry in ipairs(sublevels) do
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = entry.text
			info.value = entry.value
			local currentSublevel = db.presets[db.currentDungeonIdx]
				and db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
				and db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
			info.checked = (entry.value == (currentSublevel or 1))
			info.func = function()
				db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel =
					entry.value
				L_UIDropDownMenu_SetText(MethodDungeonTools.main_frame.DungeonSublevelSelectDropdown, entry.text)
				MethodDungeonTools:UpdateMap()
				MethodDungeonTools:ZoomMap(1, true)
			end
			L_UIDropDownMenu_AddButton(info, level)
		end
	end)
	L_UIDropDownMenu_SetWidth(sublevelDD, 130)
	-- Default text: first sublevel name
	local firstSublevel = MethodDungeonTools.dungeonSubLevels[db.currentDungeonIdx or 1]
	L_UIDropDownMenu_SetText(
		sublevelDD,
		firstSublevel and firstSublevel[1] and firstSublevel[1].text or "1-й ярус"
	)

	-- Dungeon Select Dropdown using LibUIDropDownMenu
	local dungeonDD = CreateFrame("Frame", "MDTDungeonSelectDropdown", frame, "L_UIDropDownMenuTemplate")
	dungeonDD:SetPoint("TOPLEFT", frame.topPanel, "TOPLEFT", -15, -28)
	dungeonDD:SetFrameLevel(20)
	dungeonDD:SetSize(180, 20)
	dungeonDD:EnableMouse(false)
	_G[dungeonDD:GetName() .. "Button"]:EnableMouse(true)
	frame.DungeonSelectDropdown = dungeonDD

	L_UIDropDownMenu_Initialize(dungeonDD, function(self, level)
		for _, entry in ipairs(MethodDungeonTools.dungeonList) do
			local info = L_UIDropDownMenu_CreateInfo()
			info.text = entry.text
			info.value = entry.value
			info.checked = (entry.value == db.currentDungeonIdx)
			info.func = function()
				MethodDungeonTools:UpdateToDungeon(entry.value)
				L_UIDropDownMenu_SetText(MethodDungeonTools.main_frame.DungeonSelectDropdown, entry.text)
			end
			L_UIDropDownMenu_AddButton(info, level)
		end
	end)
	L_UIDropDownMenu_SetWidth(dungeonDD, 130)
	-- Default text: dungeon name matching current index
	local currentDungeonEntry = MethodDungeonTools.dungeonList[db.currentDungeonIdx or 1]
	L_UIDropDownMenu_SetText(
		dungeonDD,
		currentDungeonEntry and currentDungeonEntry.text or MethodDungeonTools.dungeonList[1].text
	)
end

function MethodDungeonTools:EnsureDBTables()
	db.currentDungeonIdx = db.currentDungeonIdx or 1
	if not MethodDungeonTools.dungeonList[db.currentDungeonIdx] then
		db.currentDungeonIdx = 1
	end

	db.currentPreset[db.currentDungeonIdx] = db.currentPreset[db.currentDungeonIdx] or 1
	if not db.presets[db.currentDungeonIdx] then
		db.presets[db.currentDungeonIdx] = { { text = "Default", value = { currentSublevel = 1, pulls = {} } } }
	end
	if not db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]] then
		db.currentPreset[db.currentDungeonIdx] = 1
	end

	local currentPreset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	if not currentPreset.value or type(currentPreset.value) ~= "table" then
		currentPreset.value = { currentSublevel = 1, pulls = {} }
	end

	currentPreset.value.currentAffix = currentPreset.value.currentAffix or "fortified"
	currentPreset.value.currentDungeonIdx = db.currentDungeonIdx
	currentPreset.value.teeming = currentPreset.value.teeming or false
	currentPreset.value.currentSublevel = currentPreset.value.currentSublevel or 1
	currentPreset.value.currentPull = currentPreset.value.currentPull or 1
	currentPreset.value.pulls = currentPreset.value.pulls or {}
	currentPreset.value.pulls[currentPreset.value.currentPull] = currentPreset.value.pulls[currentPreset.value.currentPull]
		or {}

	-- Sanitize presets: remove all "<New Preset>" and add one at the end
	local presets = db.presets[db.currentDungeonIdx]
	for i = #presets, 1, -1 do
		if presets[i].text == "<New Preset>" or presets[i].value == 0 then
			table.remove(presets, i)
		end
	end
	table.insert(presets, { text = "<New Preset>", value = 0 })

	-- Ensure currentPreset index is still valid after sanitization
	if db.currentPreset[db.currentDungeonIdx] > #presets then
		db.currentPreset[db.currentDungeonIdx] = 1
	end
end

function MethodDungeonTools:UpdateMap(ignoreSetSelection, ignoreReloadPullButtons)
	MethodDungeonTools:EnsureDBTables()
	local mapPanelFrame = self.main_frame.mapPanelFrame
	local mapName
	local frame = MethodDungeonTools.main_frame
	mapName = MethodDungeonTools.dungeonMaps[db.currentDungeonIdx]
		and MethodDungeonTools.dungeonMaps[db.currentDungeonIdx][0]
	if not mapName then
		return
	end

	local sublevel = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
	local fileName = MethodDungeonTools.dungeonMaps[db.currentDungeonIdx]
		and MethodDungeonTools.dungeonMaps[db.currentDungeonIdx][sublevel]
	if not fileName then
		return
	end
	if not fileName or not mapName then
		print(
			"MDT Debug: Missing map data for dungeon "
				.. (db.currentDungeonIdx or "nil")
				.. " sublevel "
				.. (sublevel or "nil")
		)
		return
	end
	local path = "Interface\\WorldMap\\" .. mapName .. "\\"
	local localPath = "Interface\\AddOns\\" .. addonName .. "\\Textures\\Maps\\"
	if mapName ~= "" then
		localPath = localPath .. mapName .. "\\"
	end

	-- print("MDT Debug: Attempting to load textures from: " .. localPath)
	-- Check if fileName is a single file (ends with .blp or .tga)
	local isSingleFile = fileName:match("%.blp$") or fileName:match("%.tga$")

	local columns = MethodDungeonTools.dungeonMaps[db.currentDungeonIdx].columns or 4
	local tileCount = MethodDungeonTools.dungeonMaps[db.currentDungeonIdx].tileCount or (isSingleFile and 1 or 12)
	if not isSingleFile then
		MethodDungeonTools:PositionMapTiles(columns)
	end

	for i = 1, 25 do
		local texName = localPath .. fileName
		if not isSingleFile then
			texName = texName .. i
		end
		if frame["mapPanelTile" .. i] then
			if isSingleFile then
				if i == 1 then
					frame["mapPanelTile" .. i]:SetTexture(texName)
					frame["mapPanelTile" .. i]:SetAllPoints(frame.mapPanelFrame)
					frame["mapPanelTile" .. i]:Show()
				else
					frame["mapPanelTile" .. i]:Hide()
				end
			else
				if i <= tileCount then
					frame["mapPanelTile" .. i]:SetTexture(texName)
					frame["mapPanelTile" .. i]:Show()
				else
					frame["mapPanelTile" .. i]:Hide()
				end
			end
		end
	end
	MethodDungeonTools:UpdateDungeonBossButtons()
	MethodDungeonTools:UpdateDungeonEnemies()
	if not ignoreReloadPullButtons then
		MethodDungeonTools:ReloadPullButtons()
	end
	MethodDungeonTools:UpdateSidePanelCheckBoxes()

	--handle delete button disable/enable
	local presetCount = 0
	for k, v in pairs(db.presets[db.currentDungeonIdx]) do
		presetCount = presetCount + 1
	end
	if db.currentPreset[db.currentDungeonIdx] == 1 or db.currentPreset[db.currentDungeonIdx] == presetCount then
		MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(true)
	else
		MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(false)
	end

	if not ignoreSetSelection then
		MethodDungeonTools:SetSelectionToPull(
			db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentPull
		)
	end
	--update Sublevel select dropdown text and Dungeon dropdown text
	if
		MethodDungeonTools.dungeonSubLevels[db.currentDungeonIdx]
		and db.presets[db.currentDungeonIdx]
		and db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	then
		L_UIDropDownMenu_Refresh(frame.DungeonSublevelSelectDropdown)
		-- Sync visible text to current sublevel name
		local currentSublevel = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
			or 1
		local sublevels = MethodDungeonTools.dungeonSubLevels[db.currentDungeonIdx]
		for _, entry in ipairs(sublevels) do
			if entry.value == currentSublevel then
				L_UIDropDownMenu_SetText(frame.DungeonSublevelSelectDropdown, entry.text)
				break
			end
		end
	end
	-- Sync visible text to current dungeon name
	if frame.DungeonSelectDropdown then
		local dungeonEntry = MethodDungeonTools.dungeonList[db.currentDungeonIdx]
		if dungeonEntry then
			L_UIDropDownMenu_SetText(frame.DungeonSelectDropdown, dungeonEntry.text)
		end
	end
	-- Sync visible text to current preset name
	if frame.sidePanel and frame.sidePanel.DungeonPresetDropdown then
		local currentPresetIdx = db.currentPreset[db.currentDungeonIdx]
		local presetEntry = db.presets[db.currentDungeonIdx] and db.presets[db.currentDungeonIdx][currentPresetIdx]
		if presetEntry then
			L_UIDropDownMenu_SetText(frame.sidePanel.DungeonPresetDropdown, presetEntry.text)
		end
	end
end

---UpdateToDungeon
---Updates the map to the specified dungeon
function MethodDungeonTools:UpdateToDungeon(dungeonIdx, forceZone)
	local frame = MethodDungeonTools.main_frame
	db.currentDungeonIdx = dungeonIdx

	if not db.presets[db.currentDungeonIdx] then
		db.presets[db.currentDungeonIdx] = { { text = "Default", value = { currentSublevel = 1, pulls = {} } } }
	end
	if not db.currentPreset[db.currentDungeonIdx] then
		db.currentPreset[db.currentDungeonIdx] = 1
	end

	local currentPreset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	if not currentPreset or not currentPreset.value or type(currentPreset.value) ~= "table" then
		db.presets[db.currentDungeonIdx][1] = { text = "Default", value = { currentSublevel = 1, pulls = {} } }
		db.currentPreset[db.currentDungeonIdx] = 1
		currentPreset = db.presets[db.currentDungeonIdx][1]
	end
	if not currentPreset.value.currentSublevel then
		currentPreset.value.currentSublevel = 1
	end

	-- Refresh all dropdowns via LibUIDropDownMenu
	if frame.DungeonSelectDropdown then
		L_UIDropDownMenu_Refresh(frame.DungeonSelectDropdown)
	end
	if frame.DungeonSublevelSelectDropdown then
		L_UIDropDownMenu_Refresh(frame.DungeonSublevelSelectDropdown)
	end
	if frame.sidePanel and frame.sidePanel.DungeonPresetDropdown then
		L_UIDropDownMenu_Refresh(frame.sidePanel.DungeonPresetDropdown)
	end

	MethodDungeonTools:UpdateMap()
	MethodDungeonTools:ZoomMap(1, true)
end

function MethodDungeonTools:DeletePreset(index)
	tremove(db.presets[db.currentDungeonIdx], index)
	db.currentPreset[db.currentDungeonIdx] = math.max(1, index - 1)
	if
		MethodDungeonTools.main_frame
		and MethodDungeonTools.main_frame.sidePanel
		and MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown
	then
		L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
	end
	MethodDungeonTools:UpdateMap()
end

function MethodDungeonTools:ClearPreset(index)
	table.wipe(db.presets[db.currentDungeonIdx][index].value.pulls)
	db.presets[db.currentDungeonIdx][index].value.currentPull = 1
	MethodDungeonTools:EnsureDBTables()
	MethodDungeonTools:UpdateMap()
	MethodDungeonTools:ReloadPullButtons()
end

function MethodDungeonTools:CreateNewPreset(name)
	if name == "<New Preset>" then
		MethodDungeonTools.main_frame.presetCreationLabel:SetText("Cannot create preset '" .. name .. "'")
		MethodDungeonTools.main_frame.presetCreationCreateButton:SetDisabled(true)
		MethodDungeonTools.main_frame.presetCreationFrame:DoLayout()
		return
	end
	local duplicate = false
	local countPresets = 0
	for k, v in pairs(db.presets[db.currentDungeonIdx]) do
		countPresets = countPresets + 1
		if v.text == name then
			duplicate = true
		end
	end
	if duplicate == false then
		-- Find and remove existing <New Preset>
		local presets = db.presets[db.currentDungeonIdx]
		for i = #presets, 1, -1 do
			if presets[i].text == "<New Preset>" or presets[i].value == 0 then
				table.remove(presets, i)
			end
		end

		local startingPointPresetIdx = MethodDungeonTools.main_frame.PresetCreationDropDown:GetValue() - 1
		local newPreset
		if startingPointPresetIdx > 0 then
			newPreset = MethodDungeonTools:CopyObject(db.presets[db.currentDungeonIdx][startingPointPresetIdx])
			newPreset.text = name
		else
			newPreset = { text = name, value = { currentSublevel = 1, pulls = {} } }
		end
		table.insert(presets, newPreset)
		db.currentPreset[db.currentDungeonIdx] = #presets

		-- Re-add <New Preset> at the end
		table.insert(presets, { text = "<New Preset>", value = 0 })

		MethodDungeonTools.main_frame.presetCreationFrame:Hide()
		L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
		MethodDungeonTools:UpdateMap()
	else
		MethodDungeonTools.main_frame.presetCreationLabel:SetText("'" .. name .. "' already exists.")
		MethodDungeonTools.main_frame.presetCreationCreateButton:SetDisabled(true)
		MethodDungeonTools.main_frame.presetCreationFrame:DoLayout()
	end
end

function MethodDungeonTools:SanitizePresetName(text)
	--check if name is valid, block button if so, unblock if valid
	if text == "<New Preset>" then
		return false
	else
		local duplicate = false
		local countPresets = 0
		for k, v in pairs(db.presets[db.currentDungeonIdx]) do
			countPresets = countPresets + 1
			if v.text == text then
				duplicate = true
			end
		end
		return not duplicate and text or false
	end
end

function MethodDungeonTools:MakePresetImportFrame(frame)
	frame.presetImportFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.presetImportFrame:SetTitle("Import Preset")
	frame.presetImportFrame:SetWidth(400)
	frame.presetImportFrame:SetHeight(200)
	frame.presetImportFrame:EnableResize(false)
	--frame.presetCreationFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame.presetImportFrame:SetLayout("Flow")
	frame.presetImportFrame:SetCallback("OnClose", function(widget)
		if MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown then
			L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
			if db.currentPreset[db.currentDungeonIdx] ~= 1 then
				MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(false)
			end
		end
	end)

	frame.presetImportLabel = MethodDungeonTools:AceGUI_Create("Label")
	frame.presetImportLabel:SetText(nil)
	frame.presetImportLabel:SetWidth(390)
	frame.presetImportLabel:SetColor(1, 0, 0)

	local importString = ""
	frame.presetImportBox = MethodDungeonTools:AceGUI_Create("EditBox")
	frame.presetImportBox:SetLabel("Import Preset:")
	frame.presetImportBox:SetWidth(255)
	frame.presetImportBox:SetCallback("OnEnterPressed", function(widget, event, text)
		importString = text
	end)
	frame.presetImportBox:SetCallback("OnTextChanged", function(widget, event, text)
		importString = text or (widget.GetText and widget:GetText()) or ""
	end)
	frame.presetImportFrame:AddChild(frame.presetImportBox)

	local importButton = MethodDungeonTools:AceGUI_Create("Button")
	importButton:SetText("Import")
	importButton:SetWidth(100)
	importButton:SetCallback("OnClick", function()
		importString = (frame.presetImportBox.GetText and frame.presetImportBox:GetText()) or importString or ""
		local newPreset = MethodDungeonTools:StringToTable(importString, true)
		if MethodDungeonTools:ValidateImportPreset(newPreset) then
			MethodDungeonTools.main_frame.presetImportFrame:Hide()
			MethodDungeonTools:ImportPreset(newPreset)
		else
			frame.presetImportLabel:SetText("Invalid import string")
		end
	end)
	frame.presetImportFrame:AddChild(importButton)
	frame.presetImportFrame:AddChild(frame.presetImportLabel)
	frame.presetImportFrame:Hide()
end

function MethodDungeonTools:MakePresetCreationFrame(frame)
	frame.presetCreationFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.presetCreationFrame:SetTitle("New Preset")
	frame.presetCreationFrame:SetWidth(400)
	frame.presetCreationFrame:SetHeight(200)
	frame.presetCreationFrame:EnableResize(false)
	--frame.presetCreationFrame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame.presetCreationFrame:SetLayout("Flow")
	frame.presetCreationFrame:SetCallback("OnClose", function(widget)
		if MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown then
			L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
			if db.currentPreset[db.currentDungeonIdx] ~= 1 then
				MethodDungeonTools.main_frame.sidePanelDeleteButton:SetDisabled(false)
			end
		end
	end)

	frame.PresetCreationEditbox = MethodDungeonTools:AceGUI_Create("EditBox")
	frame.PresetCreationEditbox:SetLabel("Preset name:")
	frame.PresetCreationEditbox:SetWidth(255)
	frame.PresetCreationEditbox:SetCallback("OnEnterPressed", function(widget, event, text)
		--check if name is valid, block button if so, unblock if valid
		if MethodDungeonTools:SanitizePresetName(text) then
			frame.presetCreationLabel:SetText(nil)
			frame.presetCreationCreateButton:SetDisabled(false)
		else
			frame.presetCreationLabel:SetText("Cannot create preset '" .. text .. "'")
			frame.presetCreationCreateButton:SetDisabled(true)
		end
		frame.presetCreationFrame:DoLayout()
	end)
	frame.presetCreationFrame:AddChild(frame.PresetCreationEditbox)

	frame.presetCreationCreateButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.presetCreationCreateButton:SetText("Create")
	frame.presetCreationCreateButton:SetWidth(100)
	frame.presetCreationCreateButton:SetCallback("OnClick", function()
		local eb = frame.PresetCreationEditbox
		local name = ""
		if eb.GetText then
			name = eb:GetText()
		elseif eb.GetValue then
			name = eb:GetValue()
		elseif eb.editbox and eb.editbox.GetText then
			name = eb.editbox:GetText()
		end
		MethodDungeonTools:CreateNewPreset(name)
	end)
	frame.presetCreationFrame:AddChild(frame.presetCreationCreateButton)

	frame.presetCreationLabel = MethodDungeonTools:AceGUI_Create("Label")
	frame.presetCreationLabel:SetText(nil)
	frame.presetCreationLabel:SetWidth(390)
	frame.presetCreationLabel:SetColor(1, 0, 0)
	frame.presetCreationFrame:AddChild(frame.presetCreationLabel)

	frame.PresetCreationDropDown = MethodDungeonTools:AceGUI_Create("Dropdown")
	frame.PresetCreationDropDown:SetLabel("Use as a starting point:")
	frame.presetCreationFrame:AddChild(frame.PresetCreationDropDown)

	frame.presetCreationFrame:Hide()
end

function MethodDungeonTools:ValidateImportPreset(preset)
	if type(preset) ~= "table" then
		return false
	end
	if not preset.text then
		return false
	end
	if not preset.value then
		return false
	end
	if type(preset.text) ~= "string" then
		return false
	end
	if type(preset.value) ~= "table" then
		return false
	end
	if not preset.value.currentAffix then
		return false
	end
	if not preset.value.currentDungeonIdx then
		return false
	end
	if not preset.value.currentPull then
		return false
	end
	if not preset.value.currentSublevel then
		return false
	end
	if not preset.value.pulls then
		return false
	end
	if type(preset.value.pulls) ~= "table" then
		return false
	end
	return true
end

function MethodDungeonTools:ImportPreset(preset)
	--change dungeon to dungeon of the new preset
	MethodDungeonTools:UpdateToDungeon(preset.value.currentDungeonIdx)
	local name = preset.text
	local num = 2
	for k, v in pairs(db.presets[db.currentDungeonIdx]) do
		if name == v.text then
			name = preset.text .. " " .. num
			num = num + 1
		end
	end

	preset.text = name
	local presets = db.presets[db.currentDungeonIdx]

	-- Find and remove existing <New Preset>
	for i = #presets, 1, -1 do
		if presets[i].text == "<New Preset>" or presets[i].value == 0 then
			table.remove(presets, i)
		end
	end

	table.insert(presets, preset)
	db.currentPreset[db.currentDungeonIdx] = #presets

	-- Re-add <New Preset> at the end
	table.insert(presets, { text = "<New Preset>", value = 0 })

	L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
	MethodDungeonTools:UpdateMap()
end

function MethodDungeonTools:MakePullSelectionButtons(frame)
	frame.PullButtonScrollGroup = MethodDungeonTools:AceGUI_Create("SimpleGroup")
	frame.PullButtonScrollGroup:SetWidth(249)
	frame.PullButtonScrollGroup:SetHeight(410)
	frame.PullButtonScrollGroup:SetPoint("TOPLEFT", frame.WidgetGroup.frame, "BOTTOMLEFT", -4, -32)
	frame.PullButtonScrollGroup:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 30)
	frame.PullButtonScrollGroup:SetLayout("Fill")
	frame.PullButtonScrollGroup.frame:SetFrameStrata(mainFrameStrata)
	frame.PullButtonScrollGroup.frame:Show()

	--dirty hook to make PullButtonScrollGroup show/hide
	local originalShow, originalHide = MethodDungeonTools.main_frame.Show, MethodDungeonTools.main_frame.Hide
	function MethodDungeonTools.main_frame:Show(...)
		frame.PullButtonScrollGroup.frame:Show()
		return originalShow(self, ...)
	end
	function MethodDungeonTools.main_frame:Hide(...)
		frame.PullButtonScrollGroup.frame:Hide()
		return originalHide(self, ...)
	end

	frame.pullButtonsScrollFrame = MethodDungeonTools:AceGUI_Create("ScrollFrame")
	frame.pullButtonsScrollFrame:SetLayout("Flow")

	frame.PullButtonScrollGroup:AddChild(frame.pullButtonsScrollFrame)

	frame.newPullButtons = {}

	--rightclick context menu
	frame.optionsDropDown = CreateFrame("Frame", "PullButtonsOptionsDropDown", nil, "L_UIDropDownMenuTemplate")
end

function MethodDungeonTools:PresetsAddPull(index)
	if index then
		tinsert(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls, index, {})
	else
		tinsert(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls, {})
	end
end

function MethodDungeonTools:PresetsDeletePull(p, j)
	tremove(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls, p)
	--TODO remove all pulls from j to end? bug where u have to remove multiple times to remove "invisible pulls"
	for k, v in ipairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls) do
		--print(k,v,j)
	end
end

function MethodDungeonTools:CopyObject(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do
		res[MethodDungeonTools:CopyObject(k, s)] = MethodDungeonTools:CopyObject(v, s)
	end
	return res
end

function MethodDungeonTools:PresetsSwapPulls(p1, p2)
	local p1copy = MethodDungeonTools:CopyObject(
		db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[p1]
	)
	local p2copy = MethodDungeonTools:CopyObject(
		db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[p2]
	)
	db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[p1] = p2copy
	db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[p2] = p1copy
end

function MethodDungeonTools:SetMapSublevel(pull)
	--set map sublevel
	local shouldResetZoom = false
	local lastSubLevel
	for enemyIdx, clones in
		pairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[pull])
	do
		for idx, cloneIdx in pairs(clones) do
			if MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx][enemyIdx]["clones"][cloneIdx] then
				lastSubLevel =
					MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx][enemyIdx]["clones"][cloneIdx].sublevel
			end
		end
	end
	if lastSubLevel then
		shouldResetZoom = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
			~= lastSubLevel
		db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel = lastSubLevel
		MethodDungeonTools:UpdateMap(true, true)
	end

	--update dropdown
	L_UIDropDownMenu_Refresh(self.main_frame.DungeonSublevelSelectDropdown)
	if shouldResetZoom then
		MethodDungeonTools:ZoomMap(1, true)
	end
end

function MethodDungeonTools:SetSelectionToPull(pull, noAutoCenter)
	--if pull is not specified set pull to last pull in preset (for adding new pulls)
	if not pull then
		local count = 0
		for k, v in pairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls) do
			count = count + 1
		end
		pull = count
	end
	--SaveCurrentPresetPull
	db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentPull = pull
	MethodDungeonTools:PickPullButton(pull)

	--deselect all
	for k, v in pairs(dungeonEnemyBlips) do
		MethodDungeonTools:UpdateEnemyBlipSelection(k, true)
	end

	--highlight current pull enemies
	for enemyIdx, clones in
		pairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[pull])
	do
		for j, cloneIdx in pairs(clones) do
			for k, v in ipairs(dungeonEnemyBlips) do
				if (v.enemyIdx == enemyIdx) and (v.cloneIdx == cloneIdx) then
					MethodDungeonTools:UpdateEnemyBlipSelection(k, nil, true)
				end
			end
		end
	end

	--highlight other pull enemies
	for pullIdx, p in pairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls) do
		if pullIdx ~= pull then
			for enemyIdx, clones in pairs(p) do
				for j, cloneIdx in pairs(clones) do
					for k, v in ipairs(dungeonEnemyBlips) do
						if (v.enemyIdx == enemyIdx) and (v.cloneIdx == cloneIdx) then
							MethodDungeonTools:UpdateEnemyBlipSelection(k, nil, true, pullIdx)
						end
					end
				end
			end
		end
	end

	-- Centering map on current pull
	if not noAutoCenter then
		local avgX, avgY = 0, 0
		local count = 0
		local pullEnemies = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[pull]
		if pullEnemies then
			for enemyIdx, clones in pairs(pullEnemies) do
				local dungeonData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
				local enemyData = dungeonData and dungeonData[enemyIdx] or nil
				if enemyData and enemyData.clones then
					for _, cloneIdx in pairs(clones) do
						local clone = enemyData.clones[cloneIdx]
						if clone and clone.x and clone.y then
							avgX = avgX + clone.x
							avgY = avgY + clone.y
							count = count + 1
						end
					end
				end
			end
		end
		if count > 0 then
			avgX = avgX / count
			avgY = avgY / count
			local scrollFrame = MethodDungeonTools.main_frame.scrollFrame
			local mapScale = MethodDungeonTools.main_frame.mapPanelFrame:GetScale()
			if mapScale > 1.05 and scrollFrame.maxX and scrollFrame.maxY then
				-- Map dimensions are 856x642
				local mapW, mapH = 856, 642
				local viewW = scrollFrame:GetWidth() or 840
				local viewH = scrollFrame:GetHeight() or 555
				local targetX = avgX * mapScale
				local targetY = -avgY * mapScale
				local rangeX = (mapW * mapScale) - viewW
				local rangeY = (mapH * mapScale) - viewH
				local targetScrollH, targetScrollV = 0, 0
				if rangeX > 0 and scrollFrame.maxX and scrollFrame.maxX > 0 then
					local fractionX = (targetX - (viewW / 2)) / rangeX
					targetScrollH = fractionX * scrollFrame.maxX
				end
				if rangeY > 0 and scrollFrame.maxY and scrollFrame.maxY > 0 then
					local fractionY = (targetY - (viewH / 2)) / rangeY
					targetScrollV = fractionY * scrollFrame.maxY
				end
				targetScrollH = math.max(0, math.min(targetScrollH, scrollFrame.maxX or 0))
				targetScrollV = math.max(0, math.min(targetScrollV, scrollFrame.maxY or 0))
				scrollFrame:SetHorizontalScroll(targetScrollH)
				scrollFrame:SetVerticalScroll(targetScrollV)
			end
		end
	end

	MethodDungeonTools:UpdateEnemiesSelected()
end

---UpdatePullButtonNPCData
---Updates the portraits display of a button to show which and how many npcs are selected
function MethodDungeonTools:UpdatePullButtonNPCData(idx)
	local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
	local frame = MethodDungeonTools.main_frame.sidePanel
	local teeming = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.teeming
	local enemyTable = {}
	if preset.value.pulls[idx] then
		local enemyTableIdx = 0
		for enemyIdx, clones in pairs(preset.value.pulls[idx]) do
			local dungeonData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
			local enemyData = dungeonData and dungeonData[enemyIdx] or nil
			if enemyData then
				local incremented = false
				local npcId = enemyData["id"]
				local name = enemyData["name"]
				local creatureType = enemyData["creatureType"]
				local level = enemyData["level"]
				local baseHealth = enemyData["health"]
				for k, cloneIdx in pairs(clones) do
					if enemyData["clones"] and enemyData["clones"][cloneIdx] then
						--check for teeming
						local cloneIsTeeming = enemyData["clones"][cloneIdx].teeming
						if
							(cloneIsTeeming and teeming)
							or (not cloneIsTeeming and not teeming)
							or (not cloneIsTeeming and teeming)
						then
							if not incremented then
								enemyTableIdx = enemyTableIdx + 1
								incremented = true
							end
							if not enemyTable[enemyTableIdx] then
								enemyTable[enemyTableIdx] = {}
							end
							enemyTable[enemyTableIdx].quantity = enemyTable[enemyTableIdx].quantity or 0
							enemyTable[enemyTableIdx].npcId = npcId
							enemyTable[enemyTableIdx].id = npcId
							enemyTable[enemyTableIdx].count = enemyData["count"]
							enemyTable[enemyTableIdx].displayId = enemyData["displayId"]
							enemyTable[enemyTableIdx].iconId = enemyData["iconId"]
							enemyTable[enemyTableIdx].quantity = enemyTable[enemyTableIdx].quantity + 1
							enemyTable[enemyTableIdx].name = name
							enemyTable[enemyTableIdx].level = level
							enemyTable[enemyTableIdx].creatureType = creatureType
							enemyTable[enemyTableIdx].baseHealth = baseHealth
						end
					end
				end
			end
		end
	end
	if frame.newPullButtons[idx] then
		frame.newPullButtons[idx]:SetNPCData(enemyTable)
	end
end

---ReloadPullButtons
---Reloads all pull buttons in the scroll frame
function MethodDungeonTools:ReloadPullButtons()
	local frame = MethodDungeonTools.main_frame.sidePanel
	local preset = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]

	--first release all children of the scroll frame
	frame.pullButtonsScrollFrame:ReleaseChildren()

	local maxPulls = 0
	for k, v in pairs(preset.value.pulls) do
		maxPulls = maxPulls + 1
	end

	--add new children to the scrollFrame, the frames are from the widget pool so no memory is wasted

	local idx = 0
	for k, pull in pairs(preset.value.pulls) do
		idx = idx + 1
		frame.newPullButtons[idx] = MethodDungeonTools:AceGUI_Create("MethodDungeonToolsPullButton")
		frame.newPullButtons[idx]:SetMaxPulls(maxPulls)
		frame.newPullButtons[idx]:SetIndex(idx)
		MethodDungeonTools:UpdatePullButtonNPCData(idx)
		frame.newPullButtons[idx]:Initialize()
		frame.newPullButtons[idx]:Enable()
		frame.pullButtonsScrollFrame:AddChild(frame.newPullButtons[idx])
	end

	--add the "new pull" button
	frame.newPullButton = MethodDungeonTools:AceGUI_Create("MethodDungeonToolsNewPullButton")
	frame.newPullButton:Initialize()
	frame.newPullButton:Enable()
	frame.pullButtonsScrollFrame:AddChild(frame.newPullButton)
end

---ClearPullButtonPicks
---Deselects all pull buttons
function MethodDungeonTools:ClearPullButtonPicks()
	local frame = MethodDungeonTools.main_frame.sidePanel
	for k, v in pairs(frame.newPullButtons) do
		v:ClearPick()
	end
end

---PickPullButton
---Selects the current pull button and deselects all other buttons
function MethodDungeonTools:PickPullButton(idx)
	MethodDungeonTools:ClearPullButtonPicks()
	local frame = MethodDungeonTools.main_frame.sidePanel
	frame.newPullButtons[idx]:Pick()
end

---AddPull
---Creates a new pull in the current preset and calls ReloadPullButtons to reflect the change in the scrollframe
function MethodDungeonTools:AddPull(index)
	MethodDungeonTools:PresetsAddPull(index)
	MethodDungeonTools:ReloadPullButtons()
	MethodDungeonTools:SetSelectionToPull(index)
end

---ClearPull
---Clears all the npcs out of a pull
function MethodDungeonTools:ClearPull(index)
	table.wipe(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls[index])
	MethodDungeonTools:ReloadPullButtons()
	MethodDungeonTools:SetSelectionToPull(index)
end

---MovePullUp
---Moves the selected pull up
function MethodDungeonTools:MovePullUp(index)
	MethodDungeonTools:PresetsSwapPulls(index, index - 1)
	MethodDungeonTools:ReloadPullButtons()
	MethodDungeonTools:SetSelectionToPull(index - 1)
end

---MovePullDown
---Moves the selected pull down
function MethodDungeonTools:MovePullDown(index)
	MethodDungeonTools:PresetsSwapPulls(index, index + 1)
	MethodDungeonTools:ReloadPullButtons()
	MethodDungeonTools:SetSelectionToPull(index + 1)
end

---DeletePull
---Deletes the selected pull and makes sure that a pull will be selected afterwards
function MethodDungeonTools:DeletePull(index)
	MethodDungeonTools:PresetsDeletePull(index)
	MethodDungeonTools:ReloadPullButtons()
	local pullCount = 0
	for k, v in pairs(db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.pulls) do
		pullCount = pullCount + 1
	end
	if index > pullCount then
		index = pullCount
	end
	MethodDungeonTools:SetSelectionToPull(index)
end

---RenamePreset
function MethodDungeonTools:RenamePreset(renameText)
	db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].text = renameText
	MethodDungeonTools.main_frame.RenameFrame:Hide()
	L_UIDropDownMenu_Refresh(MethodDungeonTools.main_frame.sidePanel.DungeonPresetDropdown)
end

function MethodDungeonTools:MakeRenameFrame(frame)
	frame.RenameFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.RenameFrame:SetTitle("Rename Preset")
	frame.RenameFrame:SetWidth(350)
	frame.RenameFrame:SetHeight(150)
	frame.RenameFrame:EnableResize(false)
	frame.RenameFrame:SetLayout("Flow")
	frame.RenameFrame:SetCallback("OnClose", function(widget) end)
	frame.RenameFrame:Hide()

	local renameText
	frame.RenameFrame.Editbox = MethodDungeonTools:AceGUI_Create("EditBox")
	frame.RenameFrame.Editbox:SetLabel("Insert new Preset Name:")
	frame.RenameFrame.Editbox:SetWidth(200)
	frame.RenameFrame.Editbox:SetCallback("OnEnterPressed", function(...)
		local widget, event, text = ...
		--check if name is valid, block button if so, unblock if valid
		if MethodDungeonTools:SanitizePresetName(text) then
			frame.RenameFrame.PresetRenameLabel:SetText(nil)
			frame.RenameFrame.RenameButton:SetDisabled(false)
			renameText = text
		else
			frame.RenameFrame.PresetRenameLabel:SetText("Cannot rename preset to '" .. text .. "'")
			frame.RenameFrame.RenameButton:SetDisabled(true)
			renameText = nil
		end
		frame.presetCreationFrame:DoLayout()
	end)

	frame.RenameFrame:AddChild(frame.RenameFrame.Editbox)

	frame.RenameFrame.RenameButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.RenameFrame.RenameButton:SetText("Rename")
	frame.RenameFrame.RenameButton:SetWidth(100)
	frame.RenameFrame.RenameButton:SetCallback("OnClick", function()
		MethodDungeonTools:RenamePreset(renameText)
	end)
	frame.RenameFrame:AddChild(frame.RenameFrame.RenameButton)

	frame.RenameFrame.PresetRenameLabel = MethodDungeonTools:AceGUI_Create("Label")
	frame.RenameFrame.PresetRenameLabel:SetText(nil)
	frame.RenameFrame.PresetRenameLabel:SetWidth(390)
	frame.RenameFrame.PresetRenameLabel:SetColor(1, 0, 0)
	frame.RenameFrame:AddChild(frame.RenameFrame.PresetRenameLabel)
end

---MakeExportFrame
---Creates the frame used to export presets to a string which can be uploaded to text sharing websites like pastebin
---@param frame frame
function MethodDungeonTools:MakeExportFrame(frame)
	frame.ExportFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.ExportFrame:SetTitle("Preset Export")
	frame.ExportFrame:SetWidth(600)
	frame.ExportFrame:SetHeight(400)
	frame.ExportFrame:EnableResize(false)
	frame.ExportFrame:SetLayout("Flow")
	frame.ExportFrame:SetCallback("OnClose", function(widget) end)

	frame.ExportFrameEditbox = MethodDungeonTools:AceGUI_Create("MultiLineEditBox")
	frame.ExportFrameEditbox:SetLabel("Preset Export:")
	frame.ExportFrameEditbox:SetWidth(600)
	frame.ExportFrameEditbox:DisableButton(true)
	frame.ExportFrameEditbox:SetNumLines(20)
	frame.ExportFrameEditbox:SetCallback("OnEnterPressed", function(widget, event, text) end)
	frame.ExportFrame:AddChild(frame.ExportFrameEditbox)
	--frame.presetCreationFrame:SetStatusText("AceGUI-3.0 Example Container Frame")
	frame.ExportFrame:Hide()
end

---MakeDeleteConfirmationFrame
---Creates the delete confirmation dialog that pops up when a user wants to delete a preset
function MethodDungeonTools:MakeDeleteConfirmationFrame(frame)
	frame.DeleteConfirmationFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.DeleteConfirmationFrame:SetTitle("Delete Preset")
	frame.DeleteConfirmationFrame:SetWidth(250)
	frame.DeleteConfirmationFrame:SetHeight(120)
	frame.DeleteConfirmationFrame:EnableResize(false)
	frame.DeleteConfirmationFrame:SetLayout("Flow")
	frame.DeleteConfirmationFrame:SetCallback("OnClose", function(widget) end)

	frame.DeleteConfirmationFrame.label = MethodDungeonTools:AceGUI_Create("Label")
	frame.DeleteConfirmationFrame.label:SetWidth(390)
	frame.DeleteConfirmationFrame.label:SetHeight(10)
	--frame.DeleteConfirmationFrame.label:SetColor(1,0,0)
	frame.DeleteConfirmationFrame:AddChild(frame.DeleteConfirmationFrame.label)

	frame.DeleteConfirmationFrame.OkayButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.DeleteConfirmationFrame.OkayButton:SetText("Delete")
	frame.DeleteConfirmationFrame.OkayButton:SetWidth(100)
	frame.DeleteConfirmationFrame.OkayButton:SetCallback("OnClick", function()
		MethodDungeonTools:DeletePreset(db.currentPreset[db.currentDungeonIdx])
		frame.DeleteConfirmationFrame:Hide()
	end)
	frame.DeleteConfirmationFrame.CancelButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.DeleteConfirmationFrame.CancelButton:SetText("Cancel")
	frame.DeleteConfirmationFrame.CancelButton:SetWidth(100)
	frame.DeleteConfirmationFrame.CancelButton:SetCallback("OnClick", function()
		frame.DeleteConfirmationFrame:Hide()
	end)

	frame.DeleteConfirmationFrame:AddChild(frame.DeleteConfirmationFrame.OkayButton)
	frame.DeleteConfirmationFrame:AddChild(frame.DeleteConfirmationFrame.CancelButton)
	frame.DeleteConfirmationFrame:Hide()
end

---MakeClearConfirmationFrame
---Creates the clear confirmation dialog that pops up when a user wants to clear a preset
function MethodDungeonTools:MakeClearConfirmationFrame(frame)
	frame.ClearConfirmationFrame = MethodDungeonTools:AceGUI_Create("Frame")
	frame.ClearConfirmationFrame:SetTitle("Clear Preset")
	frame.ClearConfirmationFrame:SetWidth(250)
	frame.ClearConfirmationFrame:SetHeight(120)
	frame.ClearConfirmationFrame:EnableResize(false)
	frame.ClearConfirmationFrame:SetLayout("Flow")
	frame.ClearConfirmationFrame:SetCallback("OnClose", function(widget) end)

	frame.ClearConfirmationFrame.label = MethodDungeonTools:AceGUI_Create("Label")
	frame.ClearConfirmationFrame.label:SetWidth(390)
	frame.ClearConfirmationFrame.label:SetHeight(10)
	--frame.DeleteConfirmationFrame.label:SetColor(1,0,0)
	frame.ClearConfirmationFrame:AddChild(frame.ClearConfirmationFrame.label)

	frame.ClearConfirmationFrame.OkayButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.ClearConfirmationFrame.OkayButton:SetText("Clear")
	frame.ClearConfirmationFrame.OkayButton:SetWidth(100)
	frame.ClearConfirmationFrame.OkayButton:SetCallback("OnClick", function()
		MethodDungeonTools:ClearPreset(db.currentPreset[db.currentDungeonIdx])
		frame.ClearConfirmationFrame:Hide()
	end)
	frame.ClearConfirmationFrame.CancelButton = MethodDungeonTools:AceGUI_Create("Button")
	frame.ClearConfirmationFrame.CancelButton:SetText("Cancel")
	frame.ClearConfirmationFrame.CancelButton:SetWidth(100)
	frame.ClearConfirmationFrame.CancelButton:SetCallback("OnClick", function()
		frame.ClearConfirmationFrame:Hide()
	end)

	frame.ClearConfirmationFrame:AddChild(frame.ClearConfirmationFrame.OkayButton)
	frame.ClearConfirmationFrame:AddChild(frame.ClearConfirmationFrame.CancelButton)
	frame.ClearConfirmationFrame:Hide()
end

---CreateTutorialButton
---Creates the tutorial button and sets up the help plate frames
-- function MethodDungeonTools:CreateTutorialButton(parent)
-- 	local button = CreateFrame("Button", parent, parent, "MainHelpPlateButton")
-- 	button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 48)
-- 	button:SetScale(0.8)
-- 	button:SetFrameStrata(mainFrameStrata)
-- 	button:SetFrameLevel(6)
-- 	button:Hide()

-- 	--dirty hook to make button hide
-- 	local originalHide = parent.Hide
-- 	function parent:Hide(...)
-- 		button:Hide()
-- 		return originalHide(self, ...)
-- 	end

-- 	local helpPlate = {
-- 		FramePos = { x = 0, y = 0 },
-- 		FrameSize = { width = sizex, height = sizey },
-- 		[1] = {
-- 			ButtonPos = { x = 190, y = 0 },
-- 			HighLightBox = { x = 0, y = 0, width = 197, height = 56 },
-- 			ToolTipDir = "RIGHT",
-- 			ToolTipText = "Select a dungeon",
-- 		},
-- 		[2] = {
-- 			ButtonPos = { x = 190, y = -210 },
-- 			HighLightBox = { x = 0, y = -58, width = sizex - 6, height = sizey - 58 },
-- 			ToolTipDir = "RIGHT",
-- 			ToolTipText = "Select enemies for your pulls\nCTRL+Click to single select enemies",
-- 		},
-- 		[3] = {
-- 			ButtonPos = { x = 828, y = 0 },
-- 			HighLightBox = { x = 838, y = 30, width = 251, height = 87 },
-- 			ToolTipDir = "LEFT",
-- 			ToolTipText = "Manage presets",
-- 		},
-- 		[4] = {
-- 			ButtonPos = { x = 828, y = -87 },
-- 			HighLightBox = { x = 838, y = 30 - 87, width = 251, height = 83 },
-- 			ToolTipDir = "LEFT",
-- 			ToolTipText = "Customize dungeon Options",
-- 		},
-- 		[5] = {
-- 			ButtonPos = { x = 828, y = -(87 + 83) },
-- 			HighLightBox = { x = 838, y = 30 - (87 + 83), width = 251, height = 415 },
-- 			ToolTipDir = "LEFT",
-- 			ToolTipText = "Create and manage your pulls\nRight click for more options",
-- 		},
-- 	}

-- 	local function TutorialButtonOnClick(self)
-- 		if not HelpPlate_IsShowing(helpPlate) then
-- 			HelpPlate_Show(helpPlate, MethodDungeonTools.main_frame, self)
-- 		else
-- 			HelpPlate_Hide(true)
-- 		end
-- 	end

-- 	local function TutorialButtonOnHide(self)
-- 		HelpPlate_Hide(true)
-- 	end

-- 	parent.HelpButton = button

-- 	button:SetScript("OnClick", TutorialButtonOnClick)
-- 	button:SetScript("OnHide", TutorialButtonOnHide)
-- end

---RegisterOptions
---Register the options of the addon to the blizzard options
function MethodDungeonTools:RegisterOptions()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(
		"MethodDungeonTools",
		MethodDungeonTools.blizzardOptionsMenuTable
	)
	self.blizzardOptionsMenu =
		LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MethodDungeonTools", "MethodDungeonTools")
end

function initFrames()
	local main_frame = CreateFrame("frame", "MethodDungeonToolsFrame", UIParent)

	main_frame:SetFrameStrata(mainFrameStrata)
	main_frame:SetFrameLevel(1)
	main_frame.background = main_frame:CreateTexture(nil, "BACKGROUND")
	main_frame.background:SetAllPoints()
	main_frame.background:SetDrawLayer("ARTWORK", 1)
	MethodDungeonTools:SetColorTexture(main_frame.background, 0, 0, 0, 0.5)
	main_frame.background:SetAlpha(0.2)
	main_frame:SetSize(sizex, sizey)
	MethodDungeonTools.main_frame = main_frame

	tinsert(UISpecialFrames, "MethodDungeonToolsFrame")
	-- Set frame position
	main_frame:ClearAllPoints()
	main_frame:SetPoint(db.anchorTo, UIParent, db.anchorFrom, db.xoffset, db.yoffset)

	--TODO: fix all these
	main_frame:SetScript("OnEvent", function(self, ...)
		local event, loaded = ...
		if event == "ADDON_LOADED" then
			if addon == loaded then
				--AltManager:OnLoad();
			end
		end
		if event == "PLAYER_LOGIN" then
			--AltManager:OnLogin();
		end
		if event == "PLAYER_LOGOUT" or event == "ARTIFACT_XP_UPDATE" then
			--local data = AltManager:CollectData();
			--AltManager:StoreData(data);
		end
	end)

	main_frame.contextDropdown =
		CreateFrame("Frame", "MethodDungeonToolsContextDropDown", nil, "L_UIDropDownMenuTemplate")

	MethodDungeonTools:CreateMenu()
	MethodDungeonTools:MakeTopBottomTextures(main_frame)
	MethodDungeonTools:MakeMapTexture(main_frame)
	MethodDungeonTools:MakeSidePanel(main_frame)
	MethodDungeonTools:MakePresetCreationFrame(main_frame)
	MethodDungeonTools:MakePresetImportFrame(main_frame)

	MethodDungeonTools:MakeDungeonBossButtons(main_frame)
	MethodDungeonTools:UpdateDungeonEnemies(main_frame)

	MethodDungeonTools:CreateDungeonSelectDropdown(main_frame)
	MethodDungeonTools:CreateDungeonPresetDropdown(main_frame.sidePanel)

	MethodDungeonTools:MakePullSelectionButtons(main_frame.sidePanel)

	MethodDungeonTools:MakeExportFrame(main_frame)
	MethodDungeonTools:MakeRenameFrame(main_frame)
	MethodDungeonTools:MakeDeleteConfirmationFrame(main_frame)
	MethodDungeonTools:MakeClearConfirmationFrame(main_frame)

	-- MethodDungeonTools:CreateTutorialButton(main_frame)

	--tooltip
	do
		tooltip = CreateFrame("Frame", "MethodDungeonToolsModelTooltip", UIParent)
		tooltip:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		tooltip:SetClampedToScreen(true)
		tooltip:SetFrameStrata("TOOLTIP")
		tooltip.mySizes = { x = 250, y = 110 }
		tooltip:SetSize(tooltip.mySizes.x, tooltip.mySizes.y)
		tooltip:Hide()

		tooltip.Model = CreateFrame("PlayerModel", nil, tooltip)
		tooltip.Model:SetFrameLevel(5)
		tooltip.Model:SetSize(100, 100)

		tooltip.Model.fac = 0
		if true then
			tooltip.Model:SetScript("OnUpdate", function(self, elapsed)
				self.fac = self.fac + 0.5
				if self.fac >= 360 then
					self.fac = 0
				end
				self:SetFacing(math.pi * 2 / 360 * self.fac)
				--print(tooltip.Model:GetModelFileID())
			end)
		else
			tooltip.Model:SetFacing(math.pi * 2 / 360 * 2)
		end

		tooltip.Model:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 7, -7)

		tooltip.String = tooltip:CreateFontString("MethodDungeonToolsToolTipString")
		tooltip.String:SetFont("Fonts\\FRIZQT__.TTF", 10)
		tooltip.String:SetTextColor(1, 1, 1, 1)
		tooltip.String:SetJustifyH("LEFT")
		tooltip.String:SetJustifyV("CENTER")
		tooltip.String:SetWidth(tooltip:GetWidth())
		tooltip.String:SetHeight(125)
		tooltip.String:SetWidth(120)
		tooltip.String:SetText(" ")
		tooltip.String:SetPoint("LEFT", tooltip, "LEFT", 110, 0)
		tooltip.String:Show()
	end

	-- Coordinate Display for Dev Mode
	main_frame.CoordinateDisplay =
		main_frame:CreateFontString("MethodDungeonToolsCoordinateDisplay", "OVERLAY", "GameFontNormal")
	main_frame.CoordinateDisplay:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	main_frame.CoordinateDisplay:SetTextColor(1, 1, 1, 1)
	main_frame.CoordinateDisplay:SetPoint("BOTTOMLEFT", main_frame, "BOTTOMLEFT", 10, 10)
	main_frame.CoordinateDisplay:Hide()

	main_frame.GridToggle = CreateFrame("Button", "MethodDungeonToolsGridToggle", main_frame, "UIPanelButtonTemplate")
	main_frame.GridToggle:SetPoint("BOTTOMLEFT", main_frame.CoordinateDisplay, "TOPLEFT", 0, 5)
	main_frame.GridToggle:SetSize(80, 26)
	main_frame.GridToggle:SetFrameLevel(main_frame:GetFrameLevel() + 5)
	main_frame.GridToggle:SetText("Clear Lines")
	main_frame.GridToggle:SetScript("OnClick", function(self)
		for _, line in ipairs(MethodDungeonTools.DevDrawLines) do
			line:Hide()
		end
		table.wipe(MethodDungeonTools.DevDrawLines)
	end)
	main_frame.GridToggle:Hide()

	MethodDungeonTools.DevDrawLines = {}

	--pullTooltip
	do
		MethodDungeonTools.pullTooltip = CreateFrame("Frame", "MethodDungeonToolsPullTooltip", UIParent)
		MethodDungeonTools.pullTooltip:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
		MethodDungeonTools.pullTooltip:SetClampedToScreen(true)
		MethodDungeonTools.pullTooltip:SetFrameStrata("TOOLTIP")
		MethodDungeonTools.pullTooltip.myHeight = 120
		MethodDungeonTools.pullTooltip:SetSize(250, MethodDungeonTools.pullTooltip.myHeight)
		MethodDungeonTools.pullTooltip:Hide()

		-- 3D модель слева
		MethodDungeonTools.pullTooltip.Model = CreateFrame("PlayerModel", nil, MethodDungeonTools.pullTooltip)
		MethodDungeonTools.pullTooltip.Model:SetFrameLevel(5)
		MethodDungeonTools.pullTooltip.Model:SetSize(90, 90)
		MethodDungeonTools.pullTooltip.Model:SetPoint("TOPLEFT", MethodDungeonTools.pullTooltip, "TOPLEFT", 10, -15)
		MethodDungeonTools.pullTooltip.Model.fac = 0
		MethodDungeonTools.pullTooltip.Model:SetScript("OnUpdate", function(self, elapsed)
			self.fac = self.fac + 0.5
			if self.fac >= 360 then
				self.fac = 0
			end
			self:SetFacing(math.pi * 2 / 360 * self.fac)
		end)

		-- Текст справа от модели
		MethodDungeonTools.pullTooltip.topString = MethodDungeonTools.pullTooltip:CreateFontString(nil, "OVERLAY")
		MethodDungeonTools.pullTooltip.topString:SetFont("Fonts\\FRIZQT__.TTF", 10)
		MethodDungeonTools.pullTooltip.topString:SetTextColor(1, 1, 1, 1)
		MethodDungeonTools.pullTooltip.topString:SetJustifyH("LEFT")
		MethodDungeonTools.pullTooltip.topString:SetJustifyV("CENTER")
		MethodDungeonTools.pullTooltip.topString:SetHeight(100)
		MethodDungeonTools.pullTooltip.topString:SetWidth(130)
		MethodDungeonTools.pullTooltip.topString:SetPoint("LEFT", MethodDungeonTools.pullTooltip, "LEFT", 112, 0)
		MethodDungeonTools.pullTooltip.topString:Hide()

		-- botString — строка с суммарным % пула внизу
		MethodDungeonTools.pullTooltip.botString = MethodDungeonTools.pullTooltip:CreateFontString(nil, "OVERLAY")
		local botString = MethodDungeonTools.pullTooltip.botString
		botString:SetFont("Fonts\\FRIZQT__.TTF", 10)
		botString:SetTextColor(1, 0.82, 0, 1)
		botString:SetJustifyH("CENTER")
		botString:SetJustifyV("BOTTOM")
		botString:SetHeight(20)
		botString:SetWidth(250)
		botString.defaultText = "Получаемые %%: %d  |  Всего: %d/%d"
		botString:SetPoint("BOTTOM", MethodDungeonTools.pullTooltip, "BOTTOM", 0, 14)
		botString:Hide()
	end

	--Blizzard Options
	MethodDungeonTools.blizzardOptionsMenuTable = {
		name = "Method Dungeon Tools",
		type = "group",
		args = {
			enable = {
				type = "toggle",
				name = "Enable Minimap Button",
				desc = "If the Minimap Button is enabled.",
				get = function()
					return not db.minimap.hide
				end,
				set = function(_, newValue)
					db.minimap.hide = not newValue
					if not db.minimap.hide then
						icon:Show("MethodDungeonTools")
					else
						icon:Hide("MethodDungeonTools")
					end
				end,
				order = 1,
				width = "full",
			},
			tooltipSelect = {
				type = "select",
				name = "Chose npc tooltip position",
				desc = "Where the tooltip should be positioned",
				values = {
					[1] = "Next to the npc",
					[2] = "In the bottom right corner",
				},
				get = function()
					return db.tooltipInCorner and 2 or 1
				end,
				set = function(_, newValue)
					if newValue == 1 then
						db.tooltipInCorner = false
					end
					if newValue == 2 then
						db.tooltipInCorner = true
					end
				end,
				style = "radio",
			},
		},
	}
end

-- Add MDT Forces to GameTooltip
local mdtTooltipDebug = true

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	local _, unit = self:GetUnit()
	if not unit then
		return
	end

	local guid = UnitGUID(unit)
	if not guid then
		return
	end

	local id
	if guid:find("-") then
		id = tonumber(select(6, strsplit("-", guid)))
	else
		id = tonumber(guid:sub(-12, -9), 16)
	end

	-- if mdtTooltipDebug then
	-- 	print("MDT Навели мышку: " .. unit .. " GUID: " .. guid .. " ID: " .. tostring(id))
	-- end

	if id and MethodDungeonTools and MethodDungeonTools.dungeonEnemies then
		for dIdx, dEnemies in pairs(MethodDungeonTools.dungeonEnemies) do
			if dEnemies[id] then
				local enemyData = dEnemies[id]
				local countData = MethodDungeonTools.dungeonTotalCount[dIdx]
				if countData and enemyData.count and enemyData.count > 0 then
					local teeming = false
					if
						db
						and db.presets
						and db.presets[dIdx]
						and db.currentPreset
						and db.currentPreset[dIdx]
						and db.presets[dIdx][db.currentPreset[dIdx]]
					then
						teeming = db.presets[dIdx][db.currentPreset[dIdx]].value.teeming
					end

					local total = teeming and countData.teeming or countData.normal
					if total and total > 0 then
						local percent = (enemyData.count / total) * 100
						self:AddLine(string.format("MDT: %.2f%%", percent), 0, 1, 0)
						self:Show()
					end
				end
				break
			end
		end
	end
end)

-- MDT Automated Tracker for Sirus
local mdtTrackerFrame = CreateFrame("Frame")
local mdtIsTracking = false
local mdtLastForces = 0
local mdtRecentlyDead = {}
local mdtUpdateTimer = 0

-- Cache of recently targeted units: guid -> {id, name}
local mdtTargetCache = {}

mdtTrackerFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
mdtTrackerFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

-- Helper: extract NPC ID from a GUID string
local function GUIDtoNPCID(guid)
	if not guid then
		return 0
	end
	-- Modern TrinityCore format: "Creature-0-MapID-InstanceID-Diff-NpcID-UID"
	if guid:find("-") then
		local parts = { strsplit("-", guid) }
		if #parts >= 6 then
			return tonumber(parts[6]) or 0
		end
		return 0
	end
	-- Old Wrath hex GUID: 0xF130XXXXXXNNNNXXXX
	-- Type is high nibbles, entry is in mid bytes
	-- Parse as 64-bit hex: entry = (hex >> 24) & 0xFFFFF isn't doable without BitLib
	-- Try sub-string extraction (bytes 5-8 of the hex part)
	local hex = guid:match("^0?[xX]?(%x+)$")
	if hex and #hex >= 12 then
		-- NPC ID is typically in characters 5-10 of the 16-char hex
		local candidate = tonumber(hex:sub(5, 10), 16) or 0
		if candidate > 0 and candidate < 1000000 then
			return candidate
		end
		-- fallback: last 4 bytes upper half
		return tonumber(hex:sub(-12, -9), 16) or 0
	end
	return 0
end

local function CacheUnit(unitid)
	if not UnitExists(unitid) then
		return
	end
	if UnitIsPlayer(unitid) then
		return
	end
	local guid = UnitGUID(unitid)
	if not guid then
		return
	end
	local name = UnitName(unitid) or "Unknown"
	local id = GUIDtoNPCID(guid)
	mdtTargetCache[guid] = { id = id, name = name }
end

-- Listen for UNIT_DIED in COMBAT_LOG
mdtTrackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mdtTrackerFrame:SetScript("OnEvent", function(self, event, ...)
	if not mdtIsTracking then
		return
	end
	-- Standard WoW 3.3.5: the FIRST arg is timestamp, second IS the subevent
	-- But Sirus may pass subevent as arg[1] directly in some builds
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)

	local subevent, destGUID, destName

	if arg1 == "UNIT_DIED" then
		-- Sirus sometimes drops timestamp
		subevent = "UNIT_DIED"
		destGUID = select(5, ...) -- (subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName)
		destName = select(6, ...)
	elseif arg2 == "UNIT_DIED" then
		-- Standard layout: (timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, ...)
		subevent = "UNIT_DIED"
		destGUID = select(6, ...)
		destName = select(7, ...)
	end

	if subevent == "UNIT_DIED" and destGUID then
		local id = GUIDtoNPCID(destGUID)
		-- Also try our target cache for better ID match
		if mdtTargetCache[destGUID] then
			if id == 0 then
				id = mdtTargetCache[destGUID].id
			end
			if not destName or destName == "Unknown" then
				destName = mdtTargetCache[destGUID].name
			end
		end
		-- Debug print - remove after identifying GUID format
		-- print(
		-- 	"|cFFFFFF00[MDT Debug]|r DIED guid=" .. tostring(destGUID) .. " name=" .. tostring(destName) .. " id=" .. id
		-- )
		-- Record all non-player deaths (creatures, pets, etc.)
		if destGUID and not destGUID:find("Player") then
			table.insert(mdtRecentlyDead, { id = id, name = destName or "Unknown", time = GetTime() })
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		CacheUnit("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		CacheUnit("mouseover")
	end
end)

mdtTrackerFrame:SetScript("OnUpdate", function(self, elapsed)
	if not mdtIsTracking then
		return
	end
	mdtUpdateTimer = mdtUpdateTimer + elapsed
	if mdtUpdateTimer < 0.5 then
		return
	end
	mdtUpdateTimer = 0

	-- Try to read forces from Sirus C_GlobalStorage
	local p = mdtLastForces
	local ok, cData = pcall(function()
		return C_GlobalStorage
			and C_GlobalStorage.GetVar
			and C_GlobalStorage.GetVar("ASMSG_CHALLENGE_MODE_CREATURE_KILLED")
	end)
	if ok and cData and cData.total then
		p = math.min(cData.total, 100)
	end

	if p > mdtLastForces then
		local diff = p - mdtLastForces
		mdtLastForces = p

		if not db.MobDataTally then
			db.MobDataTally = {}
		end

		local now = GetTime()
		local matched = {}
		for i = #mdtRecentlyDead, 1, -1 do
			if (now - mdtRecentlyDead[i].time) <= 5 then
				table.insert(matched, mdtRecentlyDead[i])
			end
		end

		local count = #matched
		if count > 0 then
			local perMob = math.floor((diff / count) * 100) / 100
			local msg = ""
			for _, mob in ipairs(matched) do
				msg = msg .. mob.name .. " (" .. mob.id .. ") "
				table.insert(db.MobDataTally, {
					name = mob.name,
					id = mob.id,
					percent = perMob,
					totalPercent = p,
					date = date("%Y-%m-%d %H:%M:%S"),
				})
			end
			print(
				"|cFF00FF00[MDT Tracker]|r "
					.. msg
					.. "=> "
					.. string.format("%.2f", diff)
					.. "% (по "
					.. string.format("%.2f", perMob)
					.. "% каждый)"
			)
		else
			-- Forces changed but nobody died in our list - record as unknown
			table.insert(db.MobDataTally, {
				name = "Unknown Target",
				id = 0,
				percent = diff,
				totalPercent = p,
				date = date("%Y-%m-%d %H:%M:%S"),
			})
			print(
				"|cFFFF8800[MDT Tracker]|r Неизвестная цель дала "
					.. string.format("%.2f", diff)
					.. "%"
			)
		end
		mdtRecentlyDead = {}
	end
end)

-- Command: /mdttrack
SLASH_MDTTRACK1 = "/mdttrack"
SlashCmdList["MDTTRACK"] = function(msg)
	mdtIsTracking = not mdtIsTracking
	if mdtIsTracking then
		local ok, cData = pcall(function()
			return C_GlobalStorage
				and C_GlobalStorage.GetVar
				and C_GlobalStorage.GetVar("ASMSG_CHALLENGE_MODE_CREATURE_KILLED")
		end)
		mdtLastForces = (ok and cData and cData.total) and math.min(cData.total, 100) or 0
		mdtRecentlyDead = {}
		print("|cFF00FF00[MDT Tracker]|r Авто-запись ВКЛЮЧЕНА. Текущий % = " .. mdtLastForces)
		print(
			"|cFF00FF00[MDT Tracker]|r Убивай мобов — результаты появятся в чате и сохранятся в SavedVariables."
		)
	else
		mdtRecentlyDead = {}
		local savedCount = db.MobDataTally and #db.MobDataTally or 0
		print(
			"|cFF00FF00[MDT Tracker]|r Авто-запись ВЫКЛЮЧЕНА. Итого записей: "
				.. savedCount
				.. ". Данные в MethodDungeonTools.lua (SavedVariables)."
		)
	end
end

-- Command: /mdtdump  — вывести последние 20 записей в чат
SLASH_MDTDUMP1 = "/mdtdump"
SlashCmdList["MDTDUMP"] = function()
	local tally = db and db.MobDataTally
	if not tally or #tally == 0 then
		print("|cFFFF0000[MDT Tracker]|r Нет сохранённых данных.")
		return
	end
	local start = math.max(1, #tally - 19)
	print(
		"|cFF00FF00[MDT Tracker]|r Последние записи ("
			.. start
			.. "-"
			.. #tally
			.. " из "
			.. #tally
			.. "):"
	)
	for i = start, #tally do
		local e = tally[i]
		print(string.format("  #%d %s [%d] => %.2f%%  (total %.2f%%)", i, e.name, e.id, e.percent, e.totalPercent))
	end
end

-- Command: /mdtclear — очистить все записи
SLASH_MDTCLEAR1 = "/mdtclear"
SlashCmdList["MDTCLEAR"] = function()
	if db then
		db.MobDataTally = {}
	end
	print("|cFF00FF00[MDT Tracker]|r Все записи очищены.")
end

function MethodDungeonTools:ShowEnemyInfoFrame(blipIndex, bossIndex)
	if not self.EnemyInfoFrame then
		-- ... existing frame creation code (I'll need to check the actual current content of the file at the end to see if it was reverted too)
		local f = CreateFrame("Frame", "MDTEnemyInfoFrame", self.main_frame)
		f:SetSize(600, 450)
		f:SetPoint("CENTER", UIParent, "CENTER")
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f:SetScript("OnEnter", function() end) -- Block tooltips from showing
		f:SetScript("OnLeave", function() end)

		-- Background
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})

		-- Title
		f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		f.title:SetPoint("TOP", 0, -15)

		-- Close Button
		f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		f.closeBtn:SetPoint("TOPRIGHT", -5, -5)

		-- Backgrounds for columns
		local leftBg = f:CreateTexture(nil, "BACKGROUND")
		self:SetColorTexture(leftBg, 0.05, 0.05, 0.05, 0.8)
		leftBg:SetPoint("TOPLEFT", 15, -45)
		leftBg:SetSize(200, 390)

		local midBg = f:CreateTexture(nil, "BACKGROUND")
		self:SetColorTexture(midBg, 0.1, 0.1, 0.1, 0.5)
		midBg:SetPoint("TOPLEFT", 225, -45)
		midBg:SetSize(180, 390)

		local rightBg = f:CreateTexture(nil, "BACKGROUND")
		self:SetColorTexture(rightBg, 0.1, 0.1, 0.1, 0.5)
		rightBg:SetPoint("TOPLEFT", 415, -45)
		rightBg:SetSize(170, 390)

		-- Left Panel: Model
		f.model = CreateFrame("PlayerModel", nil, f)
		f.model:SetSize(190, 380)
		f.model:SetPoint("TOPLEFT", 20, -50)

		-- Middle Panel: Info
		local function createLabel(text, parent, yOffset)
			local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			lbl:SetText(text)
			lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 235, yOffset)
			local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			val:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -5)
			val:SetWidth(160)
			val:SetJustifyH("LEFT")
			return val
		end

		local function createCopyableLabel(text, parent, yOffset)
			local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			lbl:SetText(text)
			lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 235, yOffset)
			local val = CreateFrame("EditBox", nil, parent)
			val:SetFontObject("GameFontHighlight")
			val:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -4, -5) -- -4 offset because EditBox padding is weird
			val:SetSize(160, 15)
			val:SetAutoFocus(false)
			val:SetScript("OnEscapePressed", val.ClearFocus)
			val:SetScript("OnEditFocusGained", val.HighlightText)
			return val
		end

		f.infoName = createLabel("Имя", f, -50)
		f.infoId = createCopyableLabel("NPC Id", f, -90)
		f.infoHealth = createLabel("Здоровье", f, -130)
		f.infoType = createLabel("Тип", f, -170)
		f.infoLevel = createLabel("Lvl", f, -210)
		f.infoForces = createLabel("Количество %", f, -250)

		-- Right Panel: Spells
		f.spellsTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		f.spellsTitle:SetText("Spells")
		f.spellsTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 425, -50)

		f.noSpellsText = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
		f.noSpellsText:SetPoint("TOPLEFT", f.spellsTitle, "BOTTOMLEFT", 0, -10)
		f.noSpellsText:SetText("No spells recorded yet.")

		self.EnemyInfoFrame = f
	end

	local f = self.EnemyInfoFrame
	local data
	if bossIndex then
		local sublevel = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]].value.currentSublevel
		data = MethodDungeonTools.dungeonBosses[db.currentDungeonIdx][sublevel][bossIndex]
	else
		local enemyData = MethodDungeonTools.dungeonEnemies[db.currentDungeonIdx]
		local blip = dungeonEnemyBlips[blipIndex]
		local enemyIdx = blip and blip.enemyIdx
		data = enemyIdx and enemyData and enemyData[enemyIdx]
	end

	if data then
		f.title:SetText(data.name or "Unknown")

		-- Model
		if data.displayId then
			self:SetDisplayInfo(f.model, data.displayId, true)
		else
			self:SetDisplayInfo(f.model, data.id, true)
		end

		-- Stats
		f.infoName:SetText(data.name or "Unknown")
		f.infoId:SetText(tostring(data.id))
		f.infoId:SetCursorPosition(0)

		local hp = data.health or 0
		if hp > 1000000 then
			f.infoHealth:SetText(string.format("%.2fm", hp / 1000000))
		elseif hp > 1000 then
			f.infoHealth:SetText(string.format("%.1fk", hp / 1000))
		else
			f.infoHealth:SetText(tostring(hp))
		end

		f.infoType:SetText(data.creatureType or "Unknown")
		f.infoLevel:SetText(tostring(data.level or "??"))

		local forces = data.count or 0
		local total = 100
		local cd = MethodDungeonTools.dungeonTotalCount[db.currentDungeonIdx]
		if cd then
			local tmg = false
			if db.presets and db.presets[db.currentDungeonIdx] then
				local p = db.presets[db.currentDungeonIdx][db.currentPreset[db.currentDungeonIdx]]
				if p and p.value then
					tmg = p.value.teeming
				end
			end
			total = tmg and cd.teeming or cd.normal
		end

		local pct = 0
		if total and total > 0 then
			pct = (forces / total) * 100
		end
		f.infoForces:SetText(string.format("%.2f%%", pct))

		f.spellFrames = f.spellFrames or {}
		for _, sf in ipairs(f.spellFrames) do
			sf:Hide()
		end

		-- Spells
		if data.spells and #data.spells > 0 then
			f.noSpellsText:Hide()
			local yOffset = -10
			for i, spellId in ipairs(data.spells) do
				local sName, _, sIcon = GetSpellInfo(spellId)
				if sName then
					local sf = f.spellFrames[i]
					if not sf then
						sf = CreateFrame("Frame", nil, f)
						sf:SetSize(160, 30)
						sf:EnableMouse(true)

						local icon = sf:CreateTexture(nil, "ARTWORK")
						icon:SetSize(24, 24)
						icon:SetPoint("LEFT", sf, "LEFT", 0, 0)
						sf.icon = icon

						local nameLbl = sf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
						nameLbl:SetPoint("LEFT", icon, "RIGHT", 5, 0)
						nameLbl:SetWidth(125)
						nameLbl:SetJustifyH("LEFT")
						nameLbl:SetWordWrap(false)
						sf.nameLbl = nameLbl

						sf:SetScript("OnEnter", function(self)
							GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
							GameTooltip:SetHyperlink("spell:" .. self.spellId)
							GameTooltip:Show()
						end)
						sf:SetScript("OnLeave", function(self)
							GameTooltip:Hide()
						end)

						f.spellFrames[i] = sf
					end

					sf.spellId = spellId
					sf.icon:SetTexture(sIcon)
					sf.nameLbl:SetText(sName)
					sf:SetPoint("TOPLEFT", f.spellsTitle, "BOTTOMLEFT", 0, yOffset)
					sf:Show()

					yOffset = yOffset - 35
				end
			end
			-- if all spells were invalid, show text
			if yOffset == -10 then
				f.noSpellsText:Show()
			end
		else
			f.noSpellsText:Show()
		end

		f:Show()
	end
end
