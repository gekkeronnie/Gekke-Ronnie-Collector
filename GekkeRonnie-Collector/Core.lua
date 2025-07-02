-- Core.lua - COMPLETE FILE with Enhanced Ready State Tracking and Boss Kill Detection
local addonName, GRC = ...
GRC.Core = GRC.Core or {}

-- Settings
GRCollectorSettings = GRCollectorSettings or {
    showTooltips = true,
    showMinimapButton = true,
    soundOnDrop = true,
    showCollected = true,
    showUncollected = true,
    selectedExpansions = {},
    selectedCategories = {},
    debugMode = false,
    autoTrackAttempts = true,
    trackRareSpawns = true,
    dataQualityReporting = false,
    trackPets = true,
    trackToys = true,
    trackItems = true,
    trackMounts = true,
    enhancedBossTracking = true,
    optionalRarityIntegration = true,
    uiScale = 1.0,
    minimapButtonAngle = 180,
    -- ADD THIS NESTED TABLE:
    minimapButton = {
        hide = false,
        minimapPos = 180,
        radius = 80,
        lock = false,
        showInCompartment = true  -- This is the key setting!
    }
}

-- Character tracking
local characterKey = nil
local isReady = false
local initAttempts = 0
local maxInitAttempts = 30  -- Try for up to 30 seconds

-- Add tracking for boss kills and attempt updates
local lastBossKill = 0
local sessionAttempts = 0

-- ENHANCED: Global ready state tracking for better debugging
GRC._coreReady = false
GRC._initializationStatus = {
    characterKeySet = false,
    smartCacheReady = false,
    coreReady = false,
    uiReady = false,
    settingsLoaded = false,
    startTime = time()
}

-- Helper function to get NPC ID from GUID
function GRC.Core.GetNPCIDFromGUID(guid)
    if not guid then return nil end
    local npcID = tonumber(guid:match("-(%d+)-%x+$"))
    return npcID
end

-- Enhanced boss kill detection and notification
function GRC.Core.OnBossKill(npcID, encounterID, encounterName, zoneName)
    lastBossKill = time()
    
    GRC.Debug.Info("Core", "Boss kill detected: %s (NPC: %s, Encounter: %s) in %s", 
                   encounterName or "Unknown", tostring(npcID), tostring(encounterID), zoneName or GetZoneText())
    
    -- Notify all systems of boss kill
    if GRC.RarityDataImporter and GRC.RarityDataImporter.OnBossKill then
        GRC.RarityDataImporter.OnBossKill(npcID, encounterID, zoneName)
    end
    
    if GRC.SmartCache and GRC.SmartCache.OnBossKill then
        GRC.SmartCache.OnBossKill(npcID, encounterID)
    end
    
    if GRC.TrackingBar and GRC.TrackingBar.OnBossKill then
        GRC.TrackingBar.OnBossKill(npcID, encounterID)
    end
    
    -- Force UI refresh after boss kills
    C_Timer.After(2, function()
        if GRC.UI and GRC.UI.RefreshUI then
            GRC.UI.RefreshUI()
        end
    end)
end

-- Enhanced attempt tracking notification
function GRC.Core.OnAttemptAdded(itemType, itemID, newAttempts, characterKey)
    sessionAttempts = sessionAttempts + 1
    
    GRC.Debug.Trace("Core", "Attempt added: %s %s (%d attempts) for %s", 
                    itemType, tostring(itemID), newAttempts, characterKey or "current")
    
    -- Notify all systems of attempt update
    if GRC.RarityDataImporter and GRC.RarityDataImporter.OnAttemptAdded then
        GRC.RarityDataImporter.OnAttemptAdded(itemType, itemID, newAttempts, characterKey)
    end
    
    if GRC.SmartCache and GRC.SmartCache.OnAttemptAdded then
        GRC.SmartCache.OnAttemptAdded(itemType, itemID, newAttempts)
    end
    
    if GRC.TrackingBar and GRC.TrackingBar.OnAttemptAdded then
        GRC.TrackingBar.OnAttemptAdded(itemType, itemID, newAttempts)
    end
end

-- Enhanced collection update notification
function GRC.Core.OnCollectionUpdate(itemType, itemID, isCollected, itemName)
    GRC.Debug.Info("Core", "Collection update: %s %s (%s) = %s", 
                   itemType, tostring(itemID), itemName or "Unknown", tostring(isCollected))
    
    -- Notify all systems of collection update
    if GRC.RarityDataImporter and GRC.RarityDataImporter.OnCollectionUpdate then
        GRC.RarityDataImporter.OnCollectionUpdate(itemType, itemID, isCollected)
    end
    
    if GRC.SmartCache and GRC.SmartCache.OnCollectionUpdate then
        GRC.SmartCache.OnCollectionUpdate(itemType, itemID, isCollected)
    end
    
    if GRC.TrackingBar and GRC.TrackingBar.OnCollectionUpdate then
        GRC.TrackingBar.OnCollectionUpdate()
    end
    
    -- Show notification for new collections
    if isCollected and GRCollectorSettings.soundOnDrop then
        PlaySound(SOUNDKIT.ACHIEVEMENT_MENU_OPEN)
        print(string.format("|cFFFF6B35GRC:|r |cFF00FF00NEW %s COLLECTED:|r %s", 
              itemType:upper(), itemName or "Unknown"))
    end
    
    -- Force UI and tracking bar refresh
    C_Timer.After(0.5, function()
        if GRC.UI and GRC.UI.RefreshUI then
            GRC.UI.RefreshUI()
        end
        if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
            GRC.TrackingBar.ForceRefresh()
        end
    end)
