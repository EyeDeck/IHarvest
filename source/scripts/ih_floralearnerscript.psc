Scriptname IH_FloraLearnerScript extends ReferenceAlias
;/ Current list of soft dependencies for compiling:
;	- DLC1TrapPoisonBloom from Dawnguard
;	- USKP_NirnrootACTIVATORScript from USKP (bug #15589)
;	- BSKWispStalkACTIVATORScript from Beyond Skyrim - Bruma
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

IH_FloraLearnerControllerScript Property IH_FloraLearnerController Auto ; v1.0.5: added a callback

Event OnInit()
	DoThing()
	Clear()
	IH_FloraLearnerController.LearnerCallback()
EndEvent

Function DoThing()
	ObjectReference this = GetReference()
	if (this == None)
		;~_Util.Trace("Learner thread found nothing")
		return
	endif
	
	Form base = this.GetBaseObject()
	; IH_Util.Trace("\tLearner: IH_ExaminedTypes.HasForm(" + base + "): " + IH_ExaminedTypes.HasForm(base))
	; this frequently comes back true, not sure why because the condition functions for filling the alias
	; ought to prevent that... doesn't break anything I guess, but does annoy me.
	IH_ExaminedTypes.AddForm(base)
	
	;IH_Util.Trace("Learner thread examining ref " + this + "/base " + base + "...")
	
	Form ingr = None
	if (base as Ingredient)
		IH_LearnedTypes.AddForm(base)
		IH_Util.Trace("\tLearner: Learned loose ingredient " + this + "/" + base)
		return
	endif
	
	bool learnFood = IH_LearnFood.GetValue() > 0.0
	if (learnFood)
		Potion thisPotion = base as Potion
		if (thisPotion && thisPotion.IsFood())
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned loose food " + this + "/" + base)
			return
		endif
	endif
	
	TreeObject thisTree = base as TreeObject
	if (thisTree != None)
		; Most harvestable things are trees instead of flora, I have no idea why this is
		ingr = thisTree.GetIngredient()
		if (ingr != None && IH_Util.ProducesIngredient(ingr, learnFood))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned TreeObject " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless TreeObject " + this + "/" + base)
		endif
		return
	endif
	Flora thisFlora = base as Flora
	if (thisFlora != None)
		ingr = thisFlora.GetIngredient()
		if (ingr != None && IH_Util.ProducesIngredient(ingr, learnFood))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned Flora " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless Flora " + this + "/" + base)
		endif
		return
	endif
	
	Activator thisActivator = base as Activator
	if (thisActivator == None)
		IH_Util.Trace("\tLearner: Ignoring activator of unknown type " + this + "/" + base)
		return
	endif
	
	;/ =========================== \;
	;		Here be Activators		;
	;\ =========================== /;
	
	Critter thisCritter = this as Critter
	if (thisCritter != None)
		if (thisCritter.lootableCount > 0 && (thisCritter.lootable || IH_Util.ProducesIngredient(thisCritter.nonIngredientLootable, learnFood)))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned Critter " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless Critter " + this + "/" + base)
		endif
		return
	endif
	
	FXfakeCritterScript thisFakeCritter = this as FXfakeCritterScript
	if (thisFakeCritter != None)
		if ((thisFakeCritter.numberOfIngredientsOnCatch > 0 && thisFakeCritter.myIngredient) || (learnFood && thisFakeCritter.myFood))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned FXfakeCritterScript " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless FXfakeCritterScript " + this + "/" + base)
		endif
		return
	endif
	
	DLC1TrapPoisonBloom thisPB = this as DLC1TrapPoisonBloom
	if (thisPB != None)
		if (thisPB.myIngredient != None || IH_Util.ProducesIngredient(thisPB.myMiscObject, learnFood) || IH_Util.ProducesIngredient(thisPB.myPotion, learnFood))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned DLC1TrapPoisonBloom " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless DLC1TrapPoisonBloom " + this + "/" + base)
		endif
		return
	endif
	
	if (this as NirnrootACTIVATORScript || this as USKP_NirnrootACTIVATORScript )
		; unofficial patch adds an additional nirnroot script, used at Sarethi Farm
		IH_LearnedTypes.AddForm(base)
		IH_Util.Trace("\tLearner: Learned NirnrootACTIVATORScript " + this + "/" + base)
		return
	endif
	
	; Here's where the learner system can be made compatibile with non-vanilla activators,
	; without having to add hard plugin dependencies, like so
	
	; Beyond Skyrim - Bruma: Wisp Stalks (looks like they're scripted activators because they also control a light source)
	if (this as BSKWispStalkACTIVATORScript)
		IH_LearnedTypes.AddForm(base)
		IH_Util.Trace("\tLearner: Learned BSKWispStalkACTIVATORScript " + this + "/" + base)
		return
	endif
EndFunction
