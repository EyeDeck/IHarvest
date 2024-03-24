ScriptName IH_HarvestStaffScript extends ObjectReference

Keyword Property IH_IsHarvestStaff Auto
Spell Property IH_StaffCastMonitorAbility Auto

Event OnEquipped(Actor akActor)
{Prevent dual-equipping harvest staves, which won't work for technical reasons}
	Weapon left = akActor.GetEquippedWeapon(true)
	Weapon right = akActor.GetEquippedWeapon(false)
	if (left && right && left.HasKeyword(IH_IsHarvestStaff) && right.HasKeyword(IH_IsHarvestStaff))
		akActor.UnequipItem(left, false, false)
		return
	endif
	akActor.AddSpell(IH_StaffCastMonitorAbility)
EndEvent

Event OnUnequipped(Actor akActor)
	akActor.RemoveSpell(IH_StaffCastMonitorAbility)
EndEvent
