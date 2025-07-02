-- ============================================================================
-- GUI.lua - COMPLETE FILE WITH ENHANCED LOCKOUT TOOLTIPS INTEGRATED
-- ============================================================================

-- GUI.lua - Enhanced with ALL fixes: Clear Button, Tooltips, Filter Memory, Pet Journal, COLUMN FIXES, LOCKOUT TOOLTIPS
local addonName, GRC = ...
GRC.UI = GRC.UI or {}

-- UI State
local currentSort = { column = "name", descending = false }
local currentSearch = ""
local activeTab = "mounts" -- "mounts", "pets", "toys"

-- FIXED: Add global filter memory (preserves filters between tabs)
local globalFilterMemory = {
    expansions = {},
    categories = {}
}

-- Filter state - now using global memory instead of local tables
local selectedExpansions = globalFilterMemory.expansions
local selectedCategories = globalFilterMemory.categories

-- Colors
local COLORS = {
    background = {0.02, 0.02, 0.02, 0.95},
    header = {0.1, 0.1, 0.1, 0.95},
    panel = {0.05, 0.05, 0.05, 0.9},
    text = {0.95, 0.95, 0.95, 1},
    textSecondary = {0.8, 0.8, 0.8, 1},
    textMuted = {0.6, 0.6, 0.6, 1},
    collected = {0.2, 0.8, 0.2, 1},
    uncollected = {0.9, 0.4, 0.4, 1},
    removed = {0.6, 0.3, 0.3, 1},
    gold = {1, 0.82, 0, 1},
    rarityOverride = {0.4, 0.7, 1, 1},
    activeTab = {0.2, 0.4, 0.8, 1},
    inactiveTab = {0.3, 0.3, 0.3, 0.8},
    border = {0.3, 0.3, 0.3, 1},
    loading = {0.8, 0.8, 0.2, 1},
    favorite = {1, 0.84, 0, 1}, -- Gold for favorites
    favoriteEmpty = {0.5, 0.5, 0.5, 0.7} -- Gray for non-favorites
}

-- Helper functions
local function CreateStyledBackground(frame, color)
    if not frame or not color then return nil end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(unpack(color))
    return bg
end

local function CreateFontString(parent, text, size, color)
    if not parent then return nil end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE") end
    if text then fs:SetText(text) end
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

-- Enhanced tooltip functions for GUI items (using clean tooltip system)
local function ShowItemTooltip(frame, item, itemType)
    if not GRC.Tooltip or not GRC.Tooltip.IsEnabled() then
        return
    end
    
    -- Use the clean working tooltip function
    return GRC.Tooltip.ShowItemTooltip(frame, item, itemType)
end

local function HideItemTooltip()
    if GRC.Tooltip and GRC.Tooltip.HideItemTooltip then
        GRC.Tooltip.HideItemTooltip()
    end
end

-- FIXED: Enhanced item interaction with PREVIEW-ONLY left click
local function HandleItemClick(item, itemType, button, isShiftPressed)
    local itemID = nil
    local itemName = item.name or "Unknown"
    
    -- Get proper item ID for each type
    if itemType == "mount" then
        itemID = item.spellID or item.mountID
    elseif itemType == "pet" then
        itemID = item.speciesID
    elseif itemType == "toy" then
        itemID = item.toyID or item.itemID
    end
    
    if button == "LeftButton" then
        if isShiftPressed then
            -- Shift+Left Click = Link to chat
            if itemID then
                local linkText = ""
                if itemType == "mount" then
                    linkText = string.format("[Mount: %s (SpellID: %d)]", itemName, itemID)
                elseif itemType == "pet" then
                    linkText = string.format("[Pet: %s (SpeciesID: %d)]", itemName, itemID)
                elseif itemType == "toy" then
                    linkText = string.format("[Toy: %s (ItemID: %d)]", itemName, itemID)
                end
                
                -- Insert into chat
                local chatFrame = ChatEdit_GetActiveWindow()
                if chatFrame then
                    chatFrame:Insert(linkText)
                else
                    print(linkText)
                end
                
                print("|cFFFF6B35GRC:|r Linked " .. itemName .. " to chat")
            end
        else
            -- FIXED: Left Click behaviors
            if itemType == "mount" then
                if item.mountID and GRC.Core.PreviewMount then
                    local success = GRC.Core.PreviewMount(item.mountID)
                    if success then
                        print("|cFFFF6B35GRC:|r Opening Mount Journal for: " .. itemName)
                    else
                        print("|cFFFF6B35GRC:|r Failed to open Mount Journal for: " .. itemName)
                    end
                else
                    print("|cFFFF6B35GRC:|r Cannot open Mount Journal for: " .. itemName)
                end
                
            elseif itemType == "pet" then
                -- FIXED: Open Pet Journal instead of model preview
                if item.speciesID and GRC.Core.PreviewPet then
                    local success = GRC.Core.PreviewPet(item.speciesID)
                    if success then
                        print("|cFFFF6B35GRC:|r Opening Pet Journal for: " .. itemName)
                    else
                        print("|cFFFF6B35GRC:|r Failed to open Pet Journal for: " .. itemName)
                    end
                else
                    print("|cFFFF6B35GRC:|r Cannot open Pet Journal for: " .. itemName)
                end
                
            elseif itemType == "toy" then
                -- FIXED: NO ACTION for toys on left click - PREVIEW ONLY MODE
                print("|cFFFF6B35GRC:|r Toys cannot be previewed: " .. itemName)
                print("  |cFFCCCCCCUse Shift+Left Click to link to chat or Right Click for Wowhead|r")
            end
        end
        
    elseif button == "RightButton" then
        -- Right Click = Show Wowhead link
        if itemID then
            local baseURL = "https://www.wowhead.com/"
            local link = ""
            
            if itemType == "mount" then
                link = baseURL .. "spell=" .. itemID
            elseif itemType == "pet" then
                link = baseURL .. "npc=" .. itemID
            elseif itemType == "toy" then
                link = baseURL .. "item=" .. itemID
            end
            
            print("|cFFFF6B35GRC:|r Wowhead link: " .. link)
        end
    end
end

-- Create multi-select dropdown helper function
local function CreateMultiSelectDropdown(parent, width, height, items, selectedItems, title, callback)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(width, height)
    
    -- Background
    CreateStyledBackground(dropdown, {0.02, 0.02, 0.05, 0.9})
    
    -- Border
    local border = dropdown:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetColorTexture(unpack(COLORS.border))
    border:SetDrawLayer("ARTWORK", 1)
    
    local borderInner = dropdown:CreateTexture(nil, "ARTWORK") 
    borderInner:SetPoint("TOPLEFT", 1, -1)
    borderInner:SetPoint("BOTTOMRIGHT", -1, 1)
    borderInner:SetColorTexture(0.02, 0.02, 0.05, 0.9)
    borderInner:SetDrawLayer("ARTWORK", 2)
    
    -- Title and selected count
    local titleText = CreateFontString(dropdown, title .. " (All)", 10, COLORS.text)
    titleText:SetPoint("LEFT", 5, 0)
    titleText:SetPoint("RIGHT", -15, 0)
    titleText:SetJustifyH("LEFT")
    
    -- Dropdown arrow (text only, no icon)
    local arrow = CreateFontString(dropdown, "v", 8, COLORS.textMuted)
    arrow:SetPoint("RIGHT", -3, 0)
    
    -- Click area
    local button = CreateFrame("Button", nil, dropdown)
    button:SetAllPoints()
    
    local isOpen = false
    local itemFrame = nil
    
    local function updateTitle()
        local selectedCount = 0
        local totalCount = 0
        for _, item in ipairs(items) do
            totalCount = totalCount + 1
            if selectedItems[item] then
                selectedCount = selectedCount + 1
            end
        end
        
        if selectedCount == 0 then
            titleText:SetText(title .. " (None)")
        elseif selectedCount == totalCount then
            titleText:SetText(title .. " (All)")
        else
            titleText:SetText(title .. " (" .. selectedCount .. "/" .. totalCount .. ")")
        end
    end
    
    button:SetScript("OnClick", function()
        if isOpen then
            -- Close dropdown
            if itemFrame then
                itemFrame:Hide()
                itemFrame = nil
            end
            isOpen = false
            arrow:SetText("v")
        else
            -- Open dropdown - calculate proper height
            local dropdownHeight = #items * 22 + 35 -- 22px per item + 35px for buttons
            itemFrame = CreateFrame("Frame", nil, dropdown)
            itemFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
            itemFrame:SetSize(width, dropdownHeight)
            itemFrame:SetFrameLevel(dropdown:GetFrameLevel() + 10)
            CreateStyledBackground(itemFrame, {0.01, 0.01, 0.02, 0.98})
            
            -- Border for dropdown
            local dropBorder = itemFrame:CreateTexture(nil, "ARTWORK")
            dropBorder:SetAllPoints()
            dropBorder:SetColorTexture(unpack(COLORS.border))
            
            local dropBorderInner = itemFrame:CreateTexture(nil, "ARTWORK")
            dropBorderInner:SetPoint("TOPLEFT", 1, -1)
            dropBorderInner:SetPoint("BOTTOMRIGHT", -1, 1)
            dropBorderInner:SetColorTexture(0.01, 0.01, 0.02, 0.98)
            dropBorderInner:SetDrawLayer("ARTWORK", 1)
            
            -- Select All / None buttons
            local selectAllBtn = CreateFrame("Button", nil, itemFrame, "UIPanelButtonTemplate")
            selectAllBtn:SetSize(60, 18)
            selectAllBtn:SetPoint("TOPLEFT", 5, -5)
            selectAllBtn:SetText("All")
            
            local selectNoneBtn = CreateFrame("Button", nil, itemFrame, "UIPanelButtonTemplate")
            selectNoneBtn:SetSize(60, 18)
            selectNoneBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
            selectNoneBtn:SetText("None")
            
            selectAllBtn:SetScript("OnClick", function()
                for _, item in ipairs(items) do
                    selectedItems[item] = true
                end
                updateTitle()
                if callback then callback() end
                
                -- Update all checkboxes
                local children = {itemFrame:GetChildren()}
                for _, child in pairs(children) do
                    if child.isItemCheckbox then
                        child:SetChecked(true)
                    end
                end
            end)
            
            selectNoneBtn:SetScript("OnClick", function()
                for _, item in ipairs(items) do
                    selectedItems[item] = false
                end
                updateTitle()
                if callback then callback() end
                
                -- Update all checkboxes
                local children = {itemFrame:GetChildren()}
                for _, child in pairs(children) do
                    if child.isItemCheckbox then
                        child:SetChecked(false)
                    end
                end
            end)
            
            -- Create item checkboxes directly in the frame (no scroll needed)
            for i, item in ipairs(items) do
                local checkbox = CreateFrame("CheckButton", nil, itemFrame, "UICheckButtonTemplate")
                checkbox:SetSize(16, 16)
                checkbox:SetPoint("TOPLEFT", 5, -30 - (i-1) * 22)
                checkbox:SetChecked(selectedItems[item] == true)
                checkbox.isItemCheckbox = true
                
                local label = CreateFontString(itemFrame, item, 9, COLORS.text)
                label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
                label:SetSize(width - 50, 16)
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                
                checkbox:SetScript("OnClick", function(self)
                    selectedItems[item] = self:GetChecked()
                    updateTitle()
                    if callback then callback() end
                end)
            end
            
            isOpen = true
            arrow:SetText("^")
        end
    end)
    
    -- Close dropdown when clicking elsewhere
    local function OnGlobalClick()
        if isOpen and itemFrame then
            itemFrame:Hide()
            itemFrame = nil
            isOpen = false
            arrow:SetText("v")
        end
    end
    
    dropdown:SetScript("OnHide", OnGlobalClick)
    
    -- Initialize title
    updateTitle()
    
    dropdown.UpdateTitle = updateTitle
    dropdown.GetSelection = function()
        local selected = {}
        for item, isSelected in pairs(selectedItems) do
            if isSelected then
                table.insert(selected, item)
            end
        end
        return selected
    end
    
    return dropdown
