-- RarityDataImporter.lua - COMPLETE Fixed Data Synchronization + Smart Refresh
local addonName, GRC = ...
GRC.RarityDataImporter = GRC.RarityDataImporter or {}

-- Import statistics
local importStats = {
    totalAttempts = 0,
    mountAttempts = 0,
    petAttempts = 0,
    toyAttempts = 0,
    charactersProcessed = 0,
    lastImportTime = 0,
    available = false,
    importSource = "None"
}

-- FIXED: Add real-time data cache
local liveAttemptData = {
    mounts = {},
    pets = {},
    toys = {},
    lastUpdate = 0
}

-- Cache for processed attempt data
local processedAttempts = {
    mounts = {},
    pets = {},
    toys = {},
    version = 1
}

-- FIXED: Smart refresh control - only refresh on meaningful events
local refreshTriggers = {
    lastRefresh = 0,
    minRefreshInterval = 10, -- Minimum 10 seconds between refreshes
    pendingRefresh = false
}

-- FIXED: Enhanced attempt data retrieval
function GRC.RarityDataImporter.GetLatestAttemptData(item, itemType)
    if not item then return nil end
    
    local itemKey = nil
    if itemType == "mount" then
        itemKey = item.spellID or item.mountID
    elseif itemType == "pet" then
        itemKey = item.speciesID
    elseif itemType == "toy" then
        itemKey = item.toyID or item.itemID
    end
    
    if not itemKey then return nil end
    
    -- Check live data first
    local liveData = liveAttemptData[itemType .. "s"] and liveAttemptData[itemType .. "s"][itemKey]
    if liveData and liveData.attempts > 0 then
        return {
            attempts = liveData.attempts,
            charactersTracked = liveData.charactersTracked or 0,
            lastAttempt = liveData.lastAttempt,
            sessionAttempts = liveData.sessionAttempts or 0
        }
    end
    
    -- Fall back to processed data
    local processedData = processedAttempts[itemType .. "s"] and processedAttempts[itemType .. "s"][itemKey]
    if processedData then
        return {
            attempts = processedData.attempts or 0,
            charactersTracked = processedData.charactersTracked or 0,
            lastAttempt = processedData.lastAttempt,
            sessionAttempts = processedData.sessionAttempts or 0
        }
    end
    
    -- Return item's existing data
    return {
        attempts = item.attempts or 0,
        charactersTracked = item.charactersTracked or 0,
        lastAttempt = item.lastAttempt,
        sessionAttempts = item.sessionAttempts or 0
    }
end

-- FIXED: Smart data refresh - only when needed
function GRC.RarityDataImporter.RefreshAttemptData()
    local currentTime = time()
    
    -- FIXED: Respect minimum refresh interval to prevent spam
    if currentTime - refreshTriggers.lastRefresh < refreshTriggers.minRefreshInterval then
        GRC.Debug.Trace("RarityDataImporter", "Refresh skipped - too soon (last refresh %d seconds ago)", 
                        currentTime - refreshTriggers.lastRefresh)
        return false
    end
    
    if not GRC.RarityDataImporter.IsAvailable() then
        return false
    end
    
    refreshTriggers.lastRefresh = currentTime
    liveAttemptData.lastUpdate = currentTime
    
    GRC.Debug.Info("RarityDataImporter", "Refreshing attempt data from Rarity")
    
    -- Update live data from Rarity
    if _G.Rarity and _G.Rarity.db and _G.Rarity.db.profile then
        local profile = _G.Rarity.db.profile
        local updatedItems = 0
        
        -- FIXED: Process attempts for each character GROUP (not chars)
        for groupName, groupData in pairs(profile.groups or {}) do
            if type(groupData) == "table" and groupName ~= "name" then
                -- Each group represents a character, scan all items in this group
                for itemKey, attemptData in pairs(groupData) do
                    if type(attemptData) == "table" and attemptData.attempts and attemptData.attempts > 0 then
                        -- Find the item in our database
                        local item, itemType = GRC.RarityDataImporter.FindItemByKey(itemKey)
                        if item and itemType then
                            local liveKey = item.spellId or item.speciesId or item.itemId
                            if liveKey then
                                if not liveAttemptData[itemType .. "s"][liveKey] then
                                    liveAttemptData[itemType .. "s"][liveKey] = {
                                        attempts = 0,
                                        charactersTracked = 0,
                                        lastAttempt = nil,
                                        sessionAttempts = 0,
                                        characterBreakdown = {}
                                    }
                                end
                                
                                local liveItem = liveAttemptData[itemType .. "s"][liveKey]
                                
                                -- Update character-specific data
                                local attempts = attemptData.attempts or 0
                                if attempts > 0 then
                                    liveItem.characterBreakdown[groupName] = {
                                        attempts = attempts,
                                        lastAttempt = attemptData.lastAttempt,
                                        dates = attemptData.dates
                                    }
                                    updatedItems = updatedItems + 1
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Aggregate character data
        for itemType, items in pairs(liveAttemptData) do
            if itemType ~= "lastUpdate" then
                for itemKey, itemData in pairs(items) do
                    local totalAttempts = 0
                    local charactersTracked = 0
                    local lastAttempt = nil
                    
                    for charKey, charData in pairs(itemData.characterBreakdown or {}) do
                        totalAttempts = totalAttempts + (charData.attempts or 0)
                        if charData.attempts > 0 then
                            charactersTracked = charactersTracked + 1
                        end
                        if charData.lastAttempt and (not lastAttempt or charData.lastAttempt > lastAttempt) then
                            lastAttempt = charData.lastAttempt
                        end
                    end
                    
                    itemData.attempts = totalAttempts
                    itemData.charactersTracked = charactersTracked
                    itemData.lastAttempt = lastAttempt
                end
            end
        end
        
        GRC.Debug.Trace("RarityDataImporter", "Processed %d item updates from Rarity", updatedItems)
        return updatedItems > 0
    end
    
    return false
