ScriptName IH_FinderPointerHolderScript extends ObjectReference

IH_PersistentDataScript Property IH_PersistentData Auto
ObjectReference[] Property RefPointer Auto
int[] Property IntPointer Auto

Event OnInit()
	RefPointer = IH_PersistentData.FinderThreadResultsRefs
	IntPointer = IH_PersistentData.FinderThreadResultsInts
	IH_Util.Trace(self + " Initialized; RefPointer=" + RefPointer + ", IntPointer=" + IntPointer)
EndEvent