end

-- Settings Panel
function GRC.UI.CreateSettingsPanel()
    -- FIXED: Don't recreate if already exists, just show it
    if GRC.UI.SettingsPanel then 
        if not GRC.UI.SettingsPanel:IsShown() then
            GRC.UI.SettingsPanel:Show()
        end
        return 
    end
    
    -- FIXED: Optimized frame size for better content flow
    local frame = CreateFrame("Frame", "GRCSettingsPanel", UIParent)
    frame:SetSize(460, 650) -- Increased width and height for better spacing
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    
    CreateStyledBackground(frame, COLORS.background)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    CreateStyledBackground(titleBar, COLORS.header)
    
    -- Title
    local title = CreateFontString(titleBar, "|cFFFF6B35Gekke Ronnie|r|cFF00D4AA Collector|r - Settings", 12, COLORS.text)
    title:SetPoint("LEFT", 10, 0)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -5, 0)
    CreateStyledBackground(closeBtn, {0.8, 0.2, 0.2, 0.7})
    CreateFontString(closeBtn, "×", 12, {1, 1, 1, 1}):SetPoint("CENTER")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Drag functionality
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    local contentFrame = frame
    
    -- FIXED: Properly spaced layout starting from top
    local yOffset = -45
    local sectionSpacing = 40
    local itemSpacing = 30
    local labelIndent = 40
    local checkboxIndent = 60
    
    -- === GENERAL SETTINGS SECTION ===
    local generalHeader = CreateFontString(contentFrame, "General Settings", 14, COLORS.gold)
    generalHeader:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - sectionSpacing
    
    -- FIXED: Minimap Button Setting - properly positioned
    local minimapCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    minimapCheck:SetSize(20, 20)
    minimapCheck:SetChecked(GRCollectorSettings.showMinimapButton)

    local minimapLabel = CreateFontString(contentFrame, "Show Minimap Button", 11, COLORS.text)
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 10, 0)

    minimapCheck:SetScript("OnClick", function(self)
        GRCollectorSettings.showMinimapButton = self:GetChecked()
        if GRC.MinimapButton then
            if GRCollectorSettings.showMinimapButton then
                GRC.MinimapButton.Show() -- FIXED: Use function call, not method
            else
                GRC.MinimapButton.Hide() -- FIXED: Use function call, not method
            end
        end
        print("GRC: Minimap button " .. (self:GetChecked() and "shown" or "hidden"))
    end)

    yOffset = yOffset - itemSpacing

    -- Enhanced Tooltips Setting
    local tooltipCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    tooltipCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    tooltipCheck:SetSize(20, 20)
    tooltipCheck:SetChecked(GRCollectorSettings.showTooltips)
    
    local tooltipLabel = CreateFontString(contentFrame, "Show Enhanced Tooltips", 11, COLORS.text)
    tooltipLabel:SetPoint("LEFT", tooltipCheck, "RIGHT", 10, 0)
    
    tooltipCheck:SetScript("OnClick", function(self)
        GRCollectorSettings.showTooltips = self:GetChecked()
        if GRC.Tooltip then
            if GRCollectorSettings.showTooltips then
                GRC.Tooltip.Initialize()
                print("|cFFFF6B35GRC:|r Enhanced tooltips |cFF00FF00ENABLED|r")
            else
                print("|cFFFF6B35GRC:|r Enhanced tooltips |cFFFF0000DISABLED|r")
            end
        end
    end)
    
    yOffset = yOffset - itemSpacing
    
    -- Debug Mode Setting
    local debugCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    debugCheck:SetSize(20, 20)
    debugCheck:SetChecked(GRCollectorSettings.debugMode)
    
    local debugLabel = CreateFontString(contentFrame, "Enable Debug Mode", 11, COLORS.text)
    debugLabel:SetPoint("LEFT", debugCheck, "RIGHT", 10, 0)
    
    debugCheck:SetScript("OnClick", function(self)
        GRCollectorSettings.debugMode = self:GetChecked()
        print("|cFFFF6B35GRC:|r Debug mode: " .. (GRCollectorSettings.debugMode and "ON" or "OFF"))
    end)
    
    yOffset = yOffset - itemSpacing
    
    -- Sound on Drop Setting
    local soundCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    soundCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    soundCheck:SetSize(20, 20)
    soundCheck:SetChecked(GRCollectorSettings.soundOnDrop)
    
    local soundLabel = CreateFontString(contentFrame, "Sound on Item Drop", 11, COLORS.text)
    soundLabel:SetPoint("LEFT", soundCheck, "RIGHT", 10, 0)
    
    soundCheck:SetScript("OnClick", function(self)
        GRCollectorSettings.soundOnDrop = self:GetChecked()
    end)
    
    yOffset = yOffset - itemSpacing + 10 -- Extra space before slider
    
    -- FIXED: Consistent slider positioning and alignment
    local sliderStartX = 170 -- Consistent X position for all sliders
    local sliderWidth = 180
    
    -- UI Scale Setting
    local scaleLabel = CreateFontString(contentFrame, "UI Scale:", 11, COLORS.text)
    scaleLabel:SetPoint("LEFT", labelIndent, 0)
    scaleLabel:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 9)
    
    local scaleSlider = CreateFrame("Slider", nil, contentFrame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("LEFT", sliderStartX, 0)
    scaleSlider:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 3)
    scaleSlider:SetSize(sliderWidth, 20)
    scaleSlider:SetMinMaxValues(0.5, 1.5)
    scaleSlider:SetValue(GRCollectorSettings.uiScale or 1.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    
    -- FIXED: Properly hide/remove built-in slider labels
    scaleSlider:SetScript("OnShow", function(self)
        if self.textLow then self.textLow:SetText("") self.textLow:Hide() end
        if self.textHigh then self.textHigh:SetText("") self.textHigh:Hide() end
    end)
    
    local scaleValue = CreateFontString(contentFrame, string.format("%.0f%%", (GRCollectorSettings.uiScale or 1.0) * 100), 10, COLORS.gold)
    scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)
    
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        GRCollectorSettings.uiScale = value
        scaleValue:SetText(string.format("%.0f%%", value * 100))
        if GRC.UI.MainFrame then
            GRC.UI.MainFrame:SetScale(value)
        end
    end)
    
    yOffset = yOffset - 60 -- Extra space for slider labels
    
    -- === TRACKING BAR SETTINGS SECTION ===
    local trackingHeader = CreateFontString(contentFrame, "Tracking Bar Settings", 14, COLORS.gold)
    trackingHeader:SetPoint("TOPLEFT", 20, yOffset)
    yOffset = yOffset - sectionSpacing
    
    -- Show Tracking Bar Setting
    local trackingCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    trackingCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    trackingCheck:SetSize(20, 20)
    trackingCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.visible or true)
    
    local trackingLabel = CreateFontString(contentFrame, "Show Favorites Tracking Bar", 11, COLORS.text)
    trackingLabel:SetPoint("LEFT", trackingCheck, "RIGHT", 10, 0)
    
    trackingCheck:SetScript("OnClick", function(self)
        if GRC.TrackingBar then
            if self:GetChecked() then
                GRCollectorTrackingSettings.visible = true
                GRC.TrackingBar.UpdateVisibility()
            else
                GRCollectorTrackingSettings.visible = false
                GRC.TrackingBar.UpdateVisibility()
            end
        end
    end)
    
    yOffset = yOffset - itemSpacing
    
    -- Lock Tracking Bar Setting
    local lockTrackingCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    lockTrackingCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    lockTrackingCheck:SetSize(20, 20)
    lockTrackingCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.locked or false)
    
    local lockTrackingLabel = CreateFontString(contentFrame, "Lock Tracking Bar Position", 11, COLORS.text)
    lockTrackingLabel:SetPoint("LEFT", lockTrackingCheck, "RIGHT", 10, 0)
    
    lockTrackingCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings then
            GRCollectorTrackingSettings.locked = self:GetChecked()
        end
    end)
    
    yOffset = yOffset - itemSpacing
    
    -- Mouse Interaction Setting
    local mouseCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    mouseCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    mouseCheck:SetSize(20, 20)
    mouseCheck:SetChecked(not (GRCollectorTrackingSettings and GRCollectorTrackingSettings.noMouseInteraction))
    
    local mouseLabel = CreateFontString(contentFrame, "Enable Mouse Interaction on Bars", 11, COLORS.text)
    mouseLabel:SetPoint("LEFT", mouseCheck, "RIGHT", 10, 0)
    
    mouseCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings then
            GRCollectorTrackingSettings.noMouseInteraction = not self:GetChecked()
            if GRC.TrackingBar and GRC.TrackingBar.RefreshData then
                GRC.TrackingBar.RefreshData()
            end
        end
    end)
    
    yOffset = yOffset - itemSpacing
    
    -- Show Percentages Setting
    local percentCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    percentCheck:SetPoint("TOPLEFT", checkboxIndent, yOffset)
    percentCheck:SetSize(20, 20)
    percentCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.showPercentage or true)
    
    local percentLabel = CreateFontString(contentFrame, "Show Progress Percentages", 11, COLORS.text)
    percentLabel:SetPoint("LEFT", percentCheck, "RIGHT", 10, 0)
    
    percentCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings then
            GRCollectorTrackingSettings.showPercentage = self:GetChecked()
            if GRC.TrackingBar and GRC.TrackingBar.RefreshData then
                GRC.TrackingBar.RefreshData()
            end
        end
    end)
    
    yOffset = yOffset - sectionSpacing
    
    -- FIXED: Column Settings with proper layout
    local columnLabel = CreateFontString(contentFrame, "Visible Columns:", 11, COLORS.text)
    columnLabel:SetPoint("TOPLEFT", labelIndent, yOffset)
    yOffset = yOffset - 25
    
    -- FIXED: Evenly spaced column checkboxes in a row
    local columnStartX = checkboxIndent
    local columnSpacing = 100 -- Space between each column option
    
    -- Mounts Column
    local mountsColumnCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    mountsColumnCheck:SetPoint("TOPLEFT", columnStartX, yOffset)
    mountsColumnCheck:SetSize(20, 20)
    mountsColumnCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns and GRCollectorTrackingSettings.enabledColumns.mounts)
    
    local mountsColumnLabel = CreateFontString(contentFrame, "Mounts", 10, COLORS.text)
    mountsColumnLabel:SetPoint("LEFT", mountsColumnCheck, "RIGHT", 10, 0)
    
    mountsColumnCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns then
            GRCollectorTrackingSettings.enabledColumns.mounts = self:GetChecked()
            
            if GRC.TrackingBar and GRC.TrackingBar.RefreshColumns then
                GRC.TrackingBar.RefreshColumns()
            end
            
            print("|cFFFF6B35GRC:|r Mounts column: " .. (self:GetChecked() and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
        end
    end)
    
    -- Pets Column
    local petsColumnCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    petsColumnCheck:SetPoint("TOPLEFT", columnStartX + columnSpacing, yOffset)
    petsColumnCheck:SetSize(20, 20)
    petsColumnCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns and GRCollectorTrackingSettings.enabledColumns.pets)
    
    local petsColumnLabel = CreateFontString(contentFrame, "Pets", 10, COLORS.text)
    petsColumnLabel:SetPoint("LEFT", petsColumnCheck, "RIGHT", 10, 0)
    
    petsColumnCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns then
            GRCollectorTrackingSettings.enabledColumns.pets = self:GetChecked()
            
            if GRC.TrackingBar and GRC.TrackingBar.RefreshColumns then
                GRC.TrackingBar.RefreshColumns()
            end
            
            print("|cFFFF6B35GRC:|r Pets column: " .. (self:GetChecked() and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
        end
    end)
    
    -- Toys Column
    local toysColumnCheck = CreateFrame("CheckButton", nil, contentFrame, "UICheckButtonTemplate")
    toysColumnCheck:SetPoint("TOPLEFT", columnStartX + (columnSpacing * 2), yOffset)
    toysColumnCheck:SetSize(20, 20)
    toysColumnCheck:SetChecked(GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns and GRCollectorTrackingSettings.enabledColumns.toys)
    
    local toysColumnLabel = CreateFontString(contentFrame, "Toys", 10, COLORS.text)
    toysColumnLabel:SetPoint("LEFT", toysColumnCheck, "RIGHT", 10, 0)
    
    toysColumnCheck:SetScript("OnClick", function(self)
        if GRCollectorTrackingSettings and GRCollectorTrackingSettings.enabledColumns then
            GRCollectorTrackingSettings.enabledColumns.toys = self:GetChecked()
            
            if GRC.TrackingBar and GRC.TrackingBar.RefreshColumns then
                GRC.TrackingBar.RefreshColumns()
            end
            
            print("|cFFFF6B35GRC:|r Toys column: " .. (self:GetChecked() and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
        end
    end)
    
    yOffset = yOffset - sectionSpacing
    
    -- FIXED: Aligned slider settings with consistent positioning
    local sliderStartX = 170 -- Consistent X position for all sliders
    
    -- Row Spacing Setting
    local spacingLabel = CreateFontString(contentFrame, "Row Spacing:", 11, COLORS.text)
    spacingLabel:SetPoint("LEFT", labelIndent, 0)
    spacingLabel:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 9)
    
    local spacingSlider = CreateFrame("Slider", nil, contentFrame, "OptionsSliderTemplate")
    spacingSlider:SetPoint("LEFT", sliderStartX, 0)
    spacingSlider:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 3)
    spacingSlider:SetSize(sliderWidth, 20)
    spacingSlider:SetMinMaxValues(0, 10)
    spacingSlider:SetValue(GRCollectorTrackingSettings and GRCollectorTrackingSettings.rowSpacing or 0)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    
    -- FIXED: Properly hide/remove built-in slider labels
    spacingSlider:SetScript("OnShow", function(self)
        if self.textLow then self.textLow:SetText("") self.textLow:Hide() end
        if self.textHigh then self.textHigh:SetText("") self.textHigh:Hide() end
    end)
    
    local spacingValue = CreateFontString(contentFrame, string.format("%d px", GRCollectorTrackingSettings and GRCollectorTrackingSettings.rowSpacing or 0), 10, COLORS.gold)
    spacingValue:SetPoint("LEFT", spacingSlider, "RIGHT", 10, 0)
    
    spacingSlider:SetScript("OnValueChanged", function(self, value)
        if GRCollectorTrackingSettings then
            GRCollectorTrackingSettings.rowSpacing = value
            spacingValue:SetText(string.format("%d px", value))
            if GRC.TrackingBar and GRC.TrackingBar.RefreshData then
                GRC.TrackingBar.RefreshData()
            end
        end
    end)
    
    yOffset = yOffset - 40
    
    -- Tracking bar scale setting
    local trackingScaleLabel = CreateFontString(contentFrame, "Tracking Bar Scale:", 11, COLORS.text)
    trackingScaleLabel:SetPoint("LEFT", labelIndent, 0)
    trackingScaleLabel:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 9)
    
    local trackingScaleSlider = CreateFrame("Slider", nil, contentFrame, "OptionsSliderTemplate")
    trackingScaleSlider:SetPoint("LEFT", sliderStartX, 0)
    trackingScaleSlider:SetPoint("TOP", contentFrame, "TOP", 0, yOffset - 3)
    trackingScaleSlider:SetSize(sliderWidth, 20)
    trackingScaleSlider:SetMinMaxValues(0.5, 1.5)
    trackingScaleSlider:SetValue(GRCollectorTrackingSettings and GRCollectorTrackingSettings.scale or 1.0)
    trackingScaleSlider:SetValueStep(0.1)
    trackingScaleSlider:SetObeyStepOnDrag(true)
    
    -- FIXED: Properly hide/remove built-in slider labels
    trackingScaleSlider:SetScript("OnShow", function(self)
        if self.textLow then self.textLow:SetText("") self.textLow:Hide() end
        if self.textHigh then self.textHigh:SetText("") self.textHigh:Hide() end
    end)
    
    local trackingScaleValue = CreateFontString(contentFrame, string.format("%.0f%%", (GRCollectorTrackingSettings and GRCollectorTrackingSettings.scale or 1.0) * 100), 10, COLORS.gold)
    trackingScaleValue:SetPoint("LEFT", trackingScaleSlider, "RIGHT", 10, 0)
    
    trackingScaleSlider:SetScript("OnValueChanged", function(self, value)
        if GRCollectorTrackingSettings then
            GRCollectorTrackingSettings.scale = value
            trackingScaleValue:SetText(string.format("%.0f%%", value * 100))
            if GRC.TrackingBar and GRC.TrackingBar.UpdateScale then
                GRC.TrackingBar.UpdateScale(value)
            end
        end
    end)
    
    yOffset = yOffset - 60
    
    -- === FIXED: ACTION BUTTONS with proper spacing ===
    local buttonWidth = 120
    local buttonHeight = 25
    local buttonSpacing = 10
    local buttonStartX = 40
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    resetBtn:SetSize(buttonWidth, buttonHeight)
    resetBtn:SetPoint("TOPLEFT", buttonStartX, yOffset)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        -- Reset all settings to defaults
        GRCollectorSettings.showMinimapButton = true
        GRCollectorSettings.debugMode = false
        GRCollectorSettings.soundOnDrop = true
        GRCollectorSettings.showTooltips = true
        GRCollectorSettings.uiScale = 1.0
        
        -- Reset tracking bar settings
        GRCollectorTrackingSettings.visible = true
        GRCollectorTrackingSettings.locked = false
        GRCollectorTrackingSettings.noMouseInteraction = true
        GRCollectorTrackingSettings.showPercentage = true
        GRCollectorTrackingSettings.rowSpacing = 0
        GRCollectorTrackingSettings.scale = 1.0
        GRCollectorTrackingSettings.enabledColumns = {mounts = true, pets = true, toys = true}
        
        -- Update UI elements
        minimapCheck:SetChecked(true)
        debugCheck:SetChecked(false)
        soundCheck:SetChecked(true)
        tooltipCheck:SetChecked(true)
        trackingCheck:SetChecked(true)
        lockTrackingCheck:SetChecked(false)
        mouseCheck:SetChecked(false)
        percentCheck:SetChecked(true)
        mountsColumnCheck:SetChecked(true)
        petsColumnCheck:SetChecked(true)
        toysColumnCheck:SetChecked(true)
        scaleSlider:SetValue(1.0)
        spacingSlider:SetValue(0)
        trackingScaleSlider:SetValue(1.0)
        
        if GRC.UI.MainFrame then
            GRC.UI.MainFrame:SetScale(1.0)
        end
        
        if GRC.TrackingBar then
            if GRC.TrackingBar.UpdateScale then
                GRC.TrackingBar.UpdateScale(1.0)
            end
            if GRC.TrackingBar.RefreshColumns then
                GRC.TrackingBar.RefreshColumns()
            end
        end
        
        print("|cFFFF6B35GRC:|r Settings reset to defaults")
    end)
    
    -- Reset Tracking Position button
    local resetPosBtn = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(buttonWidth, buttonHeight)
    resetPosBtn:SetPoint("TOPLEFT", buttonStartX + buttonWidth + buttonSpacing, yOffset)
    resetPosBtn:SetText("Reset Position")
    resetPosBtn:SetScript("OnClick", function()
        if GRC.TrackingBar and GRC.TrackingBar.ResetPosition then
            GRC.TrackingBar.ResetPosition()
        end
    end)
    
    -- Open Main GUI button
    local openGUIBtn = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    openGUIBtn:SetSize(buttonWidth, buttonHeight)
    openGUIBtn:SetPoint("TOPLEFT", buttonStartX + (buttonWidth + buttonSpacing) * 2, yOffset)
    openGUIBtn:SetText("Open Main GUI")
    openGUIBtn:SetScript("OnClick", function()
        if GRC.UI and GRC.UI.ToggleUI then
            GRC.UI.ToggleUI()
        end
    end)
    
    yOffset = yOffset - 40
    
    -- Store the frame reference
    GRC.UI.SettingsPanel = frame
    
    -- Show the frame
    frame:Show()
