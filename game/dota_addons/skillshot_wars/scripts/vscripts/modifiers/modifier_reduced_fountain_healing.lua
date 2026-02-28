modifier_reduced_fountain_healing = class({})

function modifier_reduced_fountain_healing:IsHidden()
    local parent = self:GetParent()
    return not parent or parent:IsNull() or not parent:HasModifier("modifier_fountain_aura_buff")
end

function modifier_reduced_fountain_healing:IsDebuff()
    return true
end

function modifier_reduced_fountain_healing:IsPurgable()
    return false
end

function modifier_reduced_fountain_healing:RemoveOnDeath()
    return true
end

function modifier_reduced_fountain_healing:GetTexture()
    return "serega_pirat"
end