end

-- FIXED: Helper function to find item by Rarity key
function GRC.RarityDataImporter.FindItemByKey(rarityKey)
    if not _G.Rarity or not _G.Rarity.ItemDB then
        return nil, nil
    end
    
    -- Check mounts
    if _G.Rarity.ItemDB.mounts then
        for mountKey, mountData in pairs(_G.Rarity.ItemDB.mounts) do
            if mountKey == rarityKey and type(mountData) == "table" and mountData.spellId then
                return mountData, "mount"
            end
        end
    end
    
    -- Check pets
    if _G.Rarity.ItemDB.pets then
        for petKey, petData in pairs(_G.Rarity.ItemDB.pets) do
            if petKey == rarityKey and type(petData) == "table" and petData.spellId then
                return petData, "pet"
            end
        end
    end
    
    -- Check toys
    if _G.Rarity.ItemDB.toys then
        for toyKey, toyData in pairs(_G.Rarity.ItemDB.toys) do
            if toyKey == rarityKey and type(toyData) == "table" and toyData.itemId then
                return toyData, "toy"
            end
        end
    end
    
    return nil, nil
end

-- Check if Rarity addon and data are available
function GRC.RarityDataImporter.IsAvailable()
    if not _G.Rarity then
        importStats.available = false
        importStats.importSource = "Rarity addon not found"
        return false
    end
    
    -- FIXED: More thorough Rarity data structure checking
    if not _G.Rarity.db then
        importStats.available = false
        importStats.importSource = "Rarity database not initialized"
        return false
    end
    
    if not _G.Rarity.db.profile then
        importStats.available = false
        importStats.importSource = "Rarity profile not available"
        return false
    end
    
    -- FIXED: Debug Rarity's data structure
    GRC.Debug.Info("RarityDataImporter", "Rarity structure check:")
    GRC.Debug.Info("RarityDataImporter", "  Rarity.db exists: %s", tostring(_G.Rarity.db ~= nil))
    GRC.Debug.Info("RarityDataImporter", "  Rarity.db.profile exists: %s", tostring(_G.Rarity.db.profile ~= nil))
    
    if _G.Rarity.db.profile then
        -- FIXED: Check for groups structure (primary Rarity storage)
        GRC.Debug.Info("RarityDataImporter", "  Profile.groups exists: %s", tostring(_G.Rarity.db.profile.groups ~= nil))
        if _G.Rarity.db.profile.groups then
            local groupCount = 0
            for groupName, groupData in pairs(_G.Rarity.db.profile.groups) do
                if type(groupData) == "table" and groupName ~= "name" then
                    groupCount = groupCount + 1
                end
            end
            GRC.Debug.Info("RarityDataImporter", "  Character groups found: %d", groupCount)
            
            -- List first few groups for debugging
            local i = 0
            for groupName, groupData in pairs(_G.Rarity.db.profile.groups) do
                if type(groupData) == "table" and groupName ~= "name" then
                    i = i + 1
                    if i <= 3 then
                        local itemCount = GRC.RarityDataImporter.CountTable(groupData)
                        GRC.Debug.Info("RarityDataImporter", "    %s: %d items", groupName, itemCount)
                    end
                end
            end
        end
        
        -- FIXED: Also check for chars structure (alternative storage)
        GRC.Debug.Info("RarityDataImporter", "  Profile.chars exists: %s", tostring(_G.Rarity.db.profile.chars ~= nil))
        if _G.Rarity.db.profile.chars then
            local charCount = 0
            for _ in pairs(_G.Rarity.db.profile.chars) do charCount = charCount + 1 end
            GRC.Debug.Info("RarityDataImporter", "  Characters found: %d", charCount)
        end
    end
    
    importStats.available = true
    importStats.importSource = "Rarity SavedVariables"
    return true
