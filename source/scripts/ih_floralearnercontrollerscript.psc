Scriptname IH_FloraLearnerControllerScript extends Quest  

Actor Property PlayerRef Auto

Quest Property IH_FloraLearnerStart Auto
Quest Property IH_FloraLearnerSM Auto

; GlobalVariable Property IH_LearnerRunning Auto ; v1.0.9: deprecated, hasn't been useful since v1.0.4
GlobalVariable Property IH_SearchMode Auto

GlobalVariable Property IH_LearnFood Auto
GlobalVariable Property IH_LearnHearthfire Auto

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
		
		int startMode = IH_SearchMode.GetValue() as int
		int examinedTypesSize = IH_ExaminedTypes.GetSize()
		if (startMode < 2)
			Cell currentCell = PlayerRef.GetParentCell()
			
			; did the last run not find anything, or was it cast with the same cells loaded?
			; if yes to both, don't bother running, because starting that quest is very expensive (and potentially crashy)
			if (lastExaminedTypesSize != examinedTypesSize || currentCell != lastLearnedCell)
				IH_Util.Trace("Starting learner threads; cell: " + currentCell + " / last count: " + examinedTypesSize)
				
				if (startMode == 0)
					RunLearnerSMEvent()
					RegisterForSingleUpdate(0.1) ; restart after a short delay, for stability
				elseif (startMode == 1)
					RunLearnerStart()
					RegisterForSingleUpdate(0.1)
				endif
			endif
			
			lastLearnedCell = currentCell
		else
			IH_Util.Trace("Starting skypal learner routine / last count: " + examinedTypesSize)
			RunLearnerSkypal()
		endif
		lastExaminedTypesSize = examinedTypesSize
		
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
	if (IH_SearchMode.GetValue() == 1)
		IH_FloraLearnerStart.Stop()
	else
		IH_FloraLearnerSM.Stop()
	endif
EndFunction

bool Function WaitForThreads(int timeout)
	int i = 0
	while (unfinishedThreads > 0 && i < timeout)
		Utility.wait(0.1)
		i += 1
	endwhile
	if (i >= timeout)
		return false
	else
		return true
	endif
EndFunction

Function RunLearnerSkypal()
	bool learnFood = IH_LearnFood.GetValue() > 0.0
	bool learnHF = IH_LearnHearthfire.GetValue() > 0.0
	
	int[] formTypes = new int[3] ; see SKSE's GameForms.h for indices
	formTypes[0] = 0x26 ; Tree
	formTypes[1] = 0x27 ; Flora
	formTypes[2] = 0x1E ; Ingredient
	ObjectReference[] grid = skypal_references.Grid()
	
	ObjectReference[] refs = skypal_references.Filter_Base_Form_Types(grid, formTypes, "")
	refs = skypal_references.Filter_Bases_Form_List(refs, IH_ExaminedTypes, "!")
	Form[] bases = skypal_bases.From_References(refs, ".")
	IH_Util.AddFormsToFormList(bases, IH_ExaminedTypes)
	
	; IH_Util.Trace("refs to process:" + refs)
	
	int i = 0
	int len = bases.Length
	while (i < len)
		Form base = bases[i]
		; IH_Util.Trace("	processing:" + base)
		if (IH_FloraLearnerScript.ShouldLearnBase(base, learnFood, learnHF))
			IH_LearnedTypes.AddForm(base)
		endif
		i += 1
	endwhile
	
	formTypes = new int[1]
	formTypes[0] = 0x18 ; Activator
	refs = skypal_references.Filter_Base_Form_Types(grid, formTypes, "")
	
	; IH_Util.Trace("activators to process:" + refs)
	
	while (refs.Length > 0)
		refs = skypal_references.Filter_Bases_Form_List(refs, IH_ExaminedTypes, "!")
		bases = skypal_bases.From_References(refs, "...")
		i = 0
		while (i < IH_Util.MinI(4, refs.Length))
			Form base = bases[i]
			IH_ExaminedTypes.AddForm(base)
			; IH_Util.Trace("	processing:" + refs[i] + ", " + base)
			if (IH_FloraLearnerScript.ShouldLearnActivator(refs[i], base, learnFood, learnHF))
				IH_LearnedTypes.AddForm(base)
			endif
			i += 1
		endwhile
	endwhile
EndFunction

Function RunLearnerSMEvent()
	unfinishedThreads = 4
	
	IH_SMKeyword.SendStoryEvent(aiValue2 = 2)
	
	int i = 0
	while (i < 50 && !IH_FloraLearnerSM.IsRunning()) ; 5 second timeout
		Utility.Wait(0.1)
		i += 1
	endwhile
	
	if (i == 50)
		IH_StoryManagerHighLoad.Show()
		IH_FloraLearnerSM.Stop()
		Utility.Wait(0.1)
		return
	endif
	
	if (WaitForThreads(25) == false) ; 2.5s
		VerifyState()
	endif
	
	IH_FloraLearnerSM.Stop()
EndFunction

Function RunLearnerStart()
	unfinishedThreads = 4
	
	if (!IH_FloraLearnerStart.Start()) 
		; try stopping and restarting I guess
		IH_FloraLearnerStart.Stop()
		Utility.Wait(0.1)
		return
	endif
	
	if (WaitForThreads(25) == false) ; 2.5s
		VerifyState()
	endif
	
	IH_FloraLearnerStart.Stop()
EndFunction
