-- DebugSystem.lua - Centralized Debug Management with Log Viewer
local addonName, GRC = ...
GRC.Debug = GRC.Debug or {}

-- Debug levels
local DEBUG_LEVELS = {
    INFO = 1,
    WARN = 2, 
    ERROR = 3,
    TRACE = 4
}

-- Color codes for different debug levels
local DEBUG_COLORS = {
    [DEBUG_LEVELS.INFO] = "|cFF88CCFF",   -- Light blue
    [DEBUG_LEVELS.WARN] = "|cFFFFAA00",   -- Orange
    [DEBUG_LEVELS.ERROR] = "|cFFFF4444",  -- Red
    [DEBUG_LEVELS.TRACE] = "|cFFCCCCCC"   -- Gray
}

-- Debug log storage
local debugLog = {}
local maxLogEntries = 1000
local logIndex = 0

-- Module prefixes for organized output
local MODULE_COLORS = {
    ["Core"] = "|cFF00FF00",
    ["Cache"] = "|cFF00CCFF", 
    ["Import"] = "|cFFFFAA00",
    ["UI"] = "|cFFFF6B35",
    ["Lockout"] = "|cFFAA88FF",
    ["Rarity"] = "|cFF88FFAA",
    ["Tooltip"] = "|cFFFFCC88",
    ["AttemptsTracker"] = "|cFFFF88CC"
}

-- Check if debug mode is enabled
local function IsDebugEnabled()
    return GRCollectorSettings and GRCollectorSettings.debugMode == true
end

-- Add entry to debug log
local function AddToDebugLog(level, module, message, ...)
    logIndex = logIndex + 1
    
    -- Format message with any additional parameters
    local finalMessage = message
    if ... then
        local success, formatted = pcall(string.format, message, ...)
        if success then
            finalMessage = formatted
        else
            finalMessage = message .. " (format error)"
        end
    end
    
    -- Create log entry
    local entry = {
        index = logIndex,
        timestamp = time(),
        level = level,
        module = module or "Unknown",
        message = finalMessage,
        fullText = string.format("[%s] %s: %s", 
                                date("%H:%M:%S", time()),
                                module or "Unknown",
                                finalMessage)
    }
    
    -- Add to log
    table.insert(debugLog, entry)
    
    -- Maintain log size
    if #debugLog > maxLogEntries then
        table.remove(debugLog, 1)
    end
    
    return entry
end

-- Core debug function
local function DebugPrint(level, module, message, ...)
    -- Always add to log (even if debug mode is off)
    local entry = AddToDebugLog(level, module, message, ...)
    
    -- Only print to chat if debug mode is enabled
    if not IsDebugEnabled() then return end
    
    local levelColor = DEBUG_COLORS[level] or "|cFFFFFFFF"
    local moduleColor = MODULE_COLORS[module] or "|cFFFFFFFF"
    local prefix = "|cFFFF6B35GRC"
    
    if module then
        prefix = prefix .. " " .. moduleColor .. module .. "|r"
    end
    
    prefix = prefix .. " Debug:|r"
    
    print(prefix .. " " .. levelColor .. entry.message .. "|r")
end

-- Public debug functions
function GRC.Debug.Info(module, message, ...)
    DebugPrint(DEBUG_LEVELS.INFO, module, message, ...)
end

function GRC.Debug.Warn(module, message, ...)
    DebugPrint(DEBUG_LEVELS.WARN, module, message, ...)
end

function GRC.Debug.Error(module, message, ...)
    DebugPrint(DEBUG_LEVELS.ERROR, module, message, ...)
end

function GRC.Debug.Trace(module, message, ...)
    DebugPrint(DEBUG_LEVELS.TRACE, module, message, ...)
end

-- Specialized debug functions for common use cases
function GRC.Debug.MountInfo(mountName, message, ...)
    if not IsDebugEnabled() then return end
    GRC.Debug.Info("Mount", "%s: " .. message, mountName or "Unknown", ...)
end

