Scriptname IH_MCMScript extends SKI_ConfigBase

GlobalVariable Property IH_CastExp Auto
GlobalVariable Property IH_CritterCap Auto
GlobalVariable Property IH_NotificationSpam Auto
GlobalVariable Property IH_InheritGreenThumb Auto
GlobalVariable Property IH_LearnFood Auto
GlobalVariable Property IH_SpawnDistanceMult Auto
GlobalVariable Property IH_OffsetReturnPoint Auto

IH_PersistentDataScript Property IH_PersistentData Auto

int OIDcrittercap
int OIDrecall
int OIDexp
int OIDclear
int OIDnspam
int OIDgt
int OIDfood
int OIDspawnDist
int OIDreturnOffset
int OIDstats

Event OnPageReset(string a_page)
	if (a_page == "")
		AddHeaderOption("Getter Critters")
		AddEmptyOption()
		
		float crittercap = IH_CritterCap.GetValue()
		OIDcrittercap = AddSliderOption("Max Concurrent Critters", crittercap, "{0}")
		
		OIDgt = AddToggleOption("Use Green Thumb", IH_InheritGreenThumb.GetValue() as bool)
		
		float spawnDist = IH_SpawnDistanceMult.GetValue()
		OIDspawnDist = AddSliderOption("Spawn Distance Multiplier", spawnDist, "{1}")
		
		OIDrecall = AddTextOption("Recall Active Critters", "[ ]")
		
		float returnOffset = IH_OffsetReturnPoint.GetValue()
		OIDreturnOffset = AddSliderOption("Critter Return Distance Offset", returnOffset, "{0}")
		
		OIDstats = AddTextOption("Show Critter Stats", "[ ]")
		
		SetCursorFillMode(TOP_TO_BOTTOM)
		
		AddEmptyOption()
		
		AddHeaderOption("Experience")
		float exp = IH_CastExp.GetValue()
		OIDexp = AddSliderOption("Experience Per Cast", exp, "{2}")
		
		AddEmptyOption()
		
		AddHeaderOption("Misc")
		OIDclear = AddTextOption("Clear Flora Cache", "[ ]")
		OIDnspam = AddToggleOption("Item Notification Spam", IH_NotificationSpam.GetValue() as bool)
		OIDfood = AddToggleOption("Harvest Food", IH_LearnFood.GetValue() as bool)
	endif
EndEvent

Event OnOptionSelect(int a_option)
	if (a_option == OIDclear)
		SetTextOptionValue(a_option, "[Please close menu]", false)
		IH_PersistentData.ClearFloraCaches()
	elseif (a_option == OIDrecall)
		SetTextOptionValue(a_option, "[Please close menu]", false)
		IH_PersistentData.RecallAllCritters()
	elseif (a_option == OIDstats)
		SetTextOptionValue(a_option, "[Please close menu]", false)
		IH_PersistentData.TallyCritterStats()
	elseif (a_option == OIDnspam)
		ToggleGlobal(IH_NotificationSpam, a_option)
	elseif (a_option == OIDgt)
		ToggleGlobal(IH_InheritGreenThumb, a_option)
	elseif (a_option == OIDfood)
		ToggleGlobal(IH_LearnFood, a_option)
	endif
EndEvent

Event OnOptionSliderOpen(int a_option)
	if (a_option == OIDexp)
		SetSliderDialogStartValue(IH_CastExp.GetValue())
		SetSliderDialogDefaultValue(10.0)
		SetSliderDialogRange(0.0, 100.0)
		SetSliderDialogInterval(0.25)
	elseif (a_option == OIDcrittercap)
		SetSliderDialogStartValue(IH_CritterCap.GetValue())
		SetSliderDialogDefaultValue(64.0)
		SetSliderDialogRange(1.0, 128.0)
		SetSliderDialogInterval(1.0)
	elseif (a_option == OIDspawnDist)
		SetSliderDialogStartValue(IH_SpawnDistanceMult.GetValue())
		SetSliderDialogDefaultValue(1.0)
		SetSliderDialogRange(-3.0, 3.0)
		SetSliderDialogInterval(0.1)
	elseif (a_option == OIDreturnOffset)
		SetSliderDialogStartValue(IH_OffsetReturnPoint.GetValue())
		SetSliderDialogDefaultValue(0.0)
		SetSliderDialogRange(0.0, 1000.0)
		SetSliderDialogInterval(1.0)
	endif
