function FixItem(keys)
	local caster = keys.caster
	local realItem = keys.RealItem
	for i=0,6 do
		local item = caster:GetItemInSlot(i)
		if item ~= nil and item:GetAbilityName() == keys.ability:GetAbilityName() then
			caster:RemoveItem(item)
			caster:AddItemByName(realItem)
		end
		item = nil
	end
end