end

-- Get import statistics
function GRC.RarityDataImporter.GetImportStatistics()
    return importStats
end

-- FIXED: Enhanced mount data with synchronized attempts
function GRC.RarityDataImporter.EnhanceMount(mount)
    if not mount or not GRC.RarityDataImporter.IsAvailable() then
        return mount
    end
    
    -- Get latest attempt data
    local latestData = GRC.RarityDataImporter.GetLatestAttemptData(mount, "mount")
    
    if latestData and latestData.attempts > 0 then
        mount.attempts = latestData.attempts
        mount.charactersTracked = latestData.charactersTracked
        mount.lastAttempt = latestData.lastAttempt
        mount.sessionAttempts = latestData.sessionAttempts
        
        -- Update source to indicate enhanced data
        if mount.source and not mount.source:find("Enhanced") then
            mount.source = mount.source:gsub(" %[Rarity Imported%]", "") .. " [Enhanced with Live Data]"
        end
    end
    
    return mount
end

-- FIXED: Enhanced pet data with synchronized attempts
function GRC.RarityDataImporter.EnhancePet(pet)
    if not pet or not GRC.RarityDataImporter.IsAvailable() then
        return pet
    end
    
    -- Get latest attempt data
    local latestData = GRC.RarityDataImporter.GetLatestAttemptData(pet, "pet")
    
    if latestData and latestData.attempts > 0 then
        pet.attempts = latestData.attempts
        pet.charactersTracked = latestData.charactersTracked
        pet.lastAttempt = latestData.lastAttempt
        pet.sessionAttempts = latestData.sessionAttempts
        
        -- Update source to indicate enhanced data
        if pet.source and not pet.source:find("Enhanced") then
            pet.source = pet.source:gsub(" %[Rarity Imported%]", "") .. " [Enhanced with Live Data]"
        end
    end
    
    return pet
end

-- FIXED: Enhanced toy data with synchronized attempts
function GRC.RarityDataImporter.EnhanceToy(toy)
    if not toy or not GRC.RarityDataImporter.IsAvailable() then
        return toy
    end
    
    -- Get latest attempt data
    local latestData = GRC.RarityDataImporter.GetLatestAttemptData(toy, "toy")
    
    if latestData and latestData.attempts > 0 then
        toy.attempts = latestData.attempts
        toy.charactersTracked = latestData.charactersTracked
        toy.lastAttempt = latestData.lastAttempt
        toy.sessionAttempts = latestData.sessionAttempts
        
        -- Update source to indicate enhanced data
        if toy.source and not toy.source:find("Enhanced") then
            toy.source = toy.source:gsub(" %[Rarity Imported%]", "") .. " [Enhanced with Live Data]"
        end
    end
    
    return toy
end