end

-- Tab creation and management - INSTANT switching
function GRC.UI.CreateTabBar()
    if GRC.UI.TabBar then return end
    
    local tabBar = CreateFrame("Frame", nil, GRC.UI.MainFrame)
    tabBar:SetPoint("TOPLEFT", 2, -40)
    tabBar:SetPoint("TOPRIGHT", -2, -40)
    tabBar:SetHeight(35)
    CreateStyledBackground(tabBar, COLORS.header)
    
    local tabs = {
        {key = "mounts", text = "Mounts"},
        {key = "pets", text = "Pets"},
        {key = "toys", text = "Toys & Items"}
    }
    
    local tabWidth = 200
    local tabHeight = 30
    
    GRC.UI.TabButtons = {}
    
    for i, tabInfo in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetSize(tabWidth, tabHeight)
        tab:SetPoint("LEFT", (i-1) * (tabWidth + 2) + 10, 0)
        
        -- Background
        local bg = CreateStyledBackground(tab, 
            activeTab == tabInfo.key and COLORS.activeTab or COLORS.inactiveTab)
        tab.background = bg
        
        -- Text
        local text = CreateFontString(tab, tabInfo.text, 12, COLORS.text)
        text:SetPoint("CENTER")
        tab.text = text
        
        -- Click handler - INSTANT switching
        tab:SetScript("OnClick", function()
            GRC.UI.SwitchTab(tabInfo.key)
        end)
        
        -- Hover effects
        tab:SetScript("OnEnter", function(self)
            if activeTab ~= tabInfo.key then
                self.background:SetColorTexture(0.4, 0.4, 0.4, 0.9)
            end
        end)
        
        tab:SetScript("OnLeave", function(self)
            if activeTab ~= tabInfo.key then
                self.background:SetColorTexture(unpack(COLORS.inactiveTab))
            end
        end)
        
        GRC.UI.TabButtons[tabInfo.key] = tab
    end
    
    -- Settings button
    local settingsBtn = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
    settingsBtn:SetSize(80, 25)
    settingsBtn:SetPoint("TOPRIGHT", -10, -5)
    settingsBtn:SetText("Settings")
    settingsBtn:SetScript("OnClick", function()
        GRC.UI.CreateSettingsPanel()
    end)
    
    GRC.UI.TabBar = tabBar
