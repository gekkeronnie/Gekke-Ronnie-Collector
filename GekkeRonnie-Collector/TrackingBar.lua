-- TrackingBar.lua - COMPLETE with Smart Event Filtering + Boss Kill Refresh
local addonName, GRC = ...
GRC.TrackingBar = GRC.TrackingBar or {}

-- Settings for tracking bar (account-wide through favorites system)
GRCollectorTrackingSettings = GRCollectorTrackingSettings or {
    visible = true,
    locked = false,
    anchor = false,
    scale = 1.0,
    width = 650, -- Wider for 3 columns
    height = 18,  -- Slightly smaller individual bars
    font = "Friz Quadrata TT",
    fontSize = 9,
    texture = "Blizzard",
    showIcon = true,
    showText = true,
    showPercentage = true,
    growUp = false,
    rightAligned = false,
    maxBarsPerColumn = 10, -- 10 per column
    showOnlyUncollected = false,
    columnSpacing = 210, -- Space between columns
    rowSpacing = 0, -- Space between rows (0 = no spacing)
    noMouseInteraction = true, -- Don't interact with mouse (enabled by default)
    enabledColumns = { -- Which columns to show
        mounts = true,
        pets = true,
        toys = true
    }
}

-- Ensure enabledColumns exists (fix for nil value error)
if not GRCollectorTrackingSettings.enabledColumns then
    GRCollectorTrackingSettings.enabledColumns = {
        mounts = true,
        pets = true,
        toys = true
    }
end

-- Ensure other new settings exist
if GRCollectorTrackingSettings.rowSpacing == nil then
    GRCollectorTrackingSettings.rowSpacing = 0
end
if GRCollectorTrackingSettings.noMouseInteraction == nil then
    GRCollectorTrackingSettings.noMouseInteraction = true
end

-- Tracking bar frame
local trackingBarGroup = nil
local activeBars = {}
local isInitialized = false

-- Simple refresh control without delays
local lastAttemptDataHash = ""

-- Available textures and fonts (fallbacks)
local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-- Colors for different item types and statuses
local BAR_COLORS = {
    mount = {r = 0.8, g = 0.3, b = 0.3, a = 1}, -- Red-ish for mounts
    pet = {r = 0.3, g = 0.8, b = 0.3, a = 1},   -- Green-ish for pets
    toy = {r = 0.3, g = 0.3, b = 0.8, a = 1},   -- Blue-ish for toys
    collected = {r = 0.2, g = 0.8, b = 0.2, a = 1}, -- Bright green for collected
    background = {r = 0.1, g = 0.1, b = 0.1, a = 0.6} -- Darker, more transparent background
}

-- Enhanced attempt data synchronization
local function GetLatestAttemptData(item, itemType)
    local attempts = item.attempts or 0
    local charactersTracked = item.charactersTracked or 0
    local lastAttempt = item.lastAttempt
    local sessionAttempts = item.sessionAttempts or 0
    
    -- Try to get fresh data from Rarity if available
    if GRC.RarityDataImporter and GRC.RarityDataImporter.GetLatestAttemptData then
        local freshData = GRC.RarityDataImporter.GetLatestAttemptData(item, itemType)
        if freshData then
            attempts = freshData.attempts or attempts
            charactersTracked = freshData.charactersTracked or charactersTracked
            lastAttempt = freshData.lastAttempt or lastAttempt
            sessionAttempts = freshData.sessionAttempts or sessionAttempts
        end
    end
    
    -- Try to get live tracking data if available
    if GRC.AttemptsTracker then
        local liveData = nil
        if itemType == "mount" and item.spellID then
            liveData = GRC.AttemptsTracker.GetMountAttempts(item.mountID or item.spellID, item.spellID)
        elseif itemType == "pet" and item.speciesID then
            liveData = GRC.AttemptsTracker.GetPetAttempts(item.speciesID)
        elseif itemType == "toy" and item.toyID then
            liveData = GRC.AttemptsTracker.GetToyAttempts(item.toyID)
        end
        
        if liveData and liveData.totalAttempts > attempts then
            attempts = liveData.totalAttempts
            charactersTracked = liveData.charactersTracked or charactersTracked
            lastAttempt = liveData.lastAttempt or lastAttempt
            sessionAttempts = liveData.sessionAttempts or sessionAttempts
        end
    end
    
    return {
        attempts = attempts,
        charactersTracked = charactersTracked,
        lastAttempt = lastAttempt,
        sessionAttempts = sessionAttempts
    }
end

-- Create data hash for change detection
local function CreateAttemptDataHash()
    if not GRC.Favorites or not GRC.Favorites.GetFavoriteItems then
        return ""
    end
    
    local hashData = {}
    local itemTypes = {"mount", "pet", "toy"}
    
    for _, itemType in ipairs(itemTypes) do
        local favorites = GRC.Favorites.GetFavoriteItems(itemType)
        for _, item in ipairs(favorites) do
            local latestData = GetLatestAttemptData(item, itemType)
            local key = string.format("%s_%s", itemType, item.name or "unknown")
            hashData[key] = string.format("%d_%d_%s", 
                latestData.attempts, 
                latestData.charactersTracked,
                latestData.lastAttempt or "never")
        end
    end
    
    -- Create simple hash
    local hashString = ""
    for key, value in pairs(hashData) do
        hashString = hashString .. key .. ":" .. value .. ";"
    end
    
    return hashString
end

