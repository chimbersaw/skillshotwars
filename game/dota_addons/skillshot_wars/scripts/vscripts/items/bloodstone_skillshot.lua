LinkLuaModifier("modifier_item_bloodstone_skillshot", "items/bloodstone_skillshot.lua", LUA_MODIFIER_MOTION_NONE)

item_bloodstone_skillshot = class({})

function item_bloodstone_skillshot:GetIntrinsicModifierName()
    return "modifier_item_bloodstone_skillshot"
end

modifier_item_bloodstone_skillshot = class({})

function modifier_item_bloodstone_skillshot:IsHidden()
    return true
end

function modifier_item_bloodstone_skillshot:IsPurgable()
    return false
end

function modifier_item_bloodstone_skillshot:RemoveOnDeath()
    return false
end

function modifier_item_bloodstone_skillshot:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_item_bloodstone_skillshot:OnCreated()
    self.bonus_aoe = self:GetAbility():GetSpecialValueFor("bonus_aoe")
end

modifier_item_bloodstone_skillshot.OnRefresh = modifier_item_bloodstone_skillshot.OnCreated

function modifier_item_bloodstone_skillshot:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL,
        MODIFIER_PROPERTY_OVERRIDE_ABILITY_SPECIAL_VALUE
    }
end

function modifier_item_bloodstone_skillshot:GetModifierOverrideAbilitySpecial(keys)
    local item = self:GetAbility()
    local ability = keys.ability
    if not item or item:IsNull() or not ability or ability:IsNull() or ability == item then
        return 0
    end

    -- Only an equipped, enabled item contributes; each copy owns its modifier.
    local slot = item:GetItemSlot()
    if slot < 0 or slot > 5 or self:GetParent():IsMuted() then
        return 0
    end

    -- Unlike ability:GetAbilityKeyValues(), this API is available on both realms.
    local kv = GetAbilityKeyValuesByName(ability:GetAbilityName())
    local special = kv and kv.AbilityValues and kv.AbilityValues[keys.ability_special_value]
    if type(special) == "table" and tonumber(special.affected_by_aoe_increase) == 1 then
        return 1
    end
    return 0
end

function modifier_item_bloodstone_skillshot:GetModifierOverrideAbilitySpecialValue(keys)
    local ability = keys.ability
    if not ability or ability:IsNull() then
        return 0
    end

    local value = ability:GetLevelSpecialValueNoOverride(keys.ability_special_value, keys.ability_special_level)
    if self:GetModifierOverrideAbilitySpecial(keys) == 0 then
        return value
    end

    -- Override the original value, so multiple copies still give only +50.
    -- Use the same KV opt-in as native AOE bonuses, not every radius/vision field.
    return value + self.bonus_aoe
end