end

-- CLEAN SYSTEM: All data comes from SmartCache with RarityDataImporter
function GRC.Core.GetAllMounts()
    if not GRC.SmartCache or not GRC.SmartCache.IsReady() then
        return {}
    end
    
    return GRC.SmartCache.GetAllMounts()
end

function GRC.Core.GetAllPets()
    if not GRC.SmartCache or not GRC.SmartCache.IsReady() then
        return {}
    end
    
    return GRC.SmartCache.GetAllPets()
end

function GRC.Core.GetAllToys()
    if not GRC.SmartCache or not GRC.SmartCache.IsReady() then
        return {}
    end
    
    return GRC.SmartCache.GetAllToys()
end

-- Get filtered mounts (used by UI)
function GRC.Core.GetFilteredMounts(searchText)
    local allMounts = GRC.Core.GetAllMounts()
    return GRC.Core.ApplyFilters(allMounts, searchText)
end

-- Get filtered pets (used by UI)
function GRC.Core.GetFilteredPets(searchText)
    local allPets = GRC.Core.GetAllPets()
    return GRC.Core.ApplyFilters(allPets, searchText)
end

-- Get filtered toys (used by UI)
function GRC.Core.GetFilteredToys(searchText)
    local allToys = GRC.Core.GetAllToys()
    return GRC.Core.ApplyFilters(allToys, searchText)
end

-- Generic filter function for all item types
function GRC.Core.ApplyFilters(items, searchText)
    local filtered = {}
    
    for _, item in ipairs(items) do
        local include = true
        
        -- Collection filter
        if not GRCollectorSettings.showCollected and item.isCollected then
            include = false
        end
        
        if not GRCollectorSettings.showUncollected and not item.isCollected then
            include = false
        end
        
        -- Search filter
        if searchText and searchText ~= "" then
            local searchLower = searchText:lower()
            local nameMatch = item.name and item.name:lower():find(searchLower, 1, true)
            local expansionMatch = item.expansion and item.expansion:lower():find(searchLower, 1, true)
            local categoryMatch = item.category and item.category:lower():find(searchLower, 1, true)
            local sourceMatch = item.sourceText and item.sourceText:lower():find(searchLower, 1, true)
            
            if not (nameMatch or expansionMatch or categoryMatch or sourceMatch) then
                include = false
            end
        end
        
        if include then
            table.insert(filtered, item)
        end
    end
    
    return filtered
end

-- ENHANCED: Core system functions with better ready state tracking
function GRC.Core.IsReady()
    local coreReady = isReady and GRC.SmartCache and GRC.SmartCache.IsReady()
    GRC._coreReady = coreReady -- Store globally for debugging
    GRC._initializationStatus.coreReady = coreReady
    return coreReady
end

-- ENHANCED: Debug function to check what's missing
function GRC.Core.GetReadyStatus()
    local status = {
        isReadyFlag = isReady,
        smartCacheExists = GRC.SmartCache ~= nil,
        smartCacheReady = GRC.SmartCache and GRC.SmartCache.IsReady() or false,
        smartCacheBuilding = GRC.SmartCache and GRC.SmartCache.IsBuilding and GRC.SmartCache.IsBuilding() or false,
        characterKey = characterKey,
        initAttempts = initAttempts,
        maxInitAttempts = maxInitAttempts,
        initializationStatus = GRC._initializationStatus,
        timeElapsed = time() - GRC._initializationStatus.startTime,
        uiExists = GRC.UI ~= nil,
        uiToggleExists = GRC.UI and GRC.UI.ToggleUI ~= nil,
        settingsExists = GRCollectorSettings ~= nil
    }
    return status
end

function GRC.Core.Refresh()
    if GRC.SmartCache then
        local success = GRC.SmartCache.Refresh()
        if success then
            print("|cFFFF6B35GRC:|r Cache refreshed successfully")
            
            -- Force tracking bar refresh after cache refresh
            if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
                C_Timer.After(0.5, function()
                    GRC.TrackingBar.ForceRefresh()
                end)
            end
        end
        return success
    end
    return false
end

