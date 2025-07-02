-- SimpleLockoutSystem.lua - COMPLETE with Multi-Character SavedVariables and Real-Time Tracking
local addonName, GRC = ...
GRC.SimpleLockouts = GRC.SimpleLockouts or {}

-- Enhanced lockout cache with per-character tracking
local lockoutData = {}
local characterLockouts = {} -- Track lockouts per character
local instanceNameCache = {} -- Cache Rarity-based instance names
local lastUpdate = 0
local CACHE_DURATION = 600 -- 10 minutes cache for better expiry detection
local lastRequestTime = 0
local REQUEST_THROTTLE = 60 -- 1 minute between API requests

-- Character key helper
local function GetCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- Difficulty mappings
local DIFFICULTY_NAMES = {
    [1] = "Normal",
    [2] = "Heroic", 
    [3] = "10 Player",
    [4] = "25 Player",
    [5] = "10 Player Heroic",
    [6] = "25 Player Heroic",
    [7] = "LFR",
    [14] = "Normal",
    [15] = "Heroic",
    [16] = "Mythic",
    [17] = "LFR",
    [23] = "Mythic",
    [24] = "Timewalking"
}

-- Get instance name using Rarity database integration
function GRC.SimpleLockouts.GetInstanceNameFromRarity(itemName, sourceText)
    if not itemName then return nil end
    
    -- Check cache first
    local cacheKey = (itemName or "") .. "|" .. (sourceText or "")
    if instanceNameCache[cacheKey] then
        return instanceNameCache[cacheKey]
    end
    
    local instanceName = nil
    
    -- Method 1: Use RarityIntegration to find the mount in Rarity database
    if GRC.RarityIntegration and GRC.RarityIntegration.IsAvailable() then
        local rarityData = nil
        
        if GRC.RarityIntegration.FindMountInRarity then
            -- Try by name first
            rarityData = GRC.RarityIntegration.FindMountInRarity(itemName, nil, nil)
            
            -- If not found, try with common variations
            if not rarityData then
                local variations = {
                    "Reins of " .. itemName,
                    "Reins of the " .. itemName,
                    itemName .. "'s Reins"
                }
                
                for _, variation in ipairs(variations) do
                    rarityData = GRC.RarityIntegration.FindMountInRarity(variation, nil, nil)
                    if rarityData then break end
                end
            end
        end
        
        -- If we found the mount in Rarity, try to get its instance
        if rarityData then
            -- Method 1a: Use GetInstanceFromRarityData if available
            if GRC.RarityIntegration.GetInstanceFromRarityData then
                instanceName = GRC.RarityIntegration.GetInstanceFromRarityData(rarityData)
            end
            
            -- Method 1b: Try to extract from boss name
            if not instanceName and rarityData.lockBossName then
                local bossToInstance = {
                    ["Gul'dan"] = "The Nighthold",
                    ["Argus the Unmaker"] = "Antorus, the Burning Throne",
                    ["G'huun"] = "Uldir",
                    ["Onyxia"] = "Onyxia's Lair",
                    ["Ragnaros"] = "Firelands",
                    ["The Lich King"] = "Icecrown Citadel",
                    ["Kael'thas Sunstrider"] = "Tempest Keep",
                    ["Prince Malchezaar"] = "Karazhan",
                    ["Attumen the Huntsman"] = "Karazhan"
                }
                
                instanceName = bossToInstance[rarityData.lockBossName]
            end
            
            -- Method 1c: Try to extract from coordinates/zone data
            if not instanceName and rarityData.coords and type(rarityData.coords) == "table" then
                for _, coord in ipairs(rarityData.coords) do
                    if coord and coord.m then
                        local zoneToInstance = {
                            [1088] = "The Nighthold",
                            [1712] = "Antorus, the Burning Throne",
                            [1861] = "Uldir",
                            [249] = "Onyxia's Lair",
                            [367] = "Firelands",
                            [631] = "Icecrown Citadel",
                            [550] = "Tempest Keep",
                            [532] = "Karazhan"
                        }
                        
                        instanceName = zoneToInstance[coord.m]
                        if instanceName then break end
                    end
                end
            end
        end
    end
    
    -- Method 2: Parse sourceText for known instance names
    if not instanceName and sourceText then
        local sourceTextLower = sourceText:lower()
        
        local knownInstances = {
            {"nighthold", "The Nighthold"},
            {"antorus", "Antorus, the Burning Throne"},
            {"uldir", "Uldir"},
            {"onyxia", "Onyxia's Lair"},
            {"firelands", "Firelands"},
            {"icecrown", "Icecrown Citadel"},
            {"tempest keep", "Tempest Keep"},
            {"karazhan", "Karazhan"},
            {"black temple", "Black Temple"},
            {"molten core", "Molten Core"}
        }
        
        for _, instancePair in ipairs(knownInstances) do
            if sourceTextLower:find(instancePair[1]) then
                instanceName = instancePair[2]
                break
            end
        end
    end
    
    -- Cache the result
    instanceNameCache[cacheKey] = instanceName
    
    return instanceName