function GRC.Debug.ImportInfo(message, ...)
    if not IsDebugEnabled() then return end
    GRC.Debug.Info("Import", message, ...)
end

function GRC.Debug.CacheInfo(message, ...)
    if not IsDebugEnabled() then return end
    GRC.Debug.Info("Cache", message, ...)
end

function GRC.Debug.LockoutInfo(message, ...)
    if not IsDebugEnabled() then return end
    GRC.Debug.Info("Lockout", message, ...)
end

function GRC.Debug.UIInfo(message, ...)
    if not IsDebugEnabled() then return end
    GRC.Debug.Info("UI", message, ...)
end

-- Create debug log viewer window
function GRC.Debug.CreateLogViewer()
    if GRC.Debug.LogViewer then
        GRC.Debug.LogViewer:Show()
        GRC.Debug.RefreshLogViewer()
        return
    end
    
    local frame = CreateFrame("Frame", "GRCDebugLogViewer", UIParent)
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    
    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.95)
    
    -- Border
    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    local borderInner = frame:CreateTexture(nil, "ARTWORK")
    borderInner:SetPoint("TOPLEFT", 2, -2)
    borderInner:SetPoint("BOTTOMRIGHT", -2, 2)
    borderInner:SetColorTexture(0.02, 0.02, 0.02, 0.95)
    borderInner:SetDrawLayer("ARTWORK", 1)
    
    -- Drag functionality
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 2, -2)
    titleBar:SetPoint("TOPRIGHT", -2, -2)
    titleBar:SetHeight(30)
    bg = titleBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
    
    -- Title
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("|cFFFF6B35GRC Debug Log Viewer|r (" .. #debugLog .. " entries)")
    title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    frame.titleText = title
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(25, 25)
    closeBtn:SetPoint("RIGHT", -5, 0)
    bg = closeBtn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.8, 0.2, 0.2, 0.7)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeText:SetPoint("CENTER")
    closeText:SetText("×")
    closeText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    closeText:SetTextColor(1, 1, 1, 1)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Control bar
    local controlBar = CreateFrame("Frame", nil, frame)
    controlBar:SetPoint("TOPLEFT", 2, -32)
    controlBar:SetPoint("TOPRIGHT", -2, -32)
    controlBar:SetHeight(30)
    bg = controlBar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    -- Filter buttons
    local filterAll = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    filterAll:SetSize(50, 25)
    filterAll:SetPoint("LEFT", 5, 0)
    filterAll:SetText("All")
    
    local filterInfo = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    filterInfo:SetSize(50, 25)
    filterInfo:SetPoint("LEFT", filterAll, "RIGHT", 5, 0)
    filterInfo:SetText("Info")
    
    local filterWarn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    filterWarn:SetSize(50, 25)
    filterWarn:SetPoint("LEFT", filterInfo, "RIGHT", 5, 0)
    filterWarn:SetText("Warn")
    
    local filterError = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    filterError:SetSize(50, 25)
    filterError:SetPoint("LEFT", filterWarn, "RIGHT", 5, 0)
    filterError:SetText("Error")
    
    -- Clear button
    local clearBtn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 25)
    clearBtn:SetPoint("RIGHT", -150, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        debugLog = {}
        logIndex = 0
        GRC.Debug.RefreshLogViewer()
        print("|cFFFF6B35GRC Debug:|r Log cleared")
    end)
    
    -- Copy button
    local copyBtn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    copyBtn:SetSize(80, 25)
    copyBtn:SetPoint("RIGHT", -65, 0)
    copyBtn:SetText("Copy All")
    copyBtn:SetScript("OnClick", function()
        GRC.Debug.CopyLogToClipboard()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, controlBar, "UIPanelButtonTemplate")
    refreshBtn:SetSize(60, 25)
    refreshBtn:SetPoint("RIGHT", -5, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        GRC.Debug.RefreshLogViewer()
    end)
    
    -- Scroll frame for log entries
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -64)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 4)
    
    -- Content frame
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(770, 500)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Store references
    frame.scrollFrame = scrollFrame
    frame.contentFrame = contentFrame
    frame.currentFilter = "all"
    
    -- Filter functionality
    local function setFilter(filterType)
        frame.currentFilter = filterType
        GRC.Debug.RefreshLogViewer()
        
        -- Update button states
        filterAll:SetEnabled(filterType ~= "all")
        filterInfo:SetEnabled(filterType ~= "info") 
        filterWarn:SetEnabled(filterType ~= "warn")
        filterError:SetEnabled(filterType ~= "error")
    end
    
    filterAll:SetScript("OnClick", function() setFilter("all") end)
    filterInfo:SetScript("OnClick", function() setFilter("info") end)
    filterWarn:SetScript("OnClick", function() setFilter("warn") end)
    filterError:SetScript("OnClick", function() setFilter("error") end)
    
    -- Initialize with all filter
    setFilter("all")
    
    GRC.Debug.LogViewer = frame
    GRC.Debug.RefreshLogViewer()