-- ENHANCED: Callback for when cache becomes ready with better notifications
function GRC.Core.OnCacheReady()
    if not isReady then
        isReady = true
        GRC._coreReady = true
        GRC._initializationStatus.coreReady = true
        GRC._initializationStatus.smartCacheReady = true
        
        local stats = GRC.Core.GetStatistics()
        local cacheStats = GRC.SmartCache.GetStats()
        
        -- Show ready message
        print("|cFFFF6B35GRC:|r Ready! Use /grc or the minimap button to open interface.")
        
        -- DETAILED: Only in debug mode
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print(string.format("  %d mounts (%d collected), %d pets (%d collected), %d toys (%d collected)", 
                  stats.totalMounts, stats.collectedMounts,
                  stats.totalPets, stats.collectedPets,
                  stats.totalToys, stats.collectedToys))
            
            local totalTracked = stats.mountsBeingTracked + stats.petsBeingTracked + stats.toysBeingTracked
            if totalTracked > 0 then
                print(string.format("  %d items with attempt data", totalTracked))
            end
            
            -- Show integration status
            if cacheStats.standaloneMode then
                print("  Running in |cFFFFAA00STANDALONE MODE|r")
            else
                print("  Running with |cFF00FF00RARITY IMPORT|r")
                
                if GRC.RarityIntegration then
                    local rarityStats = GRC.RarityIntegration.GetDatabaseStatistics()
                    print(string.format("  - Rarity database: %d mounts, %d pets, %d toys", 
                          rarityStats.totalMounts, rarityStats.totalPets, rarityStats.totalToys))
                end
                
                if GRC.RarityDataImporter then
                    local importStats = GRC.RarityDataImporter.GetImportStatistics()
                    print(string.format("  - Total attempts imported: %d", importStats.totalAttempts))
                end
            end
            
            -- Show attempt sync status
            if GRC.SmartCache and GRC.SmartCache.GetAttemptSyncStatus then
                local syncStatus = GRC.SmartCache.GetAttemptSyncStatus()
                print(string.format("  - Attempt sync: %s (interval: %ds)", 
                      syncStatus.syncActive and "Active" or "Inactive", syncStatus.syncInterval))
            end
        end
        
        -- Initialize tracking bar when cache is ready
        if GRC.TrackingBar and GRC.TrackingBar.Initialize then
            C_Timer.After(1, function()
                GRC.TrackingBar.Initialize()
            end)
        end
        
        -- Refresh UI if it's open
        if GRC.UI and GRC.UI.RefreshUI then
            GRC.UI.RefreshUI()
        end
        
        -- Notify minimap button that we're ready
        if GRC.MinimapButton and GRC.MinimapButton.UpdateTooltip then
            GRC.MinimapButton.UpdateTooltip()
        end
    end
end

-- ENHANCED: Mount preview with dressing room fallback
function GRC.Core.PreviewMount(mountID)
    if not mountID then return end
    
    -- Try dressing room first
    if DressUpMount then
        local success, error = pcall(DressUpMount, mountID)
        if success then
            return
        end
    end
    
    -- Fallback to summon
    if C_MountJournal and C_MountJournal.SummonByID then
        C_MountJournal.SummonByID(mountID)
    end
end

-- ENHANCED: Pet summon with dressing room preview
function GRC.Core.SummonPet(speciesID)
    if not speciesID then return end
    
    -- Try dressing room first
    if DressUpBattlePet then
        local success, error = pcall(DressUpBattlePet, speciesID)
        if success then
            return
        end
    end
    
    -- Fallback to summon
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local petID, currentSpeciesID, owned = C_PetJournal.GetPetInfoByIndex(i)
        if currentSpeciesID == speciesID and owned and petID then
            C_PetJournal.SummonPetByGUID(petID)
            break
        end
    end
end

-- Enhanced toy function with proper error handling
function GRC.Core.UseToy(toyID)
    if not toyID then 
        print("|cFFFF6B35GRC:|r Invalid toy ID")
        return 
    end
    
    if PlayerHasToy and PlayerHasToy(toyID) then
        if C_ToyBox and C_ToyBox.UseToy then
            C_ToyBox.UseToy(toyID)
        else
            print("|cFFFF6B35GRC:|r ToyBox API not available")
        end
    else
        print("|cFFFF6B35GRC:|r You don't own this toy")
    end
end

function GRC.Core.CopyWowheadLink(itemID, itemType)
    if not itemID then return end
    
    local baseURL = "https://www.wowhead.com/"
    local link = ""
    
    if itemType == "mount" then
        link = baseURL .. "spell=" .. itemID
    elseif itemType == "pet" then
        link = baseURL .. "npc=" .. itemID
    elseif itemType == "toy" then
        link = baseURL .. "item=" .. itemID
    else
        link = baseURL .. "item=" .. itemID
    end
    
    print("|cFFFF6B35GRC:|r Wowhead link: " .. link)
end

