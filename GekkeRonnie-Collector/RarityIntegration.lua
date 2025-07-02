-- RarityIntegration.lua - Optimized with Fast Lookups
local addonName, GRC = ...
GRC.RarityIntegration = GRC.RarityIntegration or {}

-- Integration state
local isRarityAvailable = false
local rarityVersion = nil
local integrationReady = false

-- PERFORMANCE: Pre-built lookup tables for instant access
local lookupTables = {
    mountsBySpellID = {},
    mountsByItemID = {},
    mountsByName = {},
    petsBySpeciesID = {},
    petsByName = {},
    toysByItemID = {},
    toysByName = {},
    lastBuilt = 0,
    isBuilt = false
}

local LOOKUP_CACHE_DURATION = 300 -- 5 minutes

-- Build fast lookup tables (called once, cached)
local function BuildLookupTables()
    local currentTime = time()
    if lookupTables.isBuilt and (currentTime - lookupTables.lastBuilt) < LOOKUP_CACHE_DURATION then
        return -- Use existing cache
    end
    
    GRC.Debug.Info("Rarity", "Building fast lookup tables...")
    
    -- Clear existing tables
    lookupTables.mountsBySpellID = {}
    lookupTables.mountsByItemID = {}
    lookupTables.mountsByName = {}
    lookupTables.petsBySpeciesID = {}
    lookupTables.petsByName = {}
    lookupTables.toysByItemID = {}
    lookupTables.toysByName = {}
    
    -- Build mount lookups
    if _G.Rarity and _G.Rarity.ItemDB and _G.Rarity.ItemDB.mounts then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.mounts) do
            if type(itemData) == "table" and itemKey ~= "name" and itemData.name then
                itemData._rarityKey = itemKey
                
                -- Index by spellID (primary)
                if itemData.spellId then
                    lookupTables.mountsBySpellID[itemData.spellId] = itemData
                end
                
                -- Index by itemID (secondary)
                if itemData.itemId then
                    lookupTables.mountsByItemID[itemData.itemId] = itemData
                end
                
                -- Index by name (exact match only for performance)
                if itemData.name then
                    lookupTables.mountsByName[itemData.name:lower()] = itemData
                end
            end
        end
    end
    
    -- Build pet lookups
    if _G.Rarity and _G.Rarity.ItemDB and _G.Rarity.ItemDB.pets then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.pets) do
            if type(itemData) == "table" and itemKey ~= "name" and itemData.name then
                itemData._rarityKey = itemKey
                
                -- Index by speciesID/creatureID
                if itemData.spellId then
                    lookupTables.petsBySpeciesID[itemData.spellId] = itemData
                end
                if itemData.creatureId then
                    lookupTables.petsBySpeciesID[itemData.creatureId] = itemData
                end
                
                -- Index by name (exact match)
                if itemData.name then
                    lookupTables.petsByName[itemData.name:lower()] = itemData
                end
            end
        end
    end
    
    -- Build toy lookups
    if _G.Rarity and _G.Rarity.ItemDB and _G.Rarity.ItemDB.toys then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.toys) do
            if type(itemData) == "table" and itemKey ~= "name" and itemData.name then
                itemData._rarityKey = itemKey
                
                -- Index by itemID
                if itemData.itemId then
                    lookupTables.toysByItemID[itemData.itemId] = itemData
                end
                
                -- Index by name (exact match)
                if itemData.name then
                    lookupTables.toysByName[itemData.name:lower()] = itemData
                end
            end
        end
    end
    
    lookupTables.lastBuilt = currentTime
    lookupTables.isBuilt = true
    
    GRC.Debug.Info("Rarity", "Lookup tables built: %d mounts, %d pets, %d toys",
                   GRC.RarityIntegration.CountTable(lookupTables.mountsBySpellID),
                   GRC.RarityIntegration.CountTable(lookupTables.petsBySpeciesID),
                   GRC.RarityIntegration.CountTable(lookupTables.toysByItemID))
end

-- Check if Rarity addon is loaded and accessible (enhanced detection)
local function CheckRarityAvailability()
    -- Step 1: Check if Rarity addon is loaded
    local isLoaded = C_AddOns.IsAddOnLoaded("Rarity")
    
    if not isLoaded then
        GRC.Debug.Trace("Rarity", "Rarity addon not found - running in standalone mode")
        return false
    end
    
    -- Give Rarity time to fully initialize
    if not _G.Rarity then
        GRC.Debug.Trace("Rarity", "Rarity global not found - running in standalone mode")
        return false
    end
    
    -- Check if Rarity has initialized its database
    if not _G.Rarity.ItemDB then
        GRC.Debug.Trace("Rarity", "Rarity ItemDB not ready - running in standalone mode")
        return false
    end
    
    -- Check databases
    local hasValidData = false
    local totalItems = 0
    
    -- Check mounts
    if _G.Rarity.ItemDB.mounts and type(_G.Rarity.ItemDB.mounts) == "table" then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.mounts) do
            if type(itemData) == "table" and itemKey ~= "name" then
                totalItems = totalItems + 1
                hasValidData = true
                if totalItems >= 5 then break end
            end
        end
    end
    
    -- Check pets
    if _G.Rarity.ItemDB.pets and type(_G.Rarity.ItemDB.pets) == "table" then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.pets) do
            if type(itemData) == "table" and itemKey ~= "name" then
                totalItems = totalItems + 1
                hasValidData = true
                if totalItems >= 5 then break end
            end
        end
    end
    
    -- Check toys
    if _G.Rarity.ItemDB.toys and type(_G.Rarity.ItemDB.toys) == "table" then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.toys) do
            if type(itemData) == "table" and itemKey ~= "name" then
                totalItems = totalItems + 1
                hasValidData = true
                if totalItems >= 5 then break end
            end
        end
    end
    
    if not hasValidData then
        GRC.Debug.Trace("Rarity", "Rarity database appears empty - running in standalone mode")
        return false
    end
    
    -- Get Rarity version if available
    if _G.Rarity.version then
        rarityVersion = _G.Rarity.version
    end
    
    GRC.Debug.Info("Rarity", "Rarity addon detected with %d+ items%s", totalItems, (rarityVersion and (" v" .. rarityVersion) or ""))
    return true
