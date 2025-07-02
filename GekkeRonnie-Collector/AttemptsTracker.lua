-- AttemptsTracker.lua - FIXED Integration with RarityDataImporter System
local addonName, GRC = ...
GRC.AttemptsTracker = GRC.AttemptsTracker or {}

-- FIXED: Simplified system that works WITH RarityDataImporter, not against it
local characterKey = nil
local sessionStartTime = time()
local isInitialized = false
local rarityAvailable = false

-- Session-only tracking (don't duplicate Rarity data)
local sessionAttempts = {
    mounts = {},
    pets = {},
    toys = {},
    totalAttempts = 0,
    lastUpdate = 0
}

-- FIXED: Check if we should use integrated system
local function ShouldUseIntegratedTracking()
    -- Use RarityDataImporter if available, fall back to basic tracking
    return GRC.RarityDataImporter and GRC.RarityDataImporter.IsAvailable()
end

-- Initialize tracking system
function GRC.AttemptsTracker.Initialize()
    if isInitialized then
        return true
    end
    
    characterKey = UnitName("player") .. "-" .. GetRealmName()
    sessionStartTime = time()
    
    if not characterKey or characterKey == "-" then
        GRC.Debug.Error("AttemptsTracker", "Could not determine character key")
        return false
    end
    
    rarityAvailable = ShouldUseIntegratedTracking()
    
    if rarityAvailable then
        GRC.Debug.Info("AttemptsTracker", "Using integrated Rarity system for attempt tracking")
    else
        GRC.Debug.Info("AttemptsTracker", "Using basic session tracking (no Rarity)")
    end
    
    isInitialized = true
    return true
end

-- FIXED: Enhanced encounter handler that notifies the integrated system
function GRC.AttemptsTracker.OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    if not success or not isInitialized then
        return
    end
    
    GRC.Debug.Info("AttemptsTracker", "Encounter completed: %s (ID: %d)", 
                   encounterName or "Unknown", encounterID or 0)
    
    if rarityAvailable then
        -- FIXED: Let RarityDataImporter handle the heavy lifting
        -- Just notify systems that a boss kill occurred
        if GRC.RarityDataImporter and GRC.RarityDataImporter.OnBossKill then
            GRC.RarityDataImporter.OnBossKill(nil, encounterID, GetZoneText())
        end
        
        if GRC.Core and GRC.Core.OnBossKill then
            GRC.Core.OnBossKill(nil, encounterID, encounterName, GetZoneText())
        end
    else
        -- Basic session tracking for non-Rarity users
        GRC.AttemptsTracker.AddSessionAttempt("mount", encounterID, encounterName)
    end
end

-- FIXED: Simple session tracking for when Rarity is not available
function GRC.AttemptsTracker.AddSessionAttempt(itemType, itemID, itemName)
    if not isInitialized then
        return false
    end
    
    local currentTime = time()
    local sessionKey = string.format("%s_%s", itemType, tostring(itemID))
    
    if not sessionAttempts[itemType .. "s"][sessionKey] then
        sessionAttempts[itemType .. "s"][sessionKey] = {
            itemID = itemID,
            itemName = itemName or "Unknown",
            attempts = 0,
            firstAttempt = currentTime,
            lastAttempt = currentTime,
            character = characterKey
        }
    end
    
    local sessionData = sessionAttempts[itemType .. "s"][sessionKey]
    sessionData.attempts = sessionData.attempts + 1
    sessionData.lastAttempt = currentTime
    sessionAttempts.totalAttempts = sessionAttempts.totalAttempts + 1
    sessionAttempts.lastUpdate = currentTime
    
    GRC.Debug.Trace("AttemptsTracker", "Session attempt added: %s %s (%d attempts)", 
                    itemType, itemName or "Unknown", sessionData.attempts)
    
    return true
end

-- FIXED: Get mount attempts - delegate to RarityDataImporter when available
function GRC.AttemptsTracker.GetMountAttempts(mountID, spellID)
    if not isInitialized then
        return GRC.AttemptsTracker.GetEmptyAttemptData()
    end
    
    if rarityAvailable and GRC.RarityDataImporter then
        -- FIXED: Use the integrated system's data
        local item = {
            mountID = mountID,
            spellID = spellID,
            attempts = 0,
            charactersTracked = 0
        }
        
        local latestData = GRC.RarityDataImporter.GetLatestAttemptData(item, "mount")
        if latestData then
            return {
                totalAttempts = latestData.attempts or 0,
                characterAttempts = 0, -- Would need character-specific logic
                sessionAttempts = latestData.sessionAttempts or 0,
                lastAttempt = latestData.lastAttempt,
                obtained = false, -- Would need to check collection status
                timeSpent = 0,
                sources = {},
                encounters = {},
                bossKills = {},
                charactersTracked = latestData.charactersTracked or 0
            }
        end
    end
    
    -- Fall back to session data or empty
    local sessionKey = string.format("mount_%s", tostring(spellID or mountID))
    local sessionData = sessionAttempts.mounts[sessionKey]
    
    if sessionData then
        return {
            totalAttempts = sessionData.attempts,
            characterAttempts = sessionData.attempts,
            sessionAttempts = sessionData.attempts,
            lastAttempt = sessionData.lastAttempt,
            obtained = false,
            timeSpent = 0,
            sources = {},
            encounters = {},
            bossKills = {},
            charactersTracked = 1
        }
    end
    
    return GRC.AttemptsTracker.GetEmptyAttemptData()
end

-- FIXED: Get pet attempts - delegate to RarityDataImporter when available
function GRC.AttemptsTracker.GetPetAttempts(speciesID)
    if not isInitialized then
        return GRC.AttemptsTracker.GetEmptyAttemptData()
    end
    
    if rarityAvailable and GRC.RarityDataImporter then
        local item = {
            speciesID = speciesID,
            attempts = 0,
            charactersTracked = 0
        }
        
        local latestData = GRC.RarityDataImporter.GetLatestAttemptData(item, "pet")
        if latestData then
            return {
                totalAttempts = latestData.attempts or 0,
                characterAttempts = 0,
                sessionAttempts = latestData.sessionAttempts or 0,
                lastAttempt = latestData.lastAttempt,
                obtained = false,
                timeSpent = 0,
                charactersTracked = latestData.charactersTracked or 0
            }
        end
    end
    
    -- Fall back to session data
    local sessionKey = string.format("pet_%s", tostring(speciesID))
    local sessionData = sessionAttempts.pets[sessionKey]
    
    if sessionData then
        return {
            totalAttempts = sessionData.attempts,
            characterAttempts = sessionData.attempts,
            sessionAttempts = sessionData.attempts,
            lastAttempt = sessionData.lastAttempt,
            obtained = false,
            timeSpent = 0,
            charactersTracked = 1
        }
    end
    
    return GRC.AttemptsTracker.GetEmptyAttemptData()
end

-- FIXED: Get toy attempts - delegate to RarityDataImporter when available
function GRC.AttemptsTracker.GetToyAttempts(toyID)
    if not isInitialized then
        return GRC.AttemptsTracker.GetEmptyAttemptData()
    end
    
    if rarityAvailable and GRC.RarityDataImporter then
        local item = {
            toyID = toyID,
            attempts = 0,
            charactersTracked = 0
        }
        
        local latestData = GRC.RarityDataImporter.GetLatestAttemptData(item, "toy")
        if latestData then
            return {
                totalAttempts = latestData.attempts or 0,
                characterAttempts = 0,
                sessionAttempts = latestData.sessionAttempts or 0,
                lastAttempt = latestData.lastAttempt,
                obtained = false,
                timeSpent = 0,
                charactersTracked = latestData.charactersTracked or 0
            }
        end
    end
    
    -- Fall back to session data
    local sessionKey = string.format("toy_%s", tostring(toyID))
    local sessionData = sessionAttempts.toys[sessionKey]
    
    if sessionData then
        return {
            totalAttempts = sessionData.attempts,
            characterAttempts = sessionData.attempts,
            sessionAttempts = sessionData.attempts,
            lastAttempt = sessionData.lastAttempt,
            obtained = false,
            timeSpent = 0,
            charactersTracked = 1
        }
    end
    
    return GRC.AttemptsTracker.GetEmptyAttemptData()
end

-- Helper function for empty attempt data
function GRC.AttemptsTracker.GetEmptyAttemptData()
    return {
        totalAttempts = 0,
        characterAttempts = 0,
        sessionAttempts = 0,
        lastAttempt = nil,
        obtained = false,
        timeSpent = 0,
        sources = {},
        encounters = {},
        bossKills = {},
        charactersTracked = 0
    }
end

-- FIXED: Get statistics - use integrated system when available
function GRC.AttemptsTracker.GetStatistics()
    if not isInitialized then
        return {
            totalMountsTracked = 0,
            totalAttempts = 0,
            totalTimeSpent = 0,
            charactersTracked = 0,
            mountsObtained = 0,
            totalBossKills = 0,
            integrationMode = "Not Initialized",
            requiresRarity = false,
            currentSession = {
                attempts = 0,
                timeSpent = time() - sessionStartTime,
                mounts = {}
            },
            topAttempts = {}
        }
    end
    
    local stats = {
        totalMountsTracked = 0,
        totalAttempts = 0,
        totalTimeSpent = 0,
        charactersTracked = 0,
        mountsObtained = 0,
        totalBossKills = 0,
        integrationMode = rarityAvailable and "Integrated with RarityDataImporter" or "Session Tracking Only",
        requiresRarity = false,
        currentSession = {
            attempts = sessionAttempts.totalAttempts,
            timeSpent = time() - sessionStartTime,
            mounts = {}
        },
        topAttempts = {}
    }
    
    if rarityAvailable and GRC.RarityDataImporter then
        -- FIXED: Get statistics from the integrated system
        local importerStats = GRC.RarityDataImporter.GetImportStatistics()
        if importerStats then
            stats.totalAttempts = importerStats.totalAttempts or 0
            stats.charactersTracked = importerStats.charactersProcessed or 0
        end
        
        local sessionStats = GRC.RarityDataImporter.GetSessionStatistics()
        if sessionStats then
            stats.currentSession.attempts = sessionStats.totalSessionAttempts or 0
        end
    else
        -- Use session-only data
        for itemType, items in pairs(sessionAttempts) do
            if itemType ~= "totalAttempts" and itemType ~= "lastUpdate" then
                for sessionKey, sessionData in pairs(items) do
                    if type(sessionData) == "table" then
                        stats.totalMountsTracked = stats.totalMountsTracked + 1
                        stats.totalAttempts = stats.totalAttempts + (sessionData.attempts or 0)
                        
                        if sessionData.attempts and sessionData.attempts > 0 then
                            table.insert(stats.currentSession.mounts, {
                                name = sessionData.itemName,
                                attempts = sessionData.attempts,
                                key = sessionKey
                            })
                            
                            table.insert(stats.topAttempts, {
                                name = sessionData.itemName,
                                attempts = sessionData.attempts,
                                obtained = false,
                                key = sessionKey,
                                lastAttempt = sessionData.lastAttempt
                            })
                        end
                    end
                end
            end
        end
        
        stats.charactersTracked = 1 -- Just this character
    end
    
    -- Sort top attempts
    table.sort(stats.topAttempts, function(a, b) 
        return (a.attempts or 0) > (b.attempts or 0) 
    end)
    
    return stats
end

-- FIXED: Utility functions
function GRC.AttemptsTracker.CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function GRC.AttemptsTracker.IsAvailable()
    return isInitialized
end

function GRC.AttemptsTracker.GetIntegrationMode()
    if not isInitialized then
        return "Not Initialized"
    end
    
    return rarityAvailable and "Integrated with RarityDataImporter" or "Session Tracking Only"
end

function GRC.AttemptsTracker.GetSessionData()
    return {
        sessionAttempts = sessionAttempts,
        sessionStartTime = sessionStartTime,
        characterKey = characterKey,
        totalSessionAttempts = sessionAttempts.totalAttempts,
        lastUpdate = sessionAttempts.lastUpdate
    }
end

-- FIXED: Simple event registration - just for encounters
local function RegisterEventHandlers()
    local frame = CreateFrame("Frame")
    
    -- SMART FILTERED: Only register encounter events
    frame:RegisterEvent("ENCOUNTER_END")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_END" then
            -- Only process if the smart filter allows it
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            
            if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("encounter_end", {
                encounterID = encounterID,
                encounterName = encounterName,
                success = success == 1
            }) then
                local success, errorMsg = pcall(GRC.AttemptsTracker.OnEncounterEnd, ...)
                if not success then
                    GRC.Debug.Error("AttemptsTracker", "Encounter tracking failed: %s", tostring(errorMsg))
                end
            end
        end
    end)
    
    GRC.Debug.Info("AttemptsTracker", "Smart filtered event handlers registered")
    return frame
