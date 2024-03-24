Scriptname IH_FloraFinderWorkerScript extends ReferenceAlias

IH_PersistentDataScript Property IH_PersistentData Auto

ReferenceAlias Property Caster Auto
Actor Property PlayerRef Auto
ActorBase Property Player Auto

bool Property TriggerOnInit=true Auto
; true = "autonomous" mode, where script is expected to set itself up and then trigger via OnInit()
; false = "manual" mode, where script is configured/triggered by an external script

int Property Index Auto

Actor Property LastCasterRef Auto
ObjectReference Property LastObject Auto

IH_FinderPointerHolderScript Property ArrayPointerHolder Auto
ObjectReference[] Property ReturnArray Auto
int[] Property ErrorArray Auto
; bool arraysFilled = false

Event OnInit()
	if (TriggerOnInit)
		; I tried multithreading this but it simply does not work, it often waits until the OnInit() thread finishes before the update thread starts
		; RegisterForSingleUpdate(0.0)
		
		DoExtraFiltering(GetReference(), Caster.GetReference() as Actor, Index, ArrayPointerHolder.RefPointer, ArrayPointerHolder.IntPointer, PlayerRef, Player, false)
	endif
EndEvent

Function FillAndRun(ObjectReference object, Actor casterRef, int i, ObjectReference[] refArray, int[] intArray)
	Index = i
	LastObject = object
	LastCasterRef = casterRef
	ReturnArray = refArray
	ErrorArray = intArray
	; arraysFilled = true
	RegisterForSingleUpdate(0.0)
EndFunction

Event OnUpdate()
	; if (TriggerOnInit)
	; 	IH_Util.Trace(self + " arrays? " + arraysFilled)
	; 	; in automatic mode, this data needs to be filled in here while OnInit() triggers DoExtraFiltering()
	; 	if (arraysFilled == false)
	; 		ReturnArray = ArrayPointerHolder.RefPointer
	; 		ErrorArray = ArrayPointerHolder.IntPointer
	; 		; arraysFilled = true
	; 	endif
	; else
	
	; in manual mode, the thread effectively starts here, and not OnInit()
	DoExtraFiltering(LastObject, LastCasterRef, Index, ReturnArray, ErrorArray, PlayerRef, Player, true)
EndEvent

Function DoExtraFiltering(ObjectReference this, Actor casterRef, int i, ObjectReference[] rA, int[] iA, Actor PlayerRef, ActorBase Player, bool ignoreOwnership) Global
	; IH_Util.Trace("ref: " + (self.GetOwningQuest().GetAlias(0) as ReferenceAlias).GetReference())
	if (this == None)
	;	IH_Util.Trace("\t" + self + " GetReference() is null.")
		; UpdateOwner(None, 1, i, rA, iA)
		rA[i] = this
		iA[i] = 1
		return
	endif
	Form base = this.GetBaseObject()
	
	; IH_Util.Trace("\t" + self + " filled with ref " + this + ", base " + base)
	
	; test if activation is blocked (this is probably almost never an issue,
	; but hey this code is all multithreaded anyway so there's no harm in checking)
	if (base as Activator)
		; v1.0.8: Ignore this setting for activators, because blocking activation on an activator
		; does almost nothing anyway, and it prevents poison blooms from being harvested unless
		; the unofficial patch version of DLC1TrapPoisonBloom is installed
	elseif (this.IsActivationBlocked())
		; UpdateOwner(this, 2, i, rA, iA)
		rA[i] = this
		iA[i] = 2
		return
	endif
	
	;;Story manager should preclude these
	;if (this.IsDisabled() || this.IsDeleted())
	;	; UpdateOwner(this, 3, i, rA, iA)
	;	rA[i] = this
	;	iA[i] = 3
	;	return
	;endif
	
	; test if object is already harvested
	bool isTree = (base as TreeObject) != None
	if (((isTree || base as Flora) && this.IsHarvested()) || this.GetState() == "harvested")
		; UpdateOwner(this, 4, i, rA, iA)
		rA[i] = this
		iA[i] = 4
		return
	endif
	
	if (ignoreOwnership)
		rA[i] = this
		iA[i] = 0
		return
	endif
	
	; now test if taking object would be stealing
	
	; cell inherited ownership checking, first check cell faction ownership (most common)
	; Actor casterRef
	ActorBase casterBase
	Cell thisCell = this.GetParentCell()
	Faction thisCellFaction = thisCell.GetFactionOwner()
	if (thisCellFaction != None)
		; casterRef = Caster.GetReference() as Actor
		if (!casterRef.IsInFaction(thisCellFaction))
			; UpdateOwner(this, 6, i, rA, iA)
			rA[i] = this
			iA[i] = 6
			return
		endif
	endif
	
	; continue cell inherited ownership, check cell actor owner
	ActorBase thisCellOwner = thisCell.GetActorOwner()
	if (thisCellOwner != None)
		; if (casterRef == None)
		;	casterRef = Caster.GetReference() as Actor
		; endif
		if (casterRef == PlayerRef)
			; skip GetBaseObject() on the player ref, which would be very slow
			casterBase = Player
		else
			casterBase = casterRef.GetBaseObject() as ActorBase
		endif
		if (thisCellOwner != casterBase)
			; UpdateOwner(this, 6, i, rA, iA)
			rA[i] = this
			iA[i] = 6
			return
		endif
	endif
	
	if (!isTree)
		; trees cannot have per-object ownership data set, so we can skip the rest of the checks
		
		; now check if the item is owned by the caster's faction
		Faction factionOwner = this.GetFactionOwner()
		if (factionOwner != None && factionOwner != thisCellFaction) ; thisCellFaction already tested
			; if (casterRef == None)
			;	casterRef = Caster.GetReference() as Actor
			; endif
			if (!casterRef.IsInFaction(factionOwner))
				; UpdateOwner(this, 5, i, rA, iA)
				rA[i] = this
				iA[i] = 5
				return
			endif
		endif
		
		; finally check if the item is owned by the caster directly
		ActorBase owner = this.GetActorOwner()
		if (owner != None)
			; if (casterRef == None)
			;	casterRef = Caster.GetReference() as Actor
			; endif
			if (casterBase == None)
				if (casterRef == PlayerRef)
					casterBase = Player
				else
					casterBase = casterRef.GetBaseObject() as ActorBase
				endif
			endif
			if (owner != casterBase)
				; UpdateOwner(this, 5, i, rA, iA)
				rA[i] = this
				iA[i] = 5
				return
			endif
		endif
	endif
	
	; This looks like a valid object, so update our persistent data script and finish
	; UpdateOwner(this, 0)
	rA[i] = this
	iA[i] = 0
EndFunction

; Decided to inline this since it only runs 2 very short lines at this point anyway
;Function UpdateOwner(ObjectReference thing, int err, i, rA, iA) Global
;	; IH_Util.Trace("Updating owner " + IH_PersistentData + " with " + thing + ", " + err)
;	; int i = 0
;	; while (arraysFilled == false && i < 50)
;	; 	Utility.WaitMenuMode(0.033)
;	; 	i += 1
;	; endwhile
;	
;	rA[i] = thing
;	iA[i] = err
;EndFunction
