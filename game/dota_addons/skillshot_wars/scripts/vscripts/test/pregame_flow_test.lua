-- Run from the Dota installation root:
-- lua game/dota_addons/skillshot_wars/scripts/vscripts/test/pregame_flow_test.lua
local scripts = "game/dota_addons/skillshot_wars/scripts/vscripts/"
barebones = {}
class = function(methods) return methods end
DebugPrint = function() end
DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS = 2, 3
-- Stand-ins for engine team constants used by the real settings file.
for index = 1, 8 do _G["DOTA_TEAM_CUSTOM_" .. index] = 5 + index end
DOTA_GAMERULES_STATE_PRE_GAME, DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 7, 8
DOTA_RUNE_DOUBLEDAMAGE, DOTA_RUNE_HASTE, DOTA_RUNE_ILLUSION = 0, 1, 2
DOTA_RUNE_INVISIBILITY, DOTA_RUNE_REGENERATION, DOTA_RUNE_ARCANE = 3, 4, 5
MODIFIER_STATE_STUNNED = 1
dofile(scripts .. "settings.lua")
HeroList = { GetAllHeroes = function() return {} end }
CustomGameEventManager = { RegisterListener = function() end }
CustomNetTables = { SetTableValue = function() end }

local now, state, preGameTime, mapName, queue, spawned
GetMapName = function() return mapName end
GameRules = setmetatable({
    GetGameTime = function() return now end,
    State_Get = function() return state end,
    SetPreGameTime = function(_, seconds) preGameTime = seconds end,
    -- Stop InitGameMode after reading the actual pre-game setting, before unrelated setup.
    SetPostGameTime = function() error("pre-game configuration captured") end,
    GetGameModeEntity = function()
        return { SetCustomDireScore = function() end, SetCustomRadiantScore = function() end }
    end,
}, { __index = function() return function() end end })
Timers = {
    CreateTimer = function(_, delayOrName, callbackOrArgs)
        local named = type(delayOrName) == "string"
        queue[#queue + 1] = {
            name = named and delayOrName or nil,
            at = now + (named and callbackOrArgs.endTime or delayOrName),
            callback = named and callbackOrArgs.callback or callbackOrArgs,
        }
    end,
    RemoveTimer = function(_, name)
        for index = #queue, 1, -1 do
            if queue[index].name == name then table.remove(queue, index) end
        end
    end,
}
local function advance(time)
    now = time
    while true do
        local due
        for index, timer in ipairs(queue) do
            if timer.at <= now then due = index; break end
        end
        if not due then break end
        table.remove(queue, due).callback()
    end
end
Vector = function(x, y, z) return { x = x, y = y, z = z } end
RandomInt = function(_, maximum) return maximum end
Entities = {
    FindAllByClassname = function()
        return {{ GetAbsOrigin = function() return Vector(1, 2, 3) end, SetOrigin = function() end }}
    end,
    FindAllByClassnameWithin = function() return {} end,
}
CreateRune = function(_, rune) spawned[#spawned + 1] = { time = now, rune = rune } end

-- Load the real lifecycle functions without pulling in unrelated engine libraries.
local originalRequire = require
require = function() end
dofile(scripts .. "gamemode.lua")
require = originalRequire
dofile(scripts .. "kill_limit_vote.lua")
dofile(scripts .. "components/runes/custom_rune_system.lua")
dofile(scripts .. "modifiers/modifier_kill_limit_vote_lock.lua")
local runeSystem = CustomRuneSystem
assert(modifier_kill_limit_vote_lock:IsHidden())
assert(not modifier_kill_limit_vote_lock:IsPurgable())
assert(not modifier_kill_limit_vote_lock:IsDebuff())
assert(modifier_kill_limit_vote_lock:CheckState()[MODIFIER_STATE_STUNNED])

for _, map in ipairs({"skillshot_wars", "skillshot_3v3"}) do
    for _, votingEnabled in ipairs({true, false}) do
        for _, runeDelay in ipairs({0, 3}) do
            now, state, mapName = 0, DOTA_GAMERULES_STATE_PRE_GAME, map
            queue, spawned = {}, {}
            END_GAME_ON_KILLS = votingEnabled
            FIRST_POWER_RUNE_SPAWN_TIME = runeDelay
            CustomRuneSystem = setmetatable({}, { __index = runeSystem })
            dofile(scripts .. "map_settings.lua")
            local mode = setmetatable({}, { __index = barebones })
            local ok, err = pcall(function() mode:InitGameMode() end)
            assert(not ok and tostring(err):find("pre%-game configuration captured"), err)
            assert(PRE_GAME_TIME == 15)
            assert(preGameTime == PRE_GAME_TIME + mode:GetKillLimitVoteDuration())
            mode:OnPreGame()
            assert(#spawned == 0)
            if votingEnabled then
                assert(mode:IsKillLimitVoteBlockingGameplay())
                advance(mode.killLimitVote.ends_at)
                assert(mode.killLimitVote.finished == 1 and mode:IsKillLimitVoteBlockingGameplay())
                advance(mode.killLimitVote.result_ends_at)
            end
            assert(not mode:IsKillLimitVoteBlockingGameplay())
            assert(preGameTime - now == 15, "All 15 preparation seconds must remain")
            advance(preGameTime)
            assert(#spawned == 0, "Runes must wait for the actual game-start event")
            state = DOTA_GAMERULES_STATE_GAME_IN_PROGRESS
            mode:OnGameInProgress()
            CustomRuneSystem:StartRuneSpawning() -- Repeated calls must not duplicate runes.
            advance(preGameTime + runeDelay)
            advance(preGameTime + runeDelay + 0.03) -- Existing rune cleanup/spawn frame delay.
            assert(#spawned == 1)
            assert(spawned[1].time == preGameTime + runeDelay + 0.03)
        end
    end
end
print("Pre-game flow: both maps retain 15 seconds; rune spawn follows the horn; voting-disabled flow passed")