end

-- FIXED: Tab switching now preserves filter memory
function GRC.UI.SwitchTab(newTab)
    if activeTab == newTab then return end
    
    GRC.Debug.UIInfo("Switching from %s to %s (preserving filters)", activeTab, newTab)
    
    activeTab = newTab
    
    -- INSTANT: Update tab appearances immediately
    for tabKey, tabButton in pairs(GRC.UI.TabButtons) do
        if tabKey == activeTab then
            tabButton.background:SetColorTexture(unpack(COLORS.activeTab))
        else
            tabButton.background:SetColorTexture(unpack(COLORS.inactiveTab))
        end
    end
    
    -- INSTANT: Clear search immediately
    if GRC.UI.FilterPanel and GRC.UI.FilterPanel.searchBox then
        GRC.UI.FilterPanel.searchBox:SetText("")
        currentSearch = ""
        
        if GRC.UI.FilterPanel.searchStatus then
            GRC.UI.FilterPanel.searchStatus:SetText("")
        end
    end
    
    -- INSTANT: Show ready state immediately (no loading)
    GRC.UI.SafeUpdateStatistics(0, 0, 0, "Ready")
    
    -- INSTANT: Update everything immediately (no delays)
    GRC.UI.UpdateFiltersForTab()
    GRC.UI.UpdateHeadersForTab()
    GRC.UI.InstantRefreshItemList()
    
    GRC.Debug.UIInfo("Tab switch to %s complete (filters preserved)", activeTab)
end

-- FIXED: Update filter sections with preserved memory
function GRC.UI.UpdateFiltersForTab()
    if not GRC.UI.FilterPanel then return end
    
    -- INSTANT: Get available expansions and categories
    local expansions = {}
    local categories = {}
    
    if GRC.SmartCache and GRC.SmartCache.IsReady() then
        expansions = GRC.SmartCache.GetAvailableExpansions()
        categories = GRC.SmartCache.GetAvailableCategories()
    end
    
    -- FIXED: Initialize memory only once with all enabled by default
    for _, exp in ipairs(expansions) do
        if globalFilterMemory.expansions[exp] == nil then
            globalFilterMemory.expansions[exp] = true
        end
    end
    
    for _, cat in ipairs(categories) do
        if globalFilterMemory.categories[cat] == nil then
            globalFilterMemory.categories[cat] = true
        end
    end
    
    -- Update the references
    selectedExpansions = globalFilterMemory.expansions
    selectedCategories = globalFilterMemory.categories
    
    -- INSTANT: Update dropdown sections
    if GRC.UI.FilterPanel.expansionDropdown then
        GRC.UI.FilterPanel.expansionDropdown:Hide()
        GRC.UI.FilterPanel.expansionDropdown = nil
    end
    
    if GRC.UI.FilterPanel.categoryDropdown then
        GRC.UI.FilterPanel.categoryDropdown:Hide()
        GRC.UI.FilterPanel.categoryDropdown = nil
    end
    
    -- INSTANT: Create new dropdown sections
    GRC.UI.FilterPanel.expansionDropdown = CreateMultiSelectDropdown(
        GRC.UI.FilterPanel, 180, 25, expansions, selectedExpansions, "Expansion",
        function() 
            GRC.UI.InstantRefreshItemList() 
        end
    )
    GRC.UI.FilterPanel.expansionDropdown:SetPoint("TOPLEFT", 20, -55)
    
    GRC.UI.FilterPanel.categoryDropdown = CreateMultiSelectDropdown(
        GRC.UI.FilterPanel, 180, 25, categories, selectedCategories, "Category",
        function() 
            GRC.UI.InstantRefreshItemList() 
        end
    )
    GRC.UI.FilterPanel.categoryDropdown:SetPoint("TOPLEFT", 210, -55)
    
    GRC.Debug.UIInfo("Updated filters for %s tab (memory preserved)", activeTab)
end

-- Headers with proper cleanup and column alignment - INSTANT with Favorites column
function GRC.UI.UpdateHeadersForTab()
    if not GRC.UI.ItemList or not GRC.UI.ItemList.headerFrame then return end
    
    -- INSTANT: Clear all existing headers
    local children = {GRC.UI.ItemList.headerFrame:GetChildren()}
    for _, child in pairs(children) do
        if child then
            child:Hide()
            child:ClearAllPoints()
            child:SetParent(nil)
        end
    end
    
    -- INSTANT: Create new headers with compact name column and favorites column
    local headers = {
        {text = "|TInterface\\Common\\ReputationStar:16:16|t", width = 25, key = "favorite"}, -- Star icon for favorites
        {text = "Name", width = 220, key = "name"}, -- Reduced by 50 from 270 to 220
        {text = "Expansion", width = 145, key = "expansion"},
        {text = "Category", width = 135, key = "category"},
        {text = "Drop Rate", width = 95, key = "dropRate"},
        {text = "Attempts", width = 75, key = "attempts"},
        {text = "Lockout", width = 115, key = "lockout"}, -- Enhanced header text
        {text = "Status", width = 100, key = "isCollected"}
    }
    
    -- Adjusted column positions to account for new star column
    local colPositions = {10, 40, 265, 415, 555, 655, 735, 880}
    
    for i, header in ipairs(headers) do
        local headerText = CreateFontString(GRC.UI.ItemList.headerFrame, header.text, 12, COLORS.gold)
        if headerText then
            headerText:SetPoint("LEFT", colPositions[i], 0)
            headerText:SetSize(header.width, 25)
            headerText:SetJustifyH("LEFT")
            headerText:SetWordWrap(false)
            headerText:SetNonSpaceWrap(false)
            
            -- Special styling for star column
            if header.key == "favorite" then
                headerText:SetTextColor(1, 0.84, 0, 1) -- Gold color for star
                headerText:SetJustifyH("CENTER")
            end
        end
    end
    
    GRC.Debug.UIInfo("Updated headers for %s tab with favorites column (instant)", activeTab)
end

-- Main UI Frame with better sizing and layout
function GRC.UI.CreateMainFrame()
    if GRC.UI.MainFrame then return end
    
    local frame = CreateFrame("Frame", "GekkeRonnieCollectorMainFrame", UIParent)
    frame:SetSize(1200, 800)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetScale(GRCollectorSettings.uiScale or 1.0)
    frame:Hide()
    
    CreateStyledBackground(frame, COLORS.background)
    
    -- Border
    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetColorTexture(unpack(COLORS.border))
    
    local borderInner = frame:CreateTexture(nil, "ARTWORK")
    borderInner:SetPoint("TOPLEFT", 2, -2)
    borderInner:SetPoint("BOTTOMRIGHT", -2, 2)
    borderInner:SetColorTexture(unpack(COLORS.background))
    borderInner:SetDrawLayer("ARTWORK", 1)
    
    -- Drag functionality
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 2, -2)
    titleBar:SetPoint("TOPRIGHT", -2, -2)
    titleBar:SetHeight(38)
    CreateStyledBackground(titleBar, COLORS.header)
    
    -- Title
    local title = CreateFontString(titleBar, "|cFFFF6B35Gekke Ronnie|r|cFF00D4AA Collector|r", 14, COLORS.text)
    title:SetPoint("LEFT", 15, 0)
    
    -- Statistics text
    frame.statsText = CreateFontString(titleBar, "Ready", 10, COLORS.gold)
    frame.statsText:SetPoint("CENTER", 0, 0)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(25, 25)
    closeBtn:SetPoint("RIGHT", -10, 0)
    CreateStyledBackground(closeBtn, {0.8, 0.2, 0.2, 0.7})
    CreateFontString(closeBtn, "×", 16, {1, 1, 1, 1}):SetPoint("CENTER")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    GRC.UI.MainFrame = frame
end

-- FIXED: Enhanced Filter Panel with properly positioned clear button (NO SQUARES)
function GRC.UI.CreateFilterPanel()
    if GRC.UI.FilterPanel then return end
    
    local panel = CreateFrame("Frame", nil, GRC.UI.MainFrame)
    panel:SetPoint("TOPLEFT", 2, -77)
    panel:SetPoint("TOPRIGHT", -2, -77)
    panel:SetHeight(90)
    CreateStyledBackground(panel, COLORS.panel)
    
    -- Search section
    local searchLabel = CreateFontString(panel, "Search:", 11, COLORS.text)
    searchLabel:SetPoint("TOPLEFT", 20, -15)
    
    -- FIXED: Search box with exact positioning
    local searchBox = CreateFrame("EditBox", nil, panel)
    searchBox:SetSize(200, 25) -- Smaller width to accommodate clear button
    searchBox:SetPoint("TOPLEFT", 75, -15)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(8, 8, 0, 0)
    
    -- Search box background and border
    local searchBg = searchBox:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetColorTexture(0.02, 0.02, 0.05, 0.9)
    
    local searchBorder = searchBox:CreateTexture(nil, "ARTWORK")
    searchBorder:SetAllPoints()
    searchBorder:SetColorTexture(unpack(COLORS.border))
    
    local searchBorderInner = searchBox:CreateTexture(nil, "ARTWORK")
    searchBorderInner:SetPoint("TOPLEFT", 1, -1)
    searchBorderInner:SetPoint("BOTTOMRIGHT", -1, 1)
    searchBorderInner:SetColorTexture(0.02, 0.02, 0.05, 0.9)
    searchBorderInner:SetDrawLayer("ARTWORK", 1)
    
    -- FIXED: Clear button exactly aligned with search box (NO GAP, NO SQUARES)
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetSize(50, 25)
    clearBtn:SetPoint("TOPLEFT", 277, -15) -- Exact position calculation: 75 + 200 + 2 = 277
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        currentSearch = ""
        if GRC.UI.FilterPanel.searchStatus then
            GRC.UI.FilterPanel.searchStatus:SetText("")
        end
        GRC.UI.InstantRefreshItemList()
    end)
    
    -- Search functionality
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local newSearch = self:GetText():lower()
            if newSearch ~= currentSearch then
                currentSearch = newSearch
                GRC.UI.InstantRefreshItemList()
            end
        end
    end)
    
    -- Collection filters (moved slightly right to accommodate new layout)
    local collectedCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    collectedCheck:SetPoint("TOPLEFT", 380, -15)
    collectedCheck:SetSize(16, 16)
    collectedCheck:SetChecked(true)
    
    local collectedLabel = CreateFontString(panel, "Collected", 10, COLORS.collected)
    collectedLabel:SetPoint("LEFT", collectedCheck, "RIGHT", 5, 0)
    
    local uncollectedCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    uncollectedCheck:SetPoint("LEFT", collectedLabel, "RIGHT", 20, 0)
    uncollectedCheck:SetSize(16, 16)
    uncollectedCheck:SetChecked(true)
    
    local uncollectedLabel = CreateFontString(panel, "Missing", 10, COLORS.uncollected)
    uncollectedLabel:SetPoint("LEFT", uncollectedCheck, "RIGHT", 5, 0)
    
    -- Favorites filter
    local favoritesCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    favoritesCheck:SetPoint("LEFT", uncollectedLabel, "RIGHT", 20, 0)
    favoritesCheck:SetSize(16, 16)
    favoritesCheck:SetChecked(false)
    
    local favoritesLabel = CreateFontString(panel, "|TInterface\\Common\\FavoritesIcon:24:24|tFavorites Only", 10, COLORS.favorite)
    favoritesLabel:SetPoint("LEFT", favoritesCheck, "RIGHT", 5, 0)
    
    -- Filter update functions
    local function updateFilters()
        GRC.UI.InstantRefreshItemList()
    end
    
    collectedCheck:SetScript("OnClick", updateFilters)
    uncollectedCheck:SetScript("OnClick", updateFilters)
    favoritesCheck:SetScript("OnClick", updateFilters)
    
    -- Rebuild Cache button
    local rebuildBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rebuildBtn:SetSize(120, 25)
    rebuildBtn:SetPoint("BOTTOMRIGHT", -20, 10)
    rebuildBtn:SetText("Rebuild Cache")
    rebuildBtn:SetScript("OnClick", function()
        print("|cFFFF6B35GRC:|r Rebuilding " .. activeTab .. " cache...")
        if GRC.Core and GRC.Core.Refresh then
            GRC.Core.Refresh()
        end
        GRC.UI.InstantRefreshItemList()
    end)
    
    -- Store references
    GRC.UI.FilterPanel = panel
    GRC.UI.FilterPanel.searchBox = searchBox
    GRC.UI.FilterPanel.searchStatus = searchStatus
    GRC.UI.FilterPanel.collectedCheck = collectedCheck
    GRC.UI.FilterPanel.uncollectedCheck = uncollectedCheck
    GRC.UI.FilterPanel.favoritesCheck = favoritesCheck