end

-- Initialize integration when Rarity is available
local function InitializeRarityIntegration()
    isRarityAvailable = CheckRarityAvailability()
    
    if isRarityAvailable then
        GRC.Debug.Info("Rarity", "Initializing Rarity integration...")
        
        -- Build lookup tables
        BuildLookupTables()
        
        -- Count available data
        local stats = GRC.RarityIntegration.GetDatabaseStatistics()
        GRC.Debug.Info("Rarity", "Rarity database available: %d mounts, %d pets, %d toys", 
              stats.totalMounts, stats.totalPets, stats.totalToys)
        
        GRC.Debug.Info("Rarity", "✓ Rarity integration ready")
        
        integrationReady = true
        
        -- Hook into Rarity events for real-time updates
        GRC.RarityIntegration.HookRarityEvents()
        
        -- AUTOMATICALLY refresh the cache when Rarity becomes available
        if GRC.SmartCache then
            GRC.Debug.Info("Rarity", "Auto-refreshing cache with Rarity data...")
            C_Timer.After(1, function()
                GRC.SmartCache.Refresh()
            end)
        end
    else
        GRC.Debug.Info("Rarity", "Running in standalone mode (basic journal data only)")
    end
    
    return isRarityAvailable
end

-- Hook into Rarity events for real-time updates
function GRC.RarityIntegration.HookRarityEvents()
    if not isRarityAvailable or not _G.Rarity then 
        return 
    end
    
    GRC.Debug.Info("Rarity", "Setting up Rarity event hooks...")
    
    -- Hook into Rarity's OnItemFound if it exists
    if _G.Rarity.OnItemFound then
        local originalOnItemFound = _G.Rarity.OnItemFound
        _G.Rarity.OnItemFound = function(self, itemId, item)
            -- Call original function
            local result = originalOnItemFound(self, itemId, item)
            
            -- Our additional processing - refresh cache when items are found
            if GRC.SmartCache and GRC.SmartCache.Refresh then
                print("|cFFFF6B35GRC:|r Item obtained! Refreshing data...")
                C_Timer.After(1, function()
                    GRC.SmartCache.Refresh()
                end)
            end
            
            if GRC.UI and GRC.UI.RefreshUI then
                GRC.UI.RefreshUI()
            end
            
            return result
        end
        
        GRC.Debug.Info("Rarity", "Hooked Rarity.OnItemFound")
    end
    
    -- Hook into attempt counting
    if _G.Rarity.OutputAttempts then
        local originalOutputAttempts = _G.Rarity.OutputAttempts
        _G.Rarity.OutputAttempts = function(self, item, isForcedUpdate)
            -- Call original function
            local result = originalOutputAttempts(self, item, isForcedUpdate)
            
            -- Our additional processing - refresh UI when attempts update
            if GRC.UI and GRC.UI.RefreshUI then
                GRC.UI.RefreshUI()
            end
            
            return result
        end
        
        GRC.Debug.Info("Rarity", "Hooked Rarity.OutputAttempts")
    end
    
    GRC.Debug.Info("Rarity", "Rarity event hooks established")
end

-- Public API: Check if Rarity integration is available
function GRC.RarityIntegration.IsAvailable()
    return isRarityAvailable and integrationReady
end

function GRC.RarityIntegration.GetVersion()
    return rarityVersion
end

-- Get database statistics
function GRC.RarityIntegration.GetDatabaseStatistics()
    if not isRarityAvailable then
        return {
            totalMounts = 0,
            totalPets = 0,
            totalToys = 0,
            totalItems = 0
        }
    end
    
    local stats = {
        totalMounts = 0,
        totalPets = 0,
        totalToys = 0,
        totalItems = 0
    }
    
    -- Count mounts
    if _G.Rarity.ItemDB.mounts then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.mounts) do
            if type(itemData) == "table" and itemKey ~= "name" then
                stats.totalMounts = stats.totalMounts + 1
            end
        end
    end
    
    -- Count pets
    if _G.Rarity.ItemDB.pets then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.pets) do
            if type(itemData) == "table" and itemKey ~= "name" then
                stats.totalPets = stats.totalPets + 1
            end
        end
    end
    
    -- Count toys
    if _G.Rarity.ItemDB.toys then
        for itemKey, itemData in pairs(_G.Rarity.ItemDB.toys) do
            if type(itemData) == "table" and itemKey ~= "name" then
                stats.totalToys = stats.totalToys + 1
            end
        end
    end
    
    stats.totalItems = stats.totalMounts + stats.totalPets + stats.totalToys
    
    return stats
