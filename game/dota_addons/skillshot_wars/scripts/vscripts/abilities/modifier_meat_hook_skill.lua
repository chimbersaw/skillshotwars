-- Note: functions in this file are not used

modifier_meat_hook_skill = class({})
--------------------------------------------------------------------------------

function modifier_meat_hook_skill:IsDebuff()
    return true
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:IsStunDebuff()
    return true
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:RemoveOnDeath()
    return false
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:OnCreated(kv)
    if IsServer() then
        if self:ApplyHorizontalMotionController() == false then
            self:Destroy()
        end
    end
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
    }

    return funcs
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:GetOverrideAnimation(params)
    return ACT_DOTA_FLAIL
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:CheckState()
    if IsServer() then
        if self:GetCaster() ~= nil and self:GetParent() ~= nil then
            if self:GetCaster():GetTeamNumber() ~= self:GetParent():GetTeamNumber() and (not self:GetParent():IsMagicImmune()) then
                local state = {
                    [MODIFIER_STATE_STUNNED] = true,
                }

                return state
            end
        end
    end

    local state = {}

    return state
end

--------------------------------------------------------------------------------

function modifier_meat_hook_skill:UpdateHorizontalMotion(me, dt)
    if IsServer() then
        if self:GetAbility().hVictim ~= nil then
            self:GetAbility().hVictim:SetOrigin(self:GetAbility().vProjectileLocation)
            local vToCaster = self:GetAbility().vStartPosition - self:GetCaster():GetOrigin()
            local flDist = vToCaster:Length2D()
            if self:GetAbility().bChainAttached == false and flDist > 128.0 then
                self:GetAbility().bChainAttached = true
                ParticleManager:SetParticleControlEnt(self:GetAbility().nChainParticleFXIndex, 0, self:GetCaster(), PATTACH_CUSTOMORIGIN, "attach_hitloc", self:GetCaster():GetOrigin(), true)
                ParticleManager:SetParticleControl(self:GetAbility().nChainParticleFXIndex, 0, self:GetAbility().vStartPosition + self:GetAbility().vHookOffset)
            end
        end
    end
end

--------------------------------------------------------------------------------
function modifier_meat_hook_skill:OnHorizontalMotionInterrupted()
    if IsServer() then
        if self:GetAbility().hVictim ~= nil then
            ParticleManager:SetParticleControlEnt(self:GetAbility().nChainParticleFXIndex, 1, self:GetCaster(), PATTACH_POINT_FOLLOW, "attach_weapon_chain_rt", self:GetCaster():GetAbsOrigin() + self:GetAbility().vHookOffset, true)
            self:Destroy()
        end
    end
end