end

-- Perfect scroll frame
function GRC.UI.CreateItemList()
    if GRC.UI.ItemList then return end
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, GRC.UI.MainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -192)
    scrollFrame:SetPoint("BOTTOMRIGHT", -4, 15)
    
    -- Scrollbar styling
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -2)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 15)
        scrollBar:SetWidth(16)
        
        if not scrollBar.background then
            scrollBar.background = scrollBar:CreateTexture(nil, "BACKGROUND")
            scrollBar.background:SetAllPoints()
            scrollBar.background:SetColorTexture(0.1, 0.1, 0.1, 0.6)
        end
    end
    
    -- Scroll buttons
    if scrollFrame.ScrollDownButton then
        scrollFrame.ScrollDownButton:ClearAllPoints()
        scrollFrame.ScrollDownButton:SetPoint("BOTTOM", scrollFrame, "BOTTOMRIGHT", -11, 1)
        scrollFrame.ScrollDownButton:SetSize(16, 16)
    end
    
    if scrollFrame.ScrollUpButton then
        scrollFrame.ScrollUpButton:ClearAllPoints() 
        scrollFrame.ScrollUpButton:SetPoint("TOP", scrollFrame, "TOPRIGHT", -11, -2)
        scrollFrame.ScrollUpButton:SetSize(16, 16)
    end
    
    -- Content frame
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(1150, 500)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Headers frame
    local headerFrame = CreateFrame("Frame", nil, GRC.UI.MainFrame)
    headerFrame:SetPoint("TOPLEFT", 4, -167)
    headerFrame:SetPoint("TOPRIGHT", -22, -167)
    headerFrame:SetHeight(25)
    CreateStyledBackground(headerFrame, COLORS.header)
    
    GRC.UI.ItemList = {
        scrollFrame = scrollFrame,
        contentFrame = contentFrame,
        headerFrame = headerFrame
    }
    
    GRC.UI.UpdateHeadersForTab()
end

