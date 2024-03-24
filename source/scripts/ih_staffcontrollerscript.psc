ScriptName IH_StaffControllerScript extends ActiveMagicEffect
{Added to the caster upon equipping a Staff of Harvest;
Originally was for making an aimed, concentration, dummy spell
also silumtaneously fire a self-targeted concentration spell,
because self-targeted staves don't have proper animations,
but I decided it felt nicer to make casting the staff toggle
a self-targeted constant effect instead, so it does that now.}

Enchantment Property IH_HarvestStaffEnch Auto
Keyword Property IH_IsHarvestStaff Auto
Spell Property IH_HarvestStaffAbility Auto
MagicEffect Property IH_HarvestStaffEffect Auto

Actor caster

Event OnInit()
	caster = GetTargetActor()
EndEvent

Event OnSpellCast(Form akSpell)
	if (akSpell != IH_HarvestStaffEnch)
		return
	endif
	if (caster.HasMagicEffect(IH_HarvestStaffEffect))
		caster.RemoveSpell(IH_HarvestStaffAbility)
	else
		caster.RemoveSpell(IH_HarvestStaffAbility)
		caster.AddSpell(IH_HarvestStaffAbility)
	endif
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
	; IH_Util.Trace("Effect finished, " + akTarget +","+ akCaster)
	akTarget.RemoveSpell(IH_HarvestStaffAbility)
EndEvent
