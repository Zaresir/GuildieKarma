-----------------------------------------------------------------------------------------------
-- Client Lua Script for GuildieKarma
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- GuildieKarma Module Definition
-----------------------------------------------------------------------------------------------
local GuildieKarma = {} 

kstrContainerEventName_GK = "GuildieKarma"

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
kCreator_GK = "Zaresir Tinktaker"
kVersion_GK = "1.0.0"
kResetOptions_GK = false

kKarmaMin_GK = 0
kKarmaMax_GK = 5

local config_GK = {}

config_GK.defaults = {}
config_GK.user = {}

config_GK.defaults.Debug = false

config_GK.user.Debug = false
config_GK.user.Version = nil
config_GK.user.Roster = {}

SlashCommands_GK = {
	debug = {disp = nil, desc = "Toggle DEBUG mode", hndlr = "E_GuildieKarmaDebug", func = "ToggleDebug"},
	reset = {disp = nil, desc = "Clears all saved addon data and settings", hndlr = "E_GuildieKarmaReset", func = "ClearSavedData"}
}
 
-----------------------------------------------------------------------------------------------
-- New
-----------------------------------------------------------------------------------------------
function GuildieKarma:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	self.wndGrid = nil
	
	self.KarmaValue = 0
	
	self.RosterSize = 0
	
	self.strPlayerName = nil
	self.KarmaValue = 0
	
	self.tRoster = {}
	
	self.ConfigData = {}
	self.ConfigData.default = setmetatable({}, {__index = config_GK.defaults})
	self.ConfigData.saved = setmetatable({}, {__index = config_GK.user})
	
	self.KarmaList = {}

    return o
end

