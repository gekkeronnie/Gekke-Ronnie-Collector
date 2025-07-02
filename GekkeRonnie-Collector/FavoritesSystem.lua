-- FavoritesSystem.lua - Account-Wide Standalone Favorites Management System
local addonName, GRC = ...
GRC.Favorites = GRC.Favorites or {}

-- Account-wide favorites storage (persists across all characters)
GRCollectorFavoritesGlobal = GRCollectorFavoritesGlobal or {
    mounts = {},
    pets = {},
    toys = {},
    version = 1,
    trackingPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -200
    }
}

-- Ensure the global variable is properly initialized
local function InitializeFavoritesGlobal()
    if not GRCollectorFavoritesGlobal then
        GRCollectorFavoritesGlobal = {
            mounts = {},
            pets = {},
            toys = {},
            version = 1,
            trackingPosition = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = -200
            }
        }
    end
    
    -- Ensure all required fields exist
    if not GRCollectorFavoritesGlobal.mounts then GRCollectorFavoritesGlobal.mounts = {} end
    if not GRCollectorFavoritesGlobal.pets then GRCollectorFavoritesGlobal.pets = {} end
    if not GRCollectorFavoritesGlobal.toys then GRCollectorFavoritesGlobal.toys = {} end
    if not GRCollectorFavoritesGlobal.trackingPosition then 
        GRCollectorFavoritesGlobal.trackingPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = -200
        }
    end
    if not GRCollectorFavoritesGlobal.version then GRCollectorFavoritesGlobal.version = 1 end
end

-- Constants
local MAX_FAVORITES_PER_TYPE = 10
local STAR_ICON = "Interface\\Common\\FavoritesIcon"
local EMPTY_STAR_ICON = "Interface\\Common\\ReputationStar"

-- Make MAX_FAVORITES_PER_TYPE accessible to other modules
GRC.Favorites.MAX_FAVORITES_PER_TYPE = MAX_FAVORITES_PER_TYPE

-- Check if an item is favorited
function GRC.Favorites.IsFavorited(itemID, itemType)
    if not itemID or not itemType then return false end
    
    InitializeFavoritesGlobal() -- Ensure initialization
    
    local favorites = GRCollectorFavoritesGlobal[itemType .. "s"]
    if not favorites then return false end
    
    for _, favID in ipairs(favorites) do
        if favID == itemID then
            return true
        end
    end
    
    return false
end