-- Check if attempt data has changed
local function HasAttemptDataChanged()
    local currentHash = CreateAttemptDataHash()
    local hasChanged = currentHash ~= lastAttemptDataHash
    
    if hasChanged then
        lastAttemptDataHash = currentHash
        GRC.Debug.Trace("TrackingBar", "Attempt data changed, refresh needed")
    end
    
    return hasChanged
end

-- Initialize settings function
local function InitializeTrackingSettings()
    -- Ensure the main settings table exists
    if not GRCollectorTrackingSettings then
        GRCollectorTrackingSettings = {}
    end
    
    -- Set default values for all settings
    if GRCollectorTrackingSettings.visible == nil then GRCollectorTrackingSettings.visible = true end
    if GRCollectorTrackingSettings.locked == nil then GRCollectorTrackingSettings.locked = false end
    if GRCollectorTrackingSettings.scale == nil then GRCollectorTrackingSettings.scale = 1.0 end
    if GRCollectorTrackingSettings.width == nil then GRCollectorTrackingSettings.width = 650 end
    if GRCollectorTrackingSettings.height == nil then GRCollectorTrackingSettings.height = 18 end
    if GRCollectorTrackingSettings.fontSize == nil then GRCollectorTrackingSettings.fontSize = 9 end
    if GRCollectorTrackingSettings.showIcon == nil then GRCollectorTrackingSettings.showIcon = true end
    if GRCollectorTrackingSettings.showText == nil then GRCollectorTrackingSettings.showText = true end
    if GRCollectorTrackingSettings.showPercentage == nil then GRCollectorTrackingSettings.showPercentage = true end
    if GRCollectorTrackingSettings.maxBarsPerColumn == nil then GRCollectorTrackingSettings.maxBarsPerColumn = 10 end
    if GRCollectorTrackingSettings.showOnlyUncollected == nil then GRCollectorTrackingSettings.showOnlyUncollected = false end
    if GRCollectorTrackingSettings.columnSpacing == nil then GRCollectorTrackingSettings.columnSpacing = 210 end
    if GRCollectorTrackingSettings.rowSpacing == nil then GRCollectorTrackingSettings.rowSpacing = 0 end
    if GRCollectorTrackingSettings.noMouseInteraction == nil then GRCollectorTrackingSettings.noMouseInteraction = true end
    
    -- Ensure enabledColumns exists with proper structure
    if not GRCollectorTrackingSettings.enabledColumns then
        GRCollectorTrackingSettings.enabledColumns = {}
    end
    if GRCollectorTrackingSettings.enabledColumns.mounts == nil then GRCollectorTrackingSettings.enabledColumns.mounts = true end
    if GRCollectorTrackingSettings.enabledColumns.pets == nil then GRCollectorTrackingSettings.enabledColumns.pets = true end
    if GRCollectorTrackingSettings.enabledColumns.toys == nil then GRCollectorTrackingSettings.enabledColumns.toys = true end
end

-- Column information - now dynamically calculated based on enabled columns
local function GetActiveColumns()
    -- Ensure settings are initialized before accessing them
    InitializeTrackingSettings()
    
    local activeColumns = {}
    local xPosition = 10
    
    -- Safe access to enabledColumns with fallback
    local enabledColumns = GRCollectorTrackingSettings.enabledColumns or {mounts = true, pets = true, toys = true}
    
    if enabledColumns.mounts then
        table.insert(activeColumns, {type = "mount", title = "Mounts", x = xPosition})
        xPosition = xPosition + (GRCollectorTrackingSettings.columnSpacing or 210)
    end
    
    if enabledColumns.pets then
        table.insert(activeColumns, {type = "pet", title = "Pets", x = xPosition})
        xPosition = xPosition + (GRCollectorTrackingSettings.columnSpacing or 210)
    end
    
    if enabledColumns.toys then
        table.insert(activeColumns, {type = "toy", title = "Toys & Items", x = xPosition})
        xPosition = xPosition + (GRCollectorTrackingSettings.columnSpacing or 210)
    end
    
    return activeColumns
end