EndEvent

Event OnOptionSliderAccept(int a_option, float a_value)
	if (a_option == OIDexp)
		IH_CastExp.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{2}")
	elseif (a_option == OIDcrittercap)
		IH_CritterCap.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{0}")
	elseif (a_option == OIDspawnDist)
		IH_SpawnDistanceMult.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{1}")
	elseif (a_option == OIDreturnOffset)
		IH_OffsetReturnPoint.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{0}")
	endif
EndEvent

Event OnOptionDefault(int a_option)
	if (a_option == OIDexp)
		OnOptionSliderAccept(a_option, 10.0)
	elseif (a_option == OIDcrittercap)
		OnOptionSliderAccept(a_option, 64.0)
	elseif (a_option == OIDnspam)
		IH_NotificationSpam.SetValue(1.0)
		SetToggleOptionValue(a_option, true)
	elseif (a_option == OIDgt)
		IH_InheritGreenThumb.SetValue(1.0)
		SetToggleOptionValue(a_option, true)
	elseif (a_option == OIDfood)
		IH_LearnFood.SetValue(0.0)
		SetToggleOptionValue(a_option, false)
	elseif (a_option == OIDspawnDist)
		OnOptionSliderAccept(a_option, 1.0)
	elseif (a_option == OIDreturnOffset)
		OnOptionSliderAccept(a_option, 150.0)
	endif
EndEvent

Event OnOptionHighlight(int a_option)
	if (a_option == OIDcrittercap)
		SetInfoText("How many Getter Critters can be active at a time.\nThe default value should be fine, but you can try lowering it if you experience game instability while casting.")
	elseif (a_option == OIDrecall)
		SetInfoText("Debug option: Immediately returns all currently active critters to the cache, and checks and fixes cache errors if present.")
	elseif (a_option == OIDexp)
		SetInfoText("How much Alteration exp to award per Getter Critter summon.")
	elseif (a_option == OIDclear)
		SetInfoText("Clears all examined/learned harvestables, as well as the temporary reference cache.\nRun this if you install a mod that adds or edits harvestables mid-save, or change the food setting below.")
	elseif (a_option == OIDnspam)
		SetInfoText("Toggles the \"<item> Added\" notifications, as well as item pickup sounds that play when a Getter Critter returns.")
	elseif (a_option == OIDgt)
		SetInfoText("Toggles whether Getter Critters inherit the Green Thumb perk from from the caster, if they have it.\nYou may wish to disable this for balance reasons.")
	elseif (a_option == OIDfood)
		SetInfoText("Toggles whether the mod will also learn harvestables that produce food, instead of just ingredients.\nNOTE: Changes to this setting will not fully take effect until you also run Clear Flora Cache.")
	elseif (a_option == OIDspawnDist)
		SetInfoText("Multiplies the distance at which critters will (try to) spawn in front of the caster.\nNegative values will cause critters to spawn behind the caster instead.")
	elseif (a_option == OIDreturnOffset)
		SetInfoText("Values above zero will control how close critters will AI pathfind back to the caster before despawning.\nThis can help reduce how often critters bump the caster, though AI pathfinding still tends to be unpredictable.\n64 units = 1 yard")
	elseif (a_option == OIDstats)
		SetInfoText("Show a message box containing recorded mod stats.\nNote that this will not be accurate if run while any critters are active.")
	endif
EndEvent

Function ToggleGlobal(GlobalVariable var, int option)
	bool newState = !(var.GetValue() as bool)
	var.SetValue(newState as float)
	SetToggleOptionValue(option, newState)
EndFunction
