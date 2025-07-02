-- Tooltip.lua - FIXED for Preview-Only Mode (COMPLETE VERSION)
local addonName, GRC = ...
GRC.Tooltip = GRC.Tooltip or {}

-- Settings
local tooltipEnabled = true

-- Check if tooltips are enabled
local function IsTooltipEnabled()
    return tooltipEnabled and GRCollectorSettings and GRCollectorSettings.showTooltips
end

-- FIXED: Mount tooltip with PREVIEW-ONLY instructions
function GRC.Tooltip.ShowMountTooltip(frame, mount, lockoutStatus)
    if not frame or not mount or not IsTooltipEnabled() then
        return
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    -- Mount name (colored by collection status)
    local nameColor = mount.isCollected and "|cFF00FF00" or "|cFFFF0000"
    GameTooltip:AddLine(nameColor .. (mount.name or "Unknown Mount") .. "|r", 1, 1, 1)
    
    -- Source information
    if mount.expansion or mount.category then
        GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
        if mount.expansion then
            GameTooltip:AddLine("|cFFFFFF00Expansion:|r " .. mount.expansion, 1, 1, 1)
        end
        if mount.category then
            GameTooltip:AddLine("|cFFFFFF00Category:|r " .. mount.category, 1, 1, 1)
        end
        if mount.dropRate then
            GameTooltip:AddLine("|cFFFFFF00Drop Rate:|r " .. mount.dropRate, 1, 1, 1)
        end
    end
    
    -- Enhanced attempt tracking with historic data
    local attempts = mount.attempts or 0
    local characterAttempts = mount.characterAttempts or 0
    local sessionAttempts = mount.sessionAttempts or 0
    
    if attempts > 0 or sessionAttempts > 0 then
        GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
        
        -- Total attempts with color coding
        local attemptsColor = "|cFFFF8080"
        if attempts >= 200 then
            attemptsColor = "|cFFFF0000" -- Red for extreme dedication
        elseif attempts >= 100 then
            attemptsColor = "|cFFFF4444" -- Dark red
        elseif attempts >= 50 then
            attemptsColor = "|cFFFFAA44" -- Orange
        elseif attempts >= 20 then
            attemptsColor = "|cFFFFCC44" -- Light orange
        else
            attemptsColor = "|cFFFFFF88" -- Yellow
        end
        
        GameTooltip:AddLine("|cFFFFFF00Total Attempts:|r " .. attemptsColor .. attempts .. "|r", 1, 1, 1)
        
        -- Character-specific attempts
        if characterAttempts > 0 then
            GameTooltip:AddLine("|cFFFFFF00This Character:|r " .. attemptsColor .. characterAttempts .. "|r", 1, 1, 1)
        end
        
        -- Session attempts
        if sessionAttempts > 0 then
            GameTooltip:AddLine("|cFFFFFF00This Session:|r |cFF88CCFF" .. sessionAttempts .. "|r", 1, 1, 1)
        end
        
        -- Last attempt timestamp
        if mount.lastAttempt then
            local timeAgo = time() - mount.lastAttempt
            local timeText = ""
            
            if timeAgo < 3600 then -- Less than 1 hour
                local minutes = math.floor(timeAgo / 60)
                timeText = minutes > 0 and (minutes .. " minutes ago") or "Just now"
            elseif timeAgo < 86400 then -- Less than 1 day
                local hours = math.floor(timeAgo / 3600)
                timeText = hours .. " hour" .. (hours == 1 and "" or "s") .. " ago"
            else -- Days
                local days = math.floor(timeAgo / 86400)
                timeText = days .. " day" .. (days == 1 and "" or "s") .. " ago"
            end
            
            GameTooltip:AddLine("|cFFFFFF00Last Attempt:|r |cFFCCCCCC" .. timeText .. "|r", 1, 1, 1)
        end
        
        -- Time spent farming (if available)
        if mount.timeSpent and mount.timeSpent > 0 then
            local timeSpentText = GRC.Tooltip.FormatTimeSpent(mount.timeSpent)
            GameTooltip:AddLine("|cFFFFFF00Time Spent:|r |cFFCCCCCC" .. timeSpentText .. "|r", 1, 1, 1)
        end
        
        -- Motivation messages for high attempt counts
        if attempts >= 200 then
            GameTooltip:AddLine("|cFFFF8888Legendary persistence! You're a true collector!|r", 1, 0.8, 0.8)
        elseif attempts >= 100 then
            GameTooltip:AddLine("|cFFFF8888You're incredibly dedicated! Keep going!|r", 1, 0.8, 0.8)
        elseif attempts >= 50 then
            GameTooltip:AddLine("|cFFFFAA88Halfway to the century club!|r", 1, 0.9, 0.8)
        end
    end
    
    -- Enhanced lockout information with detailed breakdown
    if mount.category == "Raid Drop" or mount.category == "Dungeon Drop" or mount.category == "World Boss" or 
       mount.category == "Trading Post" or mount.category == "World Event" or mount.category == "Holiday Event" then
        GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
        
        local lockoutInfo = lockoutStatus or mount.lockoutInfo or "Unknown"
        local lockoutColor = mount.lockoutColor or "|cFFCCCCCC"
        
        -- Category-specific lockout information
        if mount.category == "Raid Drop" then
            GameTooltip:AddLine("|cFFFFFF00Raid Lockout:|r " .. lockoutColor .. lockoutInfo .. "|r", 1, 1, 1)
        elseif mount.category == "Dungeon Drop" then
            GameTooltip:AddLine("|cFFFFFF00Dungeon Lockout:|r " .. lockoutColor .. lockoutInfo .. "|r", 1, 1, 1)
        elseif mount.category == "World Boss" then
            GameTooltip:AddLine("|cFFFFFF00World Boss:|r " .. lockoutColor .. "Weekly Reset" .. "|r", 1, 1, 1)
        elseif mount.category == "Trading Post" then
            GameTooltip:AddLine("|cFFFFFF00Trading Post:|r " .. lockoutColor .. lockoutInfo .. "|r", 1, 1, 1)
            if lockoutInfo ~= "Available" and not lockoutInfo:find("day") then
                GameTooltip:AddLine("  |cFFCCCCCCResets monthly with new items|r", 0.8, 0.8, 0.8)
            end
        elseif mount.category == "World Event" or mount.category == "Holiday Event" then
            GameTooltip:AddLine("|cFFFFFF00Holiday Event:|r " .. lockoutColor .. lockoutInfo .. "|r", 1, 1, 1)
            if lockoutInfo == "Active" then
                GameTooltip:AddLine("  |cFF00FF00Event is currently active!|r", 0.8, 1, 0.8)
            elseif lockoutInfo:find("Next") then
                GameTooltip:AddLine("  |cFFCCCCCCEvent returns " .. lockoutInfo:lower() .. "|r", 0.8, 0.8, 0.8)
            end
        end
    end
    
    -- Collection status with enhanced information
    GameTooltip:AddLine(" ", 1, 1, 1)
    local statusText = mount.isCollected and "|cFF00FF00Collected|r" or "|cFFFF0000Not Collected|r"
    GameTooltip:AddLine("|cFFFFFF00Status:|r " .. statusText, 1, 1, 1)
    
    -- Additional collection info
    if mount.isCollected then
        if mount.isFavorite then
            GameTooltip:AddLine("|cFFFFD700⭐ Favorited|r", 1, 1, 1)
        end
        if mount.obtainedAt and mount.obtainedAfter then
            local obtainedText = string.format("Obtained after %d attempts", mount.obtainedAfter)
            GameTooltip:AddLine("|cFF00FF00" .. obtainedText .. "|r", 0.8, 1, 0.8)
        end
    end
    
    -- FIXED: Click instructions - Open Mount Journal
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Click Actions:|r", 1, 1, 0)
    GameTooltip:AddLine("Left-click: Open in Mount Journal", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift+Left-click: Link to chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Show Wowhead link", 0.8, 0.8, 0.8)
    
    GameTooltip:Show()
end

-- Enhanced mini tooltip for compact displays and GUI integration
function GRC.Tooltip.ShowMiniTooltip(frame, mount)
    if not GRCollectorSettings or not GRCollectorSettings.showTooltips or not mount then 
        return 
    end
    
    GameTooltip:Hide()
    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    local nameColor = mount.isCollected and "|cFF00FF00" or "|cFFFF0000"
    GameTooltip:SetText(nameColor .. (mount.name or "Unknown") .. "|r")
    
    -- Enhanced attempt display with historic data
    local attempts = mount.attempts or 0
    local sessionAttempts = mount.sessionAttempts or 0
    
    if attempts > 0 or sessionAttempts > 0 then
        local attemptText = string.format("Total: %d", attempts)
        if sessionAttempts > 0 then
            attemptText = attemptText .. string.format(" (Session: %d)", sessionAttempts)
        end
        
        local attemptColor = GRC.Tooltip.GetAttemptColorCode(attempts)
        GameTooltip:AddLine(attemptText, unpack(GRC.Tooltip.HexToRGB(attemptColor)))
    end
    
    -- Enhanced lockout status
    if mount.lockoutInfo and mount.lockoutInfo ~= "Unknown" then
        local lockoutColor = mount.lockoutColor and GRC.Tooltip.HexToRGB(mount.lockoutColor) or {0.8, 0.8, 0.8}
        GameTooltip:AddLine("Lockout: " .. mount.lockoutInfo, unpack(lockoutColor))
    end
    
    -- Status and additional info
    if mount.isCollected then
        GameTooltip:AddLine("|cFF00FF00Collected!|r", 0.2, 1, 0.2)
        if mount.obtainedAfter and mount.obtainedAfter > 0 then
            GameTooltip:AddLine(string.format("After %d attempts", mount.obtainedAfter), 0.8, 1, 0.8)
        end
    else
        local dropRate = mount.dropRate or "~1%"
        GameTooltip:AddLine(dropRate, 0.8, 0.8, 0.8)
    end

    GameTooltip:Show()
end

-- FIXED: Pet tooltip with PREVIEW-ONLY instructions
function GRC.Tooltip.ShowPetTooltip(frame, pet, lockoutStatus)
    if not frame or not pet or not IsTooltipEnabled() then
        return
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    
    -- Pet name (colored by collection status)
    local nameColor = pet.isCollected and "|cFF00FF00" or "|cFFFF0000"
    GameTooltip:AddLine(nameColor .. (pet.name or "Unknown Pet") .. "|r", 1, 1, 1)
    
    -- Source information
    if pet.expansion or pet.category then
        GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
        if pet.expansion then
            GameTooltip:AddLine("|cFFFFFF00Expansion:|r " .. pet.expansion, 1, 1, 1)
        end
        if pet.category then
            GameTooltip:AddLine("|cFFFFFF00Category:|r " .. pet.category, 1, 1, 1)
        end
        if pet.petType then
            GameTooltip:AddLine("|cFFFFFF00Pet Type:|r " .. pet.petType, 1, 1, 1)
        end
        if pet.dropRate then
            GameTooltip:AddLine("|cFFFFFF00Drop Rate:|r " .. pet.dropRate, 1, 1, 1)
        end
    end
    
    -- Attempt tracking
    local attempts = pet.attempts or 0
    if attempts > 0 then
        GameTooltip:AddLine(" ", 1, 1, 1)
        local attemptsColor = GRC.Tooltip.GetAttemptColorCode(attempts)
        GameTooltip:AddLine("|cFFFFFF00Total Attempts:|r " .. attemptsColor .. attempts .. "|r", 1, 1, 1)
    end
    
    -- Pet-specific information
    if pet.isWild then
        GameTooltip:AddLine("|cFF88CCFF✓ Wild Pet (can be caught)|r", 1, 1, 1)
    end
    
    if pet.canBattle then
        GameTooltip:AddLine("|cFF88CCFF✓ Battle Pet|r", 1, 1, 1)
    end
    
    if pet.isTradeable then
        GameTooltip:AddLine("|cFF88CCFF✓ Tradeable|r", 1, 1, 1)
    end
    
    -- Collection status
    GameTooltip:AddLine(" ", 1, 1, 1)
    local statusText = pet.isCollected and "|cFF00FF00Collected|r" or "|cFFFF0000Not Collected|r"
    GameTooltip:AddLine("|cFFFFFF00Status:|r " .. statusText, 1, 1, 1)
    
    -- FIXED: Click instructions - Open Pet Journal
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Click Actions:|r", 1, 1, 0)
    GameTooltip:AddLine("Left-click: Open in Pet Journal", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift+Left-click: Link to chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Show Wowhead link", 0.8, 0.8, 0.8)
    
    GameTooltip:Show()
end

-- FIXED: Toy tooltip with NO ACTION instructions
function GRC.Tooltip.ShowToyTooltip(frame, toy, lockoutStatus)
    if not frame or not toy or not IsTooltipEnabled() then
        return
    end
    
    GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    
    -- Toy name (colored by collection status)
    local nameColor = toy.isCollected and "|cFF00FF00" or "|cFFFF0000"
    GameTooltip:AddLine(nameColor .. (toy.name or "Unknown Toy") .. "|r", 1, 1, 1)
    
    -- Source information
    if toy.expansion or toy.category then
        GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
        if toy.expansion then
            GameTooltip:AddLine("|cFFFFFF00Expansion:|r " .. toy.expansion, 1, 1, 1)
        end
        if toy.category then
            GameTooltip:AddLine("|cFFFFFF00Category:|r " .. toy.category, 1, 1, 1)
        end
        if toy.dropRate then
            GameTooltip:AddLine("|cFFFFFF00Drop Rate:|r " .. toy.dropRate, 1, 1, 1)
        end
    end
    
    -- Attempt tracking
    local attempts = toy.attempts or 0
    if attempts > 0 then
        GameTooltip:AddLine(" ", 1, 1, 1)
        local attemptsColor = GRC.Tooltip.GetAttemptColorCode(attempts)
        GameTooltip:AddLine("|cFFFFFF00Total Attempts:|r " .. attemptsColor .. attempts .. "|r", 1, 1, 1)
    end
    
    -- Collection status
    GameTooltip:AddLine(" ", 1, 1, 1)
    local statusText = toy.isCollected and "|cFF00FF00Collected|r" or "|cFFFF0000Not Collected|r"
    GameTooltip:AddLine("|cFFFFFF00Status:|r " .. statusText, 1, 1, 1)
    
    -- FIXED: Click instructions for toys (NO ACTION on left click)
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cFFFFD700Click Actions:|r", 1, 1, 0)
    GameTooltip:AddLine("Left-click: No action (preview mode)", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift+Left-click: Link to chat", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Show Wowhead link", 0.8, 0.8, 0.8)
    
    GameTooltip:Show()
end

-- Universal item tooltip with corrected instructions
function GRC.Tooltip.ShowItemTooltip(frame, item, itemType)
    if not IsTooltipEnabled() or not item or not frame then
        return false
    end
    
    -- Determine item type and call appropriate tooltip function
    if itemType == "mount" then
        GRC.Tooltip.ShowMountTooltip(frame, item)
    elseif itemType == "pet" then
        GRC.Tooltip.ShowPetTooltip(frame, item)
    elseif itemType == "toy" then
        GRC.Tooltip.ShowToyTooltip(frame, item)
    else
        -- Fallback: basic tooltip
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:SetText(item.name or "Unknown Item")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFD700Click Actions:|r", 1, 1, 0)
        GameTooltip:AddLine("Left-click: Preview/View item", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift+Left-click: Link to chat", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Show Wowhead link", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end
    
    return true
end

-- Hide tooltip
function GRC.Tooltip.HideTooltip()
    GameTooltip:Hide()
end

-- Alias for compatibility
function GRC.Tooltip.HideItemTooltip()
    GRC.Tooltip.HideTooltip()
end

-- Enhanced utility functions
function GRC.Tooltip.FormatTimeSpent(seconds)
    if not seconds or seconds <= 0 then
        return "0m"
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm", minutes)
    end
end

function GRC.Tooltip.GetAttemptColorCode(attempts)
    if attempts >= 200 then
        return "|cFFFF0000"  -- Red for extreme dedication
    elseif attempts >= 100 then
        return "|cFFFF4444"  -- Dark red
    elseif attempts >= 50 then
        return "|cFFFF8844"  -- Orange-red
    elseif attempts >= 20 then
        return "|cFFFFAA44"  -- Orange
    elseif attempts > 0 then
        return "|cFFFFFF88"  -- Yellow
    else
        return "|cFFCCCCCC"  -- Gray
    end
end

-- Convert hex color to RGB values
function GRC.Tooltip.HexToRGB(hexColor)
    if not hexColor or type(hexColor) ~= "string" then
        return {0.8, 0.8, 0.8} -- Default gray
    end
    
    -- Remove |c prefix and |r suffix if present
    local hex = hexColor:gsub("|c", ""):gsub("|r", "")
    
    -- Extract RGB components (skip alpha if present)
    if hex:len() == 8 then
        hex = hex:sub(3) -- Remove alpha component
    end
    
    if hex:len() == 6 then
        local r = tonumber(hex:sub(1, 2), 16) / 255
        local g = tonumber(hex:sub(3, 4), 16) / 255
        local b = tonumber(hex:sub(5, 6), 16) / 255
        return {r, g, b}
    end
    
    return {0.8, 0.8, 0.8} -- Default gray
end

-- Toggle tooltip system
function GRC.Tooltip.Toggle()
    if GRCollectorSettings then
        GRCollectorSettings.showTooltips = not GRCollectorSettings.showTooltips
        tooltipEnabled = GRCollectorSettings.showTooltips
        
        if tooltipEnabled then
            print("|cFFFF6B35GRC:|r Enhanced tooltips |cFF00FF00ENABLED|r")
        else
            print("|cFFFF6B35GRC:|r Enhanced tooltips |cFFFF0000DISABLED|r")
        end
    end
    
    return tooltipEnabled
end

-- Get tooltip status
function GRC.Tooltip.IsEnabled()
    return IsTooltipEnabled()
end

-- Initialize (simplified - no hooks needed since we call directly from GUI)
function GRC.Tooltip.Initialize()
    if not IsTooltipEnabled() then
        GRC.Debug.Info("Tooltip", "Tooltips disabled in settings")
        return
    end
    
    GRC.Debug.Info("Tooltip", "Enhanced tooltips ready for direct calls")
end

-- Slash command for testing
SLASH_GRC_TOOLTIP1 = "/grc-tooltip"
SlashCmdList["GRC_TOOLTIP"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local command = args[1] and args[1]:lower() or ""
    
    if command == "toggle" then
        GRC.Tooltip.Toggle()
    elseif command == "status" then
        print("|cFFFF6B35GRC Tooltip Status:|r")
        print("  Enabled: " .. tostring(IsTooltipEnabled()))
        print("  GameTooltip Available: " .. tostring(GameTooltip ~= nil))
    else
        print("|cFFFF6B35GRC Tooltip:|r Commands:")
        print("  /grc-tooltip toggle - Toggle enhanced tooltips")
        print("  /grc-tooltip status - Show tooltip system status")
        print("  Status: " .. (IsTooltipEnabled() and "|cFF00FF00ENABLED|r" or "|cFFFF0000DISABLED|r"))
    end
end

GRC.Debug.Info("Tooltip", "COMPLETE tooltip system with PREVIEW-ONLY behavior")

return GRC.Tooltip