-- FIXED: Enhanced import with better Rarity data structure handling
function GRC.RarityDataImporter.ImportAllAttempts()
    if not GRC.RarityDataImporter.IsAvailable() then
        GRC.Debug.Info("RarityDataImporter", "Rarity not available for import")
        return false
    end
    
    GRC.Debug.Info("RarityDataImporter", "Starting COMPLETE import of attempt data from Rarity...")
    
    -- Reset statistics
    importStats.totalAttempts = 0
    importStats.mountAttempts = 0
    importStats.petAttempts = 0
    importStats.toyAttempts = 0
    importStats.charactersProcessed = 0
    
    -- Clear ALL cached data to start fresh
    processedAttempts.mounts = {}
    processedAttempts.pets = {}
    processedAttempts.toys = {}
    liveAttemptData.mounts = {}
    liveAttemptData.pets = {}
    liveAttemptData.toys = {}
    
    local profile = _G.Rarity.db.profile
    if not profile then
        GRC.Debug.Warn("RarityDataImporter", "No Rarity profile found")
        return false
    end
    
    -- FIXED: Check both possible Rarity data structures
    local charactersData = nil
    local dataSource = "unknown"
    
    -- Method 1: Check profile.groups (primary Rarity storage)
    if profile.groups and type(profile.groups) == "table" then
        charactersData = profile.groups
        dataSource = "profile.groups"
        GRC.Debug.Info("RarityDataImporter", "Using Rarity data from profile.groups")
    
    -- Method 2: Check profile.chars (alternative Rarity versions)
    elseif profile.chars and type(profile.chars) == "table" then
        charactersData = profile.chars
        dataSource = "profile.chars"
        GRC.Debug.Info("RarityDataImporter", "Using Rarity data from profile.chars")
    
    -- Method 3: Direct profile structure
    else
        GRC.Debug.Warn("RarityDataImporter", "Searching for character data in profile structure...")
        
        -- Look for any character-like structures
        for key, value in pairs(profile) do
            if type(value) == "table" and next(value) then
                if not charactersData then charactersData = {} end
                charactersData[key] = value
                dataSource = "profile." .. key
                GRC.Debug.Info("RarityDataImporter", "Found character data in profile.%s", key)
            end
        end
    end
    
    if not charactersData then
        GRC.Debug.Error("RarityDataImporter", "No character data found in any Rarity structure")
        GRC.Debug.Error("RarityDataImporter", "Available profile keys: %s", 
                        table.concat(GRC.RarityDataImporter.GetTableKeys(profile), ", "))
        return false
    end
    
    GRC.Debug.Info("RarityDataImporter", "Processing %d characters from Rarity (%s)", 
                   GRC.RarityDataImporter.CountTable(charactersData), dataSource)
    
    -- FIXED: Process each character's attempt data (groups = characters)
    for characterKey, characterData in pairs(charactersData) do
        if type(characterData) == "table" and characterKey ~= "name" then
            importStats.charactersProcessed = importStats.charactersProcessed + 1
            GRC.Debug.Trace("RarityDataImporter", "Processing character: %s (%d items)", 
                           characterKey, GRC.RarityDataImporter.CountTable(characterData))
            
            -- FIXED: In groups structure, each item key maps directly to attempt data
            for itemKey, attemptData in pairs(characterData) do
                if type(attemptData) == "table" and attemptData.attempts and attemptData.attempts > 0 then
                    -- Find corresponding item in Rarity ItemDB
                    local item, itemType = GRC.RarityDataImporter.FindItemByKey(itemKey)
                    
                    if item and itemType then
                        local ourKey = nil
                        if itemType == "mount" then
                            ourKey = item.spellId
                        elseif itemType == "pet" then
                            ourKey = item.spellId  -- Rarity uses spellId for pets too
                        elseif itemType == "toy" then
                            ourKey = item.itemId
                        end
                        
                        if ourKey then
                            -- Initialize processed data if needed
                            if not processedAttempts[itemType .. "s"][ourKey] then
                                processedAttempts[itemType .. "s"][ourKey] = {
                                    attempts = 0,
                                    charactersTracked = 0,
                                    lastAttempt = nil,
                                    sessionAttempts = 0,
                                    characterBreakdown = {}
                                }
                            end
                            
                            local processedItem = processedAttempts[itemType .. "s"][ourKey]
                            
                            -- FIXED: Properly accumulate character attempts
                            if not processedItem.characterBreakdown[characterKey] then
                                processedItem.characterBreakdown[characterKey] = {
                                    attempts = 0,
                                    lastAttempt = nil,
                                    dates = {}
                                }
                                processedItem.charactersTracked = processedItem.charactersTracked + 1
                            end
                            
                            -- Update character-specific data
                            processedItem.characterBreakdown[characterKey].attempts = attemptData.attempts
                            processedItem.characterBreakdown[characterKey].lastAttempt = attemptData.lastAttempt
                            processedItem.characterBreakdown[characterKey].dates = attemptData.dates or {}
                            
                            -- Recalculate totals from all characters
                            local totalAttempts = 0
                            local latestAttempt = nil
                            
                            for charKey, charData in pairs(processedItem.characterBreakdown) do
                                totalAttempts = totalAttempts + (charData.attempts or 0)
                                if charData.lastAttempt and (not latestAttempt or charData.lastAttempt > latestAttempt) then
                                    latestAttempt = charData.lastAttempt
                                end
                            end
                            
                            processedItem.attempts = totalAttempts
                            processedItem.lastAttempt = latestAttempt
                            
                            -- Update import statistics
                            importStats.totalAttempts = importStats.totalAttempts + attemptData.attempts
                            if itemType == "mount" then
                                importStats.mountAttempts = importStats.mountAttempts + attemptData.attempts
                            elseif itemType == "pet" then
                                importStats.petAttempts = importStats.petAttempts + attemptData.attempts
                            elseif itemType == "toy" then
                                importStats.toyAttempts = importStats.toyAttempts + attemptData.attempts
                            end
                            
                            GRC.Debug.Trace("RarityDataImporter", "Imported %s %s: %d attempts from %s (total: %d)", 
                                           itemType, item.name or "Unknown", attemptData.attempts, characterKey, totalAttempts)
                        end
                    else
                        GRC.Debug.Trace("RarityDataImporter", "Could not find item for key: %s", itemKey)
                    end
                end
            end
        else
            GRC.Debug.Trace("RarityDataImporter", "Skipping %s - no valid data", characterKey)
        end
    end
    
    importStats.lastImportTime = time()
    
    GRC.Debug.Info("RarityDataImporter", "Import complete: %d total attempts from %d characters (%s)", 
                   importStats.totalAttempts, importStats.charactersProcessed, dataSource)
    GRC.Debug.Info("RarityDataImporter", "Breakdown: %d mount attempts, %d pet attempts, %d toy attempts", 
                   importStats.mountAttempts, importStats.petAttempts, importStats.toyAttempts)
    
    -- FIXED: Copy processed data to live data with proper aggregation
    for itemType, items in pairs(processedAttempts) do
        if itemType ~= "version" then
            liveAttemptData[itemType] = {}
            for itemKey, itemData in pairs(items) do
                liveAttemptData[itemType][itemKey] = {
                    attempts = itemData.attempts,
                    charactersTracked = itemData.charactersTracked,
                    lastAttempt = itemData.lastAttempt,
                    sessionAttempts = 0, -- Reset session attempts on import
                    characterBreakdown = itemData.characterBreakdown
                }
                
                GRC.Debug.Trace("RarityDataImporter", "Live data updated: %s %s = %d attempts", 
                               itemType, tostring(itemKey), itemData.attempts)
            end
        end
    end
    
    liveAttemptData.lastUpdate = time()
    
    GRC.Debug.Info("RarityDataImporter", "Live data synchronized with %d mount items, %d pet items, %d toy items",
                   GRC.RarityDataImporter.CountTable(liveAttemptData.mounts),
                   GRC.RarityDataImporter.CountTable(liveAttemptData.pets),
                   GRC.RarityDataImporter.CountTable(liveAttemptData.toys))
    
    return true
