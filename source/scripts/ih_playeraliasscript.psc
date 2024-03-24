Scriptname IH_PlayerAliasScript extends ReferenceAlias

IH_PersistentDataScript Property IH_PersistentData Auto

Function OnInit()
	RegisterForSingleUpdate(1.0)
EndFunction

Event OnPlayerLoadGame()
	RegisterForSingleUpdate(1.0)
EndEvent

Event OnUpdate()
	IH_PersistentData.CheckUpdates()
EndEvent
