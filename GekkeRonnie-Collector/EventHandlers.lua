-- EventHandlers.lua - Simplified Universal Event Management (No Zone Restrictions)
local addonName, GRC = ...
GRC.EventHandlers = GRC.EventHandlers or {}

-- No pattern matching needed - let all loot through and let the data systems decide
-- No throttling intervals - we don't want to miss any potential collectible data

-- Basic player state
local playerState = {
    inInstance = false,
    instanceType = nil,
    zoneName = ""
}

-- Update player state
local function UpdatePlayerState()
    local inInstance, instanceType = IsInInstance()
    playerState.inInstance = inInstance
    playerState.instanceType = instanceType
    playerState.zoneName = GetZoneText() or ""
end

-- No loot filtering - let all player loot trigger refreshes
local function IsPlayerLoot(lootText, playerName)
    if not playerName then return false end
    -- Only check our own loot
    return playerName == UnitName("player")
end

-- Simple refresh logic - no throttling, let all relevant events through
local function ShouldTriggerRefresh(eventType, context)
    -- Update player state
    UpdatePlayerState()
    
    -- Simple logic based on event type (NO THROTTLING - we want all data)
    if eventType == "boss_kill" then
        return true -- All boss kills
        
    elseif eventType == "encounter_end" then
        return context and context.success -- All successful encounters
        
    elseif eventType == "loot" then
        return context and IsPlayerLoot(context.lootText, context.playerName) -- All our loot
        
    elseif eventType == "achievement" then
        return context and context.achievementID -- All achievements
        
    elseif eventType == "collection_update" then
        return true -- Always allow direct collection updates
        
    elseif eventType == "fishing" then
        return true -- All fishing
        
    elseif eventType == "treasure" then
        return true -- All treasures
        
    elseif eventType == "rare_spawn" then
        return true -- All rare spawns
        
    elseif eventType == "world_quest_complete" then
        return true -- All world quest completions
    end
    
    return false
end

-- Public API
function GRC.EventHandlers.ShouldRefresh(eventType, context)
    local should = ShouldTriggerRefresh(eventType, context)
    
    if should then
        GRC.Debug.Info("EventHandlers", "Refresh triggered: %s (zone: %s, instance: %s)", 
                       eventType, playerState.zoneName, tostring(playerState.inInstance))
    else
        GRC.Debug.Trace("EventHandlers", "Refresh filtered: %s (zone: %s, instance: %s)", 
                        eventType, playerState.zoneName, tostring(playerState.inInstance))
    end
    
    return should
end

-- Get current filtering stats
function GRC.EventHandlers.GetStats()
    return {
        playerState = playerState,
        throttling = false, -- No longer using throttling
        zoneRestrictions = false, -- No longer using zone restrictions
        lootPatterns = false, -- No longer using loot patterns
        universalFiltering = true,
        philosophy = "Let all relevant events through - better to refresh more than miss data"
    }
end

function GRC.EventHandlers.CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- Show debug info about filtering
function GRC.EventHandlers.ShowDebugInfo()
    print("|cFFFF6B35GRC Event Filter Debug:|r")
    
    local stats = GRC.EventHandlers.GetStats()
    print(string.format("  Throttling: %s", tostring(stats.throttling)))
    print(string.format("  Zone restrictions: %s", tostring(stats.zoneRestrictions)))
    print(string.format("  Loot patterns: %s", tostring(stats.lootPatterns)))
    print(string.format("  Universal filtering: %s", tostring(stats.universalFiltering)))
    print(string.format("  Philosophy: %s", stats.philosophy))
    
    print("  Current state:")
    print(string.format("    Zone: %s", stats.playerState.zoneName))
    print(string.format("    In instance: %s (%s)", 
          tostring(stats.playerState.inInstance), 
          stats.playerState.instanceType or "none"))
    
    print("  Supported events (all trigger refreshes):")
    print("    - Boss kills (anywhere)")
    print("    - Encounters (anywhere)")
    print("    - Player loot (anywhere)")
    print("    - Achievements (anywhere)")
    print("    - Collection updates (anywhere)")
    print("    - Fishing (anywhere)")
    print("    - Treasures (anywhere)")
    print("    - Rare spawns (anywhere)")
    print("    - World quests (anywhere)")
end

-- Force refresh (no throttling to bypass)
function GRC.EventHandlers.ForceRefresh(eventType, context)
    return GRC.EventHandlers.ShouldRefresh(eventType, context)
end

-- No throttling to reset
function GRC.EventHandlers.ResetThrottling()
    print("|cFFFF6B35GRC:|r No throttling active - all events pass through")
end

-- Initialize with current state
UpdatePlayerState()

GRC.Debug.Info("EventHandlers", "Minimal universal event filtering system loaded (no restrictions, no throttling)")

return GRC.EventHandlers