end

-- Enhanced categorization using Rarity data for MOUNTS
function GRC.RarityIntegration.GetEnhancedMountData(mountName, spellID, itemID, sourceText)
    if not isRarityAvailable then
        return {
            isRarityTracked = false,
            expansion = "Unknown",
            category = "Unknown", 
            dropRate = "Unknown",
            rarityData = nil
        }
    end
    
    -- Try to find mount in Rarity database using fast lookup
    local rarityData = GRC.RarityIntegration.FindMountInRarity(mountName, spellID, itemID)
    
    if rarityData then
        return {
            isRarityTracked = true,
            expansion = GRC.RarityIntegration.GetExpansionFromRarityData(rarityData),
            category = GRC.RarityIntegration.GetCategoryFromRarityData(rarityData),
            dropRate = GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(rarityData),
            rarityData = rarityData,
            sourceInstance = GRC.RarityIntegration.GetInstanceFromRarityData(rarityData),
            bossName = rarityData.lockBossName,
            npcIDs = rarityData.npcs,
            encounterIDs = rarityData.statisticId,
            isBlackMarket = rarityData.blackMarket or rarityData.bmah,
            isRemoved = rarityData.removed
        }
    end
    
    -- Fallback to basic categorization
    return {
        isRarityTracked = false,
        expansion = GRC.RarityIntegration.GetBasicExpansion(spellID),
        category = GRC.RarityIntegration.GetBasicCategory(sourceText),
        dropRate = GRC.RarityIntegration.GetEnhancedBasicDropRate(sourceText, nil, "mount"),
        rarityData = nil
    }
end

-- Enhanced categorization using Rarity data for PETS
function GRC.RarityIntegration.GetEnhancedPetData(petName, speciesID, sourceText)
    if not isRarityAvailable then
        return {
            isRarityTracked = false,
            expansion = "Unknown",
            category = "Unknown", 
            dropRate = "Unknown",
            rarityData = nil
        }
    end
    
    -- Try to find pet in Rarity database using fast lookup
    local rarityData = GRC.RarityIntegration.FindPetInRarity(petName, speciesID)
    
    if rarityData then
        return {
            isRarityTracked = true,
            expansion = GRC.RarityIntegration.GetExpansionFromRarityData(rarityData),
            category = GRC.RarityIntegration.GetCategoryFromRarityData(rarityData),
            dropRate = GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(rarityData),
            rarityData = rarityData,
            sourceInstance = GRC.RarityIntegration.GetInstanceFromRarityData(rarityData),
            bossName = rarityData.lockBossName,
            npcIDs = rarityData.npcs,
            encounterIDs = rarityData.statisticId,
            isBlackMarket = rarityData.blackMarket or rarityData.bmah,
            isRemoved = rarityData.removed
        }
    end
    
    -- Fallback to basic categorization
    return {
        isRarityTracked = false,
        expansion = GRC.RarityIntegration.GetBasicExpansion(speciesID),
        category = GRC.RarityIntegration.GetBasicCategory(sourceText),
        dropRate = GRC.RarityIntegration.GetEnhancedBasicDropRate(sourceText, nil, "pet"),
        rarityData = nil
    }
end

-- Enhanced categorization using Rarity data for TOYS
function GRC.RarityIntegration.GetEnhancedToyData(toyName, toyID, sourceText)
    if not isRarityAvailable then
        return {
            isRarityTracked = false,
            expansion = "Unknown",
            category = "Unknown", 
            dropRate = "Unknown",
            rarityData = nil
        }
    end
    
    -- Try to find toy in Rarity database using fast lookup
    local rarityData = GRC.RarityIntegration.FindToyInRarity(toyName, toyID)
    
    if rarityData then
        return {
            isRarityTracked = true,
            expansion = GRC.RarityIntegration.GetExpansionFromRarityData(rarityData),
            category = GRC.RarityIntegration.GetCategoryFromRarityData(rarityData),
            dropRate = GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(rarityData),
            rarityData = rarityData,
            sourceInstance = GRC.RarityIntegration.GetInstanceFromRarityData(rarityData),
            bossName = rarityData.lockBossName,
            npcIDs = rarityData.npcs,
            encounterIDs = rarityData.statisticId,
            isBlackMarket = rarityData.blackMarket or rarityData.bmah,
            isRemoved = rarityData.removed
        }
    end
    
    -- Fallback to basic categorization
    return {
        isRarityTracked = false,
        expansion = GRC.RarityIntegration.GetBasicExpansion(toyID),
        category = GRC.RarityIntegration.GetBasicCategory(sourceText),
        dropRate = GRC.RarityIntegration.GetEnhancedBasicDropRate(sourceText, nil, "toy"),
        rarityData = nil
    }
end

