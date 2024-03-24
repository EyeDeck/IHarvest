Scriptname IH_MCMScript extends SKI_ConfigBase

GlobalVariable Property IH_CastExp Auto
GlobalVariable Property IH_CritterCap Auto
GlobalVariable Property IH_NotificationSpam Auto
GlobalVariable Property IH_InheritGreenThumb Auto
GlobalVariable Property IH_LearnFood Auto
GlobalVariable Property IH_LearnHearthfire Auto
GlobalVariable Property IH_SpawnDistanceMult Auto
GlobalVariable Property IH_OffsetReturnPoint Auto
GlobalVariable Property IH_StaffDrainPerSpawn Auto
GlobalVariable Property IH_MagickaDrainPerSpawn Auto
GlobalVariable Property IH_SearchMode Auto

IH_PersistentDataScript Property IH_PersistentData Auto

int OIDcrittercap
int OIDrecall
int OIDdelete
int OIDexp
int OIDclear
int OIDnspam
int OIDgt
int OIDfood
int OIDhf
int OIDspawnDist
int OIDreturnOffset
int OIDstats
int OIDstaffdrain
int OIDmagickadrain
int OIDquestmode

Event OnPageReset(string a_page)
	if (a_page == "")
		SetCursorFillMode(TOP_TO_BOTTOM)
		
		AddHeaderOption("$Spell Options")
		OIDmagickadrain = AddSliderOption("$Magicka Cost Per Cast (Spell)", IH_MagickaDrainPerSpawn.GetValue(), "{2}")
		OIDstaffdrain = AddSliderOption("$Enchant Charge Per Cast (Staff)", IH_StaffDrainPerSpawn.GetValue(), "{2}")
		OIDexp = AddSliderOption("$Experience Per Cast", IH_CastExp.GetValue(), "{2}")
		OIDnspam = AddToggleOption("$Item Notification Spam", IH_NotificationSpam.GetValue() as bool)
		OIDfood = AddToggleOption("$Harvest Food", IH_LearnFood.GetValue() as bool)
		OIDhf = AddToggleOption("$Harvest Hearthfire", IH_LearnHearthfire.GetValue() as bool)
		
		AddEmptyOption()
		
		AddHeaderOption("$Maintenance")
		OIDrecall = AddTextOption("$Recall Active Critters", "[ ]")
		OIDclear = AddTextOption("$Clear Flora Cache", "[ ]")
		OIDdelete = AddTextOption("$Delete Getter Critters", "[ ]")
		if (IH_SearchMode.GetValue() <= 0.0)
			OIDquestmode = AddMenuOption("$Quest Start Mode", "$Story Manager")
		elseif (IH_SearchMode.GetValue() == 1)
			OIDquestmode = AddMenuOption("$Quest Start Mode", "$Start")
		else
			OIDquestmode = AddMenuOption("$Quest Start Mode", "$skypal")
		endif
		
		SetCursorPosition(1) ; top right
		
		AddHeaderOption("$Getter Critters")
		OIDcrittercap = AddSliderOption("$Max Concurrent Critters", IH_CritterCap.GetValue(), "{0}")
		OIDspawnDist = AddSliderOption("$Spawn Distance Multiplier", IH_SpawnDistanceMult.GetValue(), "{1}")
		OIDreturnOffset = AddSliderOption("$Critter Return Distance Offset", IH_OffsetReturnPoint.GetValue(), "{0}")
		OIDgt = AddToggleOption("$Use Green Thumb", IH_InheritGreenThumb.GetValue() as bool)
		OIDstats = AddTextOption("$Show Critter Stats", "[ ]")
	endif
EndEvent

