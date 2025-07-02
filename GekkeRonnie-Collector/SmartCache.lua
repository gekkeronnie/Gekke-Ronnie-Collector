-- SmartCache.lua - FIXED Attempt Data Integration + TrackingBar Sync
local addonName, GRC = ...
GRC.SmartCache = GRC.SmartCache or {}

-- Global cache - persists between sessions
GRCollectionCache = GRCollectionCache or {
    mounts = {},
    pets = {},
    toys = {},
    totalMounts = 0,
    totalPets = 0,
    totalToys = 0,
    version = 24,  -- Bumped for fixed attempt synchronization
    lastUpdate = 0,
    integrationStats = {
        mountJournalMounts = 0,
        petJournalPets = 0,
        toyBoxToys = 0,
        rarityEnhanced = 0,
        standaloneMode = true,
        categorizedItems = 0,
        attemptsImported = 0,
        importSource = "None"
    },
    buildScheduled = false,
    isReady = false,
    firstLoadComplete = false
}

-- In-memory cache for INSTANT access
local memoryCache = {
    mounts = {},
    pets = {},
    toys = {},
    mountsArray = {},
    petsArray = {},
    toysArray = {},
    lastCollectionCheck = 0,
    lastAttemptSync = 0,  -- FIXED: Add attempt sync tracking
    isLoaded = false
}

-- Performance settings
local COLLECTION_CHECK_INTERVAL = 30 -- Increased from 5 to 30 seconds
local ATTEMPT_SYNC_INTERVAL = 15  -- Increased from 3 to 15 seconds
local BATCH_SIZE = 25
local YIELD_TIME = 0.001

-- FIXED: Better cache readiness detection
local function CanUseExistingCache()
    return GRCollectionCache.isReady and 
           GRCollectionCache.version >= 21 and
           GRCollectionCache.firstLoadComplete and
           memoryCache.isLoaded
end

-- FIXED: More reliable cache building detection
local function IsCacheBuilding()
    return GRCollectionCache.buildScheduled and not GRCollectionCache.firstLoadComplete
end

-- FIXED: Smart attempt data synchronization - only when needed
local function SyncAttemptDataFromRarity()
    local currentTime = time()
    if currentTime - memoryCache.lastAttemptSync < ATTEMPT_SYNC_INTERVAL then
        return false -- Don't sync too frequently
    end
    
    memoryCache.lastAttemptSync = currentTime
    
    if not GRC.RarityDataImporter or not GRC.RarityDataImporter.IsAvailable() then
        return false
    end
    
    GRC.Debug.Trace("Cache", "Syncing attempt data from Rarity")
    
    local syncCount = 0
    
    -- FIXED: Sync mount attempts using RarityDataImporter as primary source
    for mountID, mount in pairs(memoryCache.mounts) do
        local latestData = GRC.RarityDataImporter.GetLatestAttemptData(mount, "mount")
        if latestData then
            local oldAttempts = mount.attempts or 0
            if latestData.attempts ~= oldAttempts then
                mount.attempts = latestData.attempts
                mount.charactersTracked = latestData.charactersTracked
                mount.lastAttempt = latestData.lastAttempt
                mount.sessionAttempts = latestData.sessionAttempts
                syncCount = syncCount + 1
                
                -- Update in array cache too
                for i, arrayMount in ipairs(memoryCache.mountsArray) do
                    if arrayMount.mountID == mountID then
                        memoryCache.mountsArray[i] = mount
                        break
                    end
                end
            end
        end
    end
    
    -- FIXED: Sync pet attempts using RarityDataImporter as primary source
    for speciesID, pet in pairs(memoryCache.pets) do
        local latestData = GRC.RarityDataImporter.GetLatestAttemptData(pet, "pet")
        if latestData then
            local oldAttempts = pet.attempts or 0
            if latestData.attempts ~= oldAttempts then
                pet.attempts = latestData.attempts
                pet.charactersTracked = latestData.charactersTracked
                pet.lastAttempt = latestData.lastAttempt
                pet.sessionAttempts = latestData.sessionAttempts
                syncCount = syncCount + 1
                
                -- Update in array cache too
                for i, arrayPet in ipairs(memoryCache.petsArray) do
                    if arrayPet.speciesID == speciesID then
                        memoryCache.petsArray[i] = pet
                        break
                    end
                end
            end
        end
    end
    
    -- FIXED: Sync toy attempts using RarityDataImporter as primary source
    for toyID, toy in pairs(memoryCache.toys) do
        if toyID ~= "placeholder" and toyID > 0 then
            local latestData = GRC.RarityDataImporter.GetLatestAttemptData(toy, "toy")
            if latestData then
                local oldAttempts = toy.attempts or 0
                if latestData.attempts ~= oldAttempts then
                    toy.attempts = latestData.attempts
                    toy.charactersTracked = latestData.charactersTracked
                    toy.lastAttempt = latestData.lastAttempt
                    toy.sessionAttempts = latestData.sessionAttempts
                    syncCount = syncCount + 1
                    
                    -- Update in array cache too
                    for i, arrayToy in ipairs(memoryCache.toysArray) do
                        if arrayToy.toyID == toyID then
                            memoryCache.toysArray[i] = toy
                            break
                        end
                    end
                end
            end
        end
    end
    
    if syncCount > 0 then
        GRC.Debug.Trace("Cache", "Synced %d items with updated attempt data", syncCount)
        
        -- FIXED: Notify tracking bar of changes
        if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
            GRC.TrackingBar.ForceRefresh()
        end
        
        return true
    end
    
    return false
end