-- Initialize tracking bar system
function GRC.TrackingBar.Initialize()
    if isInitialized then return end
    
    -- Initialize settings first thing
    InitializeTrackingSettings()
    
    GRC.Debug.Info("TrackingBar", "Initializing enhanced tracking bar system")
    
    -- Calculate total width based on enabled columns
    local activeColumns = GetActiveColumns()
    
    -- Dynamic width calculation based on actual active columns
    local totalWidth = 0
    if #activeColumns == 1 then
        totalWidth = 240 -- Single column width
    elseif #activeColumns == 2 then
        totalWidth = 450 -- Two columns
    else
        totalWidth = 650 -- Three columns or more
    end
    
    -- Calculate total height for 10 bars per column plus headers
    local totalHeight = 35 + (GRCollectorTrackingSettings.maxBarsPerColumn * (GRCollectorTrackingSettings.height + GRCollectorTrackingSettings.rowSpacing)) + 20
    
    -- Get account-wide position from favorites system
    local position = {point = "CENTER", relativePoint = "CENTER", x = 0, y = -200}
    if GRC.Favorites and GRC.Favorites.GetTrackingPosition then
        position = GRC.Favorites.GetTrackingPosition()
    end
    
    -- Create main tracking bar group frame
    trackingBarGroup = CreateFrame("Frame", "GRCTrackingBarGroup", UIParent)
    trackingBarGroup:SetSize(totalWidth, totalHeight)
    trackingBarGroup:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
    trackingBarGroup:SetScale(GRCollectorTrackingSettings.scale)
    trackingBarGroup:SetMovable(true)
    trackingBarGroup:SetClampedToScreen(true)
    
    -- Set mouse interaction for the main frame based on settings
    if GRCollectorTrackingSettings.noMouseInteraction then
        trackingBarGroup:EnableMouse(false)
        trackingBarGroup:SetToplevel(false)
        -- Allow mouse events to pass through the main frame when interaction is disabled
    else
        trackingBarGroup:EnableMouse(true)
        trackingBarGroup:SetToplevel(true)
    end
    
    -- Create title bar area for dragging (always enabled for dragging when unlocked)
    local titleBarArea = CreateFrame("Frame", nil, trackingBarGroup)
    titleBarArea:SetPoint("TOPLEFT", 0, 0)
    titleBarArea:SetPoint("TOPRIGHT", 0, 0)
    titleBarArea:SetHeight(25)
    
    -- Title bar ALWAYS allows dragging when unlocked, regardless of mouse interaction setting
    titleBarArea:EnableMouse(true)
    titleBarArea:RegisterForDrag("LeftButton")
    titleBarArea:SetToplevel(true) -- Title bar should always be on top for dragging
    
    -- Drag functionality - ALWAYS works when unlocked, regardless of mouse interaction setting
    titleBarArea:SetScript("OnDragStart", function(self)
        if not GRCollectorTrackingSettings.locked then
            trackingBarGroup:StartMoving()
        end
    end)
    
    titleBarArea:SetScript("OnDragStop", function(self)
        trackingBarGroup:StopMovingOrSizing()
        -- Save position account-wide through favorites system
        local point, relativeTo, relativePoint, x, y = trackingBarGroup:GetPoint()
        
        if GRC.Favorites and GRC.Favorites.SaveTrackingPosition then
            GRC.Favorites.SaveTrackingPosition(point, relativePoint, x, y)
        end
        
        GRC.Debug.Trace("TrackingBar", "Position saved account-wide: %s %d,%d", point, x, y)
    end)
    
    -- Main title text (bigger and better) - centered
    local title = trackingBarGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cFFFF6B35GRC|r |cFF00D4AATracker|r")
    title:SetFont(DEFAULT_FONT, 14, "OUTLINE")
    title:SetTextColor(1, 1, 1, 1)
    trackingBarGroup.title = title
    
    -- Column headers - properly positioned for any number of columns
    trackingBarGroup.columnHeaders = {}
    for i, column in ipairs(activeColumns) do
        local header = trackingBarGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        
        -- Dynamic positioning based on actual column count and total width
        local columnWidth = totalWidth / #activeColumns
        local columnCenterX = (i - 1) * columnWidth + columnWidth / 2
        
        header:SetPoint("TOP", trackingBarGroup, "TOPLEFT", columnCenterX, -25)
        header:SetText("|cFF" .. (column.type == "mount" and "FF6B35" or column.type == "pet" and "00FF00" or "0099FF") .. column.title .. "|r")
        header:SetFont(DEFAULT_FONT, 11, "OUTLINE")
        header:SetJustifyH("CENTER")
        trackingBarGroup.columnHeaders[i] = header
    end
    
    -- Store reference to title bar for dragging
    trackingBarGroup.titleBarArea = titleBarArea
    
    isInitialized = true
    GRC.TrackingBar.RefreshData()
    GRC.TrackingBar.UpdateVisibility()
    
    GRC.Debug.Info("TrackingBar", "Enhanced tracking bar initialized with %d columns", #activeColumns)
end

-- Lightweight column refresh function - ONLY refreshes columns without full reinitialization
function GRC.TrackingBar.RefreshColumns()
    if not isInitialized or not trackingBarGroup then
        GRC.Debug.Info("TrackingBar", "Not initialized, using full refresh")
        GRC.TrackingBar.RefreshData()
        return
    end
    
    GRC.Debug.Info("TrackingBar", "Refreshing columns layout (lightweight)")
    
    -- Get new active columns configuration
    local activeColumns = GetActiveColumns()
    
    -- Calculate new frame width
    local totalWidth = 0
    if #activeColumns == 1 then
        totalWidth = 240
    elseif #activeColumns == 2 then
        totalWidth = 450
    else
        totalWidth = 650
    end
    
    -- Update main frame size
    trackingBarGroup:SetSize(totalWidth, trackingBarGroup:GetHeight())
    
    -- Clear existing column headers
    if trackingBarGroup.columnHeaders then
        for _, header in ipairs(trackingBarGroup.columnHeaders) do
            if header then
                header:Hide()
                header:SetParent(nil)
            end
        end
    end
    
    -- Create new column headers with proper positioning
    trackingBarGroup.columnHeaders = {}
    for i, column in ipairs(activeColumns) do
        local header = trackingBarGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        
        -- Dynamic positioning based on actual column count and total width
        local columnWidth = totalWidth / #activeColumns
        local columnCenterX = (i - 1) * columnWidth + columnWidth / 2
        
        header:SetPoint("TOP", trackingBarGroup, "TOPLEFT", columnCenterX, -25)
        header:SetText("|cFF" .. (column.type == "mount" and "FF6B35" or column.type == "pet" and "00FF00" or "0099FF") .. column.title .. "|r")
        header:SetFont(DEFAULT_FONT, 11, "OUTLINE")
        header:SetJustifyH("CENTER")
        trackingBarGroup.columnHeaders[i] = header
    end
    
    -- Refresh the data to update bar positions and content
    GRC.TrackingBar.RefreshData()
    
    GRC.Debug.Info("TrackingBar", "Column refresh complete - now showing %d columns", #activeColumns)
end

-- Create individual tracking bar for an item with progress percentage
function GRC.TrackingBar.CreateBar(item, itemType, columnIndex, rowIndex)
    if not trackingBarGroup then return nil end
    
    local activeColumns = GetActiveColumns()
    local column = activeColumns[columnIndex]
    if not column then return nil end
    
    local barHeight = GRCollectorTrackingSettings.height
    
    -- Dynamic bar width based on actual column count
    local totalWidth = trackingBarGroup:GetWidth()
    local columnWidth = totalWidth / #activeColumns
    local barWidth = columnWidth - 20 -- Leave some margin
    
    -- Dynamic column positioning
    local xOffset = (columnIndex - 1) * columnWidth + 10
    local yOffset = -((rowIndex - 1) * (barHeight + GRCollectorTrackingSettings.rowSpacing) + 45)
    
    -- Create bar frame
    local bar = CreateFrame("StatusBar", nil, trackingBarGroup)
    bar:SetSize(barWidth, barHeight)
    bar:SetPoint("TOPLEFT", xOffset, yOffset)
    bar:SetStatusBarTexture(DEFAULT_TEXTURE)
    
    -- Mouse interaction setting - allow mouse to pass through when disabled
    if GRCollectorTrackingSettings.noMouseInteraction then
        bar:EnableMouse(false)
        bar:SetMouseClickEnabled(false)
        bar:SetMouseMotionEnabled(false)
        -- IMPORTANT: This allows mouse events to pass through to elements behind the bar
        bar:SetToplevel(false)
    else
        bar:EnableMouse(true)
        bar:SetMouseClickEnabled(true)
        bar:SetMouseMotionEnabled(true)
        bar:SetToplevel(true)
    end
    
    -- Get latest attempt data for accurate progress calculation
    local latestData = GetLatestAttemptData(item, itemType)
    local attempts = latestData.attempts
    local charactersTracked = latestData.charactersTracked
    
    -- Calculate progress and set color
    local progress = 0
    local color = BAR_COLORS[itemType] or BAR_COLORS.mount
    
    if item.isCollected then
        color = BAR_COLORS.collected
        progress = 1.0 -- Full bar for collected items
    else
        -- Calculate progress based on attempts vs estimated attempts needed
        local estimatedNeeded = GRC.TrackingBar.GetEstimatedAttempts(item)
        progress = math.min(attempts / estimatedNeeded, 0.99) -- Never quite full until collected
    end
    
    bar:SetStatusBarColor(color.r, color.g, color.b, color.a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(progress)
    
    -- Background with better transparency
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(BAR_COLORS.background.r, BAR_COLORS.background.g, BAR_COLORS.background.b, BAR_COLORS.background.a)
    bar.bg = bg
    
    -- Icon (if enabled and smaller)
    if GRCollectorTrackingSettings.showIcon and item.icon then
        local icon = bar:CreateTexture(nil, "OVERLAY")
        icon:SetSize(barHeight - 1, barHeight - 1)
        icon:SetPoint("LEFT", 1, 0)
        icon:SetTexture(item.icon)
        bar.icon = icon
    end
    
    -- Text with progress percentage - use latest attempt data
    -- Replace the text content creation section in CreateBar function (around lines 380-420)
-- Text with progress percentage - use latest attempt data
if GRCollectorTrackingSettings.showText then
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetFont(DEFAULT_FONT, GRCollectorTrackingSettings.fontSize or 9, "OUTLINE")
    
    -- Position text
    local leftOffset = (GRCollectorTrackingSettings.showIcon and item.icon) and (barHeight + 2) or 5
    text:SetPoint("LEFT", leftOffset, 0)
    text:SetPoint("RIGHT", -5, 0)
    text:SetJustifyH("LEFT")
    
    -- Create text content with progress - use latest data
    local itemName = item.name or "Unknown"
    local suffixText = ""
    
    -- Calculate suffix text first
    if item.isCollected then
        -- Show attempt count for collected items
        if attempts > 0 then
            if GRCollectorTrackingSettings.showPercentage then
                suffixText = string.format(" (%d attempts)", attempts)
            else
                suffixText = string.format(" (%d)", attempts)
            end
        else
            suffixText = " (Collected)"
        end
    else
        local estimatedNeeded = GRC.TrackingBar.GetEstimatedAttempts(item)
        local percentage = math.floor((attempts / estimatedNeeded) * 100)
        
        if attempts > 0 then
            if GRCollectorTrackingSettings.showPercentage then
                suffixText = string.format(" (%d/%d - %d%%)", attempts, estimatedNeeded, percentage)
            else
                suffixText = string.format(" (%d)", attempts)
            end
        else
            suffixText = " (0)"
        end
    end
    
    -- Calculate available space for item name
    local availableWidth = barWidth - leftOffset - 5 -- Total width minus margins
    local suffixWidth = #suffixText * 4.5 -- Approximate character width for suffix
    local nameWidth = availableWidth - suffixWidth
    
    -- Calculate max characters for name based on available width
    local maxNameChars = math.floor(nameWidth / 5.5) -- Approximate character width
    
    -- Ensure minimum space for name (at least 8 characters)
    if maxNameChars < 8 then
        maxNameChars = 8
        -- If we can't fit a reasonable name, truncate the suffix too
        if #suffixText > 15 then
            suffixText = suffixText:sub(1, 12) .. "..."
        end
    end
    
    -- Truncate name if too long
    local displayName = itemName
    if #itemName > maxNameChars then
        displayName = itemName:sub(1, maxNameChars - 3) .. "..."
    end
    
    -- Combine name and suffix
    local textContent = displayName .. suffixText
    
    -- Final safety check - if still too long, aggressively truncate
    local maxTotalChars = math.floor(availableWidth / 5.5)
    if #textContent > maxTotalChars then
        if #suffixText < 10 then
            -- Suffix is short, truncate name more
            local nameChars = maxTotalChars - #suffixText - 3
            if nameChars > 3 then
                textContent = itemName:sub(1, nameChars) .. "..." .. suffixText
            else
                textContent = itemName:sub(1, 3) .. "..." .. suffixText
            end
        else
            -- Both name and suffix are long, truncate both
            local halfSpace = maxTotalChars / 2
            local shortName = itemName:sub(1, math.floor(halfSpace - 2)) .. ".."
            local shortSuffix = suffixText:sub(1, math.floor(halfSpace - 2)) .. ".."
            textContent = shortName .. " " .. shortSuffix
        end
    end
    
    text:SetText(textContent)
    text:SetTextColor(1, 1, 1, 1) -- White text for all items
    bar.text = text
end
    
    -- Only add interactivity if mouse interaction is enabled
    if not GRCollectorTrackingSettings.noMouseInteraction then
        -- Tooltip functionality
        bar:SetScript("OnEnter", function(self)
            if GRC.Tooltip and GRC.Tooltip.ShowItemTooltip then
                -- Create enhanced item data with latest attempts
                local enhancedItem = {}
                for k, v in pairs(item) do
                    enhancedItem[k] = v
                end
                
                -- Overlay latest attempt data
                enhancedItem.attempts = latestData.attempts
                enhancedItem.charactersTracked = latestData.charactersTracked
                enhancedItem.lastAttempt = latestData.lastAttempt
                enhancedItem.sessionAttempts = latestData.sessionAttempts
                
                GRC.Tooltip.ShowItemTooltip(self, enhancedItem, itemType)
            end
        end)
        
        bar:SetScript("OnLeave", function(self)
            if GRC.Tooltip and GRC.Tooltip.HideItemTooltip then
                GRC.Tooltip.HideItemTooltip()
            end
        end)
        
        -- Click functionality
        bar:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                -- Use/preview item
                if itemType == "mount" and item.mountID then
                    if GRC.Core and GRC.Core.PreviewMount then
                        GRC.Core.PreviewMount(item.mountID)
                    end
                elseif itemType == "pet" and item.speciesID then
                    if GRC.Core and GRC.Core.SummonPet then
                        GRC.Core.SummonPet(item.speciesID)
                    end
                elseif itemType == "toy" and item.toyID then
                    if GRC.Core and GRC.Core.UseToy then
                        GRC.Core.UseToy(item.toyID)
                    end
                end
            elseif button == "RightButton" then
                -- Remove from favorites
                local itemID = nil
                if itemType == "mount" then
                    itemID = item.spellID
                elseif itemType == "pet" then
                    itemID = item.speciesID
                elseif itemType == "toy" then
                    itemID = item.toyID
                end
                
                if itemID and GRC.Favorites then
                    GRC.Favorites.RemoveFavorite(itemID, itemType, item.name)
                end
            end
        end)
    end
    
    -- Store item data with latest attempts
    bar.itemData = item
    bar.itemType = itemType
    bar.latestAttemptData = latestData
    
    return bar
end

-- Get estimated attempts needed for an item (for progress calculation)
function GRC.TrackingBar.GetEstimatedAttempts(item)
    if not item or not item.dropRate then
        return 100 -- Default estimate
    end
    
    local dropRate = item.dropRate
    
    -- Parse drop rate text
    if dropRate == "100%" or dropRate == "Always Available" then
        return 1
    elseif dropRate:match("(%d+)%%") then
        local percentage = tonumber(dropRate:match("(%d+)%%"))
        if percentage then
            return math.ceil(100 / percentage)
        end
    elseif dropRate:match("~(%d+%.?%d*)%%") then
        local percentage = tonumber(dropRate:match("~(%d+%.?%d*)%%"))
        if percentage then
            return math.ceil(100 / percentage)
        end
    elseif dropRate:match("1/(%d+)") then
        local denominator = tonumber(dropRate:match("1/(%d+)"))
        if denominator then
            return denominator
        end
    end
    
    -- Fallback estimates based on category
    if item.category then
        if item.category:find("Raid") then
            return 50 -- Typical raid mount estimate
        elseif item.category:find("Dungeon") then
            return 30 -- Typical dungeon mount estimate
        elseif item.category == "World Drop" then
            return 200 -- Very rare world drops
        elseif item.category == "Achievement" or item.category == "Vendor" then
            return 1 -- Guaranteed
        end
    end
    
    return 100 -- Conservative default
end

-- Enhanced refresh with no delays - always immediate
function GRC.TrackingBar.RefreshData()
    if not isInitialized or not GRC.Favorites then
        return
    end
    
    GRC.Debug.Info("TrackingBar", "Refreshing tracking data with synchronized attempts")
    
    -- Force refresh of RarityDataImporter before display (ensures latest data)
    if GRC.RarityDataImporter and GRC.RarityDataImporter.RefreshAttemptData then
        GRC.RarityDataImporter.RefreshAttemptData()
    end
    
    -- Clear existing bars
    for _, bar in ipairs(activeBars) do
        if bar then
            bar:Hide()
            bar:SetParent(nil)
        end
    end
    activeBars = {}
    
    -- Clear existing headers first when refreshing
    if trackingBarGroup.columnHeaders then
        for _, header in ipairs(trackingBarGroup.columnHeaders) do
            if header then
                header:Hide()
                header:SetParent(nil)
            end
        end
    end
    
    -- Get favorites by type with fresh data
    local favoritesByType = {
        mount = GRC.Favorites.GetFavoriteItems("mount"),
        pet = GRC.Favorites.GetFavoriteItems("pet"),
        toy = GRC.Favorites.GetFavoriteItems("toy")
    }
    
    -- Enhance each item with latest attempt data before filtering/sorting
    for itemType, items in pairs(favoritesByType) do
        for i, item in ipairs(items) do
            local latestData = GetLatestAttemptData(item, itemType)
            -- Update the item with latest data
            item.attempts = latestData.attempts
            item.charactersTracked = latestData.charactersTracked
            item.lastAttempt = latestData.lastAttempt
            item.sessionAttempts = latestData.sessionAttempts
        end
    end
    
    -- Apply filters and sort each type
    for itemType, items in pairs(favoritesByType) do
        -- Filter based on settings
        if GRCollectorTrackingSettings.showOnlyUncollected then
            local filtered = {}
            for _, item in ipairs(items) do
                if not item.isCollected then
                    table.insert(filtered, item)
                end
            end
            favoritesByType[itemType] = filtered
        end
        
        -- Sort by collection status, then by attempts (highest first), then by name
        table.sort(favoritesByType[itemType], function(a, b)
            if a.isCollected ~= b.isCollected then
                return not a.isCollected and b.isCollected -- Uncollected first
            end
            
            if not a.isCollected and not b.isCollected then
                local aAttempts = a.attempts or 0
                local bAttempts = b.attempts or 0
                if aAttempts ~= bAttempts then
                    return aAttempts > bAttempts -- Higher attempts first (show most farmed items)
                end
            end
            
            return (a.name or "") < (b.name or "")
        end)
    end
    
    -- Get active columns and create bars for each column
    local activeColumns = GetActiveColumns()
    local totalBarsCreated = 0
    
    -- Update frame size based on active columns before creating headers
    local totalWidth = 0
    if #activeColumns == 1 then
        totalWidth = 240 -- Single column width
    elseif #activeColumns == 2 then
        totalWidth = 450 -- Two columns
    else
        totalWidth = 650 -- Three columns or more
    end
    
    local totalHeight = 35 + (GRCollectorTrackingSettings.maxBarsPerColumn * (GRCollectorTrackingSettings.height + GRCollectorTrackingSettings.rowSpacing)) + 20
    trackingBarGroup:SetSize(totalWidth, totalHeight)
    
    -- Recreate headers with proper positioning for current active columns
    trackingBarGroup.columnHeaders = {}
    for columnIndex, column in ipairs(activeColumns) do
        local header = trackingBarGroup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        
        -- Dynamic positioning based on actual column count and total width
        local columnWidth = totalWidth / #activeColumns
        local columnCenterX = (columnIndex - 1) * columnWidth + columnWidth / 2
        
        header:SetPoint("TOP", trackingBarGroup, "TOPLEFT", columnCenterX, -25)
        header:SetFont(DEFAULT_FONT, 11, "OUTLINE")
        header:SetJustifyH("CENTER")
        
        -- Get items for this column type to show accurate count
        local items = favoritesByType[column.type] or {}
        local maxBars = GRCollectorTrackingSettings.maxBarsPerColumn or 10
        local barsInColumn = 0
        
        -- Create bars for this column
        for i, item in ipairs(items) do
            if barsInColumn >= maxBars then
                break
            end
            
            local bar = GRC.TrackingBar.CreateBar(item, column.type, columnIndex, barsInColumn + 1)
            if bar then
                table.insert(activeBars, bar)
                barsInColumn = barsInColumn + 1
                totalBarsCreated = totalBarsCreated + 1
            end
        end
        
        -- Update header text with proper count and attempt info
        local colorCode = column.type == "mount" and "FF6B35" or column.type == "pet" and "00FF00" or "0099FF"
        local totalAttempts = 0
        for _, item in ipairs(items) do
            totalAttempts = totalAttempts + (item.attempts or 0)
        end
        
        local headerText = string.format("|cFF%s%s (%d/%d)|r", colorCode, column.title, barsInColumn, #items)
        if totalAttempts > 0 then
            headerText = headerText .. string.format(" |cFFCCCCCC[%d attempts]|r", totalAttempts)
        end
        
        header:SetText(headerText)
        trackingBarGroup.columnHeaders[columnIndex] = header
    end
    
    -- Update main title (no time indicator)
    if trackingBarGroup.title then
        trackingBarGroup.title:SetText("|cFFFF6B35GRC|r |cFF00D4AATracker|r")
    end
    
    -- Update hash after successful refresh
    lastAttemptDataHash = CreateAttemptDataHash()
    
    GRC.Debug.Trace("TrackingBar", "Created %d tracking bars across %d columns with synchronized data", totalBarsCreated, #activeColumns)
end

-- Force refresh function - now always immediate
function GRC.TrackingBar.ForceRefresh()
    if not isInitialized then
        return
    end
    
    GRC.Debug.Info("TrackingBar", "Force refresh triggered")
    
    -- Always refresh immediately - no delays
    GRC.TrackingBar.RefreshData()
    
    -- Notify if UI is open
    if GRC.UI and GRC.UI.RefreshUI then
        C_Timer.After(0.2, function()
            GRC.UI.RefreshUI()
        end)
    end
end

-- Only trigger refresh after meaningful boss encounters
function GRC.TrackingBar.OnBossKill(npcID, encounterID)
    GRC.Debug.Info("TrackingBar", "Boss kill detected: NPC %s, Encounter %s", tostring(npcID), tostring(encounterID))
    
    -- Only refresh for meaningful encounters, delay to allow data processing
    C_Timer.After(5, function()
        GRC.TrackingBar.ForceRefresh()
    end)
end

function GRC.TrackingBar.OnLootReceived()
    -- Only refresh if we're in a location where collectibles can drop
    local inInstance = IsInInstance()
    local zoneName = GetZoneText()
    
    if inInstance or zoneName:find("Dungeon") or zoneName:find("Raid") then
        GRC.Debug.Trace("TrackingBar", "Loot received in collectible zone, refreshing tracking bar")
        
        C_Timer.After(2, function()
            GRC.TrackingBar.ForceRefresh()
        end)
    end
end

function GRC.TrackingBar.OnAttemptAdded(itemType, itemID, attempts)
    -- Only refresh for significant attempt increases
    if attempts > 0 and (attempts % 5 == 0 or attempts == 1) then
        GRC.Debug.Trace("TrackingBar", "Significant attempt milestone: %s %s (%d attempts)", itemType, tostring(itemID), attempts)
        
        C_Timer.After(1, function()
            GRC.TrackingBar.ForceRefresh()
        end)
    end
end

-- Update visibility based on settings
function GRC.TrackingBar.UpdateVisibility()
    if not trackingBarGroup then return end
    
    if GRCollectorTrackingSettings.visible then
        trackingBarGroup:Show()
    else
        trackingBarGroup:Hide()
    end
end

-- Toggle visibility
function GRC.TrackingBar.Toggle()
    GRCollectorTrackingSettings.visible = not GRCollectorTrackingSettings.visible
    GRC.TrackingBar.UpdateVisibility()
    
    if GRCollectorTrackingSettings.visible then
        print("|cFFFF6B35GRC:|r Tracking bar |cFF00FF00SHOWN|r")
        -- Force refresh when showing
        GRC.TrackingBar.ForceRefresh()
    else
        print("|cFFFF6B35GRC:|r Tracking bar |cFFFF0000HIDDEN|r")
    end
    
    return GRCollectorTrackingSettings.visible
end

-- Lock/unlock the tracking bar
function GRC.TrackingBar.ToggleLock()
    GRCollectorTrackingSettings.locked = not GRCollectorTrackingSettings.locked
    
    if GRCollectorTrackingSettings.locked then
        print("|cFFFF6B35GRC:|r Tracking bar |cFFFF0000LOCKED|r")
    else
        print("|cFFFF6B35GRC:|r Tracking bar |cFF00FF00UNLOCKED|r - drag to move")
    end
    
    return GRCollectorTrackingSettings.locked
end

-- Update tracking bar scale
function GRC.TrackingBar.UpdateScale(newScale)
    if trackingBarGroup then
        trackingBarGroup:SetScale(newScale)
        GRCollectorTrackingSettings.scale = newScale
        GRC.Debug.Trace("TrackingBar", "Scale updated to %.1f", newScale)
    end
end

-- Toggle column visibility
function GRC.TrackingBar.ToggleColumn(columnType)
    InitializeTrackingSettings() -- Ensure settings are initialized
    
    if not columnType then
        return false
    end
    
    -- Ensure the column type exists in settings
    if GRCollectorTrackingSettings.enabledColumns[columnType] == nil then
        GRCollectorTrackingSettings.enabledColumns[columnType] = true
    end
    
    local wasEnabled = GRCollectorTrackingSettings.enabledColumns[columnType]
    GRCollectorTrackingSettings.enabledColumns[columnType] = not wasEnabled
    
    print(string.format("|cFFFF6B35GRC:|r %s column: %s", 
          columnType:gsub("^%l", string.upper), 
          GRCollectorTrackingSettings.enabledColumns[columnType] and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
    
    -- Use immediate refresh for manual column toggles - no delays
    if isInitialized then
        GRC.TrackingBar.RefreshColumns()
    end
    
    return GRCollectorTrackingSettings.enabledColumns[columnType]
end

-- Toggle mouse interaction
function GRC.TrackingBar.ToggleMouseInteraction()
    InitializeTrackingSettings() -- Ensure settings are initialized
    
    GRCollectorTrackingSettings.noMouseInteraction = not GRCollectorTrackingSettings.noMouseInteraction
    
    print(string.format("|cFFFF6B35GRC:|r Mouse interaction: %s", 
          GRCollectorTrackingSettings.noMouseInteraction and "|cFFFF0000DISABLED|r" or "|cFF00FF00ENABLED|r"))
    
    -- Update main frame mouse interaction (but not title bar)
    if trackingBarGroup then
        if GRCollectorTrackingSettings.noMouseInteraction then
            trackingBarGroup:EnableMouse(false)
            trackingBarGroup:SetToplevel(false)
        else
            trackingBarGroup:EnableMouse(true)
            trackingBarGroup:SetToplevel(true)
        end
        
        -- Title bar ALWAYS remains draggable when unlocked - no changes needed here
        -- It stays enabled for dragging regardless of mouse interaction setting
    end
    
    -- Refresh all bars to update their mouse interaction
    GRC.TrackingBar.RefreshData()
    return not GRCollectorTrackingSettings.noMouseInteraction
end

-- Set row spacing
function GRC.TrackingBar.SetRowSpacing(spacing)
    InitializeTrackingSettings() -- Ensure settings are initialized
    
    if spacing and spacing >= 0 and spacing <= 10 then
        GRCollectorTrackingSettings.rowSpacing = spacing
        print(string.format("|cFFFF6B35GRC:|r Row spacing set to %d pixels", spacing))
        
        -- Refresh the tracking bar
        GRC.TrackingBar.RefreshData()
        return true
    else
        print("|cFFFF6B35GRC:|r Invalid spacing value. Use 0-10 pixels.")
        return false
    end
end

-- Reset position
function GRC.TrackingBar.ResetPosition()
    local defaultPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -200
    }
    
    if GRC.Favorites and GRC.Favorites.SaveTrackingPosition then
        GRC.Favorites.SaveTrackingPosition(defaultPosition.point, defaultPosition.relativePoint, 
                                          defaultPosition.x, defaultPosition.y)
    end
    
    if trackingBarGroup then
        trackingBarGroup:ClearAllPoints()
        trackingBarGroup:SetPoint(
            defaultPosition.point,
            UIParent,
            defaultPosition.relativePoint,
            defaultPosition.x,
            defaultPosition.y
        )
    end
    
    print("|cFFFF6B35GRC:|r Tracking bar position reset")
end

-- Initialize when addon loads
local function InitializeWhenReady()
    -- Wait for other systems to be ready
    if GRC.Favorites then
        GRC.TrackingBar.Initialize()
    else
        C_Timer.After(2, InitializeWhenReady)
    end
end

-- UPDATED: Enhanced event handling with SMART EVENT FILTERING
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- SMART FILTERED: Only register events that can result in collectibles
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("BOSS_KILL")
frame:RegisterEvent("NEW_MOUNT_ADDED")
frame:RegisterEvent("NEW_PET_ADDED")
frame:RegisterEvent("NEW_TOY_ADDED")

-- Smart: Conditionally relevant events (with intelligent filtering)
frame:RegisterEvent("CHAT_MSG_LOOT")       -- Only for collectible loot
frame:RegisterEvent("ACHIEVEMENT_EARNED")  -- For mount/pet/toy achievements

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        InitializeTrackingSettings()
        C_Timer.After(3, InitializeWhenReady)
        
    elseif event == "PLAYER_LOGIN" then
        InitializeTrackingSettings()
        C_Timer.After(5, function()
            if isInitialized then
                GRC.TrackingBar.RefreshData()
            end
        end)
        
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("encounter_end", {
            encounterID = encounterID,
            encounterName = encounterName,
            success = success == 1
        }) then
            GRC.Debug.Info("TrackingBar", "Encounter completed: %s (%d)", encounterName, encounterID)
            GRC.TrackingBar.OnBossKill(nil, encounterID)
        end
        
    elseif event == "BOSS_KILL" then
        local id, name = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("boss_kill", {
            npcID = id,
            npcName = name
        }) then
            GRC.Debug.Info("TrackingBar", "Boss killed: %s", name)
            GRC.TrackingBar.OnBossKill(id, nil)
        end
        
    elseif event == "CHAT_MSG_LOOT" then
        local text, playerName = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("loot", {
            lootText = text,
            playerName = playerName
        }) then
            GRC.Debug.Info("TrackingBar", "Collectible loot detected: %s", text)
            C_Timer.After(2, function()
                GRC.TrackingBar.ForceRefresh()
            end)
        end
        
    elseif event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        GRC.Debug.Info("TrackingBar", "New mount added: %s", tostring(mountID))
        C_Timer.After(1, function()
            GRC.TrackingBar.ForceRefresh()
        end)
        
    elseif event == "NEW_PET_ADDED" then
        local petID = ...
        GRC.Debug.Info("TrackingBar", "New pet added: %s", tostring(petID))
        C_Timer.After(1, function()
            GRC.TrackingBar.ForceRefresh()
        end)
        
    elseif event == "NEW_TOY_ADDED" then
        local toyID = ...
        GRC.Debug.Info("TrackingBar", "New toy added: %s", tostring(toyID))
        C_Timer.After(1, function()
            GRC.TrackingBar.ForceRefresh()
        end)
        
    elseif event == "ACHIEVEMENT_EARNED" then
        local achievementID = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("achievement", {
            achievementID = achievementID
        }) then
            GRC.Debug.Info("TrackingBar", "Achievement earned: %s", tostring(achievementID))
            C_Timer.After(2, function()
                GRC.TrackingBar.ForceRefresh()
            end)
        end
    end
end)

-- Public API for external integration
function GRC.TrackingBar.NotifyAttemptAdded(itemType, itemID, newAttempts)
    GRC.TrackingBar.OnAttemptAdded(itemType, itemID, newAttempts)
end

function GRC.TrackingBar.NotifyBossKill(npcID, encounterID)
    GRC.TrackingBar.OnBossKill(npcID, encounterID)
end

function GRC.TrackingBar.NotifyCollectionUpdate()
    GRC.TrackingBar.OnLootReceived()
end

-- Cleanup function
function GRC.TrackingBar.Cleanup()
    if trackingBarGroup then
        trackingBarGroup:Hide()
        trackingBarGroup = nil
    end
    
    activeBars = {}
    isInitialized = false
end

GRC.Debug.Info("TrackingBar", "Enhanced tracking bar system with SMART event filtering loaded")

return GRC.TrackingBar