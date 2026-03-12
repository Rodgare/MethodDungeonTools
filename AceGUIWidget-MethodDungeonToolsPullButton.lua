local Type, Version = "MethodDungeonToolsPullButton", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

local width, height = 248, 32
local maxPortraitCount = 7
local tinsert, SetPortraitToTexture, SetPortraitTexture, GetItemQualityColor, MouseIsOver =
	table.insert, SetPortraitToTexture, SetPortraitTexture, GetItemQualityColor, MouseIsOver

--Methods
local methods = {
	["OnAcquire"] = function(self)
		self:SetWidth(width)
		self:SetHeight(height)
	end,
	["Initialize"] = function(self)
		self.callbacks = {}

		function self.callbacks.OnClickNormal(_, mouseButton)
			if not MethodDungeonTools:MouseIsOver(MethodDungeonTools.main_frame.sidePanel.pullButtonsScrollFrame.frame) then
				return
			end
			if IsControlKeyDown() then
			elseif IsShiftKeyDown() then
			else
				MethodDungeonTools:EnsureDBTables()
				if mouseButton == "RightButton" then
					MethodDungeonTools:SetMapSublevel(self.index)
					MethodDungeonTools:SetSelectionToPull(self.index)
					L_EasyMenu(
						self.menu,
						MethodDungeonTools.main_frame.sidePanel.optionsDropDown,
						"cursor",
						0,
						-15,
						"MENU"
					)
				else
					--normal click
					MethodDungeonTools:SetMapSublevel(self.index)
					MethodDungeonTools:SetSelectionToPull(self.index)
				end
			end
		end

		function self.callbacks.OnEnter()
			--ViragDevTool_AddData(self,"pullButton"..self.index)
			MethodDungeonTools.pullTooltip:SetPoint("TOPRIGHT", self.frame, "TOPLEFT", 0, 4)
			MethodDungeonTools.pullTooltip:SetPoint(
				"BOTTOMRIGHT",
				self.frame,
				"TOPLEFT",
				-250,
				-(4 + MethodDungeonTools.pullTooltip.myHeight)
			)
			local tooltipBottom = MethodDungeonTools.pullTooltip:GetBottom()
			local mainFrameBottom = MethodDungeonTools.main_frame:GetBottom()
			if tooltipBottom < mainFrameBottom then
				MethodDungeonTools.pullTooltip:SetPoint(
					"TOPRIGHT",
					self.frame,
					"BOTTOMLEFT",
					0,
					(4 + MethodDungeonTools.pullTooltip.myHeight)
				)
				MethodDungeonTools.pullTooltip:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMLEFT", -250, -4)
			end
			MethodDungeonTools:ActivatePullTooltip(self.index)
		end

		function self.callbacks.OnLeave()
			--model
			MethodDungeonTools.pullTooltip.Model:Hide()
			--topString
			MethodDungeonTools.pullTooltip.topString:Hide()
		end

		function self.callbacks.OnDragStart()
			--
		end

		function self.callbacks.OnDragStop()
			--
		end

		function self.callbacks.OnKeyDown(self, key)
			if key == "ESCAPE" then
				--
			end
		end

		self.menu = {}
		if self.index ~= 1 then
			tinsert(self.menu, {
				text = "Move up",
				notCheckable = 1,
				func = function()
					MethodDungeonTools:MovePullUp(self.index)
				end,
			})
		end
		if self.index < self.maxPulls then
			tinsert(self.menu, {
				text = "Move down",
				notCheckable = 1,
				func = function()
					MethodDungeonTools:MovePullDown(self.index)
				end,
			})
		end
		tinsert(self.menu, {
			text = "Clear",
			notCheckable = 1,
			func = function()
				MethodDungeonTools:ClearPull(self.index)
			end,
		})
		tinsert(self.menu, {
			text = " ",
			notClickable = 1,
			notCheckable = 1,
			func = nil,
		})
		if self.maxPulls > 1 then
			tinsert(self.menu, {
				text = "Delete",
				notCheckable = 1,
				func = function()
					MethodDungeonTools:DeletePull(self.index)
				end,
			})
		end
		tinsert(self.menu, {
			text = " ",
			notClickable = 1,
			notCheckable = 1,
			func = nil,
		})
		tinsert(self.menu, {
			text = "Close",
			notCheckable = 1,
			func = function()
				MethodDungeonTools.main_frame.sidePanel.optionsDropDown:Hide()
			end,
		})

		--Set pullNumber
		self.pullNumber:SetText(self.index)
		self.pullNumber:Show()

		self.frame:SetScript("OnClick", self.callbacks.OnClickNormal)
		self.frame:SetScript("OnKeyDown", self.callbacks.OnKeyDown)
		self.frame:SetScript("OnEnter", self.callbacks.OnEnter)
		self.frame:SetScript("OnLeave", self.callbacks.OnLeave)
		self.frame:EnableKeyboard(false)
		self.frame:SetMovable(true)
		self.frame:RegisterForDrag("LeftButton")
		self.frame:SetScript("OnDragStart", self.callbacks.OnDragStart)
		self.frame:SetScript("OnDragStop", self.callbacks.OnDragStop)
		self:Enable()
		--self:SetRenameAction(self.callbacks.OnRenameAction);
	end,
	["SetTitle"] = function(self, title)
		self.titletext = title
		self.title:SetText(title)
	end,
	["Disable"] = function(self)
		self.background:Hide()
		self.frame:Disable()
	end,
	["Enable"] = function(self)
		self.background:Show()
		self.frame:Enable()
	end,
	["Pick"] = function(self)
		self.frame:LockHighlight()
	end,
	["ClearPick"] = function(self)
		self.frame:UnlockHighlight()
	end,
	["SetIndex"] = function(self, index)
		self.index = index
	end,
	["SetMaxPulls"] = function(self, maxPulls)
		self.maxPulls = maxPulls
	end,
	["SetNPCData"] = function(self, enemyTable)
		local idx = 0
		--hide all textures first
		for k, v in pairs(self.enemyPortraits) do
			v:Hide()
			v.overlay:Hide()
			v.fontString:Hide()
		end

		table.sort(enemyTable, function(a, b)
			return a.count > b.count
		end)

		for npcId, data in ipairs(enemyTable) do
			idx = idx + 1
			if not self.enemyPortraits[idx] then
				break
			end
			self.enemyPortraits[idx].enemyData = data
			-- Приоритет: iconId (иконка спелла) > displayId (портрет моба) > заглушка
			local iconTexture = nil
			if data.iconId and data.iconId ~= "" and data.iconId ~= 0 then
				local _, _, icon = GetSpellInfo(data.iconId)
				iconTexture = icon
			end
			local portrait = self.enemyPortraits[idx].icon
			if iconTexture then
				portrait:SetTexture(iconTexture)
				portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			elseif data.displayId then
				SetPortraitTexture(portrait, data.displayId)
				portrait:SetTexCoord(0, 1, 0, 1)
			else
				portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			self.enemyPortraits[idx]:Show()
			self.enemyPortraits[idx].overlay:Show()
			local colorIdx = (self.index % #MethodDungeonTools.pullColors) + 1
			if colorIdx == 0 then
				colorIdx = 1
			end
			local pColor = MethodDungeonTools.pullColors[colorIdx]
			self.enemyPortraits[idx].overlay:SetVertexColor(pColor[1], pColor[2], pColor[3])
			self.enemyPortraits[idx].fontString:SetText("x" .. data.quantity)
			self.enemyPortraits[idx].fontString:Show()
		end
	end,
}

--Constructor
local function Constructor()
	local name = "MethodDungeonToolsPullButton" .. AceGUI:GetNextWidgetNum(Type)
	local button = CreateFrame("BUTTON", name, UIParent, "OptionsListButtonTemplate")
	button:SetHeight(height)
	button:SetWidth(width)
	button.dgroup = nil
	button.data = {}

	local background = button:CreateTexture(nil, "BACKGROUND")
	button.background = background
	background:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight2.blp")
	background:SetBlendMode("ADD")
	background:SetVertexColor(0.5, 0.5, 0.5, 0.25)
	background:SetPoint("TOP", button, "TOP")
	background:SetPoint("BOTTOM", button, "BOTTOM")
	background:SetPoint("LEFT", button, "LEFT")
	background:SetPoint("RIGHT", button, "RIGHT")

	local icon = button:CreateTexture(nil, "OVERLAY")
	button.icon = icon
	icon:SetWidth(height)
	icon:SetHeight(height)
	icon:SetPoint("LEFT", button, "LEFT")

	local pullNumber = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	pullNumber:SetHeight(14)
	pullNumber:SetJustifyH("CENTER")
	pullNumber:SetPoint("LEFT", button, "LEFT", 5, 0)

	local title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.title = title
	title:SetHeight(14)
	title:SetJustifyH("LEFT")
	title:SetPoint("TOP", button, "TOP", 0, -2)
	title:SetPoint("LEFT", icon, "RIGHT", 2, 0)
	title:SetPoint("RIGHT", button, "RIGHT")

	button.description = {}

	button:SetScript("OnEnter", function() end)
	button:SetScript("OnLeave", function() end)

	local renamebox = CreateFrame("EDITBOX", nil, button, "InputBoxTemplate")
	renamebox:SetHeight(height / 2)
	renamebox:SetPoint("TOP", button, "TOP")
	renamebox:SetPoint("LEFT", icon, "RIGHT", 6, 0)
	renamebox:SetPoint("RIGHT", button, "RIGHT", -4, 0)
	renamebox:SetFont("Fonts\\FRIZQT__.TTF", 10)
	renamebox:Hide()

	renamebox.func = function() --[[By default, do nothing!]]
	end
	renamebox:SetScript("OnEnterPressed", function()
		local oldid = button.title:GetText()
		local newid = renamebox:GetText()
		if
			newid == "" or (
				newid ~= oldid --[[and WeakAuras.GetData(newid)]]
			)
		then
			--if name exists
			renamebox:SetText(button.title:GetText())
		else
			renamebox.func()
			title:SetText(renamebox:GetText())
			title:Show()
			renamebox:Hide()
		end
	end)

	renamebox:SetScript("OnEscapePressed", function()
		title:Show()
		renamebox:Hide()
	end)

	--enemy portraits — Frame-контейнеры с нарастающим frameLevel (как иконки на карте)
	local enemyPortraits = {}
	local baseLevel = button:GetFrameLevel() + 2

	for i = 1, maxPortraitCount do
		-- Каждый последующий фрейм имеет более высокий level → перекрывает предыдущий
		local f = CreateFrame("Frame", nil, button)
		f:SetSize(height, height)
		f:SetFrameLevel(baseLevel + i * 2)
		f:EnableMouse(false)
		if i == 1 then
			f:SetPoint("LEFT", icon, "RIGHT", -5, 0)
		else
			f:SetPoint("LEFT", enemyPortraits[i - 1], "RIGHT", -2, 0)
		end
		f:Hide()

		-- Иконка спелла — нижний слой внутри фрейма
		f.icon = f:CreateTexture(nil, "BACKGROUND")
		f.icon:SetSize(height - 9, height - 9)
		f.icon:SetPoint("CENTER", f, "CENTER")

		-- Circle_Border — верхний слой, образует круглую рамку поверх иконки
		f.overlay = f:CreateTexture(nil, "OVERLAY")
		f.overlay:SetTexture("Interface\\Addons\\MethodDungeonTools\\Textures\\Circle_Border")
		f.overlay:SetPoint("CENTER", f, "CENTER")
		f.overlay:SetSize(height + 4, height + 4)

		-- Текст "x2" под иконкой
		f.fontString = f:CreateFontString(nil, "OVERLAY")
		f.fontString:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
		f.fontString:SetTextColor(1, 1, 1, 1)
		f.fontString:SetWidth(25)
		f.fontString:SetHeight(10)
		f.fontString:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
		f.fontString:Hide()

		enemyPortraits[i] = f
	end

	local widget = {
		frame = button,
		title = title,
		icon = icon,
		pullNumber = pullNumber,
		renamebox = renamebox,
		background = background,
		enemyPortraits = enemyPortraits,
		type = Type,
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
