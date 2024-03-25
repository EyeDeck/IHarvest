Scriptname IH_FloraFinderScript extends Quest  

IH_PersistentDataScript Property IH_PersistentData Auto

Event OnStoryScript(Keyword akKeyword, Location akLocation, ObjectReference akRef1, ObjectReference akRef2, int aiValue1, int aiValue2)
	; IH_Util.Trace("Got OnStoryScript " + akKeyword + " " + akRef1 + " " + aiValue1)
	IH_PersistentData.FloraFinderCallback(aiValue1)
EndEvent
