--------------------------------------------------------------------------------

LinkLuaModifier("modifier_citrulline", "items/citrulline_malate.lua", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------

item_citrulline_malate = class({})

function item_citrulline_malate:OnSpellStart()
    local caster = self:GetCaster()

    caster:EmitSound("DOTA_Item.Satanic.Activate")

    local heal_amount = self:GetSpecialValueFor("heal_amount")
    caster:Heal(heal_amount, caster)

    local dur = self:GetSpecialValueFor("duration")
    caster:AddNewModifier(caster, self, "modifier_citrulline", { duration = dur })

    self:SpendCharge()
end

--------------------------------------------------------------------------------

modifier_citrulline = class({})

function modifier_citrulline:OnCreated()
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        self.bonus_strength = ability:GetSpecialValueFor("bonus_strength")
    end
end

function modifier_citrulline:IsHidden()
    return false
end

function modifier_citrulline:IsPurgable()
    return false
end

function modifier_citrulline:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_citrulline:GetTexture()
    return "citrulline_malate"
end

function modifier_citrulline:GetEffectName()
    return "particles/items2_fx/satanic_buff.vpcf"
end

function modifier_citrulline:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_citrulline:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS
    }
end

function modifier_citrulline:OnTooltip()
    return self.bonus_strength
end

function modifier_citrulline:GetModifierBonusStats_Strength()
    return self.bonus_strength
end