-----------------------------------------------------------------------------------------------
-- Init
-----------------------------------------------------------------------------------------------
function GuildieKarma:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		GuildContentRoster
	}
	
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma OnLoad
-----------------------------------------------------------------------------------------------
function GuildieKarma:OnLoad()
	-- Register required addons
	self.GuildContentRoster = Apollo.GetAddon("GuildContentRoster")
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("GuildieKarma.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
	
	self:RegisterObjects()
	self:InitializeHooks()
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma OnDocLoaded
-----------------------------------------------------------------------------------------------
function GuildieKarma:OnDocLoaded()
	self:PrintMsg(string.format("Version %s loaded", tostring(kVersion_GK)), true)
	
	self:LoadOptions()
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma RegisterObjects Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:RegisterObjects()
	-- Register Slash Command Events
	self:RegisterSlashCommandEvents()
	
	-- Register Slash Commands
	Apollo.RegisterSlashCommand("gkarma", "SlashCommandHandler", self)
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma RegisterSlashCommandEvents Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:RegisterSlashCommandEvents()
	for cmd, attribs in pairs(SlashCommands_GK) do
		if attribs.hndlr ~= nil then
			self:PrintDebug(string.format("Registering event handler: %s, %s", attribs.hndlr, attribs.func))
		
			Apollo.RegisterEventHandler(attribs.hndlr, attribs.func, self)
		end
	end		
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma LoadOptions Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:LoadOptions()
	self:PrintDebug("kVersion_GK = " .. tostring(kVersion_GK))
	self:PrintDebug("User Version = " .. tostring(self.ConfigData.saved.version))
	self:PrintDebug("kResetOptions_GK = " .. tostring(kResetOptions_GK))
	
	if self.ConfigData.saved.Version ~= kVersion_GK and kResetOptions_GK then
		self:PrintDebug("Resetting Options...")
		
		self:PrintMsg("New version requires options reset. Clearing all saved data...", true)
		
		self.ConfigData.saved.Version = kVersion_GK
		
		self.ClearSavedData()
	else
		self:PrintDebug("Loading options...")
	end
	
	self.ConfigData.saved.Version = kVersion_GK
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma InitializeHooks Function
-----------------------------------------------------------------------------------------------
function GuildieKarma:InitializeHooks()
	-- Override OnToggleRoster
	local fnOnToggleRoster = self.GuildContentRoster.OnToggleRoster
	
	self.GuildContentRoster.OnToggleRoster = function (tGuildContentRoster, wndParent)
		fnOnToggleRoster(tGuildContentRoster, wndParent)
		
		self.wndMain = Apollo.LoadForm(self.xmlDoc, "ButtonContainer", tGuildContentRoster.tWndRefs.wndMain:FindChild("FooterFraming"), self)
		self.wndGKControl = self.wndMain:FindChild("KarmaControlContainer")
		self.wndMain:FindChild("GKControlBtn"):AttachWindow(self.wndGKControl)
		
		self.wndMain:Enable(false)
	end
		
	-- Override BuildRosterList
	local fnBuildRosterList = self.GuildContentRoster.BuildRosterList
	
	self.GuildContentRoster.BuildRosterList = function(tGuildContentRoster, guildCurr, tRoster)
		fnBuildRosterList(tGuildContentRoster, guildCurr, tRoster)
		
		self.wndGrid = tGuildContentRoster.tWndRefs.wndMain:FindChild("RosterGrid")

		self.tRoster = tRoster
		self.RosterSize = #tRoster
		
		self:PrintDebug(string.format("Roster Size = %d", #tRoster))
		
		for idx = 1, #tRoster do
			local tCurr = tRoster[idx]
			local vKarma = (self.ConfigData.saved.Roster[tCurr.strName] ~= nil and self.ConfigData.saved.Roster[tCurr.strName] or 0)
			
			local strTextColor = "UI_TextHoloBodyHighlight"
			
			if tCurr.fLastOnline ~= 0 then -- offline
				strTextColor = "UI_BtnTextGrayNormal"
			end
			
			self.wndGrid:SetCellDoc(idx, 2, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..tCurr.strName.." (K:" .. vKarma .. ")</T>")
		end
		
		for name in pairs(self.ConfigData.saved.Roster) do
			self:PrintDebug(string.format("Guild Member = %s; Karma = %d", name, tonumber(self.ConfigData.saved.Roster[name])))
		end
		
		self:PrintDebug(string.format("Roster Size = %d", self.RosterSize))
	end

	-- Override OnRosterGridItemClick
	local fnOnRosterGridItemClick = self.GuildContentRoster.OnRosterGridItemClick
	
	self.GuildContentRoster.OnRosterGridItemClick = function (tGuildContentRoster, wndControl, wndHandler, iRow, iCol, eMouseButton)
		local tRosterGrid = tGuildContentRoster.tWndRefs.wndMain:FindChild("RosterGrid")
		local tRowData = tRosterGrid:GetCellData(iRow, 1)

		fnOnRosterGridItemClick(tGuildContentRoster, wndControl, wndHandler, iRow, iCol, eMouseButton)

		if tRosterGrid:GetCurrentRow() ~= nil then
			self.strPlayerName = tRowData.strName
			
			local wndKarmaSetting = self.wndMain:FindChild("KarmaControlContainer"):FindChild("Setting")
			local vKarma = 0
			
			if self.ConfigData.saved.Roster[self.strPlayerName] ~= nil then
				vKarma = self.ConfigData.saved.Roster[self.strPlayerName]
				
				self:PrintDebug(string.format("Member '%s' Found; Karma = %d", self.strPlayerName, vKarma))
			else
				self:PrintDebug(string.format("Member '%s' Not Found; Karma = %d", self.strPlayerName, vKarma))
			end

			self:InitSlider(wndKarmaSetting, kKarmaMin_GK, kKarmaMax_GK, 1, vKarma, 0, function (value) vKarma = value end)
			
			self.wndMain:Enable(true)
		else
			self.wndMain:Enable(false)
		end
	end		
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma OnKarmaBtn Function
-----------------------------------------------------------------------------------------------
function GuildieKarma:OnKarmaBtn(wndHandler, wndControl)
	if wndControl ~= wndHandler then
		return
	end
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma OnKarmaCloseBtn Function
-----------------------------------------------------------------------------------------------
function GuildieKarma:OnKarmaCloseBtn(wndHandler, wndControl)
	wndHandler:SetFocus()
	self.wndGKControl:FindChild("KarmaControlContainer"):Close()
	
	local guildCurr = tGuildContentRoster.tWndRefs.wndMain:GetData()
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma ToggleDebug Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:ToggleDebug()
	self.ConfigData.saved.Debug = not self.ConfigData.saved.Debug
	
	if self.ConfigData.saved.Debug then
		self:PrintMsg("DEBUG MODE ENABLED", true)
	else
		self:PrintMsg("DEBUG MODE DISABLED", true)
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma PrintDebug Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:PrintDebug(msg)
	msg = string.format("%s: %s", kstrContainerEventName_GK, msg)
	
	if self.ConfigData.saved.Debug then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, msg)
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma PrintMsg Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:PrintMsg(msg, header)
	if header then
		msg = string.format("%s: %s", kstrContainerEventName_GK, msg)
	end
	
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, msg)
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma InitSlider Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:InitSlider(slider, min, max, tick, value, roundDigits, callback)
	self:PrintDebug(string.format("Slider = %s", slider:GetName()))
	self:PrintDebug(string.format("Value = %d", value))
	
	slider:SetData({
		callback = callback,
		digits = roundDigits
	})
	
	slider:FindChild("Slider"):SetMinMax(min, max, tick)
	slider:FindChild("Slider"):SetValue(value)
	slider:FindChild("Input"):SetText(tostring(value))
	slider:FindChild("Min"):SetText(tostring(min))
	slider:FindChild("Max"):SetText(tostring(max))
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma OnKarmaChange Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:OnKarmaChanged(wndHandler, wndControl, value)
	self:PlayOptionsSound(wndControl, "Push")
	
	value = self:UpdateSlider(wndHandler, value)
	wndHandler:GetParent():GetData().callback(value)
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma UpdateSlider Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:UpdateSlider(wndHandler, value)
	local parent = wndHandler:GetParent()
	
	self:PrintDebug(string.format("Window Handler = %s", wndHandler:GetName()))
	self:PrintDebug(string.format("Parent = %s", tostring(parent:GetName())))
	
	if wndHandler:GetName() == "Input" then
		value = tonumber(value)
		
		self:PrintDebug(string.format("Value = %d", value))
		
		if not value then
			return nil
		end
	else
		value = round(value, wndHandler:GetParent():GetData().digits)
		
		self:PrintDebug(string.format("Rounded Value = %d", value))
		 
		parent:FindChild("Input"):SetText(tostring(value))
	end
	
	parent:FindChild("Slider"):SetValue(value)
	
	return value
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma OnKarmaSave Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:OnKarmaSave(wndHandler, wndControl)
	self.ConfigData.saved.Roster[self.strPlayerName] = wndHandler:GetParent():FindChild("Slider"):GetValue()
	self:PrintMsg(string.format("%s's karma is now %d", self.strPlayerName, self.ConfigData.saved.Roster[self.strPlayerName]))
	
	local vKarma = self.wndGKControl:FindChild("Slider"):GetValue()
	local rosterId = 0
	local strTextColor
	
	for idx = 1, #self.tRoster do
		local tCurr = self.tRoster[idx]

		if tCurr.strName == self.strPlayerName then
			self:PrintDebug(string.format("Player Name: %s", tostring(self.tRoster[idx].strName)))
			
			rosterId = idx
		
			strTextColor = "UI_TextHoloBodyHighlight"
			
			if tCurr.fLastOnline ~= 0 then -- offline
				strTextColor = "UI_BtnTextGrayNormal"
			end
			
			break
		end
	end
		
	self.wndGrid:SetCellDoc(rosterId, 2, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..self.strPlayerName.." (K:" .. vKarma .. ")</T>")
	
	wndHandler:GetParent():Close()
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma PlayOptionsSound Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:PlayOptionsSound(wndControl, soundType)
	if soundType == "Checkbox" then
		if wndControl:IsChecked() then
			Sound.Play(Sound.PlayUIButtonHoloLarge)
		else
			Sound.Play(Sound.PlayUIButtonHoloSmall)
		end
	elseif soundType == "Push" then
		Sound.Play(Sound.PlayUI11To13GenericPushButtonDigital01)
	elseif soundType == "Window" then	
		if not wndControl:IsShown() then
			Sound.Play(Sound.PlayUIWindowHoloOpen)
		else
			Sound.Play(Sound.PlayUIWindowHoloClose)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma ClearSavedData Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:ClearSavedData()
	self.ResetSavedData = true
	
	self:PrintMsg("Resetting addon...", true)
	
	self.ConfigData.saved.Roster = {}
	
	self:LoadOptions()
	
	for idx = 1, #self.tRoster do
		local tCurr = self.tRoster[idx]

		local pName = self.tRoster[idx].strName
		
		self:PrintDebug(string.format("Player Name: %s", tostring(pName)))
		
		local strTextColor = "UI_TextHoloBodyHighlight"
		
		if tCurr.fLastOnline ~= 0 then -- offline
			strTextColor = "UI_BtnTextGrayNormal"
		end
		
		self.wndGrid:SetCellDoc(idx, 2, "<T Font=\"CRB_InterfaceSmall\" TextColor=\""..strTextColor.."\">"..pName.." (K:0)</T>")
	end
	
	local wndKarmaSetting = self.wndMain:FindChild("KarmaControlContainer"):FindChild("Setting")
	
	self:InitSlider(wndKarmaSetting, kKarmaMin_GK, kKarmaMax_GK, 1, 0, 0, function (value) vKarma = value end)
				
	self:PrintMsg(" - Addon reset", false)
	
	self.ResetSavedData = false
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma OnSave Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:OnSave(eLevel)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		return self.ConfigData.saved
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma OnRestore Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:OnRestore(eLevel, tData)
	if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
		self.ConfigData.saved = setmetatable(tData, {__index = config_GK.user})
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma SlashCommandHandler Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:SlashCommandHandler(cmd, arg)
	local CmdFound = false
	
	self:PrintDebug(string.format("cmd = %s; arg = %s", cmd, arg))
	
	for cmd, attribs in pairs(SlashCommands_GK) do
		if arg == cmd then
			CmdFound = true
			
			if attribs.hndlr ~= nil then
				self:PrintDebug(string.format("%s : %s (%s)", cmd, attribs.hndlr, attribs.func))
			
				Event_FireGenericEvent(attribs.hndlr)
			end
		end
	end
	
	if not CmdFound then
		self:PrintCommands()
	end
end

---------------------------------------------------------------------------------------------------
-- GuildieKarma PrintCommands Function
---------------------------------------------------------------------------------------------------
function GuildieKarma:PrintCommands()
	self:PrintMsg(string.format("%s Available Commands:", kstrContainerEventName_GK), false)

	local cmdList = {}
	
	for cmd in pairs(SlashCommands_GK) do
		self:PrintDebug("cmd")
		table.insert(cmdList, cmd)
	end
	
	table.sort(cmdList)

	for idx, cmd in pairs(cmdList) do
		local PrintCmd = true
		
		if cmd == "debug" then
			if GameLib.GetPlayerUnit():GetName() ~= kCreator_GK then
				PrintCmd = false
			end
		end

		if PrintCmd then
			local pCmd = (SlashCommands_GK[cmd].disp ~= nil and SlashCommands_GK[cmd].disp or cmd)
			local pDesc = SlashCommands_GK[cmd].desc
						
			if pDesc ~= nil then
				self:PrintMsg(string.format("- %s : %s", pCmd, pDesc), false)
			else
				self:PrintMsg(string.format("- %s", pCmd), false)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
-- GuildieKarma Instance
-----------------------------------------------------------------------------------------------
local GuildieKarmaInst = GuildieKarma:new()
GuildieKarmaInst:Init()
