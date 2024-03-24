Scriptname IH_FloraFinderWorkerScript extends ReferenceAlias

IH_PersistentDataScript Property IH_PersistentData Auto

ReferenceAlias Property Caster Auto
Actor Property PlayerRef Auto
ActorBase Property Player Auto

Event OnInit()
	ObjectReference this = GetReference()
	
	if (this == None)
		;IH_Util.Trace(self + " GetReference() is null.")
		UpdateOwner(None, 1)
		return
	endif
	Form base = this.GetBaseObject()
	
	; test if activation is blocked (this is probably almost never an issue,
	; but hey this code is all multithreaded anyway so there's no harm in checking)
	if (this.IsActivationBlocked())
		UpdateOwner(this,2)
		return
	endif
	
	;/ Story manager should preclude these
	if (this.IsDisabled() || this.IsDeleted())
		UpdateOwner(this,3)
		return
	endif/;
	
	; test if object is already harvested
	bool isTree = (base as TreeObject) != None
	if ((isTree || base as Flora) && this.IsHarvested())
		UpdateOwner(this, 4)
		return
	endif
	
	; test if taking object would be stealing
	
	; cell inherited ownership checking, first check cell faction ownership (most common)
	Actor casterRef
	ActorBase casterBase
	Cell thisCell = this.GetParentCell()
	Faction thisCellFaction = thisCell.GetFactionOwner()
	if (thisCellFaction != None)
		casterRef = Caster.GetReference() as Actor
		if (!casterRef.IsInFaction(thisCellFaction))
			UpdateOwner(this, 6)
			return
		endif
	endif
	
	; continue cell inherited ownership, check cell actor owner
	ActorBase thisCellOwner = thisCell.GetActorOwner()
	if (thisCellOwner != None)
		if (casterRef == None)
			casterRef = Caster.GetReference() as Actor
		endif
		if (casterRef == PlayerRef)
			; skip GetBaseObject() on the player ref, which would be very slow
			casterBase = Player
		else
			casterBase = casterRef.GetBaseObject() as ActorBase
		endif
		if (thisCellOwner != casterBase)
			UpdateOwner(this, 6)
			return
		endif
	endif
	
	if (!isTree)
		; trees cannot have per-object ownership data set, so we can skip the rest of the checks
		
		; now check if the item is owned by the caster's faction
		Faction factionOwner = this.GetFactionOwner()
		if (factionOwner != None && factionOwner != thisCellFaction) ; thisCellFaction already tested
			if (casterRef == None)
				casterRef = Caster.GetReference() as Actor
			endif
			if (!casterRef.IsInFaction(factionOwner))
				UpdateOwner(this, 5)
				return
			endif
		endif
		
		; finally check if the item is owned by the caster directly
		ActorBase owner = this.GetActorOwner()
		if (owner != None)
			if (casterRef == None)
				casterRef = Caster.GetReference() as Actor
			endif
			if (casterBase == None)
				if (casterRef == PlayerRef)
					casterBase = Player
				else
					casterBase = casterRef.GetBaseObject() as ActorBase
				endif
			endif
			if (owner != casterBase)
				UpdateOwner(this, 5)
				return
			endif
		endif
	endif
	
	; This looks like a valid object, so update our persistent data script and finish
	UpdateOwner(this, 0)
EndEvent

Function UpdateOwner(ObjectReference thing, int err)
	IH_PersistentData.FloraFinderUpdate(thing, err)
	self.Clear()
EndFunction