end

-- Refresh the log viewer content
function GRC.Debug.RefreshLogViewer()
    local frame = GRC.Debug.LogViewer
    if not frame then return end
    
    -- Update title with entry count
    frame.titleText:SetText("|cFFFF6B35GRC Debug Log Viewer|r (" .. #debugLog .. " entries)")
    
    -- Clear existing content
    local children = {frame.contentFrame:GetChildren()}
    for _, child in pairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Filter entries based on current filter
    local filteredEntries = {}
    for _, entry in ipairs(debugLog) do
        local include = false
        if frame.currentFilter == "all" then
            include = true
        elseif frame.currentFilter == "info" and entry.level == DEBUG_LEVELS.INFO then
            include = true
        elseif frame.currentFilter == "warn" and entry.level == DEBUG_LEVELS.WARN then
            include = true
        elseif frame.currentFilter == "error" and entry.level == DEBUG_LEVELS.ERROR then
            include = true
        end
        
        if include then
            table.insert(filteredEntries, entry)
        end
    end
    
    -- Create log entry frames
    local yOffset = 0
    for i, entry in ipairs(filteredEntries) do
        local entryFrame = CreateFrame("Frame", nil, frame.contentFrame)
        entryFrame:SetSize(750, 20)
        entryFrame:SetPoint("TOPLEFT", 5, yOffset)
        
        -- Background (alternating colors)
        local bg = entryFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        if i % 2 == 0 then
            bg:SetColorTexture(0.05, 0.05, 0.08, 0.3)
        else
            bg:SetColorTexture(0.08, 0.08, 0.05, 0.3)
        end
        
        -- Get level color
        local levelColor = DEBUG_COLORS[entry.level] or "|cFFFFFFFF"
        local moduleColor = MODULE_COLORS[entry.module] or "|cFFFFFFFF"
        
        -- Timestamp
        local timeText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeText:SetPoint("LEFT", 5, 0)
        timeText:SetText(date("%H:%M:%S", entry.timestamp))
        timeText:SetTextColor(0.7, 0.7, 0.7, 1)
        timeText:SetFont("Fonts\\FRIZQT__.TTF", 9)
        
        -- Level indicator
        local levelText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        levelText:SetPoint("LEFT", timeText, "RIGHT", 10, 0)
        levelText:SetSize(40, 20)
        
        local levelName = ""
        if entry.level == DEBUG_LEVELS.INFO then levelName = "INFO"
        elseif entry.level == DEBUG_LEVELS.WARN then levelName = "WARN"
        elseif entry.level == DEBUG_LEVELS.ERROR then levelName = "ERROR"
        elseif entry.level == DEBUG_LEVELS.TRACE then levelName = "TRACE"
        end
        
        levelText:SetText(levelColor .. levelName .. "|r")
        levelText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        
        -- Module
        local moduleText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        moduleText:SetPoint("LEFT", levelText, "RIGHT", 10, 0)
        moduleText:SetSize(80, 20)
        moduleText:SetText(moduleColor .. entry.module .. "|r")
        moduleText:SetFont("Fonts\\FRIZQT__.TTF", 9)
        
        -- Message
        local messageText = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        messageText:SetPoint("LEFT", moduleText, "RIGHT", 10, 0)
        messageText:SetPoint("RIGHT", entryFrame, "RIGHT", -5, 0)
        messageText:SetHeight(20)
        messageText:SetText(entry.message)
        messageText:SetTextColor(0.95, 0.95, 0.95, 1)
        messageText:SetFont("Fonts\\FRIZQT__.TTF", 9)
        messageText:SetJustifyH("LEFT")
        messageText:SetWordWrap(false)
        
        -- Click to copy functionality
        entryFrame:EnableMouse(true)
        entryFrame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                GRC.Debug.CopyLogEntry(entry)
            end
        end)
        
        -- Tooltip
        entryFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText("Debug Log Entry", 1, 1, 1)
            GameTooltip:AddLine("Click to copy this entry", 0.7, 0.7, 0.7)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Full message:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine(entry.fullText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        
        entryFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        yOffset = yOffset - 22
    end
    
    -- Update content frame height
    frame.contentFrame:SetHeight(math.max(500, #filteredEntries * 22 + 20))
    
    -- Scroll to bottom
    C_Timer.After(0.1, function()
        frame.scrollFrame:SetVerticalScroll(frame.scrollFrame:GetVerticalScrollRange())
    end)
end

-- Copy single log entry to "clipboard" (print for copying)
function GRC.Debug.CopyLogEntry(entry)
    if not entry then return end
    
    print("|cFFFF6B35GRC Debug Copy:|r " .. entry.fullText)
    print("|cFFAAAAAAUse Ctrl+A, Ctrl+C to copy from chat|r")
end

-- Copy entire log to "clipboard" (print for copying)
function GRC.Debug.CopyLogToClipboard()
    if #debugLog == 0 then
        print("|cFFFF6B35GRC Debug:|r No log entries to copy")
        return
    end
    
    print("|cFFFF6B35GRC Debug Log Export:|r (" .. #debugLog .. " entries)")
    print("=" .. string.rep("=", 50))
    
    for _, entry in ipairs(debugLog) do
        print(entry.fullText)
    end
    
    print("=" .. string.rep("=", 50))
    print("|cFFAAAAAAUse Ctrl+A, Ctrl+C to copy all from chat|r")
end

-- Get recent log entries (for quick access)
function GRC.Debug.GetRecentEntries(count)
    count = count or 50
    local recent = {}
    
    local startIndex = math.max(1, #debugLog - count + 1)
    for i = startIndex, #debugLog do
        table.insert(recent, debugLog[i])
    end
    
    return recent
end

-- Get log statistics
function GRC.Debug.GetLogStats()
    local stats = {
        total = #debugLog,
        info = 0,
        warn = 0,
        error = 0,
        trace = 0,
        modules = {}
    }
    
    for _, entry in ipairs(debugLog) do
        if entry.level == DEBUG_LEVELS.INFO then
            stats.info = stats.info + 1
        elseif entry.level == DEBUG_LEVELS.WARN then
            stats.warn = stats.warn + 1
        elseif entry.level == DEBUG_LEVELS.ERROR then
            stats.error = stats.error + 1
        elseif entry.level == DEBUG_LEVELS.TRACE then
            stats.trace = stats.trace + 1
        end
        
        stats.modules[entry.module] = (stats.modules[entry.module] or 0) + 1
    end
    
    return stats
end

-- Debug stats and information
function GRC.Debug.ShowStats()
    if not IsDebugEnabled() then
        print("|cFFFF6B35GRC:|r Debug mode is disabled. Use /grc debug to enable.")
        return
    end
    
    print("|cFFFF6B35GRC Debug Stats:|r")
    print("  Debug Mode: |cFF00FF00ENABLED|r")
    
    -- SmartCache stats
    if GRC.SmartCache then
        local stats = GRC.SmartCache.GetStats()
        print("  SmartCache:")
        print(string.format("    Total Mounts: %d", stats.totalMounts or 0))
        print(string.format("    Total Pets: %d", stats.totalPets or 0))
        print(string.format("    Total Toys: %d", stats.totalToys or 0))
        print(string.format("    Standalone Mode: %s", tostring(stats.standaloneMode)))
        print(string.format("    Last Update: %s", stats.lastUpdate and date("%H:%M:%S", stats.lastUpdate) or "Never"))
    end
    
    -- RarityDataImporter stats
    if GRC.RarityDataImporter then
        local importStats = GRC.RarityDataImporter.GetImportStatistics()
        print("  Rarity Importer:")
        print(string.format("    Available: %s", tostring(importStats.available)))
        print(string.format("    Mounts with Attempts: %d", importStats.mountsWithAttempts))
        print(string.format("    Pets with Attempts: %d", importStats.petsWithAttempts))
        print(string.format("    Toys with Attempts: %d", importStats.toysWithAttempts))
        print(string.format("    Total Attempts: %d", importStats.totalAttempts))
        print(string.format("    Cache Size: %d", importStats.cacheSize))
    end
    
    -- AttemptsTracker stats
    if GRC.AttemptsTracker then
        local trackingStats = GRC.AttemptsTracker.GetStatistics()
        print("  Attempts Tracker:")
        print(string.format("    Integration Mode: %s", trackingStats.integrationMode))
        print(string.format("    Mounts Tracked: %d", trackingStats.totalMountsTracked))
        print(string.format("    Total Attempts: %d", trackingStats.totalAttempts))
        print(string.format("    Characters: %d", trackingStats.charactersTracked))
        print(string.format("    Current Session: %d attempts", trackingStats.currentSession.attempts))
    end
    
    -- SimpleLockouts stats
    if GRC.SimpleLockouts then
        local lockoutSummary = GRC.SimpleLockouts.GetLockoutSummary()
        print("  Simple Lockouts:")
        print(string.format("    Active Lockouts: %d", lockoutSummary.totalLockouts))
        print(string.format("    Expiring Soon: %d", #lockoutSummary.expiringSoon))
    end
    
    -- Debug log stats
    local logStats = GRC.Debug.GetLogStats()
    print("  Debug Log:")
    print(string.format("    Total Entries: %d", logStats.total))
    print(string.format("    Info: %d, Warn: %d, Error: %d", logStats.info, logStats.warn, logStats.error))
end

-- Debug specific mount
function GRC.Debug.AnalyzeMount(mountName)
    if not IsDebugEnabled() then
        print("|cFFFF6B35GRC:|r Debug mode is disabled. Use /grc debug to enable.")
        return
    end
    
    if not mountName or mountName:trim() == "" then
        print("|cFFFF6B35GRC Debug:|r Usage: /grc-debug mount <mount name>")
        return
    end
    
    print("|cFFFF6B35GRC Mount Analysis:|r " .. mountName)
    
    -- Search in SmartCache
    if GRC.SmartCache and GRC.SmartCache.IsReady() then
        local allMounts = GRC.SmartCache.GetAllMounts()
        local found = false
        
        for _, mount in ipairs(allMounts) do
            if mount.name and mount.name:lower():find(mountName:lower(), 1, true) then
                found = true
                print("  SmartCache Data:")
                print(string.format("    Name: %s", mount.name))
                print(string.format("    Mount ID: %d", mount.mountID or 0))
                print(string.format("    Spell ID: %d", mount.spellID or 0))
                print(string.format("    Expansion: %s", mount.expansion or "Unknown"))
                print(string.format("    Category: %s", mount.category or "Unknown"))
                print(string.format("    Drop Rate: %s", mount.dropRate or "Unknown"))
                print(string.format("    Attempts: %d", mount.attempts or 0))
                print(string.format("    Characters Tracked: %d", mount.charactersTracked or 0))
                print(string.format("    Lockout Info: %s", mount.lockoutInfo or "Unknown"))
                print(string.format("    Is Rarity Tracked: %s", tostring(mount.isRarityTracked)))
                print(string.format("    Source: %s", mount.source or "Unknown"))
                break
            end
        end
        
        if not found then
            print("  Mount not found in SmartCache")
        end
    end
    
    -- Test Rarity import
    if GRC.RarityDataImporter then
        print("  Rarity Import Test:")
        local importData = GRC.RarityDataImporter.ImportMountAttempts(mountName, nil, nil)
        print(string.format("    Total Attempts: %d", importData.totalAttempts))
        print(string.format("    Characters: %d", importData.charactersTracked))
        print(string.format("    Source: %s", importData.source))
    end
    
    -- Test attempts tracker
    if GRC.AttemptsTracker then
        print("  Attempts Tracker Test:")
        -- Try to find by name in attempts data
        for spellID, data in pairs(GRCollectorAttempts or {}) do
            if type(data) == "table" and data.mountName and 
               data.mountName:lower():find(mountName:lower(), 1, true) then
                print(string.format("    Found: %s (Spell ID: %d)", data.mountName, spellID))
                print(string.format("    Total Attempts: %d", data.totalAttempts or 0))
                print(string.format("    Characters: %d", GRC.AttemptsTracker.CountTable(data.characters or {})))
                break
            end
        end
    end
    
    -- Test lockout info
    if GRC.SimpleLockouts then
        local lockoutStatus = GRC.SimpleLockouts.GetLockoutStatus(mountName)
        print("  Lockout Test:")
        print(string.format("    Status: %s", lockoutStatus))
    end
end

-- Debug system performance
function GRC.Debug.PerformanceTest()
    if not IsDebugEnabled() then
        print("|cFFFF6B35GRC:|r Debug mode is disabled. Use /grc debug to enable.")
        return
    end
    
    print("|cFFFF6B35GRC Performance Test:|r")
    
    local startTime = GetTime()
    
    -- Test SmartCache performance
    if GRC.SmartCache and GRC.SmartCache.IsReady() then
        local cacheStart = GetTime()
        local mounts = GRC.SmartCache.GetAllMounts()
        local cacheTime = GetTime() - cacheStart
        print(string.format("  SmartCache.GetAllMounts(): %.3f seconds (%d mounts)", cacheTime, #mounts))
        
        local petsStart = GetTime()
        local pets = GRC.SmartCache.GetAllPets()
        local petsTime = GetTime() - petsStart
        print(string.format("  SmartCache.GetAllPets(): %.3f seconds (%d pets)", petsTime, #pets))
        
        local toysStart = GetTime()
        local toys = GRC.SmartCache.GetAllToys()
        local toysTime = GetTime() - toysStart
        print(string.format("  SmartCache.GetAllToys(): %.3f seconds (%d toys)", toysTime, #toys))
    end
    
    -- Test Core performance
    if GRC.Core and GRC.Core.IsReady() then
        local coreStart = GetTime()
        local stats = GRC.Core.GetStatistics()
        local coreTime = GetTime() - coreStart
        print(string.format("  Core.GetStatistics(): %.3f seconds", coreTime))
    end
    
    -- Test lockout performance
    if GRC.SimpleLockouts then
        local lockoutStart = GetTime()
        local summary = GRC.SimpleLockouts.GetLockoutSummary()
        local lockoutTime = GetTime() - lockoutStart
        print(string.format("  SimpleLockouts.GetLockoutSummary(): %.3f seconds", lockoutTime))
    end
    
    -- Test debug log performance
    local logStart = GetTime()
    local logStats = GRC.Debug.GetLogStats()
    local logTime = GetTime() - logStart
    print(string.format("  Debug.GetLogStats(): %.3f seconds (%d entries)", logTime, logStats.total))
    
    local totalTime = GetTime() - startTime
    print(string.format("  Total Test Time: %.3f seconds", totalTime))
end

-- Clear all debug output (for testing)
function GRC.Debug.Clear()
    if not IsDebugEnabled() then return end
    
    for i = 1, 50 do
        print(" ")
    end
    print("|cFFFF6B35GRC Debug:|r Output cleared")
end

-- Toggle debug mode
function GRC.Debug.Toggle()
    GRCollectorSettings.debugMode = not GRCollectorSettings.debugMode
    
    if GRCollectorSettings.debugMode then
        print("|cFFFF6B35GRC:|r Debug mode |cFF00FF00ENABLED|r")
        print("  Use /grc-debug for debug commands")
        print("  Use /debuglog for debug log viewer")
    else
        print("|cFFFF6B35GRC:|r Debug mode |cFFFF0000DISABLED|r")
        print("  Debug log viewer still available with /debuglog")
    end
    
    return GRCollectorSettings.debugMode
end

-- Get debug status
function GRC.Debug.IsEnabled()
    return IsDebugEnabled()
end

-- Debug commands with log viewer
SLASH_GRC_DEBUG1 = "/grc-debug"
SlashCmdList["GRC_DEBUG"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local command = args[1] and args[1]:lower() or ""
    
    if command == "stats" then
        GRC.Debug.ShowStats()
    elseif command == "mount" then
        local mountName = table.concat(args, " ", 2)
        GRC.Debug.AnalyzeMount(mountName)
    elseif command == "performance" or command == "perf" then
        GRC.Debug.PerformanceTest()
    elseif command == "clear" then
        GRC.Debug.Clear()
    elseif command == "toggle" then
        GRC.Debug.Toggle()
    elseif command == "log" then
        GRC.Debug.CreateLogViewer()
    elseif command == "logstats" then
        local stats = GRC.Debug.GetLogStats()
        print("|cFFFF6B35GRC Debug Log Stats:|r")
        print(string.format("  Total Entries: %d", stats.total))
        print(string.format("  Info: %d, Warn: %d, Error: %d, Trace: %d", 
              stats.info, stats.warn, stats.error, stats.trace))
        print("  Modules:")
        local sortedModules = {}
        for module, count in pairs(stats.modules) do
            table.insert(sortedModules, {module = module, count = count})
        end
        table.sort(sortedModules, function(a, b) return a.count > b.count end)
        for i = 1, math.min(10, #sortedModules) do
            local mod = sortedModules[i]
            print(string.format("    %s: %d", mod.module, mod.count))
        end
    elseif command == "copy" then
        local count = tonumber(args[2]) or 50
        local recent = GRC.Debug.GetRecentEntries(count)
        print("|cFFFF6B35GRC Debug Recent Log:|r (last " .. count .. " entries)")
        for _, entry in ipairs(recent) do
            print(entry.fullText)
        end
        print("|cFFAAAAAAUse Ctrl+A, Ctrl+C to copy from chat|r")
    elseif command == "help" then
        print("|cFFFF6B35GRC Debug Commands:|r")
        print("  /grc-debug stats - Show debug statistics")
        print("  /grc-debug mount <name> - Analyze specific mount")
        print("  /grc-debug performance - Run performance tests")
        print("  /grc-debug clear - Clear debug output")
        print("  /grc-debug toggle - Toggle debug mode")
        print("  /grc-debug log - Open debug log viewer")
        print("  /grc-debug logstats - Show log statistics")
        print("  /grc-debug copy [count] - Copy recent log entries")
        print("  /grc-debug help - Show this help")
        print("  /grc debug - Quick toggle (also available)")
        print("  /debuglog - Quick access to log viewer")
    else
        if IsDebugEnabled() then
            GRC.Debug.ShowStats()
        else
            print("|cFFFF6B35GRC:|r Debug mode is |cFFFF0000DISABLED|r")
            print("  Use /grc debug or /grc-debug toggle to enable")
            print("  Use /grc-debug log to view debug log (always available)")
        end
    end
end

-- Quick access to debug log
SLASH_DEBUGLOG1 = "/grc-debuglog"
SlashCmdList["DEBUGLOG"] = function(msg)
    GRC.Debug.CreateLogViewer()
end

-- Alternative quick toggle
SLASH_GRC_DEBUG_TOGGLE1 = "/grc-debug-toggle"
SlashCmdList["GRC_DEBUG_TOGGLE"] = function(msg)
    GRC.Debug.Toggle()
end

return GRC.Debug