end

-- FIXED: Real-time attempt tracking integration - ONLY for meaningful events
function GRC.RarityDataImporter.OnAttemptAdded(itemType, itemID, newAttempts, characterKey)
    if not itemID then return end
    
    characterKey = characterKey or (UnitName("player") .. "-" .. GetRealmName())
    
    GRC.Debug.Trace("RarityDataImporter", "Attempt added: %s %s (%d attempts) for %s", 
                    itemType, tostring(itemID), newAttempts, characterKey)
    
    -- Initialize live data if needed
    if not liveAttemptData[itemType .. "s"] then
        liveAttemptData[itemType .. "s"] = {}
    end
    
    if not liveAttemptData[itemType .. "s"][itemID] then
        liveAttemptData[itemType .. "s"][itemID] = {
            attempts = 0,
            charactersTracked = 0,
            lastAttempt = nil,
            sessionAttempts = 0,
            characterBreakdown = {}
        }
    end
    
    local liveItem = liveAttemptData[itemType .. "s"][itemID]
    
    -- Update character-specific data
    if not liveItem.characterBreakdown[characterKey] then
        liveItem.characterBreakdown[characterKey] = {
            attempts = 0,
            lastAttempt = nil,
            dates = {}
        }
        liveItem.charactersTracked = liveItem.charactersTracked + 1
    end
    
    local oldAttempts = liveItem.characterBreakdown[characterKey].attempts
    liveItem.characterBreakdown[characterKey].attempts = newAttempts
    liveItem.characterBreakdown[characterKey].lastAttempt = time()
    
    -- Update totals
    local attemptDifference = newAttempts - oldAttempts
    liveItem.attempts = liveItem.attempts + attemptDifference
    liveItem.lastAttempt = time()
    liveItem.sessionAttempts = (liveItem.sessionAttempts or 0) + attemptDifference
    
    liveAttemptData.lastUpdate = time()
    
    -- FIXED: Only notify tracking bar for significant events, not mouseovers
    if GRC.TrackingBar and GRC.TrackingBar.NotifyAttemptAdded then
        C_Timer.After(0.2, function()
            GRC.TrackingBar.NotifyAttemptAdded(itemType, itemID, newAttempts)
        end)
    end