-- Fast collection status update
local function UpdateCollectionStatus()
    local currentTime = time()
    if currentTime - memoryCache.lastCollectionCheck < COLLECTION_CHECK_INTERVAL then
        return
    end
    
    memoryCache.lastCollectionCheck = currentTime
    
    GRC.Debug.Trace("Cache", "Quick collection status update")
    
    local collectionChanges = 0
    
    -- Update mount collection status
    if C_MountJournal and C_MountJournal.GetMountIDs then
        local mountIDs = C_MountJournal.GetMountIDs()
        for _, mountID in ipairs(mountIDs) do
            local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, 
                  isFactionSpecific, faction, shouldHideOnChar, isCollected = 
                  C_MountJournal.GetMountInfoByID(mountID)
            
            if memoryCache.mounts[mountID] and memoryCache.mounts[mountID].isCollected ~= isCollected then
                memoryCache.mounts[mountID].isCollected = isCollected
                collectionChanges = collectionChanges + 1
                
                -- Update in array cache too
                for i, mount in ipairs(memoryCache.mountsArray) do
                    if mount.mountID == mountID then
                        memoryCache.mountsArray[i].isCollected = isCollected
                        break
                    end
                end
            end
        end
    end
    
    -- Update pet collection status
    if C_PetJournal and C_PetJournal.GetNumPets then
        local numPets = C_PetJournal.GetNumPets()
        for i = 1, numPets do
            local petID, speciesID, owned = C_PetJournal.GetPetInfoByIndex(i)
            
            if memoryCache.pets[speciesID] and memoryCache.pets[speciesID].isCollected ~= owned then
                memoryCache.pets[speciesID].isCollected = owned
                collectionChanges = collectionChanges + 1
                
                -- Update in array cache too
                for j, pet in ipairs(memoryCache.petsArray) do
                    if pet.speciesID == speciesID then
                        memoryCache.petsArray[j].isCollected = owned
                        break
                    end
                end
            end
        end
    end
    
    -- Update toy collection status
    if PlayerHasToy then
        for toyID, toy in pairs(memoryCache.toys) do
            if toyID ~= "placeholder" and toyID > 0 then
                local isCollected = PlayerHasToy(toyID)
                if toy.isCollected ~= isCollected then
                    toy.isCollected = isCollected
                    collectionChanges = collectionChanges + 1
                    
                    -- Update in array cache too
                    for i, arrayToy in ipairs(memoryCache.toysArray) do
                        if arrayToy.toyID == toyID then
                            memoryCache.toysArray[i].isCollected = isCollected
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- FIXED: If collection status changed, also sync attempt data
    if collectionChanges > 0 then
        GRC.Debug.Trace("Cache", "%d collection status changes detected", collectionChanges)
        SyncAttemptDataFromRarity()
    end
end

-- FIXED: Better persistent cache loading
local function LoadFromPersistentCache()
    if memoryCache.isLoaded and CanUseExistingCache() then
        return true
    end
    
    GRC.Debug.Info("Cache", "Loading from persistent cache...")
    
    -- Clear memory cache first
    memoryCache.mounts = {}
    memoryCache.pets = {}
    memoryCache.toys = {}
    
    -- Direct copy to memory cache
    for mountID, mountData in pairs(GRCollectionCache.mounts) do
        memoryCache.mounts[mountID] = mountData
    end
    
    for speciesID, petData in pairs(GRCollectionCache.pets) do
        memoryCache.pets[speciesID] = petData
    end
    
    for toyID, toyData in pairs(GRCollectionCache.toys) do
        memoryCache.toys[toyID] = toyData
    end
    
    -- Build arrays for fast iteration
    GRC.SmartCache.BuildArrayCache()
    
    memoryCache.isLoaded = true
    
    GRC.Debug.Info("Cache", "Memory cache loaded: %d mounts, %d pets, %d toys", 
                   GRCollectionCache.totalMounts, GRCollectionCache.totalPets, GRCollectionCache.totalToys)
    
    -- FIXED: Initial attempt data sync
    C_Timer.After(1, function()
        SyncAttemptDataFromRarity()
    end)
    
    return true
end