-- OPTIMIZED: Fast mount lookup using pre-built tables
function GRC.RarityIntegration.FindMountInRarity(mountName, spellID, itemID)
    if not isRarityAvailable then
        return nil
    end
    
    -- Ensure lookup tables are built
    BuildLookupTables()
    
    -- Strategy 1: Match by spellID (most reliable) - INSTANT LOOKUP
    if spellID and lookupTables.mountsBySpellID[spellID] then
        return lookupTables.mountsBySpellID[spellID]
    end
    
    -- Strategy 2: Match by itemID - INSTANT LOOKUP
    if itemID and lookupTables.mountsByItemID[itemID] then
        return lookupTables.mountsByItemID[itemID]
    end
    
    -- Strategy 3: Match by exact name - INSTANT LOOKUP
    if mountName and type(mountName) == "string" then
        local lowerName = mountName:lower()
        if lookupTables.mountsByName[lowerName] then
            return lookupTables.mountsByName[lowerName]
        end
        
        -- Try common name variations (limited to prevent loops)
        local variations = {
            lowerName:gsub("^reins of the ", ""),
            lowerName:gsub("^reins of ", ""),
            lowerName:gsub("'s reins$", "")
        }
        
        for _, variation in ipairs(variations) do
            if variation ~= lowerName and lookupTables.mountsByName[variation] then
                return lookupTables.mountsByName[variation]
            end
        end
    end
    
    return nil
end

-- OPTIMIZED: Fast pet lookup using pre-built tables
function GRC.RarityIntegration.FindPetInRarity(petName, speciesID)
    if not isRarityAvailable then
        return nil
    end
    
    -- Ensure lookup tables are built
    BuildLookupTables()
    
    -- Strategy 1: Match by speciesID (most reliable) - INSTANT LOOKUP
    if speciesID and lookupTables.petsBySpeciesID[speciesID] then
        return lookupTables.petsBySpeciesID[speciesID]
    end
    
    -- Strategy 2: Match by exact name - INSTANT LOOKUP
    if petName and type(petName) == "string" then
        local lowerName = petName:lower()
        if lookupTables.petsByName[lowerName] then
            return lookupTables.petsByName[lowerName]
        end
    end
    
    return nil
end

-- OPTIMIZED: Fast toy lookup using pre-built tables
function GRC.RarityIntegration.FindToyInRarity(toyName, toyID)
    if not isRarityAvailable then
        return nil
    end
    
    -- Ensure lookup tables are built
    BuildLookupTables()
    
    -- Strategy 1: Match by itemID (most reliable) - INSTANT LOOKUP
    if toyID and lookupTables.toysByItemID[toyID] then
        return lookupTables.toysByItemID[toyID]
    end
    
    -- Strategy 2: Match by exact name - INSTANT LOOKUP
    if toyName and type(toyName) == "string" then
        local lowerName = toyName:lower()
        if lookupTables.toysByName[lowerName] then
            return lookupTables.toysByName[lowerName]
        end
    end
    
    return nil
end

-- Get attempt data from Rarity if available (works for all item types)
function GRC.RarityIntegration.GetRarityAttemptData(rarityKey, itemType)
    if not isRarityAvailable or not rarityKey then
        return {
            attempts = 0,
            sessionAttempts = 0,
            enabled = true,
            found = false
        }
    end
    
    -- Check if Rarity has profile data
    if not _G.Rarity.db or not _G.Rarity.db.profile or not _G.Rarity.db.profile.groups then
        return {
            attempts = 0,
            sessionAttempts = 0,
            enabled = true,
            found = false
        }
    end
    
    -- Look for attempt data in Rarity's profile
    for groupName, groupData in pairs(_G.Rarity.db.profile.groups) do
        if type(groupData) == "table" and groupName ~= "name" then
            local itemData = groupData[rarityKey]
            if itemData and type(itemData) == "table" then
                return {
                    attempts = itemData.attempts or 0,
                    sessionAttempts = (itemData.session and itemData.session.attempts) or 0,
                    totalTime = itemData.time or 0,
                    sessionTime = (itemData.session and itemData.session.time) or 0,
                    lastAttempt = itemData.lastAttempt,
                    enabled = itemData.enabled ~= false,
                    found = itemData.found or false
                }
            end
        end
    end
    
    return {
        attempts = 0,
        sessionAttempts = 0,
        enabled = true,
        found = false
    }
end