end

-- FIXED: Boss kill integration - only refresh on actual boss kills
function GRC.RarityDataImporter.OnBossKill(npcID, encounterID, zoneName)
    GRC.Debug.Info("RarityDataImporter", "Boss kill detected: NPC %s, Encounter %s in %s", 
                   tostring(npcID), tostring(encounterID), tostring(zoneName))
    
    -- FIXED: Set pending refresh flag and delay to allow Rarity to process first
    refreshTriggers.pendingRefresh = true
    
    C_Timer.After(3, function()
        if refreshTriggers.pendingRefresh then
            refreshTriggers.pendingRefresh = false
            
            -- Only refresh if enough time has passed
            local success = GRC.RarityDataImporter.RefreshAttemptData()
            if success then
                GRC.Debug.Info("RarityDataImporter", "Boss kill refresh completed")
                
                -- Notify tracking bar
                if GRC.TrackingBar and GRC.TrackingBar.NotifyBossKill then
                    GRC.TrackingBar.NotifyBossKill(npcID, encounterID)
                end
                
                -- Notify UI
                if GRC.UI and GRC.UI.RefreshUI then
                    GRC.UI.RefreshUI()
                end
            end
        end
    end)
end

-- FIXED: Collection update integration - only for actual collections
function GRC.RarityDataImporter.OnCollectionUpdate(itemType, itemID, isCollected)
    GRC.Debug.Info("RarityDataImporter", "Collection update: %s %s = %s", 
                   itemType, tostring(itemID), tostring(isCollected))
    
    -- Only process actual new collections, not status checks
    if isCollected then
        -- Refresh data for new collections
        C_Timer.After(1, function()
            GRC.RarityDataImporter.RefreshAttemptData()
            
            -- Notify tracking bar
            if GRC.TrackingBar and GRC.TrackingBar.NotifyCollectionUpdate then
                GRC.TrackingBar.NotifyCollectionUpdate()
            end
        end)
    end
end

-- Get detailed attempt breakdown for an item
function GRC.RarityDataImporter.GetAttemptBreakdown(item, itemType)
    if not item then return {} end
    
    local itemKey = nil
    if itemType == "mount" then
        itemKey = item.spellID or item.mountID
    elseif itemType == "pet" then
        itemKey = item.speciesID
    elseif itemType == "toy" then
        itemKey = item.toyID or item.itemID
    end
    
    if not itemKey then return {} end
    
    -- Check live data first
    local liveData = liveAttemptData[itemType .. "s"] and liveAttemptData[itemType .. "s"][itemKey]
    if liveData and liveData.characterBreakdown then
        return liveData.characterBreakdown
    end
    
    -- Fall back to processed data
    local processedData = processedAttempts[itemType .. "s"] and processedAttempts[itemType .. "s"][itemKey]
    if processedData and processedData.characterBreakdown then
        return processedData.characterBreakdown
    end
    
    return {}
end

-- Get session statistics
function GRC.RarityDataImporter.GetSessionStatistics()
    local sessionStats = {
        totalSessionAttempts = 0,
        mountSessionAttempts = 0,
        petSessionAttempts = 0,
        toySessionAttempts = 0,
        itemsTrackedThisSession = 0
    }
    
    for itemType, items in pairs(liveAttemptData) do
        if itemType ~= "lastUpdate" then
            for itemKey, itemData in pairs(items) do
                local sessionAttempts = itemData.sessionAttempts or 0
                if sessionAttempts > 0 then
                    sessionStats.totalSessionAttempts = sessionStats.totalSessionAttempts + sessionAttempts
                    sessionStats.itemsTrackedThisSession = sessionStats.itemsTrackedThisSession + 1
                    
                    if itemType == "mounts" then
                        sessionStats.mountSessionAttempts = sessionStats.mountSessionAttempts + sessionAttempts
                    elseif itemType == "pets" then
                        sessionStats.petSessionAttempts = sessionStats.petSessionAttempts + sessionAttempts
                    elseif itemType == "toys" then
                        sessionStats.toySessionAttempts = sessionStats.toySessionAttempts + sessionAttempts
                    end
                end
            end
        end
    end
    
    return sessionStats