-- Build array cache for fast UI access
function GRC.SmartCache.BuildArrayCache()
    memoryCache.mountsArray = {}
    memoryCache.petsArray = {}
    memoryCache.toysArray = {}
    
    for mountID, mountData in pairs(memoryCache.mounts) do
        table.insert(memoryCache.mountsArray, mountData)
    end
    
    for speciesID, petData in pairs(memoryCache.pets) do
        table.insert(memoryCache.petsArray, petData)
    end
    
    for toyID, toyData in pairs(memoryCache.toys) do
        if toyID ~= "placeholder" and toyData.toyID and toyData.toyID > 0 then
            table.insert(memoryCache.toysArray, toyData)
        end
    end
    
    GRC.Debug.Trace("Cache", "Array cache built: %d mounts, %d pets, %d toys", 
                    #memoryCache.mountsArray, #memoryCache.petsArray, #memoryCache.toysArray)
end

-- FIXED: More robust async cache building
local function AsyncBuildCache()
    GRC.Debug.Info("Cache", "Building cache from scratch...")
    
    -- Mark as building to prevent multiple builds
    GRCollectionCache.buildScheduled = true
    
    local buildMounts, buildPets, buildToys, finalizeBuild, enhanceWithRarity, enhancePetsAndToys, completeAsyncBuild
    
    buildMounts = function()
        GRC.Debug.Info("Cache", "Building mounts...")
        
        -- Ensure Collections addon is loaded
        if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            local loaded = C_AddOns.LoadAddOn("Blizzard_Collections")
            if not loaded then
                GRC.Debug.Error("Cache", "Failed to load Blizzard_Collections addon")
                -- Continue anyway
            end
        end
        
        -- Wait a moment for addon to initialize
        C_Timer.After(0.5, function()
            local mountIDs = C_MountJournal.GetMountIDs()
            if not mountIDs then
                GRC.Debug.Error("Cache", "Failed to get mount IDs, creating empty cache")
                GRCollectionCache.mounts = {}
                GRCollectionCache.totalMounts = 0
                buildPets()
                return
            end
            
            local mounts = {}
            
            local function processMountBatch(startIndex)
                local endIndex = math.min(startIndex + BATCH_SIZE - 1, #mountIDs)
                
                for i = startIndex, endIndex do
                    local mountID = mountIDs[i]
                    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, 
                          isFactionSpecific, faction, shouldHideOnChar, isCollected = 
                          C_MountJournal.GetMountInfoByID(mountID)
                    
                    if name and not shouldHideOnChar and spellID then
                        local creatureDisplayInfoID, description, sourceText = C_MountJournal.GetMountInfoExtraByID(mountID)
                        
                        local mount = {
                            mountID = mountID,
                            spellID = spellID,
                            name = name,
                            icon = icon,
                            isCollected = isCollected,
                            isUsable = isUsable,
                            isFavorite = isFavorite,
                            sourceType = sourceType,
                            sourceText = sourceText or "",
                            isFactionSpecific = isFactionSpecific,
                            faction = faction,
                            description = description,
                            expansion = GRC.SmartCache.GetBasicExpansion(spellID),
                            category = GRC.SmartCache.GetBasicCategory(sourceText, sourceType, "mount"), 
                            dropRate = GRC.SmartCache.GetEnhancedDropRate(sourceText, sourceType, "mount"),
                            isRarityTracked = false,
                            rarityData = nil,
                            attempts = 0,
                            charactersTracked = 0,
                            lastAttempt = nil,
                            timeSpent = 0,
                            sessionAttempts = 0,  -- FIXED: Add session tracking
                            characterBreakdown = {},
                            lastUpdated = time(),
                            source = "Mount Journal",
                            itemType = "mount"
                        }
                        
                        -- ENHANCED: Add lockout information using SimpleLockouts
                        if GRC.SimpleLockouts and GRC.SimpleLockouts.GetMountLockout then
                            mount.lockoutInfo, mount.lockoutColor = GRC.SimpleLockouts.GetMountLockout(mount)
                        else
                            mount.lockoutInfo = GRC.SmartCache.GetBasicLockout(sourceText, sourceType)
                            mount.lockoutColor = "|cFFCCCCCC"
                        end
                        
                        mounts[mountID] = mount
                    end
                end
                
                if endIndex < #mountIDs then
                    C_Timer.After(YIELD_TIME, function()
                        processMountBatch(endIndex + 1)
                    end)
                else
                    -- Finished mounts
                    GRCollectionCache.mounts = mounts
                    GRCollectionCache.totalMounts = GRC.Utils.TableCount(mounts)
                    GRCollectionCache.integrationStats.mountJournalMounts = GRCollectionCache.totalMounts
                    
                    GRC.Debug.Info("Cache", "Mounts built: %d", GRCollectionCache.totalMounts)
                    buildPets()
                end
            end
            
            processMountBatch(1)
        end)
    end
    
    buildPets = function()
        GRC.Debug.Info("Cache", "Building pets...")
        
        -- Wait for pet journal to be ready
        C_Timer.After(0.5, function()
            local pets = {}
            local numSpecies = C_PetJournal.GetNumPets()
            
            if numSpecies == 0 then
                GRC.Debug.Warn("Cache", "No pets found, creating empty cache")
                GRCollectionCache.pets = {}
                GRCollectionCache.totalPets = 0
                buildToys()
                return
            end
            
            local function processPetBatch(startIndex)
                local endIndex = math.min(startIndex + BATCH_SIZE - 1, numSpecies)
                
                for i = startIndex, endIndex do
                    local petID, speciesID, owned, customName, level, favorite, isRevoked, 
                          speciesName, icon, petType, companionID, tooltip, description, 
                          isWild, canBattle, isTradeable, isUnique, obtainable = C_PetJournal.GetPetInfoByIndex(i)
                    
                    if speciesName and obtainable then
                        local name, icon, petType, creatureID, sourceText, description, isWild, canBattle, isTradeable, isUnique = 
                              C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                        
                        local pet = {
                            petID = petID or "",
                            speciesID = speciesID,
                            name = speciesName,
                            icon = icon,
                            isCollected = owned,
                            level = level or 1,
                            isFavorite = favorite,
                            petType = _G["BATTLE_PET_NAME_" .. petType] or "Unknown",
                            sourceText = sourceText or "",
                            description = description or "",
                            isWild = isWild,
                            canBattle = canBattle,
                            isTradeable = isTradeable,
                            isUnique = isUnique,
                            expansion = GRC.SmartCache.GetBasicExpansion(creatureID),
                            category = GRC.SmartCache.GetBasicCategory(sourceText, nil, "pet", {isWild = isWild, canBattle = canBattle}), 
                            dropRate = GRC.SmartCache.GetEnhancedDropRate(sourceText, nil, "pet", {isWild = isWild}),
                            isRarityTracked = false,
                            rarityData = nil,
                            attempts = 0,
                            charactersTracked = 0,
                            lastAttempt = nil,
                            timeSpent = 0,
                            sessionAttempts = 0,  -- FIXED: Add session tracking
                            characterBreakdown = {},
                            lockoutInfo = GRC.SmartCache.GetBasicLockout(sourceText, nil),
                            lastUpdated = time(),
                            source = "Pet Journal",
                            itemType = "pet"
                        }
                        
                        pets[speciesID] = pet
                    end
                end
                
                if endIndex < numSpecies then
                    C_Timer.After(YIELD_TIME, function()
                        processPetBatch(endIndex + 1)
                    end)
                else
                    -- Finished pets
                    GRCollectionCache.pets = pets
                    GRCollectionCache.totalPets = GRC.Utils.TableCount(pets)
                    GRCollectionCache.integrationStats.petJournalPets = GRCollectionCache.totalPets
                    
                    GRC.Debug.Info("Cache", "Pets built: %d", GRCollectionCache.totalPets)
                    buildToys()
                end
            end
            
            processPetBatch(1)
        end)
    end
    
    -- FIXED: Improved toys building with proper ToyBox API integration
    buildToys = function()
        GRC.Debug.Info("Cache", "Building toys from ToyBox API...")
        
        local toys = {}
        
        -- STEP 1: Get toys from Blizzard ToyBox API
        if C_ToyBox and C_ToyBox.GetNumFilteredToys then
            -- Store original filter settings
            local originalCollected = C_ToyBox.GetCollectedShown and C_ToyBox.GetCollectedShown() or true
            local originalUncollected = C_ToyBox.GetUncollectedShown and C_ToyBox.GetUncollectedShown() or true
            
            -- Set filters to show all toys
            if C_ToyBox.SetCollectedShown then C_ToyBox.SetCollectedShown(true) end
            if C_ToyBox.SetUncollectedShown then C_ToyBox.SetUncollectedShown(true) end
            if C_ToyBox.ForceToyRefilter then C_ToyBox.ForceToyRefilter() end
            
            -- Wait for filter to apply
            C_Timer.After(0.5, function()
                local numToys = C_ToyBox.GetNumFilteredToys()
                if numToys and numToys > 0 then
                    GRC.Debug.Info("Cache", "Found %d toys in ToyBox", numToys)
                    
                    -- Function to enhance toys with Rarity data and finalize
                    local function finalizeToyProcessing()
                        -- STEP 2: Enhance with Rarity data if available
                        if GRC.RarityIntegration and GRC.RarityIntegration.IsAvailable() then
                            GRC.Debug.Info("Cache", "Enhancing toys with Rarity data...")
                            
                            if _G.Rarity and _G.Rarity.ItemDB and _G.Rarity.ItemDB.toys then
                                local rarityToyCount = 0
                                local enhancedCount = 0
                                
                                for itemKey, itemData in pairs(_G.Rarity.ItemDB.toys) do
                                    if type(itemData) == "table" and itemKey ~= "name" and itemData.name then
                                        rarityToyCount = rarityToyCount + 1
                                        
                                        local toyID = itemData.itemId
                                        if toyID and toys[toyID] then
                                            -- Enhance existing toy with Rarity data
                                            local rarityEnhancement = GRC.RarityIntegration.GetEnhancedToyData(
                                                itemData.name, toyID, "")
                                            
                                            if rarityEnhancement.isRarityTracked then
                                                toys[toyID].isRarityTracked = true
                                                toys[toyID].expansion = rarityEnhancement.expansion
                                                toys[toyID].category = rarityEnhancement.category
                                                toys[toyID].dropRate = rarityEnhancement.dropRate
                                                toys[toyID].rarityData = rarityEnhancement.rarityData
                                                toys[toyID].sourceInstance = rarityEnhancement.sourceInstance
                                                toys[toyID].bossName = rarityEnhancement.bossName
                                                toys[toyID].isRemoved = rarityEnhancement.isRemoved
                                                toys[toyID].source = "ToyBox API + Rarity"
                                                enhancedCount = enhancedCount + 1
                                            end
                                        elseif toyID then
                                            -- Add toy that's in Rarity but not in ToyBox
                                            local rarityEnhancement = GRC.RarityIntegration.GetEnhancedToyData(
                                                itemData.name, toyID, "")
                                            
                                            local toy = {
                                                toyID = toyID,
                                                itemID = toyID,
                                                name = itemData.name,
                                                icon = nil,
                                                isCollected = PlayerHasToy(toyID),
                                                isFavorite = false,
                                                sourceText = "",
                                                description = "",
                                                itemType = "Miscellaneous",
                                                itemSubType = "Toy",
                                                quality = 1,
                                                expansion = rarityEnhancement.expansion,
                                                category = rarityEnhancement.category,
                                                dropRate = rarityEnhancement.dropRate,
                                                isRarityTracked = true,
                                                rarityData = rarityEnhancement.rarityData,
                                                attempts = 0,
                                                charactersTracked = 0,
                                                lastAttempt = nil,
                                                timeSpent = 0,
                                                sessionAttempts = 0,  -- FIXED: Add session tracking
                                                characterBreakdown = {},
                                                lockoutInfo = "Unknown",
                                                lockoutColor = "|cFFCCCCCC",
                                                lastUpdated = time(),
                                                source = "Rarity Database",
                                                itemType = "toy"
                                            }
                                            
                                            -- Try to get item info
                                            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
                                                  itemStackCount, itemEquipLoc, itemTexture, vendorPrice = GetItemInfo(toyID)
                                            if itemTexture then
                                                toy.icon = itemTexture
                                            end
                                            
                                            toys[toyID] = toy
                                        end
                                    end
                                end
                                
                                GRC.Debug.Info("Cache", "Enhanced %d toys with Rarity data (%d total in Rarity DB)", 
                                               enhancedCount, rarityToyCount)
                            end
                        else
                            GRC.Debug.Info("Cache", "Rarity not available - using ToyBox API data only")
                            
                            -- Basic categorization for toys without Rarity
                            for toyID, toy in pairs(toys) do
                                if toy.itemSubType and toy.itemSubType ~= "Toy" then
                                    toy.category = toy.itemSubType
                                else
                                    toy.category = "Toy"
                                end
                                
                                toy.source = "ToyBox API (Standalone)"
                            end
                        end
                        
                        -- Restore original filter settings
                        if C_ToyBox.SetCollectedShown then C_ToyBox.SetCollectedShown(originalCollected) end
                        if C_ToyBox.SetUncollectedShown then C_ToyBox.SetUncollectedShown(originalUncollected) end
                        if C_ToyBox.ForceToyRefilter then C_ToyBox.ForceToyRefilter() end
                        
                        -- Store results
                        GRCollectionCache.toys = toys
                        GRCollectionCache.totalToys = GRC.Utils.TableCount(toys)
                        GRCollectionCache.integrationStats.toyBoxToys = GRCollectionCache.totalToys
                        
                        GRC.Debug.Info("Cache", "Toys built: %d total", GRCollectionCache.totalToys)
                        
                        -- Continue to finalize
                        finalizeBuild()
                    end
                    
                    -- Process toys in batches for better performance
                    local function processToyBatch(startIndex)
                        local endIndex = math.min(startIndex + BATCH_SIZE - 1, numToys)
                        
                        for i = startIndex, endIndex do
                            local toyID = C_ToyBox.GetToyFromIndex(i)
                            if toyID and toyID > 0 then
                                -- Get toy info from Blizzard API
                                local itemID, toyName, icon, isFavorite, hasFanfare, itemQuality = C_ToyBox.GetToyInfo(toyID)
                                
                                if toyName then
                                    -- Get additional item info
                                    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, 
                                          itemStackCount, itemEquipLoc, itemTexture, vendorPrice = GetItemInfo(toyID)
                                    
                                    local toy = {
                                        toyID = toyID,
                                        itemID = toyID,
                                        name = toyName,
                                        icon = icon or itemTexture,
                                        isCollected = PlayerHasToy(toyID),
                                        isFavorite = isFavorite or false,
                                        sourceText = "",
                                        description = "",
                                        itemType = itemType or "Miscellaneous",
                                        itemSubType = itemSubType or "Toy",
                                        quality = itemQuality or 1,
                                        expansion = GRC.SmartCache.GetBasicExpansion(toyID),
                                        category = GRC.SmartCache.GetBasicCategory("", nil, "toy"),
                                        dropRate = GRC.SmartCache.GetEnhancedDropRate("", nil, "toy"),
                                        isRarityTracked = false,
                                        rarityData = nil,
                                        attempts = 0,
                                        charactersTracked = 0,
                                        lastAttempt = nil,
                                        timeSpent = 0,
                                        sessionAttempts = 0,  -- FIXED: Add session tracking
                                        characterBreakdown = {},
                                        lockoutInfo = "Always Available",
                                        lockoutColor = "|cFFFFFFFF",
                                        lastUpdated = time(),
                                        source = "ToyBox API",
                                        itemType = "toy"
                                    }
                                    
                                    toys[toyID] = toy
                                end
                            end
                        end
                        
                        if endIndex < numToys then
                            C_Timer.After(YIELD_TIME, function()
                                processToyBatch(endIndex + 1)
                            end)
                        else
                            -- Finished processing ToyBox toys
                            finalizeToyProcessing()
                        end
                    end
                    
                    -- Start processing toys
                    processToyBatch(1)
                else
                    GRC.Debug.Warn("Cache", "No toys found in ToyBox API")
                    finalizeToyProcessing()
                end
            end)
        else
            GRC.Debug.Warn("Cache", "ToyBox API not available")
            
            -- Create empty toys cache
            toys["placeholder"] = {
                toyID = 0,
                itemID = 0,
                name = "ToyBox API not available",
                icon = nil,
                isCollected = false,
                isFavorite = false,
                sourceText = "ToyBox API functions not found",
                description = "Update your game client for toy collection tracking",
                itemType = "Information",
                itemSubType = "Placeholder",
                quality = 1,
                expansion = "N/A",
                category = "Information",
                dropRate = "N/A",
                isRarityTracked = false,
                rarityData = nil,
                attempts = 0,
                charactersTracked = 0,
                lastAttempt = nil,
                timeSpent = 0,
                sessionAttempts = 0,  -- FIXED: Add session tracking
                characterBreakdown = {},
                lockoutInfo = "N/A",
                lockoutColor = "|cFFCCCCCC",
                lastUpdated = time(),
                source = "Placeholder",
                itemType = "toy"
            }
            
            GRCollectionCache.toys = toys
            GRCollectionCache.totalToys = 0
            GRCollectionCache.integrationStats.toyBoxToys = 0
            
            finalizeBuild()
        end
    end
    
    finalizeBuild = function()
        GRC.Debug.Info("Cache", "Finalizing cache build...")
        
        -- Check if Rarity is available
        if GRC.RarityIntegration and GRC.RarityIntegration.IsAvailable() then
            enhanceWithRarity()
        else
            completeAsyncBuild()
        end
    end
    
    enhanceWithRarity = function()
        GRC.Debug.Info("Cache", "Enhancing with Rarity data...")
        GRCollectionCache.integrationStats.standaloneMode = false
        
        local mountKeys = {}
        for mountID in pairs(GRCollectionCache.mounts) do
            table.insert(mountKeys, mountID)
        end
        
        local function enhanceMountBatch(startIndex)
            local endIndex = math.min(startIndex + BATCH_SIZE - 1, #mountKeys)
            
            for i = startIndex, endIndex do
                local mountID = mountKeys[i]
                local mount = GRCollectionCache.mounts[mountID]
                
                if mount then
                    local rarityEnhancement = GRC.RarityIntegration.GetEnhancedMountData(
                        mount.name, mount.spellID, nil, mount.sourceText)
                    
                    if rarityEnhancement.isRarityTracked then
                        mount.isRarityTracked = true
                        mount.expansion = rarityEnhancement.expansion
                        mount.category = rarityEnhancement.category
                        mount.dropRate = rarityEnhancement.dropRate
                        mount.rarityData = rarityEnhancement.rarityData
                        mount.sourceInstance = rarityEnhancement.sourceInstance
                        mount.bossName = rarityEnhancement.bossName
                        mount.npcIDs = rarityEnhancement.npcIDs
                        mount.encounterIDs = rarityEnhancement.encounterIDs
                        mount.isBlackMarket = rarityEnhancement.isBlackMarket
                        mount.isRemoved = rarityEnhancement.isRemoved
                        mount.source = "Mount Journal + Rarity"
                        GRCollectionCache.integrationStats.rarityEnhanced = (GRCollectionCache.integrationStats.rarityEnhanced or 0) + 1
                        
                        -- ENHANCED: Update lockout info with Rarity data
                        if GRC.SimpleLockouts and GRC.SimpleLockouts.GetMountLockout then
                            mount.lockoutInfo, mount.lockoutColor = GRC.SimpleLockouts.GetMountLockout(mount)
                        end
                    else
                        mount.source = "Mount Journal (Rarity checked)"
                    end
                end
            end
            
            if endIndex < #mountKeys then
                C_Timer.After(YIELD_TIME, function()
                    enhanceMountBatch(endIndex + 1)
                end)
            else
                enhancePetsAndToys()
            end
        end
        
        enhanceMountBatch(1)
    end
    
    enhancePetsAndToys = function()
        -- Quick enhance pets
        for speciesID, pet in pairs(GRCollectionCache.pets) do
            local rarityEnhancement = GRC.RarityIntegration.GetEnhancedPetData(
                pet.name, pet.speciesID, pet.sourceText)
            
            if rarityEnhancement and rarityEnhancement.isRarityTracked then
                pet.isRarityTracked = true
                pet.expansion = rarityEnhancement.expansion
                pet.category = rarityEnhancement.category
                pet.dropRate = rarityEnhancement.dropRate
                pet.rarityData = rarityEnhancement.rarityData
                pet.source = "Pet Journal + Rarity"
            else
                pet.source = "Pet Journal (Rarity checked)"
            end
        end
        
        -- Enhanced toys are already processed during build
        for toyID, toy in pairs(GRCollectionCache.toys) do
            if not toy.isRarityTracked and toyID ~= "placeholder" then
                toy.source = "ToyBox API (Rarity checked)"
            end
        end
        
        completeAsyncBuild()
    end
    
    completeAsyncBuild = function()
        -- FIXED: Import attempt data and sync with live data
        if GRC.RarityDataImporter then
            GRC.RarityDataImporter.ImportAllAttempts()
            
            for mountID, mount in pairs(GRCollectionCache.mounts) do
                GRCollectionCache.mounts[mountID] = GRC.RarityDataImporter.EnhanceMount(mount)
            end
            
            for speciesID, pet in pairs(GRCollectionCache.pets) do
                GRCollectionCache.pets[speciesID] = GRC.RarityDataImporter.EnhancePet(pet)
            end
            
            for toyID, toy in pairs(GRCollectionCache.toys) do
                if toyID ~= "placeholder" then
                    GRCollectionCache.toys[toyID] = GRC.RarityDataImporter.EnhanceToy(toy)
                end
            end
        end
        
        -- CRITICAL: Mark as completed
        GRCollectionCache.lastUpdate = time()
        GRCollectionCache.version = 24  -- Updated version
        GRCollectionCache.isReady = true
        GRCollectionCache.firstLoadComplete = true
        GRCollectionCache.buildScheduled = false
        
        -- Load into memory cache
        LoadFromPersistentCache()
        
        GRC.Debug.Info("Cache", "Async build complete! Cache is now ready.")
        
        -- FIXED: Start automatic attempt data sync
        GRC.SmartCache.StartAttemptSyncTimer()
        
        -- Notify UI
        if GRC.UI and GRC.UI.RefreshUI then
            GRC.UI.RefreshUI()
        end
        
        -- Notify Core that we're ready
        if GRC.Core then
            GRC.Core.OnCacheReady()
        end
    end
    
    -- Start the build process
    buildMounts()
end

-- FIXED: Smart attempt sync timer - much longer intervals
function GRC.SmartCache.StartAttemptSyncTimer()
    if GRC.SmartCache.attemptSyncTimer then
        GRC.SmartCache.attemptSyncTimer:Cancel()
    end
    
    -- FIXED: Much longer sync interval, only for background maintenance
    GRC.SmartCache.attemptSyncTimer = C_Timer.NewTicker(60, function() -- Every 60 seconds instead of 3
        if CanUseExistingCache() then
            SyncAttemptDataFromRarity()
        end
    end)
    
    GRC.Debug.Info("Cache", "Background attempt sync timer started (60s interval)")
end

function GRC.SmartCache.StopAttemptSyncTimer()
    if GRC.SmartCache.attemptSyncTimer then
        GRC.SmartCache.attemptSyncTimer:Cancel()
        GRC.SmartCache.attemptSyncTimer = nil
    end
    
    GRC.Debug.Info("Cache", "Attempt sync timer stopped")
end

-- FIXED: Better public API with loading states
function GRC.SmartCache.IsReady()
    return CanUseExistingCache()
end

function GRC.SmartCache.IsBuilding()
    return IsCacheBuilding()
end

function GRC.SmartCache.GetAllMounts()
    if not CanUseExistingCache() then
        if IsCacheBuilding() then
            GRC.Debug.Info("Cache", "Mounts requested while building, returning empty array")
        end
        return {}
    end
    
    UpdateCollectionStatus()
    -- REMOVED: Don't sync attempt data on every request
    return memoryCache.mountsArray
end

function GRC.SmartCache.GetAllPets()
    if not CanUseExistingCache() then
        if IsCacheBuilding() then
            GRC.Debug.Info("Cache", "Pets requested while building, returning empty array")
        end
        return {}
    end
    
    UpdateCollectionStatus()
    -- REMOVED: Don't sync attempt data on every request
    return memoryCache.petsArray
end

function GRC.SmartCache.GetAllToys()
    if not CanUseExistingCache() then
        if IsCacheBuilding() then
            GRC.Debug.Info("Cache", "Toys requested while building, returning empty array")
        end
        return {}
    end
    
    UpdateCollectionStatus()
    -- REMOVED: Don't sync attempt data on every request
    return memoryCache.toysArray
end

-- ENHANCED: Better refresh with synchronized attempt data
function GRC.SmartCache.Refresh()
    GRC.Debug.Info("Cache", "Refresh requested")
    
    -- Don't refresh if we're currently building
    if IsCacheBuilding() then
        GRC.Debug.Info("Cache", "Refresh skipped - cache is currently building")
        return false
    end
    
    if CanUseExistingCache() then
        UpdateCollectionStatus()
        
        -- FIXED: Force sync attempt data immediately
        if GRC.RarityDataImporter and GRC.RarityDataImporter.RefreshAttemptData then
            GRC.RarityDataImporter.RefreshAttemptData()
        end
        
        SyncAttemptDataFromRarity()
        
        -- ENHANCED: Update lockout information for all mounts
        if GRC.SimpleLockouts and GRC.SimpleLockouts.GetMountLockout then
            for mountID, mount in pairs(memoryCache.mounts) do
                mount.lockoutInfo, mount.lockoutColor = GRC.SimpleLockouts.GetMountLockout(mount)
                
                -- Update in array cache too
                for i, arrayMount in ipairs(memoryCache.mountsArray) do
                    if arrayMount.mountID == mountID then
                        memoryCache.mountsArray[i] = mount
                        break
                    end
                end
            end
        end
        
        GRC.Debug.Info("Cache", "Fast refresh complete with synchronized attempt data")
        
        -- FIXED: Notify tracking bar of data changes
        if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
            C_Timer.After(0.1, function()
                GRC.TrackingBar.ForceRefresh()
            end)
        end
        
        return true
    else
        -- Full rebuild needed
        GRC.Debug.Info("Cache", "Full rebuild needed")
        AsyncBuildCache()
        return false
    end
end

-- FIXED: Enhanced callback for attempt updates
function GRC.SmartCache.OnAttemptAdded(itemType, itemID, newAttempts)
    if not memoryCache.isLoaded then
        return
    end
    
    GRC.Debug.Trace("Cache", "Attempt added: %s %s (%d)", itemType, tostring(itemID), newAttempts)
    
    -- Force immediate sync
    memoryCache.lastAttemptSync = 0
    SyncAttemptDataFromRarity()
    
    -- Notify tracking bar
    if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
        C_Timer.After(0.2, function()
            GRC.TrackingBar.ForceRefresh()
        end)
    end
end

-- FIXED: Enhanced callback for boss kills
function GRC.SmartCache.OnBossKill(npcID, encounterID)
    if not memoryCache.isLoaded then
        return
    end
    
    GRC.Debug.Trace("Cache", "Boss kill detected: NPC %s, Encounter %s", tostring(npcID), tostring(encounterID))
    
    -- Delay sync to allow Rarity to process first
    C_Timer.After(1, function()
        memoryCache.lastAttemptSync = 0
        SyncAttemptDataFromRarity()
        
        -- Notify tracking bar
        if GRC.TrackingBar and GRC.TrackingBar.ForceRefresh then
            GRC.TrackingBar.ForceRefresh()
        end
    end)
end

-- Basic categorization functions
function GRC.SmartCache.GetBasicExpansion(itemID)
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

function GRC.SmartCache.GetBasicCategory(sourceText, sourceType, itemType, petData)
    if sourceType then
        local sourceTypeMap = {
            [1] = "Drop", [2] = "Quest", [3] = "Vendor", [4] = "Profession",
            [5] = "Achievement", [6] = "Reputation", [7] = "World Event",
            [8] = "Promotion", [9] = "Trading Card Game", [10] = "Store", [11] = "Trading Post"
        }
        if sourceTypeMap[sourceType] then
            return sourceTypeMap[sourceType]
        end
    end
    
    if itemType == "pet" then
        if petData then
            if petData.isWild then
                return "Wild Pet"
            end
            if petData.canBattle and not petData.isWild then
                return "Pet Battle Reward"
            end
        end
        
        if sourceText then
            local lowerText = sourceText:lower()
            
            if lowerText:find("wild") or lowerText:find("caught") or lowerText:find("captured") then
                return "Wild Pet"
            elseif lowerText:find("pet battle") or lowerText:find("battle pet") then
                return "Pet Battle"
            elseif lowerText:find("trainer") or lowerText:find("tamer") then
                return "Pet Battle Trainer"
            elseif lowerText:find("garrison") then
                return "Garrison"
            elseif lowerText:find("profession") or lowerText:find("fishing") or lowerText:find("archaeology") then
                return "Profession"
            elseif lowerText:find("dungeon") or lowerText:find("raid") or lowerText:find("boss") then
                return "Dungeon/Raid Drop"
            elseif lowerText:find("world quest") or lowerText:find("daily") then
                return "World Quest"
            elseif lowerText:find("vendor") or lowerText:find("purchase") or lowerText:find("buy") then
                return "Vendor"
            elseif lowerText:find("achievement") then
                return "Achievement"
            elseif lowerText:find("promotion") or lowerText:find("collector") then
                return "Promotion"
            elseif lowerText:find("tcg") or lowerText:find("trading card") then
                return "Trading Card Game"
            elseif lowerText:find("store") or lowerText:find("shop") then
                return "Store"
            end
        end
        
        if not sourceText or sourceText == "" then
            return "Wild Pet"
        end
    elseif itemType == "toy" then
        -- Enhanced toy categorization
        if sourceText and sourceText ~= "" then
            local lowerText = sourceText:lower()
            
            if lowerText:find("raid") or lowerText:find("boss") then
                return "Raid Drop"
            elseif lowerText:find("dungeon") then
                return "Dungeon Drop"
            elseif lowerText:find("achievement") then
                return "Achievement"
            elseif lowerText:find("vendor") or lowerText:find("purchase") then
                return "Vendor"
            elseif lowerText:find("quest") then
                return "Quest"
            elseif lowerText:find("world event") or lowerText:find("holiday") then
                return "World Event"
            elseif lowerText:find("trading post") then
                return "Trading Post"
            elseif lowerText:find("profession") then
                return "Profession"
            elseif lowerText:find("pvp") then
                return "PvP"
            elseif lowerText:find("store") then
                return "Store"
            end
        end
        
        return "Toy"
    end
    
    if not sourceText then return "Unknown" end
    local lowerText = sourceText:lower()
    
    local patterns = {
        {patterns = {"achievement", "glory", "cutting edge"}, category = "Achievement"},
        {patterns = {"vendor", "purchased", "reputation"}, category = "Vendor"},
        {patterns = {"quest", "campaign"}, category = "Quest"},
        {patterns = {"drop", "loot", "boss", "dungeon", "raid"}, category = "Drop"},
        {patterns = {"trading post"}, category = "Trading Post"},
        {patterns = {"pvp", "gladiator"}, category = "PvP"},
        {patterns = {"profession", "crafted"}, category = "Profession"},
        {patterns = {"world event", "holiday"}, category = "World Event"},
        {patterns = {"store", "shop"}, category = "Store"},
        {patterns = {"wild", "battle pet"}, category = "Battle Pet"},
        {patterns = {"toy"}, category = "Toy"}
    }
    
    for _, patternGroup in ipairs(patterns) do
        for _, pattern in ipairs(patternGroup.patterns) do
            if lowerText:find(pattern) then
                return patternGroup.category
            end
        end
    end
    
    return "Unknown"
end

-- FIXED: Drop rate logic for toys and other items
function GRC.SmartCache.GetEnhancedDropRate(sourceText, sourceType, itemType, extraData)
    -- For pets - special handling for wild pets
    if itemType == "pet" then
        if extraData and extraData.isWild then
            return "100%" -- Wild pets can be caught
        end
        
        if sourceText then
            local lowerText = sourceText:lower()
            if lowerText:find("wild") or lowerText:find("caught") or lowerText:find("captured") then
                return "100%" -- Wild pets
            end
        end
        
        return "100%"
    end
    
    -- For mounts from Mount Journal
    if itemType == "mount" then
        return "100%"
    end
    
    -- For toys - everything is 100% unless Rarity provides different data
    if itemType == "toy" then
        return "100%"
    end
    
    -- Source type based - all are 100% through their method
    if sourceType then
        return "100%"
    end
    
    return "100%"
end

function GRC.SmartCache.GetBasicLockout(sourceText, sourceType)
    if sourceType == 1 then
        if sourceText and sourceText:lower():find("raid") then return "Weekly Reset"
        elseif sourceText and sourceText:lower():find("dungeon") then return "Daily Reset"
        else return "Unknown" end
    elseif sourceType == 7 then return "Seasonal"
    elseif sourceType == 11 then return "Monthly"
    else return "N/A" end
end

function GRC.SmartCache.GetStats()
    local stats = {
        totalMounts = GRCollectionCache.totalMounts or 0,
        totalPets = GRCollectionCache.totalPets or 0,
        totalToys = GRCollectionCache.totalToys or 0,
        collectedMounts = 0,
        collectedPets = 0,
        collectedToys = 0,
        lastUpdate = GRCollectionCache.lastUpdate,
        isBuilding = IsCacheBuilding(),
        isReady = CanUseExistingCache(),
        firstLoadComplete = GRCollectionCache.firstLoadComplete,
        rarityIntegration = GRC.RarityIntegration and GRC.RarityIntegration.IsAvailable() and "Available" or "Not Available",
        importerIntegration = GRC.RarityDataImporter and "Available" or "Not Available",
        integrationStats = GRCollectionCache.integrationStats,
        standaloneMode = GRCollectionCache.integrationStats.standaloneMode,
        memoryLoaded = memoryCache.isLoaded,
        lastAttemptSync = memoryCache.lastAttemptSync,  -- FIXED: Add sync status
        attemptSyncActive = GRC.SmartCache.attemptSyncTimer ~= nil
    }
    
    if memoryCache.isLoaded then
        for mountID, mountData in pairs(memoryCache.mounts) do
            if mountData.isCollected then stats.collectedMounts = stats.collectedMounts + 1 end
        end
        
        for speciesID, petData in pairs(memoryCache.pets) do
            if petData.isCollected then stats.collectedPets = stats.collectedPets + 1 end
        end
        
        for toyID, toyData in pairs(memoryCache.toys) do
            if toyID ~= "placeholder" and toyData.isCollected then stats.collectedToys = stats.collectedToys + 1 end
        end
    end
    
    return stats
end

function GRC.SmartCache.GetAvailableExpansions()
    local expansions = {}
    local expansionSet = {}
    
    if not CanUseExistingCache() then return {} end
    
    local allItems = {}
    for _, mount in pairs(memoryCache.mounts) do
        table.insert(allItems, mount)
    end
    for _, pet in pairs(memoryCache.pets) do
        table.insert(allItems, pet)
    end
    for _, toy in pairs(memoryCache.toys) do
        if toy.toyID and toy.toyID > 0 then
            table.insert(allItems, toy)
        end
    end
    
    for _, item in ipairs(allItems) do
        if item.expansion and item.expansion ~= "Unknown" then
            if not expansionSet[item.expansion] then
                expansionSet[item.expansion] = true
                table.insert(expansions, item.expansion)
            end
        end
    end
    
    local expansionOrder = {
        "Classic", "The Burning Crusade", "Wrath of the Lich King", "Cataclysm",
        "Mists of Pandaria", "Warlords of Draenor", "Legion", "Battle for Azeroth",
        "Shadowlands", "Dragonflight", "The War Within"
    }
    
    local sortedExpansions = {}
    for _, expName in ipairs(expansionOrder) do
        if expansionSet[expName] then
            table.insert(sortedExpansions, expName)
        end
    end
    
    for _, expansion in ipairs(expansions) do
        local found = false
        for _, sorted in ipairs(sortedExpansions) do
            if sorted == expansion then
                found = true
                break
            end
        end
        if not found then
            table.insert(sortedExpansions, expansion)
        end
    end
    
    return sortedExpansions
end

function GRC.SmartCache.GetAvailableCategories()
    local categories = {}
    local categorySet = {}
    
    if not CanUseExistingCache() then return {} end
    
    local allItems = {}
    for _, mount in pairs(memoryCache.mounts) do
        table.insert(allItems, mount)
    end
    for _, pet in pairs(memoryCache.pets) do
        table.insert(allItems, pet)
    end
    for _, toy in pairs(memoryCache.toys) do
        if toy.toyID and toy.toyID > 0 then
            table.insert(allItems, toy)
        end
    end
    
    for _, item in ipairs(allItems) do
        if item.category and item.category ~= "Unknown" then
            if not categorySet[item.category] then
                categorySet[item.category] = true
                table.insert(categories, item.category)
            end
        end
    end
    
    table.sort(categories)
    return categories
end

-- Utility
GRC.Utils = GRC.Utils or {}
function GRC.Utils.TableCount(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- FIXED: Better initialization with proper timing and attempt sync
local function InitializeCache()
    GRC.Debug.Info("Cache", "Initializing cache system...")
    
    -- Reset build state on new session if needed
    if not GRCollectionCache.firstLoadComplete then
        GRCollectionCache.buildScheduled = false
        GRCollectionCache.isReady = false
    end
    
    -- Try to load from existing cache first
    if GRCollectionCache.firstLoadComplete and GRCollectionCache.version >= 21 and LoadFromPersistentCache() then
        GRC.Debug.Info("Cache", "Using existing cache data")
        
        UpdateCollectionStatus()
        
        -- FIXED: Start attempt sync timer for existing cache
        GRC.SmartCache.StartAttemptSyncTimer()
        
        -- Initial attempt sync
        C_Timer.After(2, function()
            if GRC.RarityDataImporter then
                GRC.RarityDataImporter.ImportAllAttempts()
                SyncAttemptDataFromRarity()
            end
        end)
        
        return
    end
    
    -- Need to build from scratch
    if not GRCollectionCache.buildScheduled then
        GRCollectionCache.buildScheduled = true
        GRC.Debug.Info("Cache", "Building cache from scratch...")
        
        -- Give WoW APIs time to be ready
        C_Timer.After(5, function()
            AsyncBuildCache()
        end)
    end
end

-- FIXED: Enhanced event handling for boss kills and attempts
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("BOSS_KILL")
frame:RegisterEvent("LOOT_CLOSED")
frame:RegisterEvent("NEW_MOUNT_ADDED")
frame:RegisterEvent("NEW_PET_ADDED")
frame:RegisterEvent("NEW_TOY_ADDED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and select(1, ...) == addonName then
        C_Timer.After(3, InitializeCache)
        
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("encounter_end", {
            encounterID = encounterID,
            encounterName = encounterName,
            success = success == 1
        }) then
            GRC.Debug.Trace("Cache", "Encounter completed: %s (%d)", encounterName, encounterID)
            GRC.SmartCache.OnBossKill(nil, encounterID)
        end
        
    elseif event == "BOSS_KILL" then
        local id, name = ...
        
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("boss_kill", {
            npcID = id,
            npcName = name
        }) then
            GRC.Debug.Trace("Cache", "Boss killed: %s", name)
            GRC.SmartCache.OnBossKill(id, nil)
        end
        
    elseif event == "LOOT_CLOSED" then
        if GRC.EventHandlers and GRC.EventHandlers.ShouldRefresh("loot", {
            eventType = "loot_closed"
        }) then
            C_Timer.After(1, function()
                if memoryCache.isLoaded then
                    memoryCache.lastAttemptSync = 0
                    SyncAttemptDataFromRarity()
                end
            end)
        end
        
    elseif event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        GRC.Debug.Trace("Cache", "New mount added: %s", tostring(mountID))
        UpdateCollectionStatus()
        
    elseif event == "NEW_PET_ADDED" then
        local petID = ...
        GRC.Debug.Trace("Cache", "New pet added: %s", tostring(petID))
        UpdateCollectionStatus()
        
    elseif event == "NEW_TOY_ADDED" then
        local toyID = ...
        GRC.Debug.Trace("Cache", "New toy added: %s", tostring(toyID))
        UpdateCollectionStatus()
    end
end)

-- FIXED: Cleanup function
function GRC.SmartCache.Cleanup()
    GRC.SmartCache.StopAttemptSyncTimer()
    memoryCache.isLoaded = false
    GRC.Debug.Info("Cache", "Cache system cleaned up")
end

-- FIXED: Public API for external integration
function GRC.SmartCache.ForceAttemptSync()
    memoryCache.lastAttemptSync = 0
    return SyncAttemptDataFromRarity()
end

function GRC.SmartCache.GetAttemptSyncStatus()
    return {
        lastSync = memoryCache.lastAttemptSync,
        syncActive = GRC.SmartCache.attemptSyncTimer ~= nil,
        syncInterval = ATTEMPT_SYNC_INTERVAL
    }
end

GRC.Debug.Info("Cache", "FIXED SmartCache with attempt synchronization and tracking bar integration loaded")

return GRC.SmartCache