end

-- FIXED: Initialize character lockout tracking with proper SavedVariables integration
function GRC.SimpleLockouts.InitializeCharacterTracking()
    local characterKey = GetCharacterKey()
    
    -- FIXED: Load from SavedVariables first
    if GRCollectorCharacterLockouts then
        characterLockouts = GRCollectorCharacterLockouts
    else
        characterLockouts = {}
        GRCollectorCharacterLockouts = characterLockouts
    end
    
    if not characterLockouts[characterKey] then
        characterLockouts[characterKey] = {}
    end
    
    -- FIXED: Clean up expired lockouts using REAL TIME TRACKING
    local currentTime = time()
    local expiredCount = 0
    
    for charKey, data in pairs(characterLockouts) do
        if data.lockouts then
            for instanceName, lockout in pairs(data.lockouts) do
                -- FIXED: Use absolute timestamp, not relative reset time
                if lockout.absoluteResetTime and lockout.absoluteResetTime < currentTime then
                    data.lockouts[instanceName] = nil
                    expiredCount = expiredCount + 1
                    
                    if GRCollectorSettings and GRCollectorSettings.debugMode then
                        print(string.format("|cFFFF6B35GRC:|r Cleaned expired lockout: %s for %s", instanceName, charKey))
                    end
                elseif lockout.resetTime and not lockout.absoluteResetTime then
                    -- MIGRATION: Convert old relative timestamps to absolute timestamps
                    -- This assumes the lockout was recorded when the character was last seen
                    local lastSeen = data.lastSeen or currentTime
                    lockout.absoluteResetTime = lastSeen + lockout.reset
                    
                    -- Clean if expired
                    if lockout.absoluteResetTime < currentTime then
                        data.lockouts[instanceName] = nil
                        expiredCount = expiredCount + 1
                    end
                end
            end
        end
    end
    
    if expiredCount > 0 and GRCollectorSettings and GRCollectorSettings.debugMode then
        print(string.format("|cFFFF6B35GRC:|r Cleaned %d expired lockouts across all characters", expiredCount))
    end
    
    -- Clean up character data if not seen in 14 days (increased from 7)
    local fourteenDaysAgo = currentTime - (14 * 24 * 60 * 60)
    for charKey, data in pairs(characterLockouts) do
        if data.lastSeen and data.lastSeen < fourteenDaysAgo then
            characterLockouts[charKey] = nil
        end
    end
    
    -- FIXED: Save back to SavedVariables
    GRCollectorCharacterLockouts = characterLockouts
end

-- Get current raid lockouts with character tracking
function GRC.SimpleLockouts.RefreshLockouts()
    local currentTime = time()
    local characterKey = GetCharacterKey()
    
    -- Initialize character tracking
    GRC.SimpleLockouts.InitializeCharacterTracking()
    
    -- Use cache if recent
    if currentTime - lastUpdate < CACHE_DURATION then
        return lockoutData
    end
    
    -- Throttle API requests
    if currentTime - lastRequestTime < REQUEST_THROTTLE then
        return lockoutData
    end
    
    -- Request fresh lockout data from WoW API
    RequestRaidInfo()
    lastRequestTime = currentTime
    
    -- Add delay to allow API to respond
    C_Timer.After(1, function()
        GRC.SimpleLockouts.ProcessLockoutData()
    end)
    
    return lockoutData
end

