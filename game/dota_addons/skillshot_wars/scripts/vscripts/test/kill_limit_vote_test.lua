-- Run from the Dota installation root:
-- lua game/dota_addons/skillshot_wars/scripts/vscripts/test/kill_limit_vote_test.lua
local scripts = "game/dota_addons/skillshot_wars/scripts/vscripts/"
barebones = {}
DOTA_TEAM_GOODGUYS = 2
DOTA_TEAM_BADGUYS = 3
DOTA_GAMERULES_STATE_PRE_GAME = 7
DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 8
END_GAME_ON_KILLS = true
CUSTOM_TEAM_PLAYER_COUNT = {}
DebugPrint = function() end

local now, state, listener, timer, snapshot, map, winner, teamKills
local heroes = {}
HeroList = { GetAllHeroes = function() return heroes end }
local players = { [0] = 2, [1] = 3, [2] = 2, [3] = 3, [4] = 1, [5] = 2 }
GetMapName = function() return map end
GameRules = {
    GetGameTime = function() return now end,
    State_Get = function() return state end,
    SetGameWinner = function(_, team) winner = team end,
}
PlayerResource = {
    IsValidPlayerID = function(_, id) return players[id] ~= nil end,
    GetPlayer = function(_, id) return id ~= 5 and players[id] and {} or nil end,
    GetTeam = function(_, id) return players[id] end,
}
CustomGameEventManager = {
    RegisterListener = function(_, name, callback)
        assert(name == "kill_limit_vote_cast")
        listener = callback
    end,
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end
CustomNetTables = {
    SetTableValue = function(_, tableName, key, value)
        assert(tableName == "game_state" and key == "kill_limit_vote")
        snapshot = copy(value)
    end,
}
Timers = {
    CreateTimer = function(_, name, args)
        assert(name == "kill_limit_vote")
        timer = args
    end,
    RemoveTimer = function() timer = nil end,
}
dofile(scripts .. "kill_limit_vote.lua")
dofile(scripts .. "events.lua")

local function reset(mapName)
    now, state, map = 100, DOTA_GAMERULES_STATE_PRE_GAME, mapName
    winner, timer, snapshot, heroes = nil, nil, nil, {}
    dofile(scripts .. "map_settings.lua")
    local mode = setmetatable({}, { __index = barebones })
    mode:InitKillLimitVote()
    assert(snapshot.default_kills == (mapName == "skillshot_3v3" and 30 or 50))
    return mode
end
local function cast(id, kills)
    listener(999, { PlayerID = id, kills = kills })
end

-- Both map defaults survive an empty ballot; votes before opening are ignored.
for _, mapName in ipairs({"skillshot_wars", "skillshot_3v3"}) do
    local mode = reset(mapName)
    local default = KILLS_TO_END_GAME_FOR_TEAM
    cast(0, 40)
    assert(next(snapshot.votes) == nil)
    mode:StartKillLimitVote()
    assert(timer.endTime > 0 and snapshot.ends_at == now + timer.endTime)
    local resultEndsAt = now + mode:GetKillLimitVoteDuration()
    assert(snapshot.result_ends_at == resultEndsAt)
    local originalTimer = timer
    mode:StartKillLimitVote()
    assert(timer == originalTimer)
    now = snapshot.ends_at
    timer.callback()
    assert(KILLS_TO_END_GAME_FOR_TEAM == default and snapshot.kills_to_win == default)
    assert(snapshot.finished == 1 and snapshot.active == 0 and snapshot.result_ends_at == resultEndsAt)
    assert(timer == nil)
end

-- Every pairwise tie, and a three-way tie, favors the lowest leader on either map.
for _, mapName in ipairs({"skillshot_wars", "skillshot_3v3"}) do
    for _, choices in ipairs({{30, 40}, {30, 50}, {40, 50}, {30, 40, 50}}) do
        local mode = reset(mapName)
        mode:StartKillLimitVote()
        for index, kills in ipairs(choices) do cast(index - 1, kills) end
        mode:FinishKillLimitVote()
        assert(KILLS_TO_END_GAME_FOR_TEAM == choices[1])
    end
end

-- Plurality wins; duplicate votes cannot change the original ballot.
local mode = reset("skillshot_wars")
mode:StartKillLimitVote()
cast(0.0, 40.0)
cast(0, 30)
cast(1, "40")
cast(2, 50)
assert(snapshot.votes["0"] == 40 and snapshot.counts["40"] == 2)
assert(snapshot.counts["30"] == 0 and snapshot.counts["50"] == 1)
mode:FinishKillLimitVote()
assert(KILLS_TO_END_GAME_FOR_TEAM == 40)
local finishedAt = snapshot.result_ends_at
now = 200
mode:FinishKillLimitVote()
mode:StartKillLimitVote()
cast(3, 30)
assert(snapshot.result_ends_at == finishedAt and snapshot.votes["3"] == nil)

-- Reject spectators, missing players, malformed values and expired ballots.
mode = reset("skillshot_3v3")
mode:StartKillLimitVote()
for _, id in ipairs({-1, 0.5, 4, 5, 99, "invalid"}) do cast(id, 40) end
cast(nil, 40)
for _, value in ipairs({0, 20, 31, 30.5, 60, "invalid", {}, false}) do cast(0, value) end
cast(0, nil)
assert(next(snapshot.votes) == nil)
now = snapshot.ends_at
cast(0, 40)
assert(next(snapshot.votes) == nil)

-- Early game start closes voting even if the timer has not fired yet.
mode = reset("skillshot_3v3")
mode:StartKillLimitVote()
cast(0, 50)
state = DOTA_GAMERULES_STATE_GAME_IN_PROGRESS
cast(1, 30)
mode:FinishKillLimitVote()
assert(KILLS_TO_END_GAME_FOR_TEAM == 50 and snapshot.votes["1"] == nil and timer == nil)

-- Exercise the real kill handler at each elected threshold, for both teams.
local unit = setmetatable({
    IsRealHero = function() return true end,
    GetUnitName = function() return "npc_dota_hero_pudge" end,
}, { __index = function() return function() return false end end })
EntIndexToHScript = function() return unit end
GetTeamHeroKills = function() return teamKills end
for _, limit in ipairs({30, 40, 50}) do
    for _, team in ipairs({2, 3}) do
        mode = reset("skillshot_wars")
        mode:StartKillLimitVote()
        cast(0, limit)
        mode:FinishKillLimitVote()
        unit.GetTeam = function() return team end
        teamKills = limit - 1
        mode:OnEntityKilled({entindex_killed = 1, entindex_attacker = 2})
        assert(winner == nil)
        teamKills = limit
        mode:OnEntityKilled({entindex_killed = 1, entindex_attacker = 2})
        assert(winner == team)
    end
end

-- Voting stuns existing/late heroes without rejecting orders in the filter.
dofile(scripts .. "filters.lua")
local function assertOrdersPassThrough(mode)
    -- Direct filter calls check its return value, not engine dispatch or execution.
    for order = 0, 39 do
        for queue = 0, 1 do
            assert(mode:OrderFilter({ order_type = order, queue = queue }) == true,
                string.format("Order %d (queue=%d) was rejected", order, queue))
        end
    end
end
local function newHero()
    return {
        bFirstSpawned = true,
        IsRealHero = function() return true end,
        GetOwner = function() return nil end,
        Stop = function(self) self.stopped = true end,
        AddNewModifier = function(self, caster, ability, name, params)
            assert(name == "modifier_kill_limit_vote_lock")
            self.lockDuration = params.duration
        end,
        RemoveModifierByName = function(self, name)
            assert(name == "modifier_kill_limit_vote_lock")
            self.lockRemoved = true
        end,
    }
end
mode = reset("skillshot_wars")
heroes = { newHero() }
local lockDuration = mode:GetKillLimitVoteDuration()
assert(lockDuration > 0)
assert(not mode:IsKillLimitVoteBlockingGameplay())
mode:StartKillLimitVote()
assert(heroes[1].stopped and heroes[1].lockDuration == lockDuration)
assertOrdersPassThrough(mode)
now = snapshot.ends_at
timer.callback()
assert(mode:IsKillLimitVoteBlockingGameplay(), "Lock persists during the result screen")
assertOrdersPassThrough(mode)
now = snapshot.result_ends_at - 1
local lateHero = newHero()
EntIndexToHScript = function() return lateHero end
mode:OnNPCSpawned({ entindex = 3 })
assert(lateHero.lockDuration == 1 and lateHero.stopped)
now = snapshot.result_ends_at
assert(not mode:IsKillLimitVoteBlockingGameplay())
assertOrdersPassThrough(mode)
mode:ClearKillLimitVoteLocks()
assert(heroes[1].lockRemoved)

mode = reset("skillshot_3v3")
mode:StartKillLimitVote()
local resultEndsAt = snapshot.result_ends_at
now = resultEndsAt + 1
timer.callback()
assert(snapshot.result_ends_at == resultEndsAt, "Delayed finalization must not delay preparation")
assert(not mode:IsKillLimitVoteBlockingGameplay())

END_GAME_ON_KILLS = false
mode = setmetatable({}, { __index = barebones })
mode:InitKillLimitVote()
mode:StartKillLimitVote()
mode:FinishKillLimitVote()
assert(mode.killLimitVote == nil and mode:GetKillLimitVoteDuration() == 0)
assert(not mode:IsKillLimitVoteBlockingGameplay())
print("Kill limit vote: defaults, ties, plurality, validation, deadlines, hero locks, order pass-through and victory thresholds passed")
