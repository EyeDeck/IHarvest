Scriptname IH_FloraFinderWorkerScript extends ReferenceAlias

IH_PersistentDataScript Property IH_PersistentData Auto

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
	if ((base as TreeObject || base as Flora) && this.IsHarvested())
		UpdateOwner(this, 4)
		return
	endif
	; test if taking object would be stealing
	if (this.GetFactionOwner() != None || this.GetActorOwner() != None)
		; Interacting with this might be stealing, so leave it alone
		UpdateOwner(this, 5)
		return
	endif
	Cell thisCell = this.GetParentCell()
	if (thisCell.GetFactionOwner() != None || thisCell.GetActorOwner() != None)
		UpdateOwner(this, 6)
		return
	endif
	
	; This looks like a valid object, so update our persistent data script and finish
	UpdateOwner(this, 0)
EndEvent

Function UpdateOwner(ObjectReference thing, int err)
	IH_PersistentData.FloraFinderUpdate(thing, err)
	self.Clear()
EndFunction
