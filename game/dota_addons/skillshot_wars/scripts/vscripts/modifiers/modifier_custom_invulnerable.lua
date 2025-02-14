modifier_custom_invulnerable = modifier_custom_invulnerable or class({})

function modifier_custom_invulnerable:IsHidden()
    return true
end

function modifier_custom_invulnerable:IsPurgable()
    return false
end

function modifier_custom_invulnerable:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
    }
end

function modifier_custom_invulnerable:GetAbsoluteNoDamageMagical()
    return 1
end

function modifier_custom_invulnerable:GetAbsoluteNoDamagePhysical()
    return 1
end

function modifier_custom_invulnerable:GetAbsoluteNoDamagePure()
    return 1
end

function modifier_custom_invulnerable:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true
    }
end
