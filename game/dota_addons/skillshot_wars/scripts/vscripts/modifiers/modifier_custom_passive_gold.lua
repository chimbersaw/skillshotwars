modifier_custom_passive_gold = class({})

function modifier_custom_passive_gold:IsHidden()
    return true
end

function modifier_custom_passive_gold:IsPurgable()
    return false
end

function modifier_custom_passive_gold:RemoveOnDeath()
    return false
end

if IsServer() then
    local function IsMonkeyKingClone(unit)
        if unit.HasModifier == nil then
            return true
        end

        local monkey_king_soldier_modifiers = {
            "modifier_monkey_king_fur_army_soldier_hidden",
            "modifier_monkey_king_fur_army_soldier",
            "modifier_monkey_king_fur_army_thinker",
            "modifier_monkey_king_fur_army_soldier_inactive",
            "modifier_monkey_king_fur_army_soldier_in_position",
        }

        for _, v in pairs(monkey_king_soldier_modifiers) do
            if unit:HasModifier(v) then
                return true
            end
        end

        return false
    end

    function modifier_custom_passive_gold:OnCreated()
        local parent = self:GetParent()
        if parent:IsIllusion() or parent:IsClone() or parent:IsTempestDouble() or IsMonkeyKingClone(parent) then
            self:Destroy()
            return
        end
        local gpm = ADDITIONAL_GPM or 100 -- to disable vanilla (normal dota) gpm, you either disable couriers or do some math here
        if gpm ~= 0 then
            self.goldTickTime = math.abs(60 / gpm) -- GOLD_TICK_TIME, must be > 0 hence the math.abs if we want gpm to be < 0
            self.goldPerTick = 1 -- GOLD_PER_TICK
        else
            self.goldTickTime = -1
            self.goldPerTick = 0
            self:Destroy()
        end
        self:StartIntervalThink(self.goldTickTime)
    end

    function modifier_custom_passive_gold:OnIntervalThink()
        local parent = self:GetParent()
        local game_state = GameRules:State_Get()
        if game_state >= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            parent:ModifyGold(self.goldPerTick, false, DOTA_ModifyGold_GameTick)
        end
    end
end