-- Enhanced statistics for all item types
function GRC.Core.GetStatistics()
    local allMounts = GRC.Core.GetAllMounts()
    local allPets = GRC.Core.GetAllPets()
    local allToys = GRC.Core.GetAllToys()
    
    local stats = {
        -- Mounts
        totalMounts = #allMounts,
        collectedMounts = 0,
        
        -- Pets  
        totalPets = #allPets,
        collectedPets = 0,
        
        -- Toys
        totalToys = #allToys,
        collectedToys = 0,
        
        -- Combined
        total = #allMounts + #allPets + #allToys,
        collected = 0,
        
        -- Tracking stats
        totalAttempts = 0,
        totalBossKills = 0,
        charactersTracked = 0,
        mountsBeingTracked = 0,
        petsBeingTracked = 0,
        toysBeingTracked = 0,
        currentLockouts = 0,
        sessionAttempts = sessionAttempts,  -- Add session tracking
        lastBossKill = lastBossKill
    }
    
    -- Count mounts
    for _, mount in ipairs(allMounts) do
        if mount.isCollected then
            stats.collectedMounts = stats.collectedMounts + 1
        end
        
        stats.totalAttempts = stats.totalAttempts + (mount.attempts or 0)
        
        if mount.attempts and mount.attempts > 0 then
            stats.mountsBeingTracked = stats.mountsBeingTracked + 1
        end
        
        if mount.charactersTracked and mount.charactersTracked > 0 then
            stats.charactersTracked = math.max(stats.charactersTracked, mount.charactersTracked)
        end
        
        if mount.lockoutInfo and mount.lockoutInfo ~= "Available" and mount.lockoutInfo ~= "N/A" and mount.lockoutInfo ~= "Unknown" then
            stats.currentLockouts = stats.currentLockouts + 1
        end
    end
    
    -- Count pets
    for _, pet in ipairs(allPets) do
        if pet.isCollected then
            stats.collectedPets = stats.collectedPets + 1
        end
        
        stats.totalAttempts = stats.totalAttempts + (pet.attempts or 0)
        
        if pet.attempts and pet.attempts > 0 then
            stats.petsBeingTracked = stats.petsBeingTracked + 1
        end
        
        if pet.charactersTracked and pet.charactersTracked > 0 then
            stats.charactersTracked = math.max(stats.charactersTracked, pet.charactersTracked)
        end
    end
    
    -- Count toys with support
    for _, toy in ipairs(allToys) do
        -- Skip placeholder toys
        if toy.toyID and toy.toyID > 0 and toy.name ~= "ToyBox API not available" then
            if toy.isCollected then
                stats.collectedToys = stats.collectedToys + 1
            end
            
            stats.totalAttempts = stats.totalAttempts + (toy.attempts or 0)
            
            if toy.attempts and toy.attempts > 0 then
                stats.toysBeingTracked = stats.toysBeingTracked + 1
            end
            
            if toy.charactersTracked and toy.charactersTracked > 0 then
                stats.charactersTracked = math.max(stats.charactersTracked, toy.charactersTracked)
            end
        end
    end
    
    stats.collected = stats.collectedMounts + stats.collectedPets + stats.collectedToys
    
    return stats
end

-- Enhanced statistics for DataQualityChecker compatibility
function GRC.Core.GetEnhancedStatistics()
    local stats = GRC.Core.GetStatistics()
    
    -- Check integration mode
    local cacheStats = GRC.SmartCache and GRC.SmartCache.GetStats() or {}
    local integrationMode = cacheStats.standaloneMode and "Standalone" or "Rarity Import"
    
    -- Add enhanced tracking data from RarityDataImporter
    local enhancedStats = {
        totalAttempts = stats.totalAttempts,
        totalBossKills = stats.totalBossKills,
        mountsBeingTracked = stats.mountsBeingTracked,
        petsBeingTracked = stats.petsBeingTracked,
        toysBeingTracked = stats.toysBeingTracked,
        charactersTracked = stats.charactersTracked,
        currentLockouts = stats.currentLockouts,
        integrationMode = integrationMode,
        sessionAttempts = stats.sessionAttempts,  -- Add session data
        lastBossKill = stats.lastBossKill,
        mounts = {
            total = stats.totalMounts,
            collected = stats.collectedMounts,
            tracked = stats.mountsBeingTracked,
            attempts = 0 -- Will be calculated below
        },
        pets = {
            total = stats.totalPets,
            collected = stats.collectedPets,
            tracked = stats.petsBeingTracked,
            attempts = 0 -- Will be calculated below
        },
        toys = {
            total = stats.totalToys,
            collected = stats.collectedToys,
            tracked = stats.toysBeingTracked,
            attempts = 0 -- Will be calculated below
        },
        items = {
            total = stats.totalToys, -- Toys are items
            collected = stats.collectedToys,
            tracked = stats.toysBeingTracked,
            attempts = 0
        }
    }
    
    -- Calculate attempts per type
    local allMounts = GRC.Core.GetAllMounts()
    for _, mount in ipairs(allMounts) do
        enhancedStats.mounts.attempts = enhancedStats.mounts.attempts + (mount.attempts or 0)
    end
    
    local allPets = GRC.Core.GetAllPets()
    for _, pet in ipairs(allPets) do
        enhancedStats.pets.attempts = enhancedStats.pets.attempts + (pet.attempts or 0)
    end
    
    local allToys = GRC.Core.GetAllToys()
    for _, toy in ipairs(allToys) do
        -- Skip placeholder toys
        if toy.toyID and toy.toyID > 0 and toy.name ~= "ToyBox API not available" then
            enhancedStats.toys.attempts = enhancedStats.toys.attempts + (toy.attempts or 0)
            enhancedStats.items.attempts = enhancedStats.items.attempts + (toy.attempts or 0)
        end
    end
    
    -- Get detailed stats from RarityDataImporter if available
    if GRC.RarityDataImporter and GRC.RarityDataImporter.GetImportStatistics then
        local importerStats = GRC.RarityDataImporter.GetImportStatistics()
        enhancedStats.importerStats = importerStats
        enhancedStats.integrationMode = importerStats.available and "Rarity Import" or "Standalone"
    end
    
    -- Add attempt sync status
    if GRC.SmartCache and GRC.SmartCache.GetAttemptSyncStatus then
        enhancedStats.attemptSyncStatus = GRC.SmartCache.GetAttemptSyncStatus()
    end
    
    return enhancedStats
