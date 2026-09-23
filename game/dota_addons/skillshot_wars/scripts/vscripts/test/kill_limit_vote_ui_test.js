// Run from the Dota installation root:
// node game/dota_addons/skillshot_wars/scripts/vscripts/test/kill_limit_vote_ui_test.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const panorama = "content/dota_addons/skillshot_wars/panorama/";
const layout = fs.readFileSync(panorama + "layout/custom_game/kill_limit_vote.xml", "utf8");
const source = fs.readFileSync(panorama + "scripts/custom_game/kill_limit_vote.js", "utf8");
const styles = fs.readFileSync(panorama + "styles/custom_game/kill_limit_vote.css", "utf8");

// All UI tokens exist in both supported languages, and all badge assets are present.
const tokens = new Set((layout + source).match(/#kill_vote_\w+/g));
for (const language of ["english", "russian"]) {
    const localization = fs.readFileSync(
        "game/dota_addons/skillshot_wars/resource/addon_" + language + ".txt", "utf8");
    for (const token of tokens) assert(localization.includes('"' + token.slice(1) + '"'), token);
}
for (const match of styles.matchAll(/file:\/\/\{images\}\/([^"']+)/g)) {
    assert(fs.existsSync(panorama + "images/" + match[1]), match[1]);
}

// Server snapshot fixture. A nonzero start verifies that the UI uses absolute deadlines.
const voteStartedAt = 100;
const voteDuration = 13;
const resultDuration = 2;
const reconnectAt = voteStartedAt + 5;

function initialState(defaultKills = 50) {
    return {
        active: 1, finished: 0, default_kills: defaultKills, kills_to_win: defaultKills,
        ends_at: voteStartedAt + voteDuration,
        result_ends_at: voteStartedAt + voteDuration + resultDuration,
        counts: { "30": 0, "40": 0, "50": 0 }, votes: {},
    };
}

function client(initial, team = 2, startTime = voteStartedAt, startPhase = 7) {
    const panels = {};
    for (const match of layout.matchAll(/id="([^"]+)"/g)) {
        assert(!panels["#" + match[1]], "Duplicate panel ID");
        panels["#" + match[1]] = {
            visible: false, enabled: false, classes: {}, variables: {}, text: "",
            SetHasClass(name, value) { this.classes[name] = value; },
            SetDialogVariableInt(name, value) { this.variables[name] = value; },
        };
    }
    const $ = id => {
        assert(panels[id], "Missing panel " + id);
        return panels[id];
    };
    let now = startTime, phase = startPhase, listener, handle = 0;
    const scheduled = new Map(), events = {}, sent = [];
    $.Schedule = (_, callback) => { scheduled.set(++handle, callback); return handle; };
    $.CancelScheduled = id => assert(scheduled.delete(id), "Cancelled an expired callback");
    $.Localize = (token, panel) => token + (panel ? JSON.stringify(panel.variables) : "");
    const context = vm.createContext({
        $, Game: {
            GetLocalPlayerID: () => 0,
            GetLocalPlayerInfo: () => team === null ? null : { player_team_id: team },
            GameStateIs: value => phase === value,
            GetGameTime: () => now,
            EmitSound() {},
        },
        GameEvents: {
            Subscribe: (name, callback) => { events[name] = callback; },
            SendCustomGameEventToServer: (name, payload) => { sent.push({ name, payload }); },
        },
        CustomNetTables: {
            GetTableValue: () => initial,
            SubscribeNetTableListener: (_, callback) => { listener = callback; },
        },
        DOTA_GameState: { DOTA_GAMERULES_STATE_PRE_GAME: 7, DOTA_GAMERULES_STATE_GAME_IN_PROGRESS: 8 },
        DOTATeam_t: { DOTA_TEAM_GOODGUYS: 2, DOTA_TEAM_BADGUYS: 3 },
    });
    vm.runInContext(source, context);
    return {
        context, panels, sent, scheduled,
        receive(data) { listener("game_state", "kill_limit_vote", data); },
        advance(time) {
            now = time;
            const callbacks = Array.from(scheduled.values());
            scheduled.clear();
            callbacks.forEach(callback => callback());
        },
        phase(value) { phase = value; events.game_rules_state_change(); },
    };
}

let data = initialState();
let ui = client(data);
assert(ui.panels["#KillLimitVote"].visible);
assert(ui.panels["#KillOption50"].classes.Selected);
assert.equal(ui.panels["#KillVoteCountdown"].text, String(voteDuration));
assert.equal(ui.sent.length, 0, "Preselection must not submit an automatic vote");
ui.context.SelectKillLimit(40);
ui.context.ConfirmKillLimitVote();
ui.context.ConfirmKillLimitVote();
assert.equal(ui.sent.length, 1);
assert.equal(ui.sent[0].name, "kill_limit_vote_cast");
assert.equal(JSON.stringify(ui.sent[0].payload), '{"kills":40}');
assert(!ui.panels["#ConfirmKillVote"].enabled);
data = { ...data, votes: { "0": 40 }, counts: { "30": 0, "40": 1, "50": 0 } };
ui.receive(data);
assert(ui.panels["#ConfirmKillVoteText"].text.includes("kill_vote_confirmed"));
ui.context.SelectKillLimit(30);
assert(ui.panels["#KillOption40"].classes.Selected);
ui.advance(reconnectAt);
assert.equal(ui.panels["#KillVoteCountdown"].text, String(data.ends_at - reconnectAt));
assert.equal(ui.scheduled.size, 1, "Only one countdown callback may be pending");

// Reconnection restores the vote, counts and remaining time without resubmitting.
ui = client(data, 2, reconnectAt);
assert(ui.panels["#KillOption40"].classes.Selected);
assert(!ui.panels["#ConfirmKillVote"].enabled);
assert.equal(ui.panels["#KillCount40"].variables.votes, 1);
assert.equal(ui.panels["#KillVoteCountdown"].text, String(data.ends_at - reconnectAt));
assert.equal(ui.sent.length, 0);

// Winner display expires once, then the persistent goal follows the server result.
ui.advance(data.ends_at);
data = { ...data, active: 0, finished: 1, kills_to_win: 40 };
ui.receive(data);
assert(ui.panels["#KillOption40"].classes.Winner);
assert(ui.panels["#KillOption30"].classes.Losing);
ui.advance(data.result_ends_at);
assert(!ui.panels["#KillLimitVote"].visible);
assert(ui.panels["#KillLimitGoal"].visible);
assert.equal(ui.panels["#KillLimitGoal"].variables.kills, 40);
assert.equal(ui.scheduled.size, 0);
ui.phase(8);
assert(ui.panels["#KillLimitGoal"].visible);
ui.phase(9);
assert(!ui.panels["#KillLimitGoal"].visible);
ui = client(data, 2, data.result_ends_at + 1, 8);
assert(!ui.panels["#KillLimitVote"].visible);
assert(ui.panels["#KillLimitGoal"].visible);

// Spectators, missing player info, invalid options and expired votes cannot submit.
for (const team of [1, null]) {
    ui = client(initialState(30), team);
    ui.context.ConfirmKillLimitVote();
    assert.equal(ui.sent.length, 0);
    assert(!ui.panels["#ConfirmKillVote"].enabled);
}
data = initialState(30);
ui = client(data);
assert(ui.panels["#KillOption30"].classes.Selected);
ui.context.SelectKillLimit(60);
assert(ui.panels["#KillOption30"].classes.Selected);
ui.advance(data.ends_at);
ui.context.ConfirmKillLimitVote();
assert.equal(ui.sent.length, 0);
assert(!ui.panels["#ConfirmKillVote"].enabled);

// A delayed result snapshot cannot leave the popup over the preparation period.
data = initialState();
ui = client(data);
ui.advance(data.result_ends_at);
assert(!ui.panels["#KillLimitVote"].visible);
assert.equal(ui.scheduled.size, 0);

// A late nettable snapshot or state event opens the window without a reload.
ui = client(null);
assert(!ui.panels["#KillLimitVote"].visible);
ui.receive(initialState());
assert(ui.panels["#KillLimitVote"].visible);
ui = client(initialState(), 2, voteStartedAt, 6);
assert(!ui.panels["#KillLimitVote"].visible);
ui.phase(7);
assert(ui.panels["#KillLimitVote"].visible);
ui.phase(8);
assert(!ui.panels["#KillLimitVote"].visible);
console.log("Kill limit UI: resources, selection, submission, reconnect, timer and result states passed");