-- Add item to favorites
function GRC.Favorites.AddFavorite(itemID, itemType, itemName)
    if not itemID or not itemType then return false end
    
    InitializeFavoritesGlobal() -- Ensure initialization
    
    local favorites = GRCollectorFavoritesGlobal[itemType .. "s"]
    if not favorites then return false end
    
    -- Check if already favorited
    if GRC.Favorites.IsFavorited(itemID, itemType) then
        return true
    end
    
    -- Check if we're at the limit
    if #favorites >= MAX_FAVORITES_PER_TYPE then
        print(string.format("|cFFFF6B35GRC:|r Cannot add favorite - maximum %d %s favorites reached", 
              MAX_FAVORITES_PER_TYPE, itemType))
        return false
    end
    
    -- Add to favorites
    table.insert(favorites, itemID)
    
    print(string.format("|cFFFF6B35GRC:|r ⭐ Added '%s' to %s favorites (%d/%d)", 
          itemName or "Unknown", itemType, #favorites, MAX_FAVORITES_PER_TYPE))
    
    -- Force save
    GRC.Debug.Info("Favorites", "Added favorite %s (%s), total: %d", itemName or "Unknown", itemType, #favorites)
    
    -- Update tracking bar
    GRC.Favorites.UpdateTrackingBar()
    
    return true
end

-- Remove item from favorites
function GRC.Favorites.RemoveFavorite(itemID, itemType, itemName)
    if not itemID or not itemType then return false end
    
    InitializeFavoritesGlobal() -- Ensure initialization
    
    local favorites = GRCollectorFavoritesGlobal[itemType .. "s"]
    if not favorites then return false end
    
    -- Find and remove
    for i, favID in ipairs(favorites) do
        if favID == itemID then
            table.remove(favorites, i)
            
            print(string.format("|cFFFF6B35GRC:|r ☆ Removed '%s' from %s favorites (%d/%d)", 
                  itemName or "Unknown", itemType, #favorites, MAX_FAVORITES_PER_TYPE))
            
            -- Force save
            GRC.Debug.Info("Favorites", "Removed favorite %s (%s), total: %d", itemName or "Unknown", itemType, #favorites)
            
            -- Update tracking bar
            GRC.Favorites.UpdateTrackingBar()
            
            return true
        end
    end
    
    return false
end

-- Toggle favorite status
function GRC.Favorites.ToggleFavorite(itemID, itemType, itemName)
    if GRC.Favorites.IsFavorited(itemID, itemType) then
        return GRC.Favorites.RemoveFavorite(itemID, itemType, itemName)
    else
        return GRC.Favorites.AddFavorite(itemID, itemType, itemName)
    end
end

-- Get all favorites for a type
function GRC.Favorites.GetFavorites(itemType)
    InitializeFavoritesGlobal() -- Ensure initialization
    
    local favorites = GRCollectorFavoritesGlobal[itemType .. "s"]
    if not favorites then return {} end
    
    return favorites
end

-- Get favorite items with full data
function GRC.Favorites.GetFavoriteItems(itemType)
    local favoriteIDs = GRC.Favorites.GetFavorites(itemType)
    local favoriteItems = {}
    
    if not GRC.SmartCache or not GRC.SmartCache.IsReady() then
        return favoriteItems
    end
    
    -- Get all items of this type
    local allItems = {}
    if itemType == "mount" then
        allItems = GRC.SmartCache.GetAllMounts()
    elseif itemType == "pet" then
        allItems = GRC.SmartCache.GetAllPets()
    elseif itemType == "toy" then
        allItems = GRC.SmartCache.GetAllToys()
    end
    
    -- Find favorite items
    for _, item in ipairs(allItems) do
        local itemID = nil
        if itemType == "mount" then
            itemID = item.spellID
        elseif itemType == "pet" then
            itemID = item.speciesID
        elseif itemType == "toy" then
            itemID = item.toyID
        end
        
        if itemID and GRC.Favorites.IsFavorited(itemID, itemType) then
            table.insert(favoriteItems, item)
        end
    end
    
    return favoriteItems
end

-- Get favorites statistics
function GRC.Favorites.GetStatistics()
    local stats = {
        mounts = {
            total = #GRCollectorFavoritesGlobal.mounts,
            max = MAX_FAVORITES_PER_TYPE,
            collected = 0,
            uncollected = 0,
            totalAttempts = 0
        },
        pets = {
            total = #GRCollectorFavoritesGlobal.pets,
            max = MAX_FAVORITES_PER_TYPE,
            collected = 0,
            uncollected = 0,
            totalAttempts = 0
        },
        toys = {
            total = #GRCollectorFavoritesGlobal.toys,
            max = MAX_FAVORITES_PER_TYPE,
            collected = 0,
            uncollected = 0,
            totalAttempts = 0
        }
    }
    
    -- Calculate detailed stats
    local itemTypes = {"mount", "pet", "toy"}
    for _, itemType in ipairs(itemTypes) do
        local favoriteItems = GRC.Favorites.GetFavoriteItems(itemType)
        
        for _, item in ipairs(favoriteItems) do
            if item.isCollected then
                stats[itemType .. "s"].collected = stats[itemType .. "s"].collected + 1
            else
                stats[itemType .. "s"].uncollected = stats[itemType .. "s"].uncollected + 1
            end
            
            stats[itemType .. "s"].totalAttempts = stats[itemType .. "s"].totalAttempts + (item.attempts or 0)
        end
    end
    
    return stats
end

-- Create star texture for UI
function GRC.Favorites.CreateStarTexture(parent, isFavorited)
    if not parent then return nil end
    
    local star = parent:CreateTexture(nil, "OVERLAY")
    star:SetSize(16, 16)
    
    if isFavorited then
        star:SetTexture(STAR_ICON)
        star:SetVertexColor(1, 0.84, 0, 1) -- Gold color
    else
        star:SetTexture(EMPTY_STAR_ICON)
        star:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- Gray color
    end
    
    return star
end

-- Update tracking bar with current favorites
function GRC.Favorites.UpdateTrackingBar()
    if not GRC.TrackingBar then
        return
    end
    
    GRC.TrackingBar.RefreshData()
end

-- Clear all favorites (for reset)
function GRC.Favorites.ClearAllFavorites()
    GRCollectorFavoritesGlobal.mounts = {}
    GRCollectorFavoritesGlobal.pets = {}
    GRCollectorFavoritesGlobal.toys = {}
    
    print("|cFFFF6B35GRC:|r All favorites cleared")
    
    GRC.Favorites.UpdateTrackingBar()
end

-- Save tracking bar position (account-wide)
function GRC.Favorites.SaveTrackingPosition(point, relativePoint, x, y)
    InitializeFavoritesGlobal() -- Ensure initialization
    
    GRCollectorFavoritesGlobal.trackingPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }
    
    GRC.Debug.Info("Favorites", "Saved tracking position: %s %d,%d", point, x, y)
end

-- Get tracking bar position (account-wide)
function GRC.Favorites.GetTrackingPosition()
    InitializeFavoritesGlobal() -- Ensure initialization
    
    return GRCollectorFavoritesGlobal.trackingPosition or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -200
    }
end

-- Debug function
function GRC.Favorites.Debug()
    print("|cFFFF6B35GRC Favorites Debug:|r")
    
    local stats = GRC.Favorites.GetStatistics()
    
    for itemType, data in pairs(stats) do
        print(string.format("  %s: %d/%d favorites (%d collected, %d missing, %d total attempts)", 
              itemType:gsub("^%l", string.upper), data.total, data.max, 
              data.collected, data.uncollected, data.totalAttempts))
        
        -- Show actual favorites
        local favoriteItems = GRC.Favorites.GetFavoriteItems(itemType:sub(1, -2)) -- Remove 's'
        for i, item in ipairs(favoriteItems) do
            if i <= 3 then -- Show first 3
                local status = item.isCollected and "✓" or "✗"
                local attempts = item.attempts and (" (" .. item.attempts .. " attempts)") or ""
                print(string.format("    %s %s%s", status, item.name, attempts))
            end
        end
        
        if #favoriteItems > 3 then
            print(string.format("    ... and %d more", #favoriteItems - 3))
        end
    end
end

-- Slash commands
SLASH_GRC_FAVORITES1 = "/grc-favorites"
SlashCmdList["GRC_FAVORITES"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local command = args[1] and args[1]:lower() or ""
    
    if command == "stats" or command == "" then
        GRC.Favorites.Debug()
    elseif command == "clear" then
        GRC.Favorites.ClearAllFavorites()
    elseif command == "list" then
        local itemType = args[2] and args[2]:lower() or ""
        
        if itemType == "mount" or itemType == "pet" or itemType == "toy" then
            local favoriteItems = GRC.Favorites.GetFavoriteItems(itemType)
            if #favoriteItems > 0 then
                print(string.format("|cFFFF6B35GRC:|r %s favorites (%d):", itemType:gsub("^%l", string.upper), #favoriteItems))
                for _, item in ipairs(favoriteItems) do
                    local status = item.isCollected and "|cFF00FF00✓|r" or "|cFFFF0000✗|r"
                    local attempts = item.attempts and item.attempts > 0 and (" (" .. item.attempts .. " attempts)") or ""
                    print(string.format("  %s %s%s", status, item.name, attempts))
                end
            else
                print(string.format("|cFFFF6B35GRC:|r No %s favorites found", itemType))
            end
        else
            print("|cFFFF6B35GRC:|r Usage: /grc-favorites list <mount|pet|toy>")
        end
    elseif command == "help" then
        print("|cFFFF6B35GRC Favorites:|r Commands:")
        print("  /grc-favorites - Show favorites statistics")
        print("  /grc-favorites list <type> - List favorites by type")
        print("  /grc-favorites clear - Clear all favorites")
        print("  /grc-favorites debug - Show saved variable status")
        print("  Use the ★ column in GUI to add/remove favorites")
        print("  Current limits: " .. MAX_FAVORITES_PER_TYPE .. " per category")
    elseif command == "debug" then
        InitializeFavoritesGlobal()
        print("|cFFFF6B35GRC Favorites Debug:|r")
        print("  GRCollectorFavoritesGlobal exists: " .. tostring(GRCollectorFavoritesGlobal ~= nil))
        if GRCollectorFavoritesGlobal then
            print("  Mounts: " .. #GRCollectorFavoritesGlobal.mounts)
            print("  Pets: " .. #GRCollectorFavoritesGlobal.pets)
            print("  Toys: " .. #GRCollectorFavoritesGlobal.toys)
            if GRCollectorFavoritesGlobal.trackingPosition then
                local pos = GRCollectorFavoritesGlobal.trackingPosition
                print(string.format("  Position: %s %d,%d", pos.point or "nil", pos.x or 0, pos.y or 0))
            else
                print("  Position: not saved")
            end
        end
    else
        print("|cFFFF6B35GRC Favorites:|r Commands:")
        print("  /grc-favorites - Show favorites statistics")
        print("  /grc-favorites list <mount|pet|toy> - List favorites by type")
        print("  /grc-favorites clear - Clear all favorites")
        print("  /grc-favorites debug - Show saved variable status")
        print("  /grc-favorites help - Show help")
        print("  Use the ★ column in the main interface to manage favorites")
        print("  Current limits: " .. MAX_FAVORITES_PER_TYPE .. " per category")
    end
end

GRC.Debug.Info("Favorites", "Standalone favorites system loaded - max %d per type", MAX_FAVORITES_PER_TYPE)

-- Initialize when addon loads
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        -- Initialize the global favorites immediately
        InitializeFavoritesGlobal()
        GRC.Debug.Info("Favorites", "Initialized account-wide favorites on addon load")
        
    elseif event == "PLAYER_LOGIN" then
        -- Double-check initialization after login
        InitializeFavoritesGlobal()
        
        local stats = GRC.Favorites.GetStatistics()
        local totalFavorites = stats.mounts.total + stats.pets.total + stats.toys.total
        if totalFavorites > 0 then
            GRC.Debug.Info("Favorites", "Loaded %d account-wide favorites (%d mounts, %d pets, %d toys)", 
                          totalFavorites, stats.mounts.total, stats.pets.total, stats.toys.total)
        end
    end
end)

return GRC.Favorites