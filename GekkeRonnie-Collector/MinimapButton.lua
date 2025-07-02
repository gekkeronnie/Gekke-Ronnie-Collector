-- MinimapButton.lua - Based on DBM Template with GRC Functionality (Default Dragging)
local addonName, GRC = ...

-- Early exit if required libraries are not available
if not LibStub or not LibStub("LibDataBroker-1.1", true) or not LibStub("LibDBIcon-1.0") then
	function GRC:ToggleMinimapButton() end -- NOOP
	function GRC:ToggleCompartmentButton() end -- NOOP
	return
end

-- Create the data broker object
local dataBroker = LibStub and LibStub("LibDataBroker-1.1"):NewDataObject("Gekke Ronnie Collector", {
	type = "launcher",
	label = "Gekke Ronnie Collector",
	icon = "Interface\\Icons\\Ability_Mount_RidingHorse"
})

if dataBroker then
	-- Store reference for later use
	GRC.dataBroker = dataBroker

	function dataBroker.OnClick(self, button)
		-- Normal click behavior (no shift requirement)
		if button == "LeftButton" then
			-- Left click: Open main UI
			if GRC.UI and GRC.UI.ToggleUI then
				GRC.UI.ToggleUI()
			else
				-- Fallback to slash command
				local cmd = SlashCmdList["GEKKERONNIECOLLECTOR"]
				if cmd then
					cmd("")
				else
					print("|cFFFF6B35GRC:|r GUI not ready yet - Try /grc")
				end
			end
		elseif button == "RightButton" then
			-- Right click: Open settings
			if GRC.UI and GRC.UI.CreateSettingsPanel then
				GRC.UI.CreateSettingsPanel()
			else
				-- Fallback to main UI
				if GRC.UI and GRC.UI.ToggleUI then
					GRC.UI.ToggleUI()
				else
					print("|cFFFF6B35GRC:|r Settings not ready yet - Try /grc")
				end
			end
		end
	end

	function dataBroker.OnTooltipShow(GameTooltip)
		if not GameTooltip then return end
		
		GameTooltip:SetText("|cFFFF6B35Gekke Ronnie|r|cFF00D4AA Collector|r", 1, 1, 1)
		GameTooltip:AddLine("Collection tracker for mounts, pets, and toys", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
		GameTooltip:AddLine(" ")
		
		-- Enhanced status detection
		local status = "Loading..."
		local statusColor = {1, 0.8, 0.2}
		
		-- Check multiple systems for readiness
		if GRC.Core and GRC.Core.IsReady and GRC.Core.IsReady() then
			status = "Ready"
			statusColor = {0.2, 1, 0.2}
		elseif GRC.SmartCache and GRC.SmartCache.IsReady and GRC.SmartCache.IsReady() then
			status = "Cache Ready"
			statusColor = {0.2, 1, 0.2}
		elseif GRC.UI and GRC.UI.ToggleUI then
			status = "UI Ready"
			statusColor = {0.2, 0.8, 1}
		elseif GRC.SmartCache and GRC.SmartCache.IsBuilding and GRC.SmartCache.IsBuilding() then
			status = "Building Cache..."
			statusColor = {1, 1, 0.2}
		elseif not GRC.SmartCache then
			status = "SmartCache Missing"
			statusColor = {1, 0.2, 0.2}
		elseif not GRC.Core then
			status = "Core Missing"
			statusColor = {1, 0.2, 0.2}
		end
		
		GameTooltip:AddLine("Status: " .. status, statusColor[1], statusColor[2], statusColor[3])
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Left Click: Open Interface", 0.2, 1, 0.2)
		GameTooltip:AddLine("Right Click: Settings Panel", 0.2, 0.8, 1)
		GameTooltip:AddLine("Drag: Move Button", 1, 0.8, 0.2)
		
		-- Add debug info if debug mode is on
		if GRCollectorSettings and GRCollectorSettings.debugMode then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Debug Info:", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("Core: " .. (GRC.Core and "✓" or "✗"), 0.7, 0.7, 0.7)
			GameTooltip:AddLine("UI: " .. (GRC.UI and "✓" or "✗"), 0.7, 0.7, 0.7)
			GameTooltip:AddLine("SmartCache: " .. (GRC.SmartCache and "✓" or "✗"), 0.7, 0.7, 0.7)
		end
	end
end

-- LibDBIcon integration
do
	local LibDBIcon = LibStub("LibDBIcon-1.0")

	function GRC:ToggleMinimapButton()
		if not GRCollectorSettings.minimapButton then
			GRCollectorSettings.minimapButton = {}
		end
		
		GRCollectorSettings.minimapButton.hide = not GRCollectorSettings.minimapButton.hide
		GRCollectorSettings.showMinimapButton = not GRCollectorSettings.minimapButton.hide
		
		if GRCollectorSettings.minimapButton.hide then
			LibDBIcon:Hide("Gekke Ronnie Collector")
			print("|cFFFF6B35GRC:|r Minimap button hidden")
		else
			LibDBIcon:Show("Gekke Ronnie Collector")
			print("|cFFFF6B35GRC:|r Minimap button shown")
		end
	end

	function GRC:ToggleCompartmentButton()
		-- FORCE: Compartment is always enabled - inform user but don't allow disabling
		print("|cFFFF6B35GRC:|r Addon compartment is always enabled for GRC")
		print("  The button will always be available in the compartment for easy access.")
		
		-- Ensure it's always enabled
		if not GRCollectorSettings.minimapButton then
			GRCollectorSettings.minimapButton = {}
		end
		GRCollectorSettings.minimapButton.showInCompartment = true
		LibDBIcon:AddButtonToCompartment("Gekke Ronnie Collector")
	end
	
	-- Initialize the minimap button
	local function InitializeMinimapButton()
		-- Ensure settings exist with proper defaults
		if not GRCollectorSettings then
			GRCollectorSettings = {}
		end
		
		if not GRCollectorSettings.minimapButton then
			GRCollectorSettings.minimapButton = {
				hide = false,
				minimapPos = 180, -- Position at far left (180 degrees)
				radius = 80,
				lock = false,
				showInCompartment = true
			}
		end
		
		-- Ensure minimapPos is set to 180 for far left positioning
		if GRCollectorSettings.minimapButton.minimapPos ~= 180 then
			GRCollectorSettings.minimapButton.minimapPos = 180
		end
		
		-- FORCE: Always enable compartment (even if user disabled it)
		GRCollectorSettings.minimapButton.showInCompartment = true
		
		-- Ensure main setting exists
		if GRCollectorSettings.showMinimapButton == nil then
			GRCollectorSettings.showMinimapButton = true
		end
		
		-- Register with LibDBIcon using the same name as DataObject
		LibDBIcon:Register("Gekke Ronnie Collector", dataBroker, GRCollectorSettings.minimapButton)
		
		-- Show or hide based on settings
		if GRCollectorSettings.showMinimapButton and not GRCollectorSettings.minimapButton.hide then
			LibDBIcon:Show("Gekke Ronnie Collector")
		else
			LibDBIcon:Hide("Gekke Ronnie Collector")
		end
		
		-- FORCE: Always add to compartment (override user preference)
		LibDBIcon:AddButtonToCompartment("Gekke Ronnie Collector")
		
	end
	
	-- Public API for external use
	GRC.MinimapButton = {
		Show = function()
			if LibDBIcon then
				LibDBIcon:Show("Gekke Ronnie Collector")
				if GRCollectorSettings then
					GRCollectorSettings.showMinimapButton = true
					if GRCollectorSettings.minimapButton then
						GRCollectorSettings.minimapButton.hide = false
					end
				end
				print("|cFFFF6B35GRC:|r Minimap button shown")
			end
		end,
		
		Hide = function()
			if LibDBIcon then
				LibDBIcon:Hide("Gekke Ronnie Collector")
				if GRCollectorSettings then
					GRCollectorSettings.showMinimapButton = false
					if GRCollectorSettings.minimapButton then
						GRCollectorSettings.minimapButton.hide = true
					end
				end
				print("|cFFFF6B35GRC:|r Minimap button hidden")
			end
		end,
		
		Toggle = function()
			if GRCollectorSettings and GRCollectorSettings.showMinimapButton then
				GRC.MinimapButton.Hide()
			else
				GRC.MinimapButton.Show()
			end
		end,
		
		IsShown = function()
			if LibDBIcon then
				return not (GRCollectorSettings and GRCollectorSettings.minimapButton and GRCollectorSettings.minimapButton.hide)
			end
			return false
		end,
		
		UpdatePosition = function()
			if LibDBIcon and GRCollectorSettings and GRCollectorSettings.minimapButton then
				LibDBIcon:Refresh("Gekke Ronnie Collector", GRCollectorSettings.minimapButton)
			end
		end,
		
		UpdateTooltip = function()
			-- Force tooltip refresh if it's currently shown
			if GameTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() and GameTooltip:GetOwner().dataObject == dataBroker then
				dataBroker.OnTooltipShow(GameTooltip)
			end
		end
	}
	
	-- Event handling for initialization
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("ADDON_LOADED")
	eventFrame:RegisterEvent("PLAYER_LOGIN")
	
	local addonLoaded = false
	local playerLoaded = false
	
	local function CheckInitialization()
		if addonLoaded and playerLoaded then
			-- TESTING: No timers - initialize immediately
			InitializeMinimapButton()
		end
	end
	
	eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
		if event == "ADDON_LOADED" and loadedAddonName == addonName then
			addonLoaded = true
			CheckInitialization()
		elseif event == "PLAYER_LOGIN" then
			playerLoaded = true
			CheckInitialization()
			self:UnregisterEvent("PLAYER_LOGIN")
		end
	end)
end