-- ENHANCED: Item row creation with proper click handlers, favorites system, AND LOCKOUT TOOLTIPS
function GRC.UI.CreateSafeItemRow(parent, item, yOffset)
    if not parent or not item then return nil end
    
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(1150, 22)
    row:SetPoint("TOPLEFT", 0, yOffset)
    
    -- CRITICAL: Enable mouse for tooltip functionality
    row:EnableMouse(true)
    
    -- Background
    local rowIndex = math.abs(yOffset / 22)
    local bgColor = (rowIndex % 2 == 0) and {0.03, 0.03, 0.06, 0.4} or {0.01, 0.01, 0.03, 0.4}
    
    if item.isRemoved then
        bgColor = {0.15, 0.05, 0.05, 0.4}
    end
    
    CreateStyledBackground(row, bgColor)
    
    -- ENHANCED: Tooltip integration for the entire row
    local hoverTexture = row:CreateTexture(nil, "OVERLAY")
    hoverTexture:SetAllPoints(row)
    hoverTexture:Hide()
    
    row:SetScript("OnEnter", function(self)
        -- Show hover overlay with appropriate color
        local hoverColor = {0.1, 0.2, 0.4, 0.3}
        if item.isRemoved then
            hoverColor = {0.2, 0.1, 0.1, 0.3}
        elseif item.isCollected then
            hoverColor = {0.1, 0.3, 0.1, 0.3}
        end
        
        hoverTexture:SetColorTexture(unpack(hoverColor))
        hoverTexture:Show()
        
        -- Show enhanced tooltip
        ShowItemTooltip(self, item, activeTab:sub(1, -2)) -- Remove 's' from activeTab
    end)
    
    row:SetScript("OnLeave", function(self)
        hoverTexture:Hide()
        HideItemTooltip()
    end)
    
    -- FIXED: Enhanced click functionality with proper handlers
    row:SetScript("OnMouseUp", function(self, button)
        local isShiftPressed = IsShiftKeyDown()
        HandleItemClick(item, activeTab:sub(1, -2), button, isShiftPressed)
    end)
    
    -- FIXED: Determine item ID for favorites system (with proper toys support)
    local itemID = nil
    local itemType = activeTab:sub(1, -2) -- Remove 's' from activeTab
    if activeTab == "mounts" then
        itemID = item.spellID
    elseif activeTab == "pets" then
        itemID = item.speciesID
    elseif activeTab == "toys" then
        itemID = item.toyID or item.itemID  -- FIXED: Use toyID for toys
    end
    
    -- Check if item is favorited
    local isFavorited = false
    if itemID and GRC.Favorites and GRC.Favorites.IsFavorited then
        isFavorited = GRC.Favorites.IsFavorited(itemID, itemType)
    end
    
    -- Create favorites star (clickable) - NO BROKEN ICONS
    local starFrame = CreateFrame("Button", nil, row)
    starFrame:SetSize(20, 20)
    starFrame:SetPoint("LEFT", 12, 0)
    
    local starTexture = starFrame:CreateTexture(nil, "OVERLAY")
    starTexture:SetAllPoints()
    
    if isFavorited then
        starTexture:SetTexture("Interface\\Common\\FavoritesIcon")
        starTexture:SetVertexColor(1, 0.84, 0, 1) -- Gold color
    else
        starTexture:SetTexture("Interface\\Common\\ReputationStar")
        starTexture:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- Gray color
    end
    
    -- Star click handler
    starFrame:SetScript("OnClick", function(self)
        if itemID and GRC.Favorites and GRC.Favorites.ToggleFavorite then
            local success = GRC.Favorites.ToggleFavorite(itemID, itemType, item.name)
            if success then
                -- Update star appearance
                local newFavorited = GRC.Favorites.IsFavorited(itemID, itemType)
                if newFavorited then
                    starTexture:SetTexture("Interface\\Common\\FavoritesIcon")
                    starTexture:SetVertexColor(1, 0.84, 0, 1) -- Gold color
                else
                    starTexture:SetTexture("Interface\\Common\\ReputationStar")
                    starTexture:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- Gray color
                end
                
                -- Refresh UI to update counts
                C_Timer.After(0.1, function()
                    if GRC.UI and GRC.UI.RefreshUI then
                        GRC.UI.RefreshUI()
                    end
                end)
            end
        end
    end)
    
    -- Star hover effects
    starFrame:SetScript("OnEnter", function(self)
        if isFavorited then
            starTexture:SetVertexColor(1, 0.5, 0.5, 1) -- Red tint for removal
        else
            starTexture:SetVertexColor(1, 1, 0.5, 1) -- Yellow tint for addition
        end
        
        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(isFavorited and "Remove from Favorites" or "Add to Favorites", 1, 1, 1)
        GameTooltip:AddLine("Max " .. (GRC.Favorites and GRC.Favorites.MAX_FAVORITES_PER_TYPE or 10) .. " per category", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    
    starFrame:SetScript("OnLeave", function(self)
        -- Restore original color
        if isFavorited then
            starTexture:SetVertexColor(1, 0.84, 0, 1) -- Gold color
        else
            starTexture:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- Gray color
        end
        
        GameTooltip:Hide()
    end)
    
    -- Updated column positions and data (with new star column)
    local colPositions = {40, 265, 415, 555, 655, 735, 880} -- Removed first position (star is handled above)
    local colWidths = {220, 145, 135, 95, 75, 115, 100} -- Updated for compact name column
    
    -- ENHANCED: Tab-specific data with color-coded lockout display and FIXED toys support
    local data = {}
    if activeTab == "mounts" then
        -- Get enhanced lockout info using SimpleLockouts system
        local lockoutText, lockoutColor = "Always Available", "|cFFFFFFFF"
        
        if GRC.SimpleLockouts and GRC.SimpleLockouts.GetMountLockout then
            lockoutText, lockoutColor = GRC.SimpleLockouts.GetMountLockout(item)
        elseif item.lockoutInfo then
            lockoutText = item.lockoutInfo
            lockoutColor = item.lockoutColor or "|cFFFFFFFF"
        end
        
        data = {
            item.name or "Unknown",
            item.expansion or "Unknown", 
            item.category or "Unknown",
            item.dropRate or "Unknown",
            tostring(item.attempts or 0),
            lockoutText, -- Clean lockout text without embedded colors
            item.isCollected and "Collected" or "Missing"
        }
    elseif activeTab == "pets" then
        -- Enhanced pet lockout logic with specific colors
        local petLockout = "Always Available"
        local petLockoutColor = "|cFFFFFFFF" -- White for always
        
        if item.category == "Wild Pet" then
            petLockout = "Always Catchable"
            petLockoutColor = "|cFFFFFFFF" -- White for always
        elseif item.category == "Pet Battle" then
            petLockout = "Daily Battle"
            petLockoutColor = "|cFF00FF00" -- Green for daily
        elseif item.category == "Dungeon/Raid Drop" then
            petLockout = "Weekly Reset"
            petLockoutColor = "|cFFFF8800" -- Orange for weekly
        elseif item.category == "World Event" then
            petLockout = "Seasonal Event"
            petLockoutColor = "|cFF00CCFF" -- Light blue for seasonal
        end
        
        data = {
            item.name or "Unknown",
            item.expansion or "Unknown", 
            item.category or "Unknown",
            item.dropRate or "Unknown",
            tostring(item.attempts or 0),
            petLockout,
            item.isCollected and "Collected" or "Missing"
        }
        
        item._tempLockoutColor = petLockoutColor
        
    elseif activeTab == "toys" then
        -- FIXED: Enhanced toy lockout logic with proper support
        local toyLockout = "Always Available"
        local toyLockoutColor = "|cFFFFFFFF" -- White for always
        
        -- FIXED: Better toy categorization for lockouts
        if item.category == "Raid Drop" then
            toyLockout = "Weekly Reset"
            toyLockoutColor = "|cFFFF8800" -- Orange for weekly
        elseif item.category == "Dungeon Drop" then
            toyLockout = "Daily Reset"
            toyLockoutColor = "|cFF00FF00" -- Green for daily
        elseif item.category == "World Event" then
            toyLockout = "Seasonal Event"
            toyLockoutColor = "|cFF00CCFF" -- Light blue for seasonal
        elseif item.category == "Trading Post" then
            toyLockout = "Monthly Reset"
            toyLockoutColor = "|cFF00CCFF" -- Light blue for monthly
        elseif item.category == "Achievement" then
            toyLockout = "Always Available"
            toyLockoutColor = "|cFFFFFFFF" -- White for achievement
        elseif item.category == "Vendor" then
            toyLockout = "Always Available"
            toyLockoutColor = "|cFFFFFFFF" -- White for vendor
        elseif item.category == "Quest" then
            toyLockout = "Always Available"
            toyLockoutColor = "|cFFFFFFFF" -- White for quest
        end
        
        data = {
            item.name or "Unknown",
            item.expansion or "Unknown", 
            item.category or "Unknown",
            item.dropRate or "100%",  -- FIXED: Default to 100% for toys
            tostring(item.attempts or 0),
            toyLockout,
            item.isCollected and "Collected" or "Missing"
        }
        
        item._tempLockoutColor = toyLockoutColor
    end
    
    -- Enhanced colors for each column with proper lockout color handling
    local lockoutColor = "|cFFFFFFFF" -- Default white
    
    if activeTab == "mounts" and GRC.SimpleLockouts and GRC.SimpleLockouts.GetMountLockout then
        local _, color = GRC.SimpleLockouts.GetMountLockout(item)
        lockoutColor = color
    elseif item._tempLockoutColor then
        lockoutColor = item._tempLockoutColor
    end
    
    -- Convert color codes to RGB values for font string
    local lockoutRGB = {1, 1, 1, 1} -- Default white
    if lockoutColor == "|cFF00FF00" then
        lockoutRGB = {0, 1, 0, 1} -- Green for daily
    elseif lockoutColor == "|cFFFF8800" then
        lockoutRGB = {1, 0.53, 0, 1} -- Orange for weekly
    elseif lockoutColor == "|cFF00CCFF" then
        lockoutRGB = {0, 0.8, 1, 1} -- Light blue for monthly/seasonal
    elseif lockoutColor == "|cFFFFFFFF" then
        lockoutRGB = {1, 1, 1, 1} -- White for always
    elseif lockoutColor == "|cFF888888" then
        lockoutRGB = {0.53, 0.53, 0.53, 1} -- Gray for active lockouts
    end
    
    local colors = {
        item.isRemoved and COLORS.removed or (item.isCollected and COLORS.collected or COLORS.text),
        COLORS.textSecondary,
        COLORS.textSecondary,
        item.isRemoved and COLORS.removed or COLORS.textMuted,
        COLORS.textMuted,
        lockoutRGB, -- Specific color for lockout column
        item.isRemoved and COLORS.removed or (item.isCollected and COLORS.collected or COLORS.uncollected)
    }
    
    -- Create text elements with perfect positioning
    for i = 1, #data do
        local text = CreateFontString(row, data[i], 10, colors[i])
        if text then
            text:SetPoint("LEFT", colPositions[i], 0)
            text:SetSize(colWidths[i], 22)
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            text:SetNonSpaceWrap(false)
        end
    end
    
    -- ========================================================================
    -- NEW: ENHANCED LOCKOUT TOOLTIP FUNCTIONALITY - RARITY DATABASE BASED
    -- ========================================================================
    
    -- Create invisible frame over the lockout column (index 6) for enhanced tooltip
    local lockoutFrame = CreateFrame("Frame", nil, row)
    lockoutFrame:SetSize(colWidths[6], 22) -- Width of lockout column (115)
    lockoutFrame:SetPoint("LEFT", colPositions[6], 0) -- Position at lockout column (735)
    lockoutFrame:EnableMouse(true) -- Enable mouse for tooltip
    lockoutFrame:SetFrameLevel(row:GetFrameLevel() + 1) -- Ensure it's above the row
    
    -- Enhanced lockout tooltip functionality using Rarity database
    lockoutFrame:SetScript("OnEnter", function(self)
        -- Only show enhanced tooltip for items that can have lockouts
        if activeTab == "mounts" or 
           (activeTab == "pets" and (item.category == "Dungeon/Raid Drop" or item.category == "World Event")) or
           (activeTab == "toys" and (item.category == "Raid Drop" or item.category == "Dungeon Drop" or item.category == "World Event")) then
            
            -- Use the enhanced lockout tooltip that leverages Rarity database
            if GRC.SimpleLockouts and GRC.SimpleLockouts.ShowLockoutTooltip then
                GRC.SimpleLockouts.ShowLockoutTooltip(self, item) -- Pass the entire item object
            else
                -- Fallback to basic lockout info
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine("|cFFFFFF00Lockout Information|r", 1, 1, 1)
                GameTooltip:AddLine(data[6] or "No lockout data", 1, 1, 1)
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine("|cFFCCCCCCEnhanced lockout system not available|r", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        else
            -- For items without lockouts, show basic info
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cFFFFFF00Availability|r", 1, 1, 1)
            GameTooltip:AddLine(data[6] or "Always Available", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    
    lockoutFrame:SetScript("OnLeave", function(self)
        if GRC.SimpleLockouts and GRC.SimpleLockouts.HideLockoutTooltip then
            GRC.SimpleLockouts.HideLockoutTooltip()
        else
            GameTooltip:Hide()
        end
    end)
    
    -- ========================================================================
    -- END OF ENHANCED LOCKOUT TOOLTIP FUNCTIONALITY
    -- ========================================================================
    
    -- Clean up temporary color
    item._tempLockoutColor = nil
    
    -- Store item data for tooltip access
    row.itemData = item
    row.itemType = activeTab:sub(1, -2) -- Remove 's' from activeTab
    
    return row
end

-- FIXED: Create loading state row for when cache is building
function GRC.UI.CreateLoadingRow(parent, yOffset, message)
    if not parent then return nil end
    
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(1150, 40)
    row:SetPoint("TOPLEFT", 0, yOffset)
    
    -- Background
    CreateStyledBackground(row, {0.05, 0.05, 0.1, 0.6})
    
    -- Loading text
    local loadingText = CreateFontString(row, message or "Loading collection data...", 14, COLORS.loading)
    loadingText:SetPoint("CENTER")
    
    -- Simple animated dots
    local dots = CreateFontString(row, "", 14, COLORS.loading)
    dots:SetPoint("LEFT", loadingText, "RIGHT", 5, 0)
    
    local dotCount = 0
    local function animateDots()
        dotCount = (dotCount % 3) + 1
        dots:SetText(string.rep(".", dotCount))
    end
    
    -- Animate dots
    local ticker = C_Timer.NewTicker(0.5, animateDots)
    
    -- Stop animation when row is hidden
    row:SetScript("OnHide", function()
        if ticker then
            ticker:Cancel()
        end
    end)
    
    return row
end

-- FIXED: Instant refresh with proper loading states and favorites filtering and TOYS support
function GRC.UI.InstantRefreshItemList()
    if not GRC.UI.ItemList then 
        GRC.Debug.UIInfo("ItemList not created yet")
        return 
    end
    
    -- INSTANT: Clear existing rows
    if GRC.UI.ItemList.contentFrame then
        local children = {GRC.UI.ItemList.contentFrame:GetChildren()}
        for _, child in pairs(children) do
            if child then
                child:Hide()
                child:ClearAllPoints()
                child:SetParent(nil)
            end
        end
    end
    
    -- Check cache state
    if not GRC.SmartCache then
        GRC.UI.SafeUpdateStatistics(0, 0, 0, "SmartCache not available")
        GRC.UI.CreateLoadingRow(GRC.UI.ItemList.contentFrame, 0, "SmartCache not available - Try /reload")
        return
    end
    
    if GRC.SmartCache.IsBuilding and GRC.SmartCache.IsBuilding() then
        GRC.UI.SafeUpdateStatistics(0, 0, 0, "Cache building...")
        GRC.UI.CreateLoadingRow(GRC.UI.ItemList.contentFrame, 0, "Building " .. activeTab .. " cache...")
        GRC.Debug.UIInfo("Cache is building, showing loading state")
        return
    end
    
    if not GRC.SmartCache.IsReady() then
        GRC.UI.SafeUpdateStatistics(0, 0, 0, "Cache not ready...")
        GRC.UI.CreateLoadingRow(GRC.UI.ItemList.contentFrame, 0, "Cache not ready - Please wait...")
        GRC.Debug.UIInfo("Cache not ready for UI refresh")
        return
    end
    
    -- INSTANT: Get items from memory cache with FIXED toys support
    local items = {}
    if activeTab == "mounts" then
        items = GRC.SmartCache.GetAllMounts()
    elseif activeTab == "pets" then
        items = GRC.SmartCache.GetAllPets()
    elseif activeTab == "toys" then
        items = GRC.SmartCache.GetAllToys()
        
        -- FIXED: Filter out placeholder items for toys
        local filteredToys = {}
        for _, toy in ipairs(items) do
            if toy.toyID and toy.toyID > 0 and toy.name ~= "ToyBox API not available" then
                table.insert(filteredToys, toy)
            end
        end
        items = filteredToys
    end
    
    GRC.Debug.UIInfo("Got %d items from cache for %s tab (instant)", #items, activeTab)
    
    -- Show empty state if no items
    if #items == 0 then
        local emptyMessage = "No " .. activeTab .. " found"
        if activeTab == "toys" then
            emptyMessage = "No toys found - ToyBox API may not be available"
        end
        GRC.UI.SafeUpdateStatistics(0, 0, 0, "No items available")
        GRC.UI.CreateLoadingRow(GRC.UI.ItemList.contentFrame, 0, emptyMessage)
        return
    end
    
    -- INSTANT: Apply filters
    local filteredItems = {}
    local showCollected = not GRC.UI.FilterPanel.collectedCheck or GRC.UI.FilterPanel.collectedCheck:GetChecked()
    local showUncollected = not GRC.UI.FilterPanel.uncollectedCheck or GRC.UI.FilterPanel.uncollectedCheck:GetChecked()
    local showFavoritesOnly = GRC.UI.FilterPanel.favoritesCheck and GRC.UI.FilterPanel.favoritesCheck:GetChecked() or false
    
    for _, item in ipairs(items) do
        local include = true
        
        -- Collection filter
        if not showCollected and item.isCollected then
            include = false
        end
        
        if not showUncollected and not item.isCollected then
            include = false
        end
        
        -- Favorites filter with FIXED toys support
        if showFavoritesOnly then
            local itemID = nil
            local itemType = activeTab:sub(1, -2) -- Remove 's'
            if activeTab == "mounts" then
                itemID = item.spellID
            elseif activeTab == "pets" then
                itemID = item.speciesID
            elseif activeTab == "toys" then
                itemID = item.toyID or item.itemID  -- FIXED: Proper toy ID handling
            end
            
            if not itemID or not GRC.Favorites or not GRC.Favorites.IsFavorited(itemID, itemType) then
                include = false
            end
        end
        
        -- Search filter
        if currentSearch and currentSearch ~= "" then
            local searchLower = currentSearch:lower()
            local nameMatch = item.name and item.name:lower():find(searchLower, 1, true)
            local expansionMatch = item.expansion and item.expansion:lower():find(searchLower, 1, true)
            local categoryMatch = item.category and item.category:lower():find(searchLower, 1, true)
            local sourceMatch = item.sourceText and item.sourceText:lower():find(searchLower, 1, true)
            
            if not (nameMatch or expansionMatch or categoryMatch or sourceMatch) then
                include = false
            end
        end
        
        -- Expansion filter
        local hasExpansionFilter = false
        for _, selected in pairs(selectedExpansions) do
            if selected then
                hasExpansionFilter = true
                break
            end
        end
        
        if hasExpansionFilter then
            if not selectedExpansions[item.expansion] then
                include = false
            end
        end
        
        -- Category filter
        local hasCategoryFilter = false
        for _, selected in pairs(selectedCategories) do
            if selected then
                hasCategoryFilter = true
                break
            end
        end
        
        if hasCategoryFilter then
            if not selectedCategories[item.category] then
                include = false
            end
        end
        
        if include then
            table.insert(filteredItems, item)
        end
    end
    
    -- INSTANT: Sort items
    table.sort(filteredItems, function(a, b)
        if not a or not b then return false end
        local aVal = a.name or ""
        local bVal = b.name or ""
        return aVal < bVal
    end)
    
    -- Show empty state if no filtered results
    if #filteredItems == 0 then
        local message = "No items match your filters"
        if showFavoritesOnly then
            message = "No favorites found"
        end
        GRC.UI.SafeUpdateStatistics(0, #filteredItems, #items, "No matches")
        GRC.UI.CreateLoadingRow(GRC.UI.ItemList.contentFrame, 0, message)
        return
    end
    
    -- INSTANT: Render all rows at once (no chunks for instant display)
    local totalRows = #filteredItems
    
    for i, item in ipairs(filteredItems) do
        local yOffset = -((i - 1) * 22)
        GRC.UI.CreateSafeItemRow(GRC.UI.ItemList.contentFrame, item, yOffset)
    end
    
    -- INSTANT: Update content frame size
    local totalHeight = math.max(100, totalRows * 22 + 10)
    if GRC.UI.ItemList.contentFrame then
        GRC.UI.ItemList.contentFrame:SetHeight(totalHeight)
        GRC.UI.ItemList.contentFrame:SetWidth(1150)
    end
    
    -- INSTANT: Final statistics update
    GRC.UI.SafeUpdateStatistics(totalRows, totalRows, #items)
    
    GRC.Debug.UIInfo("Rendered %d rows for %s tab with enhanced lockout display (instant)", totalRows, activeTab)
end

-- Enhanced statistics update with better filter info and search results
function GRC.UI.SafeUpdateStatistics(displayed, filtered, total, loadingText)
    if not GRC.UI.MainFrame or not GRC.UI.MainFrame.statsText then return end
    
    if loadingText then
        GRC.UI.MainFrame.statsText:SetText(loadingText)
        return
    end
    
    local collected = 0
    local tabName = activeTab:gsub("^%l", string.upper)
    
    if GRC.Core and GRC.Core.GetStatistics then
        local success, stats = pcall(GRC.Core.GetStatistics)
        if success and stats then
            if activeTab == "mounts" then
                collected = stats.collectedMounts or 0
                total = stats.totalMounts or total
            elseif activeTab == "pets" then
                collected = stats.collectedPets or 0
                total = stats.totalPets or total
            elseif activeTab == "toys" then
                collected = stats.collectedToys or 0
                total = stats.totalToys or total
            end
        end
    end
    
    local percentage = total > 0 and (collected / total) * 100 or 0
    
    -- Show filter information in stats
    local filterInfo = ""
    local activeFilters = 0
    
    for _, selected in pairs(selectedExpansions) do
        if selected then activeFilters = activeFilters + 1 end
    end
    
    for _, selected in pairs(selectedCategories) do
        if selected then activeFilters = activeFilters + 1 end
    end
    
    if activeFilters > 0 then
        filterInfo = string.format(" [%d filters]", activeFilters)
    end
    
    -- Add search info
    local searchInfo = ""
    if currentSearch and currentSearch ~= "" then
        if displayed < total then
            searchInfo = string.format(" [Search: \"%s\"]", currentSearch)
        end
    end
    
    -- Add favorites info
    local favoritesInfo = ""
    if GRC.UI.FilterPanel and GRC.UI.FilterPanel.favoritesCheck and GRC.UI.FilterPanel.favoritesCheck:GetChecked() then
        favoritesInfo = " [Favorites Only]"
    end
    
    -- Add tooltip status info
    local tooltipInfo = ""
    if GRC.Tooltip and GRC.Tooltip.IsEnabled() then
        tooltipInfo = " [Tooltips: ON]"
    end
    
    -- Show cache status if applicable
    local cacheInfo = ""
    if GRC.SmartCache then
        if GRC.SmartCache.IsBuilding and GRC.SmartCache.IsBuilding() then
            cacheInfo = " [Building...]"
        elseif not GRC.SmartCache.IsReady() then
            cacheInfo = " [Cache not ready]"
        end
    end
    
    GRC.UI.MainFrame.statsText:SetText(string.format(
        "%s - Showing: %d | Total: %d | Collected: %d (%.1f%%)%s%s%s%s%s",
        tabName, displayed, total, collected, percentage, filterInfo, searchInfo, favoritesInfo, tooltipInfo, cacheInfo
    ))
end

-- FIXED: Main UI functions with better first load handling
function GRC.UI.ToggleUI()
    GRC.Debug.UIInfo("ToggleUI called (instant mode)")
    
    if not GRC.UI.MainFrame then
        GRC.Debug.UIInfo("Creating UI frames...")
        GRC.UI.CreateMainFrame()
        GRC.UI.CreateTabBar()
        GRC.UI.CreateFilterPanel()
        GRC.UI.CreateItemList()
    end
    
    if GRC.UI.MainFrame:IsShown() then
        GRC.UI.MainFrame:Hide()
        GRC.Debug.UIInfo("UI hidden")
    else
        GRC.UI.MainFrame:Show()
        GRC.Debug.UIInfo("UI shown, loading instantly...")
        
        -- Show immediately with proper loading states
        GRC.UI.UpdateFiltersForTab()
        GRC.UI.InstantRefreshItemList()
        
        -- Check cache status and show appropriate messages
        if GRC.SmartCache then
            if GRC.SmartCache.IsBuilding and GRC.SmartCache.IsBuilding() then
                print("|cFFFF6B35GRC:|r Cache is building - Interface will update automatically when ready")
            elseif not GRC.SmartCache.IsReady() then
                print("|cFFFF6B35GRC:|r Cache not ready - Please wait or try /grc refresh")
            end
        else
            print("|cFFFF6B35GRC:|r SmartCache not available - Try /reload")
        end
    end
end

-- INSTANT: Refresh UI with no delays
function GRC.UI.RefreshUI()
    if GRC.UI.MainFrame and GRC.UI.MainFrame:IsShown() then
        GRC.UI.InstantRefreshItemList()
    end
end

-- Backward compatibility
GRC.UI.SafeRefreshItemList = GRC.UI.InstantRefreshItemList
GRC.UI.ForceRefreshUI = GRC.UI.RefreshUI

-- ENHANCED: Mount Journal opener with INSTANT selection (NO DELAYS)
function GRC.Core.PreviewMount(mountID)
    if not mountID then 
        print("|cFFFF6B35GRC:|r Invalid mount ID for preview")
        return false
    end
    
    -- ENHANCED: Open mount journal and make mount active for preview - INSTANT
    local function OpenMountInJournal(mountID)
        -- Load Collections UI if needed
        if CollectionsJournal_LoadUI then
            CollectionsJournal_LoadUI()
        end
        
        -- Open the collections journal to mounts tab
        if not CollectionsJournal or not CollectionsJournal:IsShown() then
            ToggleCollectionsJournal(1) -- 1 = Mount Journal tab
        else
            -- If already open, just switch to mounts tab
            CollectionsJournal_SetTab(CollectionsJournal, 1)
        end
        
        -- INSTANT: No delays, work with whatever is already loaded
        if MountJournal and C_MountJournal then
            -- Clear any existing search and filters first
            if MountJournalSearchBox and MountJournalSearchBox.SetText then
                MountJournalSearchBox:SetText("")
            end
            
            if C_MountJournal.ClearAllFilters then
                C_MountJournal.ClearAllFilters()
            end
            
            if C_MountJournal.SetSearch then
                C_MountJournal.SetSearch("")
            end
            
            -- Force immediate refresh
            if MountJournal_UpdateMountList then
                MountJournal_UpdateMountList()
            end
            
            -- Get mount info using multiple ID types
            local mountName, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected
            
            -- Try to get mount info by ID (mountID could be spellID or mountID)
            if C_MountJournal.GetMountInfoByID then
                mountName, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            end
            
            -- If that didn't work, try treating it as a spell ID
            if not mountName and C_MountJournal.GetMountFromSpell then
                local actualMountID = C_MountJournal.GetMountFromSpell(mountID)
                if actualMountID then
                    mountName, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(actualMountID)
                    mountID = actualMountID -- Update to use the correct mount ID
                end
            end
            
            if GRCollectorSettings and GRCollectorSettings.debugMode then
                print("|cFFFF6B35GRC Debug:|r Looking for mount: " .. (mountName or "Unknown") .. " (ID: " .. mountID .. ", SpellID: " .. (spellID or "none") .. ")")
            end
            
            -- INSTANT: Find and select the mount in the displayed list immediately
            local foundMount = false
            local numDisplayedMounts = C_MountJournal.GetNumDisplayedMounts()
            
            if GRCollectorSettings and GRCollectorSettings.debugMode then
                print("|cFFFF6B35GRC Debug:|r Searching through " .. numDisplayedMounts .. " displayed mounts...")
            end
            
            for i = 1, numDisplayedMounts do
                local displayedName, displayedSpellID, displayedIcon, displayedActive, displayedUsable, displayedSourceType, displayedFavorite, displayedFactionSpecific, displayedFaction, displayedShouldHide, displayedCollected, displayedMountID = C_MountJournal.GetDisplayedMountInfo(i)
                
                -- Check multiple matching criteria
                local isMatch = false
                if displayedMountID == mountID then
                    isMatch = true
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print("|cFFFF6B35GRC Debug:|r Found mount by mountID match at index " .. i)
                    end
                elseif displayedSpellID == mountID then
                    isMatch = true
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print("|cFFFF6B35GRC Debug:|r Found mount by spellID match at index " .. i)
                    end
                elseif spellID and displayedSpellID == spellID then
                    isMatch = true
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print("|cFFFF6B35GRC Debug:|r Found mount by cross-spellID match at index " .. i)
                    end
                elseif mountName and displayedName and displayedName:lower() == mountName:lower() then
                    isMatch = true
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print("|cFFFF6B35GRC Debug:|r Found mount by name match at index " .. i)
                    end
                end
                
                if isMatch then
                    foundMount = true
                    
                    -- INSTANT: Try multiple selection methods immediately
                    local selectionMethods = {
                        function()
                            if MountJournal_Select then
                                MountJournal_Select(i)
                                return "MountJournal_Select"
                            end
                            return false
                        end,
                        function()
                            if MountJournal.selectedMountID then
                                MountJournal.selectedMountID = displayedMountID
                                if MountJournal_UpdateMountDisplay then
                                    MountJournal_UpdateMountDisplay()
                                end
                                return "Direct selectedMountID"
                            end
                            return false
                        end,
                        function()
                            -- Force update the display manually
                            if MountJournal_UpdateMountDisplay then
                                MountJournal_UpdateMountDisplay()
                                return "Manual display update"
                            end
                            return false
                        end,
                        function()
                            -- Try setting the mount display directly
                            if MountJournalMountDisplay and MountJournalMountDisplay.SetDisplayInfo then
                                MountJournalMountDisplay:SetDisplayInfo(displayedMountID)
                                return "SetDisplayInfo"
                            end
                            return false
                        end
                    }
                    
                    local methodUsed = false
                    for methodIndex, method in ipairs(selectionMethods) do
                        local success, result = pcall(method)
                        if success and result then
                            methodUsed = result
                            if GRCollectorSettings and GRCollectorSettings.debugMode then
                                print("|cFFFF6B35GRC Debug:|r Mount selected using: " .. result)
                            end
                            break
                        end
                    end
                    
                    -- INSTANT: Force model update immediately
                    if MountJournalMountDisplay and MountJournalMountDisplay.ModelScene then
                        local modelScene = MountJournalMountDisplay.ModelScene
                        if modelScene and modelScene.SetFromModelSceneID then
                            pcall(function()
                                modelScene:SetFromModelSceneID(displayedSpellID or spellID or mountID)
                            end)
                        end
                    end
                    
                    print("|cFFFF6B35GRC:|r Mount selected in journal: " .. (mountName or displayedName or "Unknown"))
                    break
                end
            end
            
            if not foundMount then
                if GRCollectorSettings and GRCollectorSettings.debugMode then
                    print("|cFFFF6B35GRC Debug:|r Mount not found in displayed list, trying search fallback...")
                end
                
                -- INSTANT: Search fallback without delays
                if mountName then
                    if C_MountJournal.SetSearch then
                        C_MountJournal.SetSearch(mountName)
                        print("|cFFFF6B35GRC:|r Searched for mount: " .. mountName)
                        
                        -- Try immediate selection of first result
                        local searchResults = C_MountJournal.GetNumDisplayedMounts()
                        if searchResults > 0 and MountJournal_Select then
                            MountJournal_Select(1) -- Select first search result
                            print("|cFFFF6B35GRC:|r Selected first search result")
                        end
                    elseif MountJournalSearchBox and MountJournalSearchBox.SetText then
                        MountJournalSearchBox:SetText(mountName)
                        if MountJournalSearchBox.OnTextChanged then
                            MountJournalSearchBox:OnTextChanged()
                        end
                        print("|cFFFF6B35GRC:|r Searched for mount: " .. mountName)
                    end
                else
                    print("|cFFFF6B35GRC:|r No mount name available for search, opening journal only")
                end
            end
        else
            print("|cFFFF6B35GRC:|r Mount Journal not available")
        end
        
        return true
    end
    
    local success = OpenMountInJournal(mountID)
    if success then
        return true
    else
        print("|cFFFF6B35GRC:|r Failed to open Mount Journal")
        return false
    end
end

-- FIXED: Pet Journal opener with INSTANT selection (NO DELAYS)
function GRC.Core.PreviewPet(speciesID)
    if not speciesID then 
        print("|cFFFF6B35GRC:|r Invalid pet species ID for preview")
        return false
    end
    
    -- ENHANCED: Open pet journal and make pet active for preview - INSTANT
    local function OpenPetInJournal(speciesID)
        -- Method 1: Try opening Collections Journal directly to pet
        if CollectionsJournal_LoadUI then
            CollectionsJournal_LoadUI()
        end
        
        -- Open the collections journal
        if not CollectionsJournal or not CollectionsJournal:IsShown() then
            ToggleCollectionsJournal(2) -- 2 = Pet Journal tab
        else
            -- If already open, just switch to pets tab
            CollectionsJournal_SetTab(CollectionsJournal, 2)
        end
        
        -- INSTANT: No delays, work with whatever is already loaded
        if PetJournal and C_PetJournal then
            -- Clear any existing search and filters immediately
            if PetJournalSearchBox and PetJournalSearchBox.SetText then
                PetJournalSearchBox:SetText("")
            end
            
            if C_PetJournal.ClearSearchFilter then
                C_PetJournal.ClearSearchFilter()
            end
            
            -- Clear all filters to ensure pet is visible
            if C_PetJournal.SetAllPetTypesFilter then
                C_PetJournal.SetAllPetTypesFilter(true)
            end
            
            if C_PetJournal.SetAllPetSourcesFilter then
                C_PetJournal.SetAllPetSourcesFilter(true)
            end
            
            -- Force immediate refresh
            if PetJournal_UpdatePetList then
                PetJournal_UpdatePetList()
            end
            
            -- Get pet info
            local petName, icon, petType, creatureID, sourceText, canBattle, isTradeable, isUnique, obtainable = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
            
            if GRCollectorSettings and GRCollectorSettings.debugMode then
                print("|cFFFF6B35GRC Debug:|r Looking for pet: " .. (petName or "Unknown") .. " (SpeciesID: " .. speciesID .. ", CreatureID: " .. (creatureID or "none") .. ")")
            end
            
            -- INSTANT: Find and select the pet immediately
            local foundPet = false
            local numPets = C_PetJournal.GetNumPets()
            
            if GRCollectorSettings and GRCollectorSettings.debugMode then
                print("|cFFFF6B35GRC Debug:|r Searching through " .. numPets .. " pets...")
            end
            
            for i = 1, numPets do
                local petID, species, owned, customName, level, favorite, isRevoked, speciesName, icon, petType, companionID, tooltip, description, isWild, canBattle, isTradeable, isUnique, obtainable = C_PetJournal.GetPetInfoByIndex(i)
                
                -- Check if this is our pet
                if species == speciesID then
                    foundPet = true
                    
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print("|cFFFF6B35GRC Debug:|r Found pet at index " .. i .. ": " .. (speciesName or petName or "Unknown"))
                    end
                    
                    -- INSTANT: Try multiple selection methods immediately
                    local selectionMethods = {
                        function()
                            if PetJournal_ShowPetCard then
                                PetJournal_ShowPetCard(i)
                                return "PetJournal_ShowPetCard"
                            end
                            return false
                        end,
                        function()
                            if C_PetJournal.SetPetLoadOutInfo then
                                C_PetJournal.SetPetLoadOutInfo(1, petID)
                                return "SetPetLoadOutInfo"
                            end
                            return false
                        end,
                        function()
                            if PetJournal_SelectSpecies then
                                PetJournal_SelectSpecies(PetJournal, speciesID)
                                return "PetJournal_SelectSpecies"
                            end
                            return false
                        end,
                        function()
                            -- Manual selection update
                            if PetJournal.selectedPetID then
                                PetJournal.selectedPetID = petID
                                if PetJournal_UpdatePetLoadOut then
                                    PetJournal_UpdatePetLoadOut()
                                end
                                return "Manual selectedPetID"
                            end
                            return false
                        end,
                        function()
                            -- Force display update
                            if PetJournal_UpdatePetDisplay then
                                PetJournal_UpdatePetDisplay()
                                return "UpdatePetDisplay"
                            end
                            return false
                        end
                    }
                    
                    local methodUsed = false
                    for methodIndex, method in ipairs(selectionMethods) do
                        local success, result = pcall(method)
                        if success and result then
                            methodUsed = result
                            if GRCollectorSettings and GRCollectorSettings.debugMode then
                                print("|cFFFF6B35GRC Debug:|r Pet selected using: " .. result)
                            end
                            break
                        end
                    end
                    
                    -- INSTANT: Force model update immediately
                    if PetJournalPetCard and PetJournalPetCard.PetInfo and PetJournalPetCard.PetInfo.modelScene then
                        local modelScene = PetJournalPetCard.PetInfo.modelScene
                        if modelScene and modelScene.SetFromModelSceneID then
                            local displayInfo = C_PetJournal.GetPetModelSceneInfoBySpeciesID(speciesID)
                            if displayInfo then
                                pcall(function()
                                    modelScene:SetFromModelSceneID(displayInfo)
                                end)
                            end
                        end
                    end
                    
                    print("|cFFFF6B35GRC:|r Pet selected in journal: " .. (petName or speciesName or "Unknown"))
                    break
                end
            end
            
            if not foundPet then
                if GRCollectorSettings and GRCollectorSettings.debugMode then
                    print("|cFFFF6B35GRC Debug:|r Pet not found in list, trying search fallback...")
                end
                
                -- INSTANT: Search fallback without delays
                if petName then
                    if C_PetJournal.SetSearchFilter then
                        C_PetJournal.SetSearchFilter(petName)
                        print("|cFFFF6B35GRC:|r Searched for pet: " .. petName)
                        
                        -- Try immediate selection of first result
                        local searchResults = C_PetJournal.GetNumPets()
                        if searchResults > 0 then
                            local petID, species = C_PetJournal.GetPetInfoByIndex(1)
                            if species == speciesID and PetJournal_ShowPetCard then
                                PetJournal_ShowPetCard(1)
                                print("|cFFFF6B35GRC:|r Selected first search result")
                            end
                        end
                    elseif PetJournalSearchBox and PetJournalSearchBox.SetText then
                        PetJournalSearchBox:SetText(petName)
                        if PetJournalSearchBox.OnTextChanged then
                            PetJournalSearchBox:OnTextChanged()
                        end
                        print("|cFFFF6B35GRC:|r Searched for pet: " .. petName)
                    end
                else
                    print("|cFFFF6B35GRC:|r No pet name available for search, opening journal only")
                end
            end
            
            -- Force UI refresh immediately
            if PetJournal_UpdatePetList then
                PetJournal_UpdatePetList()
            end
            
            if PetJournal_UpdatePetLoadOut then
                PetJournal_UpdatePetLoadOut()
            end
        else
            print("|cFFFF6B35GRC:|r Pet Journal not available")
        end
        
        return true
    end
    
    local success = OpenPetInJournal(speciesID)
    if success then
        return true
    else
        print("|cFFFF6B35GRC:|r Failed to open Pet Journal")
        return false
    end
end

-- Debug Info Helper
if not GRC.Debug then
    GRC.Debug = {}
    function GRC.Debug.UIInfo(msg, ...)
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print("|cFFFF6B35GRC Debug:|r " .. string.format(msg, ...))
        end
    end
    function GRC.Debug.Info(category, msg)
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print("|cFFFF6B35GRC " .. category .. ":|r " .. msg)
        end
    end
end

GRC.Debug.Info("UI", "COMPLETE GUI.lua with ENHANCED LOCKOUT TOOLTIPS integrated")