-- FIXED: Process lockout data with absolute timestamps for real-time tracking
function GRC.SimpleLockouts.ProcessLockoutData()
    local currentTime = time()
    local characterKey = GetCharacterKey()
    
    -- Ensure character exists in tracking
    if not characterLockouts[characterKey] then
        characterLockouts[characterKey] = {}
    end
    
    characterLockouts[characterKey] = {
        lockouts = {},
        lastSeen = currentTime,
        className = UnitClass("player"),
        level = UnitLevel("player")
    }
    
    -- Update main cache for current character only
    lockoutData = {}
    lastUpdate = currentTime
    
    -- Get current lockouts for this character
    local lockoutCount = 0
    local numSavedInstances = GetNumSavedInstances()
    
    for i = 1, numSavedInstances do
        local name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid, isHeroic, isLegacy, encounterProgress, extendDisabled = GetSavedInstanceInfo(i)
        
        -- Better lockout detection - include extended lockouts and encounter progress
        local hasLockout = locked or extended or (encounterProgress and encounterProgress > 0)
        
        if name and hasLockout then
            lockoutCount = lockoutCount + 1
            
            -- FIXED: Calculate absolute reset time (never changes regardless of when we check)
            local absoluteResetTime = currentTime + reset
            
            -- Calculate time remaining for display
            local days = math.floor(reset / 86400)
            local hours = math.floor((reset % 86400) / 3600)
            local minutes = math.floor((reset % 3600) / 60)
            
            -- Create time string
            local timeString = ""
            if days > 0 then
                timeString = string.format("%dd %dh %dm", days, hours, minutes)
            elseif hours > 0 then
                timeString = string.format("%dh %dm", hours, minutes)
            else
                timeString = string.format("%dm", minutes)
            end
            
            -- Get difficulty name
            local difficultyName = DIFFICULTY_NAMES[difficulty] or "Unknown"
            if difficultyName ~= "Unknown" then
                timeString = timeString .. " (" .. difficultyName .. ")"
            end
            
            -- Add status indicators
            local statusIndicators = {}
            if extended then
                table.insert(statusIndicators, "Extended")
            end
            if locked then
                table.insert(statusIndicators, "Locked")
            end
            if encounterProgress and encounterProgress > 0 then
                table.insert(statusIndicators, string.format("Progress: %d", encounterProgress))
            end
            
            if #statusIndicators > 0 then
                timeString = timeString .. " [" .. table.concat(statusIndicators, ", ") .. "]"
            end
            
            -- Create lockout info
            local lockout = {
                name = name,
                id = id,
                reset = reset, -- Keep original for compatibility
                difficulty = difficulty,
                difficultyName = difficultyName,
                locked = locked,
                extended = extended,
                encounterProgress = encounterProgress or 0,
                isRaid = isRaid,
                isHeroic = isHeroic,
                isLegacy = isLegacy,
                timeString = timeString,
                lastUpdated = currentTime,
                characterKey = characterKey,
                resetTime = currentTime + reset, -- Keep for compatibility
                absoluteResetTime = absoluteResetTime -- FIXED: Absolute timestamp
            }
            
            -- Store in main lockout data (current character only)
            lockoutData[name] = lockout
            lockoutData[name:lower()] = lockout
            
            -- FIXED: Store in character-specific lockouts with absolute timestamp
            characterLockouts[characterKey].lockouts[name] = {
                difficulty = difficulty,
                difficultyName = difficultyName,
                reset = reset,
                resetTime = currentTime + reset, -- Keep for compatibility
                absoluteResetTime = absoluteResetTime, -- FIXED: Real timestamp
                extended = extended,
                locked = locked,
                encounterProgress = encounterProgress or 0,
                timeString = timeString,
                isRaid = isRaid,
                recordedAt = currentTime -- When this lockout was recorded
            }
            
            -- Create common variations
            local variations = GRC.SimpleLockouts.GetNameVariations(name)
            for _, variation in ipairs(variations) do
                lockoutData[variation] = lockout
                lockoutData[variation:lower()] = lockout
            end
        end
    end
    
    -- FIXED: Save to SavedVariables immediately
    GRCollectorCharacterLockouts = characterLockouts
end

-- Load character lockouts from saved variables (already handled in InitializeCharacterTracking)
function GRC.SimpleLockouts.LoadCharacterLockouts()
    -- This is now handled in InitializeCharacterTracking for better integration
    GRC.SimpleLockouts.InitializeCharacterTracking()
end