end

-- Clear session data
function GRC.RarityDataImporter.ClearSessionData()
    for itemType, items in pairs(liveAttemptData) do
        if itemType ~= "lastUpdate" then
            for itemKey, itemData in pairs(items) do
                itemData.sessionAttempts = 0
            end
        end
    end
    
    GRC.Debug.Info("RarityDataImporter", "Session data cleared")
end

-- FIXED: Controlled refresh system - no automatic timers, only event-driven
function GRC.RarityDataImporter.StartAutoRefresh()
    -- REMOVED: No more automatic refresh timers
    -- Data will only refresh on meaningful events (boss kills, login, manual refresh)
    GRC.Debug.Info("RarityDataImporter", "Event-driven refresh system active (no auto-timers)")
end

function GRC.RarityDataImporter.StopAutoRefresh()
    -- REMOVED: No timers to stop
    refreshTriggers.pendingRefresh = false
    GRC.Debug.Info("RarityDataImporter", "Auto-refresh stopped")
end

-- FIXED: Event handling for meaningful Rarity integration only
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")

-- FIXED: Much more restrictive event registration - only actual collectible events
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("BOSS_KILL")

-- FIXED: Only events that can actually result in collectible drops
frame:RegisterEvent("NEW_MOUNT_ADDED")
frame:RegisterEvent("NEW_PET_ADDED")  
frame:RegisterEvent("NEW_TOY_ADDED")

-- REMOVED: All other events that were causing flying/movement refreshes
-- REMOVED: LOOT_CLOSED (was triggering on every herb/ore/etc.)
-- REMOVED: SKILL_LINES_CHANGED (was triggering constantly)
-- REMOVED: Any movement or zone-based events

-- REMOVED: Mouseover events, constant polling, spell cast events

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonNameLoaded = ...
        if addonNameLoaded == "Rarity" then
            GRC.Debug.Info("RarityDataImporter", "Rarity addon loaded, starting integration")
            C_Timer.After(3, function()
                if GRC.RarityDataImporter.IsAvailable() then
                    GRC.RarityDataImporter.ImportAllAttempts()
                    GRC.RarityDataImporter.StartAutoRefresh()
                end
            end)
        end
        
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(10, function()
            if GRC.RarityDataImporter.IsAvailable() then
                GRC.RarityDataImporter.ImportAllAttempts()
                GRC.RarityDataImporter.StartAutoRefresh()
                GRC.Debug.Info("RarityDataImporter", "Login import completed")
            end
        end)
        
    elseif event == "PLAYER_LOGOUT" then
        GRC.RarityDataImporter.StopAutoRefresh()
        
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("encounter_end", {
            encounterID = encounterID,
            encounterName = encounterName,
            success = success == 1
        }) then
            GRC.RarityDataImporter.OnBossKill(nil, encounterID, GetZoneText())
        end
        
    elseif event == "BOSS_KILL" then
        local id, name = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("boss_kill", {
            npcID = id,
            npcName = name
        }) then
            GRC.RarityDataImporter.OnBossKill(id, nil, GetZoneText())
        end
        
    elseif event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        GRC.RarityDataImporter.OnCollectionUpdate("mount", mountID, true)
        
    elseif event == "NEW_PET_ADDED" then
        local petID = ...
        GRC.RarityDataImporter.OnCollectionUpdate("pet", petID, true)
        
    elseif event == "NEW_TOY_ADDED" then
        local toyID = ...
        GRC.RarityDataImporter.OnCollectionUpdate("toy", toyID, true)
    end
end)

-- FIXED: Public API for external integration
function GRC.RarityDataImporter.GetLiveData()
    return liveAttemptData
end

function GRC.RarityDataImporter.GetProcessedData()
    return processedAttempts
end