-- Get lockout information using Rarity data (enhanced with Rarity's lockout system)
function GRC.RarityIntegration.GetRarityLockoutInfo(rarityData)
    if not isRarityAvailable or not rarityData then
        return "Unknown"
    end
    
    -- Method 1: Use Rarity's built-in lockout system
    if _G.Rarity and _G.Rarity.lockouts then
        -- Check boss lockouts (weekly raids)
        if rarityData.lockBossName and _G.Rarity.lockouts[rarityData.lockBossName] then
            return "Locked (Weekly)"
        end
        
        -- Check dungeon lockouts (daily)
        if rarityData.lockDungeonId and _G.Rarity.lockouts_holiday and _G.Rarity.lockouts_holiday[rarityData.lockDungeonId] then
            return "Locked (Daily)"
        end
        
        -- If there's lockout data but not locked, show available
        if rarityData.lockBossName or rarityData.lockDungeonId then
            return "Available"
        end
    end
    
    -- Method 2: Fallback to basic categorization
    if rarityData.method == "BOSS" then
        return "Weekly Reset"
    elseif rarityData.method == "NPC" then
        return "Daily Reset"
    elseif rarityData.method == "SPECIAL" then
        return "Event Based"
    elseif rarityData.method == "USE" then
        return "N/A"
    end
    
    return "N/A"
end

-- Mapping functions using Rarity data
function GRC.RarityIntegration.GetExpansionFromRarityData(rarityData)
    if not rarityData or not rarityData.cat then
        return "Unknown"
    end
    
    local expansionMap = {
        ["BASE"] = "Classic",
        ["TBC"] = "The Burning Crusade",
        ["WOTLK"] = "Wrath of the Lich King",
        ["CATA"] = "Cataclysm",
        ["MOP"] = "Mists of Pandaria",
        ["WOD"] = "Warlords of Draenor",
        ["LEGION"] = "Legion",
        ["BFA"] = "Battle for Azeroth",
        ["SHADOWLANDS"] = "Shadowlands",
        ["DRAGONFLIGHT"] = "Dragonflight",
        ["TWW"] = "The War Within",
        ["HOLIDAY"] = "Holiday Event"
    }
    
    return expansionMap[rarityData.cat] or "Unknown"
end

function GRC.RarityIntegration.GetCategoryFromRarityData(rarityData)
    if not rarityData or not rarityData.method then
        return "Unknown"
    end
    
    local categoryMap = {
        ["BOSS"] = "Raid Drop",
        ["NPC"] = "Dungeon Drop",
        ["ZONE"] = "World Drop",
        ["USE"] = "Container",
        ["FISHING"] = "Fishing",
        ["ARCH"] = "Archaeology",
        ["SPECIAL"] = "World Event",
        ["MINING"] = "Mining",
        ["COLLECTION"] = "Achievement",
        ["PET_BATTLE"] = "Pet Battle",
        ["WILD_PET"] = "Wild Pet"
    }
    
    return categoryMap[rarityData.method] or "Unknown"
end

-- ENHANCED: Better drop rate logic with Trading Post and Wild Pet fixes
function GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(rarityData)
    if not rarityData then
        return "Unknown"
    end
    
    -- Special handling for Trading Post items
    if rarityData.cat and rarityData.cat == "TRADING_POST" then
        return "100%" -- Trading Post items are purchasable
    end
    
    -- Special handling for Wild Pets
    if rarityData.method and rarityData.method == "WILD_PET" then
        return "100%" -- Wild pets can be caught
    end
    
    -- Special handling for achievements and vendors
    if rarityData.method and (rarityData.method == "COLLECTION" or rarityData.method == "VENDOR") then
        return "100%"
    end
    
    -- Use Rarity's chance data if available
    if rarityData.chance then
        local chance = rarityData.chance
        if chance == 1 then
            return "100%"
        elseif chance == 100 then
            return "~1%"
        elseif chance == 200 then
            return "~0.5%"
        elseif chance == 333 then
            return "~0.3%"
        elseif chance == 500 then
            return "~0.2%"
        elseif chance == 1000 then
            return "~0.1%"
        else
            local percentage = (1 / chance) * 100
            if percentage >= 10 then
                return string.format("%.1f%%", percentage)
            elseif percentage >= 1 then
                return string.format("%.2f%%", percentage)
            else
                return string.format("%.3f%%", percentage)
            end
        end
    end
    
    return "Unknown"
end

function GRC.RarityIntegration.GetDropRateFromRarityData(rarityData)
    -- Use the enhanced version
    return GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(rarityData)
end

function GRC.RarityIntegration.GetInstanceFromRarityData(rarityData)
    if not rarityData then
        return nil
    end
    
    -- Try to extract instance from coordinates
    if rarityData.coords and type(rarityData.coords) == "table" and #rarityData.coords > 0 then
        local coord = rarityData.coords[1]
        if coord and coord.m then
            local mapToInstance = {
                -- Classic
                [249] = "Onyxia's Lair",
                
                -- The Burning Crusade
                [332] = "Karazhan",
                [550] = "Tempest Keep",
                
                -- Wrath of the Lich King
                [147] = "Ulduar",
                [118] = "Icecrown Citadel",
                [119] = "The Obsidian Sanctum",
                [141] = "The Eye of Eternity",
                
                -- Cataclysm
                [367] = "Firelands",
                [409] = "Dragon Soul",
                
                -- Mists of Pandaria
                [317] = "Mogu'shan Vaults",
                [362] = "Throne of Thunder",
                [433] = "Siege of Orgrimmar",
                
                -- Warlords of Draenor
                [596] = "Blackrock Foundry",
                [661] = "Hellfire Citadel",
                
                -- Legion
                [885] = "Antorus, the Burning Throne",
                
                -- Battle for Azeroth
                [1358] = "Battle of Dazar'alor",
                [1580] = "Ny'alotha, the Waking City",
                
                -- Shadowlands
                [1648] = "Sanctum of Domination",
                [1702] = "Sepulcher of the First Ones",
                
                -- Dragonflight
                [2119] = "Vault of the Incarnates",
                [2166] = "Aberrus, the Shadowed Crucible",
                [2200] = "Amirdrassil, the Dream's Hope"
            }
            
            if mapToInstance[coord.m] then
                return mapToInstance[coord.m]
            end
        end
    end
    
    -- Try boss name to instance mapping
    if rarityData.lockBossName then
        local bossToInstance = {
            -- Classic
            ["Onyxia"] = "Onyxia's Lair",
            
            -- The Burning Crusade
            ["Kael'thas Sunstrider"] = "Tempest Keep",
            ["Attumen the Huntsman"] = "Karazhan",
            
            -- Wrath of the Lich King
            ["The Lich King"] = "Icecrown Citadel",
            ["Yogg-Saron"] = "Ulduar",
            ["Sartharion"] = "The Obsidian Sanctum",
            ["Malygos"] = "The Eye of Eternity",
            
            -- And more...
        }
        
        if bossToInstance[rarityData.lockBossName] then
            return bossToInstance[rarityData.lockBossName]
        end
    end
    
    return nil
end

-- ENHANCED: Fallback functions for standalone mode with better drop rates
function GRC.RarityIntegration.GetBasicExpansion(itemID)
    if not itemID then return "Unknown" end
    
    if itemID >= 400000 then return "The War Within"
    elseif itemID >= 350000 then return "Dragonflight"
    elseif itemID >= 300000 then return "Shadowlands"
    elseif itemID >= 250000 then return "Battle for Azeroth"
    elseif itemID >= 200000 then return "Legion"
    elseif itemID >= 150000 then return "Warlords of Draenor"
    elseif itemID >= 100000 then return "Mists of Pandaria"
    elseif itemID >= 80000 then return "Cataclysm"
    elseif itemID >= 50000 then return "Wrath of the Lich King"
    elseif itemID >= 30000 then return "The Burning Crusade"
    else return "Classic"
    end
end

function GRC.RarityIntegration.GetBasicCategory(sourceText)
    if not sourceText then return "Unknown" end
    
    local lowerSource = sourceText:lower()
    
    if lowerSource:find("achievement") then
        return "Achievement"
    elseif lowerSource:find("vendor") or lowerSource:find("reputation") then
        return "Vendor"
    elseif lowerSource:find("quest") then
        return "Quest"
    elseif lowerSource:find("drop") or lowerSource:find("loot") then
        return "Drop"
    elseif lowerSource:find("trading post") then
        return "Trading Post"
    elseif lowerSource:find("pvp") or lowerSource:find("gladiator") then
        return "PvP"
    elseif lowerSource:find("profession") then
        return "Profession"
    elseif lowerSource:find("wild") or lowerSource:find("battle pet") then
        return "Wild Pet"
    elseif lowerSource:find("toy") then
        return "Toy"
    else
        return "Unknown"
    end
end

-- ENHANCED: Basic drop rate with fixes for Trading Post and Wild Pets
function GRC.RarityIntegration.GetEnhancedBasicDropRate(sourceText, sourceType, itemType)
    if not sourceText then return "Unknown" end
    
    local lowerSource = sourceText:lower()
    
    -- Enhanced logic for Trading Post
    if lowerSource:find("trading post") then
        return "100%" -- Trading Post items are purchasable
    end
    
    -- Enhanced logic for Wild Pets
    if itemType == "pet" and (lowerSource:find("wild") or lowerSource:find("caught") or lowerSource:find("captured")) then
        return "100%" -- Wild pets can be caught reliably
    end
    
    -- Standard logic
    if lowerSource:find("achievement") or lowerSource:find("vendor") or lowerSource:find("quest") then
        return "100%"
    elseif lowerSource:find("rare") then
        return "~1%"
    elseif lowerSource:find("wild") then
        return "100%" -- Wild anything can typically be obtained reliably
    else
        return "Unknown"
    end
end

function GRC.RarityIntegration.GetBasicDropRate(sourceText)
    -- Use the enhanced version
    return GRC.RarityIntegration.GetEnhancedBasicDropRate(sourceText, nil, nil)
end

-- Enhanced search functionality for all item types
function GRC.RarityIntegration.SearchRarityDatabase(searchText, itemType)
    if not isRarityAvailable then
        return {}
    end
    
    local results = {}
    local searchLower = searchText:lower()
    local database = nil
    
    if itemType == "mount" then
        database = _G.Rarity.ItemDB.mounts
    elseif itemType == "pet" then
        database = _G.Rarity.ItemDB.pets
    elseif itemType == "toy" then
        database = _G.Rarity.ItemDB.toys
    end
    
    if not database then return results end
    
    for itemKey, itemData in pairs(database) do
        if type(itemData) == "table" and itemKey ~= "name" then
            if itemData.name and itemData.name:lower():find(searchLower, 1, true) then
                table.insert(results, {
                    name = itemData.name,
                    data = itemData,
                    key = itemKey,
                    type = itemType,
                    expansion = GRC.RarityIntegration.GetExpansionFromRarityData(itemData),
                    category = GRC.RarityIntegration.GetCategoryFromRarityData(itemData),
                    dropRate = GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(itemData)
                })
            end
        end
    end
    
    return results
end

-- Get mounts by encounter ID (compatibility function for AttemptsTracker)
function GRC.RarityIntegration.GetMountsByEncounterID(encounterID)
    return GRC.RarityIntegration.GetItemsByEncounterID(encounterID, "mount")
end

-- Encounter and NPC mapping for attempt tracking (works for all item types)
function GRC.RarityIntegration.GetItemsByEncounterID(encounterID, itemType)
    if not isRarityAvailable or not encounterID then
        return {}
    end
    
    local results = {}
    local database = nil
    
    if itemType == "mount" then
        database = _G.Rarity.ItemDB.mounts
    elseif itemType == "pet" then
        database = _G.Rarity.ItemDB.pets
    elseif itemType == "toy" then
        database = _G.Rarity.ItemDB.toys
    else
        -- Search all databases
        local allDatabases = {
            {db = _G.Rarity.ItemDB.mounts, type = "mount"},
            {db = _G.Rarity.ItemDB.pets, type = "pet"},
            {db = _G.Rarity.ItemDB.toys, type = "toy"}
        }
        
        for _, dbInfo in ipairs(allDatabases) do
            if dbInfo.db then
                for itemKey, itemData in pairs(dbInfo.db) do
                    if type(itemData) == "table" and itemKey ~= "name" then
                        if itemData.statisticId and type(itemData.statisticId) == "table" then
                            for _, statId in ipairs(itemData.statisticId) do
                                if statId == encounterID then
                                    table.insert(results, {
                                        name = itemData.name,
                                        data = itemData,
                                        key = itemKey,
                                        type = dbInfo.type,
                                        spellID = itemData.spellId,
                                        itemID = itemData.itemId,
                                        speciesID = itemData.creatureId
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        return results
    end
    
    -- Single database search
    if database then
        for itemKey, itemData in pairs(database) do
            if type(itemData) == "table" and itemKey ~= "name" then
                if itemData.statisticId and type(itemData.statisticId) == "table" then
                    for _, statId in ipairs(itemData.statisticId) do
                        if statId == encounterID then
                            table.insert(results, {
                                name = itemData.name,
                                data = itemData,
                                key = itemKey,
                                type = itemType,
                                spellID = itemData.spellId,
                                itemID = itemData.itemId,
                                speciesID = itemData.creatureId
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    
    return results
end

function GRC.RarityIntegration.GetItemsByNPCID(npcID, itemType)
    if not isRarityAvailable or not npcID then
        return {}
    end
    
    local results = {}
    local database = nil
    
    if itemType == "mount" then
        database = _G.Rarity.ItemDB.mounts
    elseif itemType == "pet" then
        database = _G.Rarity.ItemDB.pets
    elseif itemType == "toy" then
        database = _G.Rarity.ItemDB.toys
    else
        -- Search all databases
        local allDatabases = {
            {db = _G.Rarity.ItemDB.mounts, type = "mount"},
            {db = _G.Rarity.ItemDB.pets, type = "pet"},
            {db = _G.Rarity.ItemDB.toys, type = "toy"}
        }
        
        for _, dbInfo in ipairs(allDatabases) do
            if dbInfo.db then
                for itemKey, itemData in pairs(dbInfo.db) do
                    if type(itemData) == "table" and itemKey ~= "name" then
                        if itemData.npcs and type(itemData.npcs) == "table" then
                            for _, id in ipairs(itemData.npcs) do
                                if id == npcID then
                                    table.insert(results, {
                                        name = itemData.name,
                                        data = itemData,
                                        key = itemKey,
                                        type = dbInfo.type,
                                        spellID = itemData.spellId,
                                        itemID = itemData.itemId,
                                        speciesID = itemData.creatureId
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        return results
    end
    
    -- Single database search
    if database then
        for itemKey, itemData in pairs(database) do
            if type(itemData) == "table" and itemKey ~= "name" then
                if itemData.npcs and type(itemData.npcs) == "table" then
                    for _, id in ipairs(itemData.npcs) do
                        if id == npcID then
                            table.insert(results, {
                                name = itemData.name,
                                data = itemData,
                                key = itemKey,
                                type = itemType,
                                spellID = itemData.spellId,
                                itemID = itemData.itemId,
                                speciesID = itemData.creatureId
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    
    return results
end

-- Utility function
function GRC.RarityIntegration.CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

-- Debug and utility functions
function GRC.RarityIntegration.DebugIntegration()
    print("|cFFFF6B35GRC Rarity Integration Debug:|r")
    print("  Available: " .. tostring(isRarityAvailable))
    print("  Ready: " .. tostring(integrationReady))
    print("  Version: " .. tostring(rarityVersion or "Unknown"))
    
    -- Check Rarity addon status
    local isLoaded = C_AddOns.IsAddOnLoaded("Rarity")
    print("  Addon Loaded: " .. tostring(isLoaded))
    
    if isLoaded then
        print("  Rarity Global: " .. tostring(_G.Rarity ~= nil))
        if _G.Rarity then
            print("  ItemDB: " .. tostring(_G.Rarity.ItemDB ~= nil))
            if _G.Rarity.ItemDB then
                -- Check all databases
                local databases = {"mounts", "pets", "toys"}
                for _, dbName in ipairs(databases) do
                    print("  " .. dbName:gsub("^%l", string.upper) .. " DB: " .. tostring(_G.Rarity.ItemDB[dbName] ~= nil))
                    if _G.Rarity.ItemDB[dbName] then
                        local count = 0
                        for itemKey, itemData in pairs(_G.Rarity.ItemDB[dbName]) do
                            if type(itemData) == "table" and itemKey ~= "name" then
                                count = count + 1
                            end
                        end
                        print("  " .. dbName:gsub("^%l", string.upper) .. " Count: " .. count)
                    end
                end
            end
        end
    end
    
    if isRarityAvailable then
        local stats = GRC.RarityIntegration.GetDatabaseStatistics()
        print(string.format("  Database: %d mounts, %d pets, %d toys", 
              stats.totalMounts, stats.totalPets, stats.totalToys))
        
        -- Show lookup table stats
        if lookupTables.isBuilt then
            print("  Lookup Tables:")
            print(string.format("    Mounts by SpellID: %d", GRC.RarityIntegration.CountTable(lookupTables.mountsBySpellID)))
            print(string.format("    Pets by SpeciesID: %d", GRC.RarityIntegration.CountTable(lookupTables.petsBySpeciesID)))
            print(string.format("    Toys by ItemID: %d", GRC.RarityIntegration.CountTable(lookupTables.toysByItemID)))
        else
            print("  Lookup Tables: Not built")
        end
        
        -- Test specific items
        local testMount = GRC.RarityIntegration.FindMountInRarity("Ashes of Al'ar", nil, nil)
        if testMount then
            print(string.format("  Test Mount: Ashes of Al'ar found - %s (%s) - %s", 
                  GRC.RarityIntegration.GetExpansionFromRarityData(testMount),
                  GRC.RarityIntegration.GetCategoryFromRarityData(testMount),
                  GRC.RarityIntegration.GetEnhancedDropRateFromRarityData(testMount)))
        else
            print("  Test Mount: Ashes of Al'ar not found")
        end
    else
        print("  Status: Not available - check if Rarity is fully loaded")
        print("  Try: /reload or wait a moment after login")
    end
end

-- Initialize and build lookup tables
local function WaitForRarityAndInitialize()
    local attempts = 0
    local maxAttempts = 15
    
    local function checkAndInit()
        attempts = attempts + 1
        
        if CheckRarityAvailability() then
            InitializeRarityIntegration()
            return
        end
        
        if attempts < maxAttempts then
            if attempts % 5 == 0 then
                GRC.Debug.Info("Rarity", "Still waiting for Rarity to fully initialize... (attempt %d/%d)", attempts, maxAttempts)
            end
            C_Timer.After(3, checkAndInit)
        else
            GRC.Debug.Info("Rarity", "Rarity not detected after %d attempts - running in standalone mode", maxAttempts)
            integrationReady = true -- Mark as ready even without Rarity
        end
    end
    
    checkAndInit()
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        -- Start checking for Rarity after our addon loads
        C_Timer.After(3, WaitForRarityAndInitialize)
        
    elseif event == "PLAYER_LOGIN" then
        -- Final check after player login
        C_Timer.After(5, function()
            if not integrationReady then
                GRC.Debug.Info("Rarity", "Forcing initialization in standalone mode")
                integrationReady = true
            end
        end)
    end
end)

-- Enhanced slash commands
SLASH_GRC_RARITY_DEBUG1 = "/grc-rarity-debug"
SlashCmdList["GRC_RARITY_DEBUG"] = function(msg)
    GRC.RarityIntegration.DebugIntegration()
end

SLASH_GRC_RARITY_SEARCH1 = "/grc-rarity-search"
SlashCmdList["GRC_RARITY_SEARCH"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local itemType = args[1] and args[1]:lower() or "mount"
    local searchTerm = table.concat(args, " ", 2)
    
    if not searchTerm or searchTerm:trim() == "" then
        print("|cFFFF6B35GRC:|r Usage: /grc-rarity-search <type> <name>")
        print("  Types: mount, pet, toy")
        print("  Example: /grc-rarity-search mount Ashes")
        return
    end
    
    if not (itemType == "mount" or itemType == "pet" or itemType == "toy") then
        print("|cFFFF6B35GRC:|r Invalid type. Use: mount, pet, or toy")
        return
    end
    
    local results = GRC.RarityIntegration.SearchRarityDatabase(searchTerm:trim(), itemType)
    if #results > 0 then
        print(string.format("|cFFFF6B35GRC:|r Found %d %s result(s) for '%s':", #results, itemType, searchTerm:trim()))
        for i, result in ipairs(results) do
            if i <= 5 then
                print(string.format("  %s - %s (%s) - %s", 
                      result.name, result.expansion, result.category, result.dropRate))
            end
        end
        if #results > 5 then
            print(string.format("  ... and %d more", #results - 5))
        end
    else
        print(string.format("|cFFFF6B35GRC:|r No %s results found for '%s'", itemType, searchTerm:trim()))
        if not isRarityAvailable then
            print("|cFFFF6B35GRC:|r (Rarity integration not available)")
        end
    end
end

return GRC.RarityIntegration