end

-- Enhanced search for all item types
function GRC.Core.SearchMounts(searchText)
    local allMounts = GRC.Core.GetAllMounts()
    return GRC.Core.SearchItems(allMounts, searchText)
end

function GRC.Core.SearchPets(searchText)
    local allPets = GRC.Core.GetAllPets()
    return GRC.Core.SearchItems(allPets, searchText)
end

function GRC.Core.SearchToys(searchText)
    local allToys = GRC.Core.GetAllToys()
    return GRC.Core.SearchItems(allToys, searchText)
end

function GRC.Core.SearchItems(items, searchText)
    local results = {}
    local searchLower = searchText:lower()
    
    for _, item in ipairs(items) do
        -- Skip placeholder toys in search
        if item.itemType == "toy" and (not item.toyID or item.toyID <= 0 or item.name == "ToyBox API not available") then
            -- Skip placeholder toys
        else
            local nameMatch = item.name and item.name:lower():find(searchLower, 1, true)
            local expansionMatch = item.expansion and item.expansion:lower():find(searchLower, 1, true)
            local categoryMatch = item.category and item.category:lower():find(searchLower, 1, true)
            local sourceMatch = item.sourceText and item.sourceText:lower():find(searchLower, 1, true)
            
            if nameMatch or expansionMatch or categoryMatch or sourceMatch then
                table.insert(results, item)
            end
        end
    end
    
    return results
end

-- ENHANCED: Better initialization with cache waiting and status tracking
function GRC.Core.Init()
    characterKey = UnitName("player") .. "-" .. GetRealmName()
    GRC._initializationStatus.characterKeySet = true
    GRC._initializationStatus.settingsLoaded = GRCollectorSettings ~= nil
    
    if GRCollectorSettings and GRCollectorSettings.debugMode then
        print("|cFFFF6B35GRC:|r Core system initialized for: " .. characterKey)
    end
    
    -- Start waiting for cache to be ready
    local function waitForCacheReady()
        initAttempts = initAttempts + 1
        
        if GRC.SmartCache then
            if GRC.SmartCache.IsReady() then
                -- Cache is ready!
                GRC.Core.OnCacheReady()
                return true
            elseif GRC.SmartCache.IsBuilding() then
                -- Cache is building, keep waiting
                if GRCollectorSettings and GRCollectorSettings.debugMode then
                    print("|cFFFF6B35GRC:|r Cache building... (attempt " .. initAttempts .. "/" .. maxInitAttempts .. ")")
                end
            else
                -- Cache exists but not ready yet, might need time
                if GRCollectorSettings and GRCollectorSettings.debugMode then
                    print("|cFFFF6B35GRC:|r Cache not ready yet... (attempt " .. initAttempts .. "/" .. maxInitAttempts .. ")")
                end
            end
        else
            -- SmartCache not available yet
            if GRCollectorSettings and GRCollectorSettings.debugMode then
                print("|cFFFF6B35GRC:|r SmartCache not available yet... (attempt " .. initAttempts .. "/" .. maxInitAttempts .. ")")
            end
        end
        
        -- Continue waiting if we haven't exceeded max attempts
        if initAttempts < maxInitAttempts then
            C_Timer.After(1, waitForCacheReady)
        else
            -- Timeout - show ready anyway but with warning
            print("|cFFFF6B35GRC:|r Ready (cache still building) - Use /grc to open interface")
            print("|cFFFF6B35GRC:|r Cache will be available shortly...")
            isReady = true
            GRC._coreReady = true
            GRC._initializationStatus.coreReady = true
        end
        
        return false
    end
    
    -- Start the waiting process
    waitForCacheReady()
    return true
end

-- UPDATED: Enhanced event handling with SMART EVENT FILTERING
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- SMART FILTERED: Only register events that can result in collectibles
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("BOSS_KILL")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
eventFrame:RegisterEvent("NEW_PET_ADDED")
eventFrame:RegisterEvent("NEW_TOY_ADDED")
eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")

