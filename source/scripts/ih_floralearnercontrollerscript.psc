Scriptname IH_FloraLearnerControllerScript extends Quest  

Actor Property PlayerRef Auto

Quest Property IH_FloraLearner Auto
Quest Property IH_FloraLearnerSM Auto

; GlobalVariable Property IH_LearnerRunning Auto ; v1.0.9: deprecated, hasn't been useful since v1.0.4
GlobalVariable Property IH_UseStartFunc Auto
Message Property IH_StoryManagerHighLoad Auto
Keyword Property IH_SMKeyword Auto

Formlist Property IH_ExaminedTypes Auto
Formlist Property IH_LearnedTypes Auto

Cell Property LastCell
	; full property because I needed to be able to externally clear this and mantain backwards compatibility
	Function Set(Cell value)
		lastLearnedCell = value
	EndFunction

	Cell Function Get()
		return lastLearnedCell
	EndFunction
EndProperty

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
;		IH_LearnerRunning.SetValue(1.0)
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
;		IH_LearnerRunning.SetValue(0.0)
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

Function VerifyState()
	int i = 0
	; wait for the quest to stop on its own; if that doesn't happen, force kill it and reset states manually
	while (i < 5 && GetState() != "Ready")
		Utility.Wait(0.5)
		i += 1
	endwhile
	if (i >= 5)
		IH_Util.Trace("FloraLearnerController stuck in state " + GetState() + ", resetting.", 1)
		Stop()
		Start()
		GoToState("Ready")
	else
		IH_Util.Trace("FloraLearnerController state " + GetState() + " seems fine.")
	endif
	if (IH_UseStartFunc.GetValue() as bool)
		IH_FloraLearner.Stop()
	else
		IH_FloraLearnerSM.Stop()
	endif
EndFunction

Function RunLearnerThreads()
	int i
	unfinishedThreads = 4
	bool startMode = IH_UseStartFunc.GetValue() as bool
	
	if (startMode)
		if (!IH_FloraLearner.Start()) 
			; try stopping and restarting I guess
			IH_FloraLearner.Stop()
			Utility.Wait(0.1)
			return
		endif
	else
		IH_SMKeyword.SendStoryEvent(aiValue2 = 2)
		
		i = 0
		while (i < 50 && !IH_FloraLearnerSM.IsRunning()) ; 5 second timeout
			Utility.WaitMenuMode(0.1)
			i += 1
		endwhile
		
		if (i == 50)
			IH_StoryManagerHighLoad.Show()
			IH_FloraLearnerSM.Stop()
			Utility.Wait(0.1)
			return
		endif
	endif
	
	i = 0
	while (unfinishedThreads > 0 && i < 25)
		Utility.wait(0.1)
		i += 1
	endwhile
	if (i >= 25)
		IH_Util.Trace("Detected that FloraLearnerController may be stuck, testing...")
		VerifyState()
	endif
	
	if (startMode)
		IH_FloraLearner.Stop()
	else
		IH_FloraLearnerSM.Stop()
	endif
EndFunction