end

-- FIXED: Simple initialization
local function Initialize()
    local success = GRC.AttemptsTracker.Initialize()
    
    if success then
        RegisterEventHandlers()
        
        if rarityAvailable then
            GRC.Debug.Info("AttemptsTracker", "Integrated tracking system ready (with RarityDataImporter)")
        else
            GRC.Debug.Info("AttemptsTracker", "Basic session tracking ready (no Rarity integration)")
        end
    else
        GRC.Debug.Error("AttemptsTracker", "Failed to initialize tracking system")
    end
end

-- Event handling for addon loading
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        frame:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- FIXED: Initialize after RarityDataImporter is ready
        C_Timer.After(12, function()
            Initialize()
        end)
        frame:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- FIXED: Simplified debug commands
SLASH_GRC_ATTEMPTS1 = "/grc-attempts"
SlashCmdList["GRC_ATTEMPTS"] = function(msg)
    if not isInitialized then
        print("|cFFFF6B35GRC Tracker:|r Not initialized yet")
        return
    end
    
    local stats = GRC.AttemptsTracker.GetStatistics()
    
    print(string.format("|cFFFF6B35GRC Tracker:|r %s", stats.integrationMode))
    print(string.format("  Total Attempts: %d", stats.totalAttempts))
    print(string.format("  Characters Tracked: %d", stats.charactersTracked))
    print(string.format("  Session Attempts: %d", stats.currentSession.attempts))
    print(string.format("  Session Time: %.1f minutes", stats.currentSession.timeSpent / 60))
    
    if rarityAvailable then
        print("  Data Source: Integrated with RarityDataImporter")
        
        if GRC.RarityDataImporter then
            local integrationStatus = GRC.RarityDataImporter.GetIntegrationStatus()
            print(string.format("  Live Data Items: %d", integrationStatus.liveDataItems or 0))
            print(string.format("  Last Refresh: %d seconds ago", 
                  integrationStatus.lastUpdate and (time() - integrationStatus.lastUpdate) or 0))
        end
    else
        print("  Data Source: Session tracking only")
        
        if #stats.currentSession.mounts > 0 then
            print("  Session Attempts:")
            for _, mount in ipairs(stats.currentSession.mounts) do
                print(string.format("    %s: %d attempts", mount.name, mount.attempts))
            end
        end
    end
    
    if #stats.topAttempts > 0 then
        print("  Top Attempts:")
        for i, mount in ipairs(stats.topAttempts) do
            if i <= 5 then
                print(string.format("    %s: %d attempts", mount.name, mount.attempts))
            end
        end
    end
end

GRC.Debug.Info("AttemptsTracker", "FIXED integrated tracking system loaded")

return GRC.AttemptsTracker