-- REMOVED: UNIT_SPELLCAST_SUCCEEDED - was causing spam during flying

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        GRC._initializationStatus.settingsLoaded = true
        
    elseif event == "PLAYER_LOGIN" then
        -- Only show in debug mode
        if GRCollectorSettings and GRCollectorSettings.debugMode then
            print("|cFFFF6B35GRC:|r Initializing collection system with smart event filtering...")
        end
        
        C_Timer.After(3, function()
            if GRC.Core.Init() then
                -- Success message is shown in OnCacheReady() when ready
            else
                print("|cFFFF6B35GRC:|r Failed to initialize.")
            end
        end)
        
    -- SMART FILTERED: Enhanced boss kill detection
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("encounter_end", {
            encounterID = encounterID,
            encounterName = encounterName,
            success = success == 1
        }) then
            local zoneName = GetZoneText()
            GRC.Core.OnBossKill(nil, encounterID, encounterName, zoneName)
        end
        
    elseif event == "BOSS_KILL" then
        local id, name = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("boss_kill", {
            npcID = id,
            npcName = name
        }) then
            local zoneName = GetZoneText()
            GRC.Core.OnBossKill(id, nil, name, zoneName)
        end
        
    elseif event == "LOOT_CLOSED" then
        -- SMART FILTERED: Only refresh in collectible contexts
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("loot", {
            eventType = "loot_closed"
        }) then
            C_Timer.After(0.5, function()
                if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
                    GRC.TrackingBar.ForceRefresh()
                end
            end)
        end
        
    elseif event == "CHAT_MSG_LOOT" then
        local text, playerName = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("loot", {
            lootText = text,
            playerName = playerName
        }) then
            C_Timer.After(1, function()
                if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
                    GRC.TrackingBar.ForceRefresh()
                end
            end)
        end
        
    elseif event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        -- Get mount info for notification
        local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
        GRC.Core.OnCollectionUpdate("mount", mountID, true, name)
        
    elseif event == "NEW_PET_ADDED" then
        local petID = ...
        -- Try to get pet info
        local name = "Unknown Pet"
        if petID then
            local petInfo = C_PetJournal.GetPetInfoByPetID(petID)
            if petInfo then
                name = petInfo
            end
        end
        GRC.Core.OnCollectionUpdate("pet", petID, true, name)
        
    elseif event == "NEW_TOY_ADDED" then
        local toyID = ...
        -- Get toy info for notification
        local name = "Unknown Toy"
        if toyID and C_ToyBox and C_ToyBox.GetToyInfo then
            local itemID, toyName = C_ToyBox.GetToyInfo(toyID)
            if toyName then
                name = toyName
            end
        end
        GRC.Core.OnCollectionUpdate("toy", toyID, true, name)
        
    elseif event == "ACHIEVEMENT_EARNED" then
        local achievementID = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("achievement", {
            achievementID = achievementID
        }) then
            C_Timer.After(2, function()
                if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
                    GRC.TrackingBar.ForceRefresh()
                end
            end)
        end
    end
end)

