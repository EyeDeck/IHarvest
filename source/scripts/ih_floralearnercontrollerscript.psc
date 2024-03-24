Scriptname IH_FloraLearnerControllerScript extends Quest  

Actor Property PlayerRef Auto

Quest Property IH_FloraLearner Auto

GlobalVariable Property IH_LearnerRunning Auto

Formlist Property IH_ExaminedTypes Auto
Formlist Property IH_LearnedTypes Auto

int lastExaminedTypesSize = 0
int unfinishedThreads = 0
Cell lastLearnedCell

Event OnInit()
	GoToState("Ready")
EndEvent

State Ready
	Function Run()
		RegisterForSingleUpdate(0.0) ; new thread so caller can get back to business
	EndFunction
	
	Event OnUpdate()
		IH_LearnerRunning.SetValue(1.0)
		GoToState("Busy")
		
		int examinedTypesSize = IH_ExaminedTypes.GetSize()
		Cell currentCell = PlayerRef.GetParentCell()
		
		; did the last run not find anything, or was it cast with the same cells loaded?
		; if yes to both, don't bother running, because starting that quest is very expensive (and potentially crashy)
		if (lastExaminedTypesSize != examinedTypesSize || currentCell != lastLearnedCell)
			IH_Util.Trace("Starting learner threads; cell: " + currentCell + " / last count: " + examinedTypesSize)
			RunLearnerThreads()
			
			; Allegedly the game can crash or freeze if a quest is restarted immediately after being stopped,
			; so we force a short delay here to ensure stability
			RegisterForSingleUpdate(0.1)
		;else
		;	IH_Util.Trace("Skipping/ending learner routine; cell: " + currentCell + " / last count: " + examinedTypesSize)
		endif
		
		lastExaminedTypesSize = examinedTypesSize
		lastLearnedCell = currentCell
		
		GoToState("Ready")
		IH_LearnerRunning.SetValue(0.0)
	EndEvent
EndState

State Busy
	; OnUpdate events deliberately ignored
EndState

Function Run()
EndFunction

Function LearnerCallback()
	unfinishedThreads -= 1
EndFunction

Function RunLearnerThreads()
	unfinishedThreads = 4
	IH_FloraLearner.Start()
	
	while (unfinishedThreads > 0)
		Utility.wait(0.1)
	endwhile
	
	IH_FloraLearner.Stop()
EndFunction
