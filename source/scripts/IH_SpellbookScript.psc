Scriptname IH_SpellbookScript extends ObjectReference  

float Property readDespawnChance = 0.8 Auto
{Chance that placed refs will despawn on load if the player has already read the spellbook
(because I placed a ton of spellbooks by hand and don't need users complaining about how
 common they are, but I don't actually want to remove any of those spawns—so we'll fudge
 it and make the player think they were just lucky to find a spellbook so quickly; they'll
 never know the difference unless they read this note anyway) }

Event OnLoad()
	if ((self.GetBaseObject() as Book).IsRead() == false)
		return
	endif
	
	if (Utility.RandomFloat(0.0, 1.0) < readDespawnChance)
		self.Disable()
	endif
	
	GoToState("done")
EndEvent

Event OnActivate(ObjectReference akActionRef)
	GoToState("done")
EndEvent

State done
	Event OnLoad()
	EndEvent
	
	Event OnActivate(ObjectReference akActionRef)
	EndEvent
EndState