function GRC.RarityDataImporter.ForceRefresh()
    -- Reset the minimum interval for manual refresh
    refreshTriggers.lastRefresh = 0
    
    if GRC.RarityDataImporter.IsAvailable() then
        GRC.RarityDataImporter.ImportAllAttempts()
        local success = GRC.RarityDataImporter.RefreshAttemptData()
        
        if success then
            GRC.Debug.Info("RarityDataImporter", "Manual refresh completed successfully")
        end
        
        return success
    end
    return false
end

-- Integration check
function GRC.RarityDataImporter.GetIntegrationStatus()
    return {
        available = GRC.RarityDataImporter.IsAvailable(),
        importStats = importStats,
        liveDataItems = (function()
            local count = 0
            for itemType, items in pairs(liveAttemptData) do
                if itemType ~= "lastUpdate" then
                    for _ in pairs(items) do
                        count = count + 1
                    end
                end
            end
            return count
        end)(),
        lastUpdate = liveAttemptData.lastUpdate,
        lastRefresh = refreshTriggers.lastRefresh,
        pendingRefresh = refreshTriggers.pendingRefresh,
        refreshInterval = refreshTriggers.minRefreshInterval
    }
end

-- Get refresh status
function GRC.RarityDataImporter.GetRefreshStatus()
    return {
        lastRefresh = refreshTriggers.lastRefresh,
        timeSinceLastRefresh = time() - refreshTriggers.lastRefresh,
        minRefreshInterval = refreshTriggers.minRefreshInterval,
        pendingRefresh = refreshTriggers.pendingRefresh,
        canRefreshNow = (time() - refreshTriggers.lastRefresh) >= refreshTriggers.minRefreshInterval
    }
end

-- FIXED: Add utility function for getting table keys
function GRC.RarityDataImporter.GetTableKeys(t)
    if not t or type(t) ~= "table" then return {} end
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, tostring(k))
    end
    return keys
end

-- FIXED: Add utility function for counting tables
function GRC.RarityDataImporter.CountTable(t)
    if not t or type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- FIXED: Debug function to compare with Rarity data
function GRC.RarityDataImporter.CompareWithRarity(itemName)
    if not GRC.RarityDataImporter.IsAvailable() then
        print("|cFFFF6B35GRC:|r Rarity not available for comparison")
        return
    end
    
    print("|cFFFF6B35GRC:|r Comparing attempt data for: " .. (itemName or "all items"))
    
    -- Find the item in Rarity's ItemDB
    local rarityItems = {}
    if _G.Rarity.ItemDB.mounts then
        for key, data in pairs(_G.Rarity.ItemDB.mounts) do
            if type(data) == "table" and data.name then
                if not itemName or data.name:lower():find(itemName:lower()) then
                    rarityItems[data.name] = {type = "mount", spellId = data.spellId, key = key, data = data}
                end
            end
        end
    end
    
    -- Compare with our data
    for name, rarityItem in pairs(rarityItems) do
        local ourData = liveAttemptData.mounts[rarityItem.spellId]
        
        -- Get attempts from Rarity's character data
        local rarityAttempts = 0
        if _G.Rarity.db.profile.groups then
            for groupName, groupData in pairs(_G.Rarity.db.profile.groups) do
                if type(groupData) == "table" and groupName ~= "name" then
                    if groupData[rarityItem.key] and groupData[rarityItem.key].attempts then
                        rarityAttempts = rarityAttempts + (groupData[rarityItem.key].attempts or 0)
                    end
                end
            end
        end
        
        local ourAttempts = ourData and ourData.attempts or 0
        
        print(string.format("  %s: Rarity=%d, Ours=%d %s", 
              name, rarityAttempts, ourAttempts, 
              (rarityAttempts == ourAttempts) and "✓" or "❌ MISMATCH"))
        
        if rarityAttempts ~= ourAttempts then
            print(string.format("    Rarity key: %s, SpellID: %s", rarityItem.key, tostring(rarityItem.spellId)))
            if ourData then
                print(string.format("    Our data - characters: %d, lastAttempt: %s", 
                      ourData.charactersTracked or 0, 
                      ourData.lastAttempt and date("%Y-%m-%d %H:%M:%S", ourData.lastAttempt) or "never"))
            else
                print("    Our data: MISSING")
            end
        end
    end
end

GRC.Debug.Info("RarityDataImporter", "COMPLETE data synchronization system with SMART refresh control loaded")

return GRC.RarityDataImporter