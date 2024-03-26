ScriptName IH_FinderPointerHolderScript extends ObjectReference

IH_PersistentDataScript Property IH_PersistentData Auto
ObjectReference[] Property RefPointer Auto
int[] Property IntPointer Auto

Event OnInit()
	RegisterForSingleUpdate(5.0)
EndEvent

Event OnUpdate()
	RefPointer = IH_PersistentData.FinderThreadResultsRefs
	IntPointer = IH_PersistentData.FinderThreadResultsInts
	IH_Util.Trace(self + " Synced pointers with IH_PersistentData; RefPointer=" + RefPointer + ", IntPointer=" + IntPointer)
EndEvent