Event OnOptionSelect(int a_option)
	if (a_option == OIDclear)
		SetTextOptionValue(a_option, "$[Please close menu]", false)
		IH_PersistentData.ClearFloraCaches()
	elseif (a_option == OIDrecall)
		SetTextOptionValue(a_option, "$[Please close menu]", false)
		IH_PersistentData.RecallAllCritters()
	elseif (a_option == OIDdelete)
		SetTextOptionValue(a_option, "$[Please close menu]", false)
		IH_PersistentData.DeleteGetterCritters()
	elseif (a_option == OIDstats)
		SetTextOptionValue(a_option, "$[Please close menu]", false)
		IH_PersistentData.TallyCritterStats()
	elseif (a_option == OIDnspam)
		ToggleGlobal(IH_NotificationSpam, a_option)
	elseif (a_option == OIDgt)
		ToggleGlobal(IH_InheritGreenThumb, a_option)
	elseif (a_option == OIDfood)
		ToggleGlobal(IH_LearnFood, a_option)
	elseif (a_option == OIDhf)
		ToggleGlobal(IH_LearnHearthfire, a_option)
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
	elseif (a_option == OIDstaffdrain)
		SetSliderDialogStartValue(IH_StaffDrainPerSpawn.GetValue())
		SetSliderDialogDefaultValue(12.0)
		SetSliderDialogRange(0.0, 100.0)
		SetSliderDialogInterval(0.25)
	elseif (a_option == OIDmagickadrain)
		SetSliderDialogStartValue(IH_MagickaDrainPerSpawn.GetValue())
		SetSliderDialogDefaultValue(5.0)
		SetSliderDialogRange(0.0, 100.0)
		SetSliderDialogInterval(0.25)
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
	elseif (a_option == OIDstaffdrain)
		IH_StaffDrainPerSpawn.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{2}")
	elseif (a_option == OIDmagickadrain)
		IH_MagickaDrainPerSpawn.SetValue(a_value)
		SetSliderOptionValue(a_option, a_value, "{2}")
	endif
EndEvent

Event OnOptionMenuOpen(int a_option)
	string[] options
	if (a_option == OIDquestmode)
		options = new string[3]
		options[0] = "$Story Manager"
		options[1] = "$Start"
		options[2] = "$skypal"
		SetMenuDialogDefaultIndex(IH_Util.MinI(2, IH_Util.MaxI(0, IH_SearchMode.GetValue() as int)))
		SetMenuDialogStartIndex(IH_SearchMode.GetValue() as int)
		SetMenuDialogOptions(options)
	endif
EndEvent

Event OnOptionMenuAccept(int a_option, int a_index)
	if (a_option == OIDquestmode)
		IH_SearchMode.SetValue(a_index as float)
		if (a_index == 0)
			SetMenuOptionValue(OIDquestmode, "$Story Manager")
		elseif (a_index == 1)
			SetMenuOptionValue(OIDquestmode, "$Start")
		else
			SetMenuOptionValue(OIDquestmode, "$skypal")
			IH_PersistentData.VerifySkypalVersion(true)
		endif
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
	elseif (a_option == OIDhf)
		IH_LearnHearthfire.SetValue(0.0)
		SetToggleOptionValue(a_option, false)
	elseif (a_option == OIDspawnDist)
		OnOptionSliderAccept(a_option, 1.0)
	elseif (a_option == OIDreturnOffset)
		OnOptionSliderAccept(a_option, 150.0)
	elseif (a_option == OIDstaffdrain)
		OnOptionSliderAccept(a_option, 12.0)
	elseif (a_option == OIDmagickadrain)
		OnOptionSliderAccept(a_option, 5.0)
	elseif (a_option == OIDquestmode)
		OnOptionMenuAccept(a_option, 0)
	endif
EndEvent

Event OnOptionHighlight(int a_option)
	if (a_option == OIDcrittercap)
		SetInfoText("$OIDcrittercap_INFO")
	elseif (a_option == OIDrecall)
		SetInfoText("$OIDrecall_INFO")
	elseif (a_option == OIDdelete)
		SetInfoText("$OIDdelete_INFO")
	elseif (a_option == OIDexp)
		SetInfoText("$OIDexp_INFO")
	elseif (a_option == OIDclear)
		SetInfoText("$OIDclear_INFO")
	elseif (a_option == OIDnspam)
		SetInfoText("$OIDnspam_INFO")
	elseif (a_option == OIDgt)
		SetInfoText("$OIDgt_INFO")
	elseif (a_option == OIDfood)
		SetInfoText("$OIDfood_INFO")
	elseif (a_option == OIDhf)
		SetInfoText("$OIDhf_INFO")
	elseif (a_option == OIDspawnDist)
		SetInfoText("$OIDspawnDist_INFO")
	elseif (a_option == OIDreturnOffset)
		SetInfoText("$OIDreturnOffset_INFO")
	elseif (a_option == OIDstats)
		SetInfoText("$OIDstats_INFO")
	elseif (a_option == OIDstaffdrain)
		SetInfoText("$OIDstaffdrain_INFO")
	elseif (a_option == OIDmagickadrain)
		SetInfoText("$OIDmagickadrain_INFO")
	elseif (a_option == OIDquestmode)
		SetInfoText("$OIDquestmode_INFO")
	endif
EndEvent

Function ToggleGlobal(GlobalVariable var, int option)
	bool newState = !(var.GetValue() as bool)
	var.SetValue(newState as float)
	SetToggleOptionValue(option, newState)
EndFunction
