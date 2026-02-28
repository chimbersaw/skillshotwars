-- Borrowed from here: https://github.com/OpenAngelArena/oaa/blob/57cda64a88fa730b55ccc14158c22deb4ea4a37d/game/scripts/vscripts/components/runes/custom_rune_system.lua

CustomRuneSystem = CustomRuneSystem or class({})

function CustomRuneSystem:Init()
    self.moduleName = "CustomRuneSystem"

    if USE_DEFAULT_RUNE_SYSTEM == true then
        return
    end

    local hidden_point = Vector(-10000, -10000, -10000)

    -- Power-up Runes
    local powerup_rune_spawners = Entities:FindAllByClassname("dota_item_rune_spawner_powerup") -- vanilla power-up spawners
    --local powerup_rune_spawners = Entities:FindAllByName("custom_powerup_rune_spot") -- Map needs an entity with this name
    self.powerup_rune_locations = {}

    -- Remove power-up rune spawner entities
    for i = 1, #powerup_rune_spawners do
        self.powerup_rune_locations[i] = powerup_rune_spawners[i]:GetAbsOrigin()
        -- Hide the vanilla spawner
        powerup_rune_spawners[i]:SetOrigin(hidden_point)
        --powerup_rune_spawners[i]:RemoveSelf() -- crashes, don't use it
    end

    DebugPrint("[BAREBONES] Powerup rune locations:")
    PrintTable(self.powerup_rune_locations)

    Timers:CreateTimer(PRE_GAME_TIME + FIRST_POWER_RUNE_SPAWN_TIME, function()
        CustomRuneSystem:SpawnRunes("powerup")
    end)

    self.power_runes_enums = {
        DOTA_RUNE_DOUBLEDAMAGE,
        DOTA_RUNE_HASTE,
        DOTA_RUNE_ILLUSION,
        DOTA_RUNE_INVISIBILITY,
        DOTA_RUNE_REGENERATION,
        DOTA_RUNE_ARCANE,
        --DOTA_RUNE_SHIELD,
        --DOTA_RUNE_WATER,
    }

    ---- Bounty Runes
    --local bounty_rune_spawners = Entities:FindAllByClassname("dota_item_rune_spawner_bounty") -- vanilla bounty rune spawners
    ----local bounty_rune_spawners = Entities:FindAllByName("custom_bounty_rune_spot") -- Map needs an entity with this name
    --self.bounty_rune_locations = {}
    --
    ---- Remove bounty rune spawner entities
    --for i = 1, #bounty_rune_spawners do
    --    self.bounty_rune_locations[i] = bounty_rune_spawners[i]:GetAbsOrigin()
    --    -- Hide the vanilla spawner
    --    bounty_rune_spawners[i]:SetOrigin(hidden_point)
    --end
    --
    --if HudTimer then
    --    HudTimer:At(FIRST_BOUNTY_RUNE_SPAWN_TIME, function()
    --        CustomRuneSystem:SpawnRunes("bounty")
    --    end)
    --else
    --    Timers:CreateTimer(FIRST_BOUNTY_RUNE_SPAWN_TIME + PREGAME_TIME, function()
    --        CustomRuneSystem:SpawnRunes("bounty")
    --    end)
    --end
end

function CustomRuneSystem:SpawnRunes(rune_type)
    local rune_locations = {}
    local spawn_interval = 60
    if rune_type == "bounty" then
        rune_locations = self.bounty_rune_locations
        spawn_interval = BOUNTY_RUNE_SPAWN_INTERVAL
    elseif rune_type == "powerup" then
        rune_locations = self.powerup_rune_locations
        spawn_interval = POWER_RUNE_SPAWN_INTERVAL
    else
        DebugPrint("CustomRuneSystem: Invalid rune_type for spawning.")
        return
    end

    if rune_locations == nil or rune_locations == {} then
        DebugPrint("CustomRuneSystem: Invalid rune locations.")
        return
    end

    -- Remove all DotA runes around the spawners first
    for i = 1, #rune_locations do
        self:RemoveRuneAroundLocation(rune_locations[i])
    end

    -- Actually Spawn Rune at rune locations
    Timers:CreateTimer(0.03, function()
        for i = 1, #rune_locations do
            if rune_type == "bounty" then
                CreateRune(rune_locations[i], DOTA_RUNE_BOUNTY)
            else
                local random_int = RandomInt(1, #CustomRuneSystem.power_runes_enums)
                local rune_to_spawn = CustomRuneSystem.power_runes_enums[random_int]
                DebugPrint("Spawning rune " .. tostring(rune_to_spawn) .. " in: " .. tostring(rune_locations[i]))
                CreateRune(rune_locations[i], rune_to_spawn)
            end
        end
    end)

    -- Repeat all this after spawn_interval
    Timers:CreateTimer(spawn_interval, function()
        CustomRuneSystem:SpawnRunes(rune_type)
    end)
end

function CustomRuneSystem:RemoveRuneAroundLocation(location)
    if not location then
        DebugPrint("CustomRuneSystem: location in RemoveRuneAroundLocation is nil!")
        return
    end
    local all_runes_around_location = Entities:FindAllByClassnameWithin("dota_item_rune", location, 100)
    if all_runes_around_location == nil then
        --DebugPrint("CustomRuneSystem: No runes found around the specified location!")
        return
    end
    -- Remove all DotA runes near the location
    for _, rune in pairs(all_runes_around_location) do
        if rune and not rune:IsNull() then
            UTIL_Remove(rune)
        end
    end
end