-- FIXED: Get all characters with lockouts using real-time calculations
function GRC.SimpleLockouts.GetCharactersWithLockout(instanceName)
    local characters = {}
    local currentTime = time()
    
    -- Try multiple matching strategies
    local matchingStrategies = {
        -- Exact match
        function(lockoutName) return lockoutName:lower() == instanceName:lower() end,
        -- Contains match
        function(lockoutName) return lockoutName:lower():find(instanceName:lower(), 1, true) end,
        -- Reverse contains match  
        function(lockoutName) return instanceName:lower():find(lockoutName:lower(), 1, true) end,
        -- Word boundary match
        function(lockoutName) 
            local pattern = "%f[%a]" .. instanceName:lower():gsub("[%p%s]", "%%%1") .. "%f[%A]"
            return lockoutName:lower():find(pattern)
        end
    }
    
    -- Check ALL characters
    for charKey, data in pairs(characterLockouts) do
        if data.lockouts then
            for lockoutName, lockout in pairs(data.lockouts) do
                -- FIXED: Check using absolute timestamp for real-time tracking
                local lockoutExpired = false
                if lockout.absoluteResetTime then
                    lockoutExpired = lockout.absoluteResetTime < currentTime
                elseif lockout.resetTime and data.lastSeen then
                    -- Fallback calculation for old data
                    local timeElapsed = currentTime - data.lastSeen
                    lockoutExpired = (lockout.resetTime - timeElapsed) < currentTime
                else
                    lockoutExpired = true -- Assume expired if no proper timestamp
                end
                
                if not lockoutExpired then
                    local isMatch = false
                    
                    -- Try each matching strategy
                    for _, strategy in ipairs(matchingStrategies) do
                        if strategy(lockoutName) then
                            isMatch = true
                            break
                        end
                    end
                    
                    if isMatch then
                        -- FIXED: Calculate real remaining time
                        local timeRemaining = 0
                        if lockout.absoluteResetTime then
                            timeRemaining = lockout.absoluteResetTime - currentTime
                        elseif lockout.resetTime and data.lastSeen then
                            local timeElapsed = currentTime - data.lastSeen
                            timeRemaining = lockout.resetTime - timeElapsed
                        end
                        
                        -- Create updated lockout info with real-time data
                        local updatedLockout = {
                            difficulty = lockout.difficulty,
                            difficultyName = lockout.difficultyName,
                            extended = lockout.extended,
                            locked = lockout.locked,
                            encounterProgress = lockout.encounterProgress,
                            isRaid = lockout.isRaid,
                            resetTime = currentTime + timeRemaining, -- Recalculated
                            absoluteResetTime = lockout.absoluteResetTime,
                            timeRemaining = timeRemaining
                        }
                        
                        table.insert(characters, {
                            characterKey = charKey,
                            characterName = charKey:match("^([^-]+)"),
                            realm = charKey:match("-(.+)$"),
                            className = data.className,
                            level = data.level,
                            lockout = updatedLockout,
                            lastSeen = data.lastSeen,
                            actualLockoutName = lockoutName
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by character name
    table.sort(characters, function(a, b)
        return a.characterName < b.characterName
    end)
    
    return characters
end

-- CLEANED: Show lockout tooltip with real-time calculations
function GRC.SimpleLockouts.ShowLockoutTooltip(frame, item)
    if not frame or not item then return end
    
    -- Get instance name using enhanced Rarity integration
    local instanceName = GRC.SimpleLockouts.GetInstanceNameFromRarity(item.name, item.sourceText)
    
    -- If no specific instance found, try category-based fallback
    if not instanceName then
        if item.category == "Raid Drop" or item.category == "World Boss" then
            instanceName = "Any Raid"
        elseif item.category == "Dungeon Drop" then
            instanceName = "Any Dungeon"
        end
    end
    
    -- Get characters with matching lockouts
    local characters = {}
    local currentTime = time()
    
    if instanceName then
        if instanceName == "Any Raid" then
            -- For generic raid items, show all raid lockouts from ALL characters
            for charKey, charData in pairs(characterLockouts) do
                if charData.lockouts then
                    for lockoutName, lockout in pairs(charData.lockouts) do
                        -- Check if not expired using real-time calculation
                        local lockoutExpired = false
                        if lockout.absoluteResetTime then
                            lockoutExpired = lockout.absoluteResetTime < currentTime
                        end
                        
                        if lockout.isRaid and not lockoutExpired then
                            -- Calculate real remaining time
                            local timeRemaining = 0
                            if lockout.absoluteResetTime then
                                timeRemaining = lockout.absoluteResetTime - currentTime
                            end
                            
                            local updatedLockout = {
                                difficulty = lockout.difficulty,
                                difficultyName = lockout.difficultyName,
                                extended = lockout.extended,
                                timeRemaining = timeRemaining,
                                resetTime = currentTime + timeRemaining
                            }
                            
                            table.insert(characters, {
                                characterKey = charKey,
                                characterName = charKey:match("^([^-]+)"),
                                realm = charKey:match("-(.+)$") or GetRealmName(),
                                className = charData.className,
                                level = charData.level,
                                lockout = updatedLockout,
                                lastSeen = charData.lastSeen,
                                actualLockoutName = lockoutName,
                                isGenericMatch = true
                            })
                        end
                    end
                end
            end
        else
            -- For specific instances, use the enhanced function
            characters = GRC.SimpleLockouts.GetCharactersWithLockout(instanceName)
            
            -- Try variations if no exact match
            if #characters == 0 then
                local variations = {
                    instanceName:gsub("^The ", ""),
                    instanceName:gsub(", .*", ""),
                    instanceName:match("^([^,]+)")
                }
                
                for _, variation in ipairs(variations) do
                    if variation and variation ~= instanceName then
                        local varChars = GRC.SimpleLockouts.GetCharactersWithLockout(variation)
                        for _, char in ipairs(varChars) do
                            table.insert(characters, char)
                        end
                    end
                end
            end
        end
    end
    
    -- Show tooltip
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    -- Header with item info
    GameTooltip:AddLine("|cFFFFFF00Character Lockouts|r", 1, 1, 1)
    GameTooltip:AddLine(string.format("Item: %s", item.name or "Unknown"), 0.8, 0.8, 1)
    
    if instanceName and instanceName ~= "Any Raid" and instanceName ~= "Any Dungeon" then
        GameTooltip:AddLine(string.format("Source: %s", instanceName), 0.8, 1, 0.8)
    elseif item.category then
        GameTooltip:AddLine(string.format("Category: %s", item.category), 0.8, 1, 0.8)
    end
    
    GameTooltip:AddLine(" ", 1, 1, 1) -- Blank line
    
    if #characters == 0 then
        GameTooltip:AddLine("|cFF00FF00No characters currently locked|r", 0.8, 1, 0.8)
    else
        GameTooltip:AddLine(string.format("|cFFFF8888%d character(s) locked out:|r", #characters), 1, 0.8, 0.8)
        
        for i, char in ipairs(characters) do
            -- Character name with class color
            local classColor = RAID_CLASS_COLORS[char.className] or {r = 1, g = 1, b = 1}
            local charNameColored = string.format("|cFF%02x%02x%02x%s|r", 
                                                 classColor.r * 255, classColor.g * 255, classColor.b * 255, 
                                                 char.characterName)
            
            -- FIXED: Real-time time formatting using actual remaining time
            local timeRemaining = char.lockout.timeRemaining or 0
            local timeString = ""
            if timeRemaining > 0 then
                local days = math.floor(timeRemaining / 86400)
                local hours = math.floor((timeRemaining % 86400) / 3600)
                local minutes = math.floor((timeRemaining % 3600) / 60)
                
                if days > 0 then
                    timeString = string.format("%dd %dh", days, hours)
                elseif hours > 0 then
                    timeString = string.format("%dh %dm", hours, minutes)
                else
                    timeString = string.format("%dm", minutes)
                end
            else
                timeString = "Expired"
            end
            
            -- Status info
            local statusText = char.lockout.difficultyName
            if char.lockout.extended then
                statusText = statusText .. " [Extended]"
            end
            
            GameTooltip:AddLine(string.format("  %s (%s) - %s", 
                                             charNameColored, statusText, timeString), 1, 1, 1)
            
            -- Show actual lockout name if different and not generic
            if char.actualLockoutName and char.actualLockoutName ~= instanceName and not char.isGenericMatch then
                GameTooltip:AddLine(string.format("    Instance: %s", char.actualLockoutName), 0.7, 0.7, 0.7)
            end
        end
        
        -- Summary for multiple characters
        if #characters > 1 then
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(string.format("|cFFCCCCCCTotal: %d characters locked|r", #characters), 0.8, 0.8, 0.8)
        end
    end
    
    GameTooltip:Show()
end

-- Hide lockout tooltip
function GRC.SimpleLockouts.HideLockoutTooltip()
    GameTooltip:Hide()
end

-- Create name variations
function GRC.SimpleLockouts.GetNameVariations(instanceName)
    local variations = {}
    
    if not instanceName or type(instanceName) ~= "string" then
        return variations
    end
    
    -- Remove "The " prefix
    local withoutThe = instanceName:gsub("^The ", "")
    if withoutThe ~= instanceName then
        table.insert(variations, withoutThe)
    end
    
    -- Remove trailing descriptors
    local withoutComma = instanceName:gsub(", .*", "")
    if withoutComma ~= instanceName then
        table.insert(variations, withoutComma)
    end
    
    return variations
end

-- Simple lockout check - enhanced with character awareness
function GRC.SimpleLockouts.GetLockoutStatus(instanceName, showCharacterCount)
    if not instanceName then return "Available" end
    
    local lockouts = GRC.SimpleLockouts.RefreshLockouts()
    
    -- Try exact match first
    local lockout = lockouts[instanceName] or lockouts[instanceName:lower()]
    
    if lockout then
        if showCharacterCount then
            local characters = GRC.SimpleLockouts.GetCharactersWithLockout(instanceName)
            if #characters > 1 then
                return lockout.timeString .. string.format(" (+%d chars)", #characters - 1)
            end
        end
        return lockout.timeString
    end
    
    -- Try partial matching as fallback
    for cachedName, lockoutInfo in pairs(lockouts) do
        if type(lockoutInfo) == "table" and lockoutInfo.name then
            local originalName = lockoutInfo.name:lower()
            local queryName = instanceName:lower()
            
            if originalName:find(queryName, 1, true) or queryName:find(originalName, 1, true) then
                if showCharacterCount then
                    local characters = GRC.SimpleLockouts.GetCharactersWithLockout(lockoutInfo.name)
                    if #characters > 1 then
                        return lockoutInfo.timeString .. string.format(" (+%d chars)", #characters - 1)
                    end
                end
                return lockoutInfo.timeString
            end
        end
    end
    
    return "Available"
end

-- Smart mount lockout with Rarity-based instance detection
function GRC.SimpleLockouts.GetMountLockout(mount)
    if not mount then return "N/A", "|cFFCCCCCC" end
    
    -- Priority 1: Use Rarity lockout info if available
    if mount.isRarityTracked and mount.rarityData then
        local rarityLockout = GRC.RarityIntegration.GetRarityLockoutInfo(mount.rarityData)
        if rarityLockout and rarityLockout ~= "Unknown" and rarityLockout ~= "N/A" then
            if rarityLockout:find("Locked") then
                return rarityLockout, "|cFF888888"
            elseif rarityLockout:find("Available") then
                return "Weekly Available", "|cFFFF8800"
            else
                return rarityLockout, "|cFFCCCCCC"
            end
        end
    end
    
    -- Priority 2: Get instance name using Rarity database and check actual lockout status
    local instanceName = GRC.SimpleLockouts.GetInstanceNameFromRarity(mount.name, mount.sourceText)
    
    if instanceName then
        local lockoutStatus = GRC.SimpleLockouts.GetLockoutStatus(instanceName, true)
        
        if lockoutStatus ~= "Available" then
            -- Has active lockout - show in gray with actual lockout time
            return lockoutStatus, "|cFF888888"
        else
            -- Available - show with orange for weekly
            return "Weekly Available", "|cFFFF8800"
        end
    end
    
    -- Priority 3: Category-based fallback
    if mount.category then
        if mount.category == "Raid Drop" or mount.category:find("Raid") then
            return "Weekly Reset", "|cFFFF8800"
        elseif mount.category == "Dungeon Drop" or mount.category:find("Dungeon") then
            return "Daily Reset", "|cFF00FF00"
        elseif mount.category == "World Event" or mount.category == "Holiday Event" then
            return "Seasonal Event", "|cFF00CCFF"
        elseif mount.category == "Trading Post" then
            return "Monthly Reset", "|cFF00CCFF"
        elseif mount.category == "Achievement" or mount.category == "Quest" or mount.category == "Vendor" then
            return "Always Available", "|cFFFFFFFF"
        elseif mount.category == "World Boss" then
            return "Weekly Boss", "|cFFFF8800"
        end
    end
    
    return "Always Available", "|cFFFFFFFF"
end

-- Get lockout color for UI - enhanced
function GRC.SimpleLockouts.GetLockoutColor(instanceName)
    if not instanceName then return "|cFF00FF00", "Available" end
    
    local lockouts = GRC.SimpleLockouts.RefreshLockouts()
    local lockout = lockouts[instanceName] or lockouts[instanceName:lower()]
    
    -- Try partial matching if needed
    if not lockout then
        for cachedName, lockoutInfo in pairs(lockouts) do
            if type(lockoutInfo) == "table" and lockoutInfo.name then
                local originalName = lockoutInfo.name:lower()
                local queryName = instanceName:lower()
                
                if originalName:find(queryName, 1, true) or queryName:find(originalName, 1, true) then
                    lockout = lockoutInfo
                    break
                end
            end
        end
    end
    
    if lockout then
        local days = math.floor(lockout.reset / 86400)
        local hours = math.floor((lockout.reset % 86400) / 3600)
        
        -- Color based on time remaining
        local color = "|cFFFF0000" -- Red for locked
        if lockout.extended then
            color = "|cFFFF8800" -- Orange for extended
        elseif days == 0 and hours < 2 then
            color = "|cFFFFAA00" -- Yellow for expiring soon
        end
        
        -- Add character count if multiple characters are locked
        local characters = GRC.SimpleLockouts.GetCharactersWithLockout(lockout.name)
        local statusText = lockout.timeString
        if #characters > 1 then
            statusText = statusText .. string.format(" (+%d chars)", #characters - 1)
        end
        
        return color, statusText
    end
    
    return "|cFF00FF00", "Available"
end

-- Enhanced lockout summary with character breakdown
function GRC.SimpleLockouts.GetLockoutSummary()
    local lockouts = GRC.SimpleLockouts.RefreshLockouts()
    local summary = {
        totalLockouts = 0,
        expiringSoon = {},
        instances = {},
        characters = {},
        lastUpdated = lastUpdate
    }
    
    -- Process unique lockouts
    local processed = {}
    
    for name, lockout in pairs(lockouts) do
        if type(lockout) == "table" and not processed[lockout.name] then
            processed[lockout.name] = true
            summary.totalLockouts = summary.totalLockouts + 1
            
            local days = math.floor(lockout.reset / 86400)
            local hours = math.floor((lockout.reset % 86400) / 3600)
            
            -- Check if expiring soon
            if days == 0 and hours < 2 then
                table.insert(summary.expiringSoon, {
                    name = lockout.name,
                    difficulty = lockout.difficultyName,
                    hoursLeft = hours,
                    minutesLeft = math.floor((lockout.reset % 3600) / 60)
                })
            end
            
            -- Get all characters with this lockout
            local characters = GRC.SimpleLockouts.GetCharactersWithLockout(lockout.name)
            
            table.insert(summary.instances, {
                name = lockout.name,
                difficulty = lockout.difficultyName,
                reset = lockout.reset,
                extended = lockout.extended,
                timeString = lockout.timeString,
                characterCount = #characters,
                characters = characters
            })
        end
    end
    
    -- Character summary
    local currentTime = time()
    for charKey, data in pairs(characterLockouts) do
        if data.lockouts then
            local activeLockouts = 0
            for _, lockout in pairs(data.lockouts) do
                -- Check using absolute timestamp
                if lockout.absoluteResetTime and lockout.absoluteResetTime > currentTime then
                    activeLockouts = activeLockouts + 1
                end
            end
            
            if activeLockouts > 0 then
                table.insert(summary.characters, {
                    characterKey = charKey,
                    characterName = charKey:match("^([^-]+)"),
                    className = data.className,
                    level = data.level,
                    activeLockouts = activeLockouts,
                    lastSeen = data.lastSeen
                })
            end
        end
    end
    
    return summary
end

-- Utility function for counting tables
function GRC.SimpleLockouts.CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- Initialize system
function GRC.SimpleLockouts.Initialize()
    -- Load existing character lockouts
    GRC.SimpleLockouts.LoadCharacterLockouts()
    
    -- Get initial lockout data with delay
    C_Timer.After(5, function()
        RequestRaidInfo()
        GRC.SimpleLockouts.RefreshLockouts()
    end)
    
    -- Initialize instance name cache refresh
    C_Timer.After(10, function()
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print("|cFFFF6B35GRC:|r Lockout system ready with multi-character real-time tracking")
        end
    end)
end

-- Event handling with character tracking
local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("RAID_INSTANCE_WELCOME")

local lastEventTime = 0
local EVENT_THROTTLE = 30 -- 30 seconds between event processing

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UPDATE_INSTANCE_INFO" then
        local currentTime = time()
        if currentTime - lastEventTime < EVENT_THROTTLE then
            return
        end
        lastEventTime = currentTime
        
        -- Clear cache when lockout info updates
        lastUpdate = 0
        
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print("|cFFFF6B35GRC:|r Instance info updated for " .. GetCharacterKey())
        end
        
        -- Refresh UI if open
        if GRC.UI and GRC.UI.RefreshUI then
            C_Timer.After(5, function()
                GRC.UI.RefreshUI()
            end)
        end
        
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        if success and success == 1 then
            -- Boss kill - refresh lockouts
            lastUpdate = 0
            C_Timer.After(2, function()
                GRC.SimpleLockouts.RefreshLockouts()
            end)
        end
        
    elseif event == "RAID_INSTANCE_WELCOME" then
        -- Entering a raid - refresh lockouts
        lastUpdate = 0
        C_Timer.After(1, function()
            GRC.SimpleLockouts.RefreshLockouts()
        end)
        
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        C_Timer.After(8, function()
            GRC.SimpleLockouts.Initialize()
        end)
    end
end)

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        C_Timer.After(5, function()
            GRC.SimpleLockouts.Initialize()
        end)
        initFrame:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Debug commands with character lockout info
SLASH_GRC_LOCKOUTS1 = "/grc-lockouts"
SlashCmdList["GRC_LOCKOUTS"] = function(msg)
    if msg == "debug" then
        GRC.SimpleLockouts.DebugLockouts()
        print(string.format("  Throttling: Request every %ds, Events every %ds", 
              REQUEST_THROTTLE, EVENT_THROTTLE))
        print(string.format("  Instance names cached: %d", GRC.SimpleLockouts.CountTable(instanceNameCache)))
              
    elseif msg == "characters" or msg == "chars" then
        print("|cFFFF6B35GRC:|r Character Lockout Summary:")
        
        local summary = GRC.SimpleLockouts.GetLockoutSummary()
        if #summary.characters == 0 then
            print("  No characters currently have active lockouts")
        else
            for _, char in ipairs(summary.characters) do
                local classColor = RAID_CLASS_COLORS[char.className] or {r = 1, g = 1, b = 1}
                local charNameColored = string.format("|cFF%02x%02x%02x%s|r", 
                                                     classColor.r * 255, classColor.g * 255, classColor.b * 255, 
                                                     char.characterName)
                
                print(string.format("  %s (%s) - %d active lockouts", charNameColored, char.level, char.activeLockouts))
                
                local charData = characterLockouts[char.characterKey]
                if charData and charData.lockouts then
                    local currentTime = time()
                    for instanceName, lockout in pairs(charData.lockouts) do
                        if lockout.absoluteResetTime and lockout.absoluteResetTime > currentTime then
                            print(string.format("    %s (%s) - %s", instanceName, lockout.difficultyName, lockout.timeString))
                        end
                    end
                end
            end
        end
        
    elseif msg == "cache" then
        print("|cFFFF6B35GRC:|r Instance Name Cache:")
        print(string.format("  Cached entries: %d", GRC.SimpleLockouts.CountTable(instanceNameCache)))
        
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            for key, instanceName in pairs(instanceNameCache) do
                local itemName = key:match("^([^|]+)")
                print(string.format("  '%s' -> '%s'", itemName or "Unknown", instanceName or "nil"))
            end
        end
        
    elseif msg == "refresh" then
        lastUpdate = 0
        lastRequestTime = 0
        instanceNameCache = {} -- Clear instance name cache
        print("|cFFFF6B35GRC:|r Refreshing lockout data and clearing cache...")
        RequestRaidInfo()
        C_Timer.After(2, function()
            GRC.SimpleLockouts.RefreshLockouts()
            GRC.SimpleLockouts.DebugLockouts()
        end)
        
    elseif msg:trim() ~= "" then
        -- Test specific instance/item with Rarity lookup
        local searchTerm = msg:trim()
        
        -- Test Rarity lookup
        local instanceName = GRC.SimpleLockouts.GetInstanceNameFromRarity(searchTerm, "")
        local characters = GRC.SimpleLockouts.GetCharactersWithLockout(instanceName or searchTerm)
        
        print(string.format("|cFFFF6B35GRC Lockout Test:|r %s", searchTerm))
        print(string.format("  Rarity Instance Name: %s", instanceName or "Not found"))
        print(string.format("  Characters with lockout: %d", #characters))
        
        for _, char in ipairs(characters) do
            local classColor = RAID_CLASS_COLORS[char.className] or {r = 1, g = 1, b = 1}
            local charNameColored = string.format("|cFF%02x%02x%02x%s|r", 
                                                 classColor.r * 255, classColor.g * 255, classColor.b * 255, 
                                                 char.characterName)
            print(string.format("    %s (%s) - %s - %s", charNameColored, char.level, 
                               char.lockout.difficultyName, char.lockout.timeString or "Unknown"))
        end
        
    else
        print("|cFFFF6B35GRC:|r Lockout Commands:")
        print("  /grc-lockouts - Show current lockouts")
        print("  /grc-lockouts debug - Show lockout details")
        print("  /grc-lockouts characters - Show character lockout summary")
        print("  /grc-lockouts cache - Show Rarity instance name cache")
        print("  /grc-lockouts refresh - Force refresh lockout data")
        print("  /grc-lockouts <item name> - Test Rarity lookup for item")
        
        GRC.SimpleLockouts.DebugLockouts()
    end
end

-- Debug function with character tracking info
function GRC.SimpleLockouts.DebugLockouts()
    if not GRCollectorSettings or not GRCollectorSettings.debugMode then
        print("|cFFFF6B35GRC:|r Debug mode disabled. Enable with /grc debug")
        return
    end
    
    local lockouts = GRC.SimpleLockouts.RefreshLockouts()
    local characterKey = GetCharacterKey()
    
    print("|cFFFF6B35GRC Simple Lockouts:|r Current lockouts for " .. characterKey .. ":")
    
    local shown = {}
    local count = 0
    
    for name, lockout in pairs(lockouts) do
        if type(lockout) == "table" and not shown[lockout.name] then
            shown[lockout.name] = true
            count = count + 1
            
            local timeStr = lockout.timeString or "Unknown"
            local characters = GRC.SimpleLockouts.GetCharactersWithLockout(lockout.name)
            local charCount = #characters > 1 and string.format(" (+%d chars)", #characters - 1) or ""
            
            print(string.format("  %s - %s%s", lockout.name, timeStr, charCount))
        end
    end
    
    if count == 0 then
        print("  No current raid lockouts")
    else
        print(string.format("  Total: %d active lockouts", count))
    end
    
    local totalCharacters = GRC.SimpleLockouts.CountTable(characterLockouts)
    print(string.format("  Characters tracked: %d", totalCharacters))
    print(string.format("  Rarity integration: %s", (GRC.RarityDataImporter ~= nil) and "Available" or "Not available"))
    print(string.format("  Cache age: %d seconds", time() - lastUpdate))
end

return GRC.SimpleLockouts