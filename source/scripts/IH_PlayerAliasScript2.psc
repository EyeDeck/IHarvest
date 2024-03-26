Scriptname IH_PlayerAliasScript2 extends ReferenceAlias

IH_PersistentDataScript Property IH_PersistentData Auto

Event OnInit()
	self.ForceRefTo(Game.GetPlayer())
	RegisterForSingleUpdate(1.0)
EndEvent

Event OnPlayerLoadGame()
	RegisterForSingleUpdate(1.0)
EndEvent

Event OnUpdate()
	Debug.OpenUserLog("IHarvest")
	IH_PersistentData.OnGameLoad()
EndEvent
