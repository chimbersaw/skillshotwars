var killLimitState = null;
var selectedKillLimit = 0;
var killVotePending = false;
var killVoteUpdate = null;
var killLimitOptions = [30, 40, 50];

function LocalKillVote() {
    var votes = killLimitState.votes || {};
    return Number(votes[String(Game.GetLocalPlayerID())]) || 0;
}

function CanVoteForKillLimit() {
    var player = Game.GetLocalPlayerInfo();
    return killLimitState && killLimitState.active === 1
        && Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME)
        && Game.GetGameTime() < killLimitState.ends_at
        && player && (player.player_team_id === DOTATeam_t.DOTA_TEAM_GOODGUYS
            || player.player_team_id === DOTATeam_t.DOTA_TEAM_BADGUYS)
        && !LocalKillVote() && !killVotePending;
}

function SelectKillLimit(kills) {
    if (!CanVoteForKillLimit() || killLimitOptions.indexOf(kills) === -1) return;
    selectedKillLimit = kills;
    Game.EmitSound("ui_generic_button_click");
    UpdateKillLimitVote();
}

function ConfirmKillLimitVote() {
    if (!CanVoteForKillLimit() || killLimitOptions.indexOf(selectedKillLimit) === -1) return;
    killVotePending = true;
    Game.EmitSound("ui_generic_button_click");
    GameEvents.SendCustomGameEventToServer("kill_limit_vote_cast", { kills: selectedKillLimit });
    UpdateKillLimitVote();
}

function UpdateKillLimitVote() {
    if (killVoteUpdate !== null) {
        $.CancelScheduled(killVoteUpdate);
        killVoteUpdate = null;
    }
    if (!killLimitState) return;

    var panel = $("#KillLimitVote");
    var now = Game.GetGameTime();
    var finished = killLimitState.finished === 1;
    var preGame = Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME);
    panel.visible = preGame && (killLimitState.active === 1 || finished)
        && now < killLimitState.result_ends_at;
    panel.SetHasClass("Finished", finished);

    var localVote = LocalKillVote();
    if (localVote) {
        selectedKillLimit = localVote;
        killVotePending = false;
    } else if (!selectedKillLimit) {
        selectedKillLimit = killLimitState.default_kills;
    }

    var canVote = CanVoteForKillLimit();
    killLimitOptions.forEach(function (kills) {
        var option = $("#KillOption" + kills);
        option.enabled = !!canVote;
        option.SetHasClass("Selected", selectedKillLimit === kills);
        option.SetHasClass("MapDefault", killLimitState.default_kills === kills);
        option.SetHasClass("Winner", finished && killLimitState.kills_to_win === kills);
        option.SetHasClass("Losing", finished && killLimitState.kills_to_win !== kills);
        var count = $("#KillCount" + kills);
        count.SetDialogVariableInt("votes", killLimitState.counts[String(kills)] || 0);
        count.text = $.Localize("#kill_vote_count", count);
    });

    $("#ConfirmKillVote").enabled = !!canVote;
    $("#ConfirmKillVoteText").text = $.Localize(localVote
        ? "#kill_vote_confirmed" : "#kill_vote_confirm");
    panel.SetDialogVariableInt("kills", finished ? killLimitState.kills_to_win
        : localVote || selectedKillLimit);
    var status = "#kill_vote_hint";
    if (finished) status = "#kill_vote_result";
    else if (localVote) status = "#kill_vote_your_vote";
    else if (killVotePending) status = "#kill_vote_sending";
    $("#KillVoteStatus").text = $.Localize(status, panel);
    $("#KillVoteCountdown").text = finished ? ""
        : String(Math.max(0, Math.ceil(killLimitState.ends_at - now)));

    var goal = $("#KillLimitGoal");
    goal.visible = finished && !panel.visible && (preGame
        || Game.GameStateIs(DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS));
    goal.SetDialogVariableInt("kills", killLimitState.kills_to_win);
    $("#KillLimitGoalText").text = $.Localize("#kill_vote_goal", goal);

    if (panel.visible) {
        killVoteUpdate = $.Schedule(0.1, function () {
            killVoteUpdate = null;
            UpdateKillLimitVote();
        });
    }
}

function ReceiveKillLimitVote(tableName, key, data) {
    if (key !== "kill_limit_vote") return;
    killLimitState = data;
    UpdateKillLimitVote();
}

(function () {
    CustomNetTables.SubscribeNetTableListener("game_state", ReceiveKillLimitVote);
    GameEvents.Subscribe("game_rules_state_change", UpdateKillLimitVote);
    killLimitState = CustomNetTables.GetTableValue("game_state", "kill_limit_vote");
    UpdateKillLimitVote();
})();
