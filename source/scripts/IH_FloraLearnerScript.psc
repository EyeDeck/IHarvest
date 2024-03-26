Scriptname IH_FloraLearnerScript extends ReferenceAlias
;/ Current list of soft dependencies for compiling:
;	- DLC1TrapPoisonBloom from Dawnguard
;	- USKP_NirnrootACTIVATORScript from USKP (bug #15589)
;	- BSKWispStalkACTIVATORScript from Beyond Skyrim - Bruma
;	- wispCoreScript_lyu from Harvest Overhaul Redone
; For each of these, an empty script in \Source with just the header will work, e.g.
;	Scriptname DLC1TrapPoisonBloom extends ObjectReference
; Then just save them as <scriptname>.psc and the compiler should stop complaining.
;
; This script analyzes forms fed to it to determine whether or not those forms are
; harvestable; these forms' base records are remembered permanently, so any given
; base form will only ever be scanned once—or until our memory FormLists are reset.
; Base forms determined to be harvestable are stored in IH_LearnedTypes, which we use to
; filter which ObjectReferences our scripts are allowed to try to harvest in the future.
/;

FormList Property IH_ExaminedTypes Auto
FormList Property IH_LearnedTypes Auto

GlobalVariable Property IH_LearnFood Auto
GlobalVariable Property IH_LearnHearthfire Auto

IH_FloraLearnerControllerScript Property IH_FloraLearnerController Auto ; v1.0.5: added a callback

Event OnInit()
	DoThing()
	Clear()
	IH_FloraLearnerController.LearnerCallback()
EndEvent

Function DoThing()
	ObjectReference this = GetReference()
	if (this == None)
		return
	endif
	Form base = this.GetBaseObject()
	IH_ExaminedTypes.AddForm(base)
	
	; IH_Util.Trace("Learner thread examining ref " + this + "/base " + base + "...")
	
	if (ShouldLearnRef(this, base, (IH_LearnFood.GetValue() > 0.0), (IH_LearnHearthfire.GetValue() > 0.0)))
		IH_LearnedTypes.AddForm(base)
	endif
EndFunction

bool Function ShouldLearnBase(Form base, bool learnFood, bool learnHF) global
	Form ingr = None
	if (base as Ingredient)
		IH_Util.Trace("\tLearner: Learned loose ingredient " + base)
		return true
	endif
	
	if (learnFood)
		Potion thisPotion = base as Potion
		if (thisPotion)
			if (thisPotion.IsFood())
				IH_Util.Trace("\tLearner: Learned loose food " + base)
				return true
			else
				IH_Util.Trace("\tLearner: Ignoring loose non-food potion " + base)
				return false
			endif
		endif
	endif
	
	TreeObject thisTree = base as TreeObject
	if (thisTree != None)
		; Most harvestable things are trees instead of flora, I have no idea why this is
		ingr = thisTree.GetIngredient()
		if (ingr != None && IH_Util.ProducesIngredient(ingr, learnFood, learnHF))
			IH_Util.Trace("\tLearner: Learned TreeObject " + base)
			return true
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless TreeObject " + base)
			return false
		endif
	endif
	
	Flora thisFlora = base as Flora
	if (thisFlora != None)
		ingr = thisFlora.GetIngredient()
		if (ingr != None && IH_Util.ProducesIngredient(ingr, learnFood, learnHF))
			IH_Util.Trace("\tLearner: Learned Flora " + base)
			return true
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless Flora " + base)
			return false
		endif
	endif
	
	return false
EndFunction

bool Function ShouldLearnActivator(ObjectReference this, Form base, bool learnFood, bool learnHF) global
	Critter thisCritter = this as Critter
	if (thisCritter != None)
		if (thisCritter.lootableCount > 0 && (thisCritter.lootable || IH_Util.ProducesIngredient(thisCritter.nonIngredientLootable, learnFood, learnHF)))
			IH_Util.Trace("\tLearner: Learned Critter " + this + "/" + base)
			return true
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless Critter " + this + "/" + base)
			return false
		endif
	endif
	
	FXfakeCritterScript thisFakeCritter = this as FXfakeCritterScript
	if (thisFakeCritter != None)
		if ((thisFakeCritter.numberOfIngredientsOnCatch > 0 && thisFakeCritter.myIngredient) || (learnFood && thisFakeCritter.myFood))
			IH_Util.Trace("\tLearner: Learned FXfakeCritterScript " + this + "/" + base)
			return true
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless FXfakeCritterScript " + this + "/" + base)
			return false
		endif
	endif
	
	if (this as NirnrootACTIVATORScript || this as USKP_NirnrootACTIVATORScript)
		; unofficial patch adds an additional nirnroot script, used at Sarethi Farm
		IH_Util.Trace("\tLearner: Learned NirnrootACTIVATORScript " + this + "/" + base)
		return true
	endif
	
	DLC1TrapPoisonBloom thisPB = this as DLC1TrapPoisonBloom
	if (thisPB != None)
		if (thisPB.myIngredient != None || IH_Util.ProducesIngredient(thisPB.myMiscObject, learnFood, learnHF) || IH_Util.ProducesIngredient(thisPB.myPotion, learnFood, learnHF))
			IH_Util.Trace("\tLearner: Learned DLC1TrapPoisonBloom " + this + "/" + base)
			return true
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless DLC1TrapPoisonBloom " + this + "/" + base)
			return false
		endif
	endif
	
	ccBGSSSE025_HarvestableActivator thisCCSS = this as ccBGSSSE025_HarvestableActivator
	if (thisCCSS != None)
		if (thisCCSS.itemToHarvest != None || thisCCSS.leveledRareCuriosItem != None && IH_Util.ProducesIngredient(thisCCSS.leveledRareCuriosItem, learnFood, learnHF))
			IH_Util.Trace("\tLearner: Learned ccBGSSSE025_HarvestableActivator " + this + "/" + base)
			return true
		else
			return false
		endif
	endif
	
	if (this as wispCoreScript || this as wispCoreScript_lyu)
		; wispCoreScript_lyu is from Harvest Overhaul Redone
		IH_Util.Trace("\tLearner: Learned wispCoreScript " + this + "/" + base)
		return true
	endif
	
	; Here's where the learner system can be made compatibile with non-vanilla activators,
	; without having to add hard plugin dependencies, like so
	
	; Beyond Skyrim - Bruma: Wisp Stalks (looks like they're scripted activators because they also control a light source)
	if (this as BSKWispStalkACTIVATORScript)
		IH_Util.Trace("\tLearner: Learned BSKWispStalkACTIVATORScript " + this + "/" + base)
		return true
	endif
	
	IH_Util.Trace("\tLearner: Ignoring activator of unknown type " + this + "/base " + base)
	return false
EndFunction

bool Function ShouldLearnRef(ObjectReference this, Form base, bool learnFood, bool learnHF) global
	; this handles anything -not- an activator, which only need base types
	if (ShouldLearnBase(base, learnFood, learnHF))
		return true
	endif
	
	if (base as Activator && ShouldLearnActivator(this, base, learnFood, learnHF))
		return true
	endif
	
	return false
EndFunction
