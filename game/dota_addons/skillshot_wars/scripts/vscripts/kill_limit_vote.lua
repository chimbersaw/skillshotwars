local KILL_LIMIT_OPTIONS = {30, 40, 50}
local VOTE_DURATION = 13
local RESULT_DURATION = 2
local VOTE_TIMER = "kill_limit_vote"
local LOCK_MODIFIER = "modifier_kill_limit_vote_lock"

function barebones:GetKillLimitVoteDuration()
    return END_GAME_ON_KILLS and (VOTE_DURATION + RESULT_DURATION) or 0
end

function barebones:InitKillLimitVote()
    if not END_GAME_ON_KILLS then
        return
    end

    self.killLimitVote = {
        active = 0,
        finished = 0,
        default_kills = KILLS_TO_END_GAME_FOR_TEAM,
        kills_to_win = KILLS_TO_END_GAME_FOR_TEAM,
        ends_at = 0,
        result_ends_at = 0,
        counts = { ["30"] = 0, ["40"] = 0, ["50"] = 0 },
        votes = {},
    }

    CustomGameEventManager:RegisterListener("kill_limit_vote_cast", function(_, event)
        self:OnKillLimitVote(event)
    end)

    self:PublishKillLimitVote()
end

function barebones:PublishKillLimitVote()
    -- A snapshot also restores the countdown and each player's vote after reconnecting.
    CustomNetTables:SetTableValue("game_state", "kill_limit_vote", self.killLimitVote)
end

function barebones:StartKillLimitVote()
    local vote = self.killLimitVote
    if not vote or vote.active == 1 or vote.finished == 1 then
        return
    end

    vote.active = 1
    vote.ends_at = GameRules:GetGameTime() + VOTE_DURATION
    -- Fix both deadlines up front so delayed callbacks cannot eat into preparation.
    vote.result_ends_at = vote.ends_at + RESULT_DURATION
    for _, hero in pairs(HeroList:GetAllHeroes()) do
        self:ApplyKillLimitVoteLock(hero)
    end
    self:PublishKillLimitVote()
    Timers:CreateTimer(VOTE_TIMER, {
        endTime = VOTE_DURATION,
        callback = function()
            self:FinishKillLimitVote()
        end,
    })
end

function barebones:IsKillLimitVoteBlockingGameplay()
    local vote = self.killLimitVote
    return vote ~= nil and (vote.active == 1 or vote.finished == 1)
        and GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME
        and GameRules:GetGameTime() < vote.result_ends_at
end

function barebones:ApplyKillLimitVoteLock(hero)
    if not hero:IsRealHero() or not self:IsKillLimitVoteBlockingGameplay() then
        return
    end
    hero:Stop()
    -- Late-spawning heroes are locked only for the remaining vote/result time.
    hero:AddNewModifier(hero, nil, LOCK_MODIFIER, {
        duration = self.killLimitVote.result_ends_at - GameRules:GetGameTime(),
    })
end

function barebones:ClearKillLimitVoteLocks()
    -- Also release heroes if Tools forces the game to start before the vote timer ends.
    for _, hero in pairs(HeroList:GetAllHeroes()) do
        hero:RemoveModifierByName(LOCK_MODIFIER)
    end
end

function barebones:OnKillLimitVote(event)
    local vote = self.killLimitVote
    if not vote or vote.active ~= 1
        or GameRules:State_Get() ~= DOTA_GAMERULES_STATE_PRE_GAME
        or GameRules:GetGameTime() >= vote.ends_at then
        return
    end

    -- PlayerID is supplied by the engine, never by the Panorama payload.
    local playerID = tonumber(event.PlayerID)
    local kills = tonumber(event.kills)
    if not playerID or playerID < 0 or playerID % 1 ~= 0
        or not PlayerResource:IsValidPlayerID(playerID)
        or not PlayerResource:GetPlayer(playerID) then
        return
    end

    local team = PlayerResource:GetTeam(playerID)
    if team ~= DOTA_TEAM_GOODGUYS and team ~= DOTA_TEAM_BADGUYS then
        return
    end
    if kills ~= 30 and kills ~= 40 and kills ~= 50 then
        return
    end

    local playerKey = string.format("%d", playerID)
    local optionKey = string.format("%d", kills)
    if vote.votes[playerKey] then
        return
    end

    vote.votes[playerKey] = kills
    vote.counts[optionKey] = vote.counts[optionKey] + 1
    self:PublishKillLimitVote()
end

function barebones:FinishKillLimitVote()
    local vote = self.killLimitVote
    if not vote or vote.finished == 1 then
        return
    end

    local winner = vote.default_kills
    local highestCount = 0
    -- Ascending order and strict comparison resolve ties to the smallest leading limit.
    -- With no votes, keep this map's default instead.
    for _, kills in ipairs(KILL_LIMIT_OPTIONS) do
        local count = vote.counts[tostring(kills)]
        if count > highestCount then
            winner = kills
            highestCount = count
        end
    end

    Timers:RemoveTimer(VOTE_TIMER)
    vote.active = 0
    vote.finished = 1
    vote.kills_to_win = winner
    KILLS_TO_END_GAME_FOR_TEAM = winner
    self:PublishKillLimitVote()
end
