Scriptname IH_FloraLearnerScript extends ReferenceAlias
;/ This script analyzes forms fed to it to determine whether or not those forms are
; harvestable; these forms' base records are remembered permanently, so any given
; base form will only ever be scanned once—or until our memory FormLists are reset.
; Base forms determined to be harvestable are stored in IH_LearnedTypes, which we use to
; filter which ObjectReferences our scripts are allowed to try to harvest in the future.
/;

FormList Property IH_ExaminedTypes Auto
FormList Property IH_LearnedTypes Auto

Event OnInit()
	DoThing()
	Clear()
EndEvent

Function DoThing()
	ObjectReference this = GetReference()
	if (this == None)
		;~_Util.Trace("Learner thread found nothing ");+ retries)
		;/if (retries < 3)
			Utility.Wait(0.01)
			DoThing(retries + 1)
		endif/;
		return
	endif
	
	Form base = this.GetBaseObject()
	IH_ExaminedTypes.AddForm(base)
	
	;IH_Util.Trace("Learner thread examining ref " + this + "/base " + base + "...")
	
	Form ingr = None
	if (base as Ingredient)
		IH_LearnedTypes.AddForm(base)
		IH_Util.Trace("\tLearner: Learned loose ingredient " + this + "/" + base)
		return
	endif
	
	TreeObject thisTree = base as TreeObject
	if (thisTree != None)
		; Most harvestable things are trees instead of flora, I have no idea why this is
		ingr = thisTree.GetIngredient()
		if (ingr != None && IH_Util.ProducesIngredient(ingr))
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
		if (ingr != None && IH_Util.ProducesIngredient(ingr))
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned Flora " + this + "/" + base)
		else
			IH_Util.Trace("\tLearner: Ignoring ingredientless Flora " + this + "/" + base)
		endif
		return
	endif
	
	; Here's where mod compatibility code would have to go to add additional non-vanilla scripts
	Activator thisActivator = base as Activator
	if (thisActivator != None)
		Critter thisCritter = this as Critter
		if (thisCritter != None)
			if (thisCritter.lootableCount > 0 && (thisCritter.lootable || IH_Util.ProducesIngredient(thisCritter.nonIngredientLootable)))
				IH_LearnedTypes.AddForm(base)
				IH_Util.Trace("\tLearner: Learned Critter " + this + "/" + base)
			else
				IH_Util.Trace("\tLearner: Ignoring ingredientless Critter " + this + "/" + base)
			endif
			return
		endif
		FXfakeCritterScript thisFakeCritter = this as FXfakeCritterScript
		if (thisFakeCritter != None)
			if (thisFakeCritter.numberOfIngredientsOnCatch > 0 && thisFakeCritter.myIngredient)
				IH_LearnedTypes.AddForm(base)
				IH_Util.Trace("\tLearner: Learned FXfakeCritterScript " + this + "/" + base)
			else
				IH_Util.Trace("\tLearner: Ignoring ingredientless FXfakeCritterScript " + this + "/" + base)
			endif
			return
		endif
		if (this as NirnrootACTIVATORScript)
			IH_LearnedTypes.AddForm(base)
			IH_Util.Trace("\tLearner: Learned NirnrootACTIVATORScript " + this + "/" + base)
			return
		endif
		
		IH_Util.Trace("\tLearner: Ignoring activator of unknown type " + this + "/" + base)
	endif
EndFunction
