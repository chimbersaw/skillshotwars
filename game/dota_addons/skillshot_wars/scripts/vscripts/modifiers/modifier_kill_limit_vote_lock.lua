modifier_kill_limit_vote_lock = modifier_kill_limit_vote_lock or class({})

function modifier_kill_limit_vote_lock:IsHidden()
    return true
end

function modifier_kill_limit_vote_lock:IsPurgable()
    return false
end

function modifier_kill_limit_vote_lock:IsDebuff()
    return false
end

function modifier_kill_limit_vote_lock:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end