-- Enhanced slash commands with ready status debugging
SLASH_GEKKERONNIECOLLECTOR1 = "/grc"
SLASH_GEKKERONNIECOLLECTOR2 = "/gekkeronnie"
SlashCmdList["GEKKERONNIECOLLECTOR"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg:lower())
    end
    
    local command = args[1] or ""
    
    if command == "stats" then
        local stats = GRC.Core.GetStatistics()
        local enhancedStats = GRC.Core.GetEnhancedStatistics()
        
        print("|cFFFF6B35GRC:|r Collection Statistics:")
        print(string.format("  Integration Mode: %s", enhancedStats.integrationMode))
        
        -- Mounts
        print(string.format("  Mounts: %d/%d collected (%.1f%%)", 
              stats.collectedMounts, stats.totalMounts, 
              stats.totalMounts > 0 and (stats.collectedMounts/stats.totalMounts)*100 or 0))
        
        -- Pets
        print(string.format("  Pets: %d/%d collected (%.1f%%)", 
              stats.collectedPets, stats.totalPets, 
              stats.totalPets > 0 and (stats.collectedPets/stats.totalPets)*100 or 0))
        
        -- Toys
        print(string.format("  Toys: %d/%d collected (%.1f%%)", 
              stats.collectedToys, stats.totalToys, 
              stats.totalToys > 0 and (stats.collectedToys/stats.totalToys)*100 or 0))
        
        -- Combined
        print(string.format("  Total: %d/%d collected (%.1f%%)", 
              stats.collected, stats.total, 
              stats.total > 0 and (stats.collected/stats.total)*100 or 0))
        
        print(string.format("  Total Attempts: %d (imported from Rarity)", stats.totalAttempts))
        print(string.format("  Characters Tracked: %d", stats.charactersTracked))
        
        local totalTracked = stats.mountsBeingTracked + stats.petsBeingTracked + stats.toysBeingTracked
        print(string.format("  Items Being Tracked: %d", totalTracked))
        print(string.format("  Current Lockouts: %d", stats.currentLockouts))
        
        -- Add session and recent activity stats
        print(string.format("  Session Attempts: %d", stats.sessionAttempts))
        if stats.lastBossKill > 0 then
            local timeSince = time() - stats.lastBossKill
            if timeSince < 3600 then
                print(string.format("  Last Boss Kill: %d minutes ago", math.floor(timeSince / 60)))
            else
                print(string.format("  Last Boss Kill: %d hours ago", math.floor(timeSince / 3600)))
            end
        end
        
        -- Integration-specific stats
        if enhancedStats.integrationMode == "Rarity Import" then
            print("  Data Source: Rarity SavedVariables (imported)")
            if enhancedStats.attemptSyncStatus then
                print(string.format("  Attempt Sync: %s", 
                      enhancedStats.attemptSyncStatus.syncActive and "Active" or "Inactive"))
            end
        else
            print("  Data Source: Standalone mode (no attempt tracking)")
        end
        
    elseif command == "ready" or command == "status" then
        -- NEW: Enhanced ready status debugging
        local readyStatus = GRC.Core.GetReadyStatus()
        
        print("|cFFFF6B35GRC:|r System Ready Status:")
        print(string.format("  Core Ready: %s", readyStatus.isReadyFlag and "✓" or "✗"))
        print(string.format("  SmartCache Exists: %s", readyStatus.smartCacheExists and "✓" or "✗"))
        print(string.format("  SmartCache Ready: %s", readyStatus.smartCacheReady and "✓" or "✗"))
        print(string.format("  SmartCache Building: %s", readyStatus.smartCacheBuilding and "✓" or "✗"))
        print(string.format("  UI Exists: %s", readyStatus.uiExists and "✓" or "✗"))
        print(string.format("  UI Toggle Exists: %s", readyStatus.uiToggleExists and "✓" or "✗"))
        print(string.format("  Settings Loaded: %s", readyStatus.settingsExists and "✓" or "✗"))
        print(string.format("  Character Key: %s", readyStatus.characterKey or "Not Set"))
        print(string.format("  Init Attempts: %d/%d", readyStatus.initAttempts, readyStatus.maxInitAttempts))
        print(string.format("  Time Elapsed: %d seconds", readyStatus.timeElapsed))
        
        -- Show what's blocking readiness
        if not GRC.Core.IsReady() then
            print("|cFFFF6B35Missing Components:|r")
            if not readyStatus.isReadyFlag then
                print("  - Core initialization not complete")
            end
            if not readyStatus.smartCacheExists then
                print("  - SmartCache module not loaded")
            elseif not readyStatus.smartCacheReady then
                print("  - SmartCache not ready (building: " .. tostring(readyStatus.smartCacheBuilding) .. ")")
            end
        else
            print("|cFF00FF00All systems ready!|r")
        end
        
    elseif command == "events" then
        -- NEW: Show event filtering stats
        if GRC.EventHandlers then
            GRC.EventHandlers.ShowDebugInfo()
        else
            print("|cFFFF6B35GRC:|r Event filtering not available")
        end
        
    elseif command == "integration" then
        local cacheStats = GRC.SmartCache and GRC.SmartCache.GetStats() or {}
        
        print("|cFFFF6B35GRC Integration Status:|r")
        print("  Rarity Integration: " .. (cacheStats.rarityIntegration or "Unknown"))
        print("  Data Importer: " .. (cacheStats.importerIntegration or "Unknown"))
        print("  Standalone Mode: " .. tostring(cacheStats.standaloneMode or false))
        print("  Cache Ready: " .. tostring(cacheStats.isReady or false))
        print("  Cache Building: " .. tostring(cacheStats.isBuilding or false))
        print("  First Load Complete: " .. tostring(cacheStats.firstLoadComplete or false))
        
        -- Add attempt sync status
        if cacheStats.attemptSyncActive then
            print("  Attempt Sync: Active")
            if cacheStats.lastAttemptSync and cacheStats.lastAttemptSync > 0 then
                local timeSince = time() - cacheStats.lastAttemptSync
                print(string.format("  Last Sync: %d seconds ago", timeSince))
            end
        else
            print("  Attempt Sync: Inactive")
        end
        
        if cacheStats.integrationStats then
            local stats = cacheStats.integrationStats
            print(string.format("  Mount Journal Mounts: %d", stats.mountJournalMounts or 0))
            print(string.format("  Pet Journal Pets: %d", stats.petJournalPets or 0))
            print(string.format("  Toy Box Toys: %d", stats.toyBoxToys or 0))
            print(string.format("  Rarity Enhanced: %d", stats.rarityEnhanced or 0))
            print(string.format("  Categorized: %d", stats.categorizedItems or 0))
            print(string.format("  With Imported Attempts: %d", stats.attemptsImported or 0))
            print(string.format("  Import Source: %s", stats.importSource or "Unknown"))
        end
        
    elseif command == "compare" then
        -- Debug command to compare our data with Rarity
        local searchTerm = args[2]
        if GRC.RarityDataImporter and GRC.RarityDataImporter.CompareWithRarity then
            GRC.RarityDataImporter.CompareWithRarity(searchTerm)
        else
            print("|cFFFF6B35GRC:|r Comparison not available - RarityDataImporter not loaded")
        end
        
    elseif command == "reimport" then
        -- Force complete reimport from Rarity
        if GRC.RarityDataImporter and GRC.RarityDataImporter.ForceRefresh then
            print("|cFFFF6B35GRC:|r Forcing complete reimport from Rarity...")
            local success = GRC.RarityDataImporter.ForceRefresh()
            if success then
                print("|cFFFF6B35GRC:|r Reimport completed - tracking bar will update")
                C_Timer.After(1, function()
                    if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
                        GRC.TrackingBar.ForceRefresh()
                    end
                end)
            else
                print("|cFFFF6B35GRC:|r Reimport failed - check that Rarity is loaded")
            end
        else
            print("|cFFFF6B35GRC:|r Reimport not available")
        end
        
    elseif command == "search" then
        local searchTerm = args[2]
        if not searchTerm then
            print("|cFFFF6B35GRC:|r Usage: /grc search <term>")
            return
        end
        
        local mountResults = GRC.Core.SearchMounts(searchTerm)
        local petResults = GRC.Core.SearchPets(searchTerm)
        local toyResults = GRC.Core.SearchToys(searchTerm)
        
        local totalResults = #mountResults + #petResults + #toyResults
        
        if totalResults > 0 then
            print(string.format("|cFFFF6B35GRC:|r Found %d result(s):", totalResults))
            
            -- Show mounts
            for i, mount in ipairs(mountResults) do
                if i <= 3 then
                    local statusText = mount.isCollected and "COLLECTED" or 
                                     (mount.attempts > 0 and string.format("%d attempts", mount.attempts) or "Not tracked")
                    print(string.format("  [MOUNT] %s [%s] - %s (%s) - %s", 
                          mount.name, mount.expansion or "Unknown", 
                          mount.category or "Unknown", mount.dropRate or "Unknown", statusText))
                end
            end
            
            -- Show pets  
            for i, pet in ipairs(petResults) do
                if i <= 3 then
                    local statusText = pet.isCollected and "COLLECTED" or 
                                     (pet.attempts > 0 and string.format("%d attempts", pet.attempts) or "Not tracked")
                    print(string.format("  [PET] %s [%s] - %s (%s) - %s", 
                          pet.name, pet.expansion or "Unknown", 
                          pet.category or "Unknown", pet.dropRate or "Unknown", statusText))
                end
            end
            
            -- Show toys
            for i, toy in ipairs(toyResults) do
                if i <= 3 then
                    local statusText = toy.isCollected and "COLLECTED" or 
                                     (toy.attempts > 0 and string.format("%d attempts", toy.attempts) or "Not tracked")
                    print(string.format("  [TOY] %s [%s] - %s (%s) - %s", 
                          toy.name, toy.expansion or "Unknown", 
                          toy.category or "Unknown", toy.dropRate or "Unknown", statusText))
                end
            end
            
            if totalResults > 9 then
                print(string.format("  ... and %d more results", totalResults - 9))
            end
        else
            print("|cFFFF6B35GRC:|r No results found for: " .. searchTerm)
        end
        
    elseif command == "cache" then
        if GRC.SmartCache then
            local stats = GRC.SmartCache.GetStats()
            print("|cFFFF6B35GRC:|r SmartCache Status:")
            print(string.format("  Total Mounts: %d", stats.totalMounts or 0))
            print(string.format("  Total Pets: %d", stats.totalPets or 0))
            print(string.format("  Total Toys: %d", stats.totalToys or 0))
            print(string.format("  Ready: %s", tostring(stats.isReady or false)))
            print(string.format("  Building: %s", tostring(stats.isBuilding or false)))
            print(string.format("  First Load Complete: %s", tostring(stats.firstLoadComplete or false)))
            print(string.format("  Integration Mode: %s", stats.standaloneMode and "Standalone" or "Rarity Import"))
            print(string.format("  Last Update: %s", stats.lastUpdate and os.date("%H:%M:%S", stats.lastUpdate) or "Unknown"))
            print(string.format("  Attempt Sync Active: %s", tostring(stats.attemptSyncActive or false)))
        end
        
    elseif command == "refresh" then
        print("|cFFFF6B35GRC:|r Refreshing cache...")
        GRC.Core.Refresh()
        
    elseif command == "debug" then
        GRCollectorSettings.debugMode = not GRCollectorSettings.debugMode
        print("|cFFFF6B35GRC:|r Debug mode: " .. (GRCollectorSettings.debugMode and "ON" or "OFF"))
        
    elseif command == "help" then
        print("|cFFFF6B35GRC:|r Commands:")
        print("/grc - Toggle UI")
        print("/grc stats - Show collection statistics")
        print("/grc ready - Show system ready status (NEW)")
        print("/grc events - Show event filtering stats")
        print("/grc integration - Show integration status")
        print("/grc compare [mount] - Compare our data with Rarity")
        print("/grc reimport - Force complete reimport from Rarity")
        print("/grc search <term> - Search all collections")
        print("/grc cache - Show cache status")
        print("/grc refresh - Refresh cache")
        print("/grc debug - Toggle debug mode")
        print("/grc help - Show this help")
        
    else
        -- Default: Toggle UI with better error handling
        if GRC.UI and GRC.UI.ToggleUI then
            GRC.UI.ToggleUI()
        elseif GRC.Core.IsReady() then
            print("|cFFFF6B35GRC:|r UI not loaded yet, but core is ready. Try again in a moment.")
        else
            local readyStatus = GRC.Core.GetReadyStatus()
            print("|cFFFF6B35GRC:|r System not ready yet:")
            if not readyStatus.smartCacheExists then
                print("  - SmartCache not loaded")
            elseif readyStatus.smartCacheBuilding then
                print("  - Cache building... Please wait")
            elseif not readyStatus.uiExists then
                print("  - UI not loaded yet")
            else
                print("  - Unknown issue, try /grc ready for details")
            end
            print("Use /grc help for available commands or /grc ready for status details.")
        end
    end
end

return GRC.Core