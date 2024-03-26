Scriptname IH_PersistentDataScript extends Quest

Actor Property PlayerRef Auto
ActorBase Property Player Auto

IH_FloraLearnerControllerScript Property IH_FloraLearnerController Auto

bool Property CanShowMismatchWarning = true Auto

Message Property IH_SKSENotInstalled		Auto
Message Property IH_SKSENotRunning			Auto
Message Property IH_SKSEMismatch			Auto
Message Property IH_Update					Auto
Message Property IH_UpdateUnsupported		Auto
Message Property IH_StoryManagerHighLoad	Auto
Message Property IH_SkyPalNotWorking		Auto
Message Property IH_SkyPalOutOfDate			Auto
Message Property IH_ModReset				Auto

Message Property IH_StatsDisplay			Auto
Message Property IH_OperationFinishedCache	Auto
Message Property IH_OperationFinishedRecall	Auto
Message Property IH_OperationFinishedDelete	Auto

FormList Property IH_SpawnableBase_01		Auto
; Forgot to fill this when I first added it, so need a new property now

GlobalVariable Property IH_CurrentSearchRadius Auto
GlobalVariable Property IH_CritterCap Auto
GlobalVariable Property IH_SetPlayerNotPushable Auto ; never managed to get this to work
GlobalVariable Property IH_SearchMode Auto

GlobalVariable Property IH_LearnHearthfire Auto

; VisualEffect Property IH_PlayerCapsuleEffect Auto

float Property cacheDecayRate = 5.0 Auto
{The oldest entry in our ignore cache will be popped out once every <this many> seconds.
 This prevents our quest from persisting loads of objects when it isn't necessary.
 With a full cache of size 256, it will take about 20 minutes to fully empty at default 5.}
int Property cacheSize = -1 Auto
{Should be set manually, but the script will attempt to set it correctly if not specified}
int Property pathAliasCount = 64 Auto

Keyword Property IH_SMKeyword Auto
IH_FloraFinderScript Property IH_FloraFinderSM Auto
IH_FloraFinderScript Property IH_FloraFinderStart Auto
IH_FloraFinderScript Property IH_FloraFinderSkypal Auto
IH_FloraFinderWorkerScript[] Property IH_FloraFinderWorkersSkypal Auto
; Quest Property IH_FloraLearner Auto

Keyword Property IH_IgnoreObject Auto

Formlist Property IH_ExaminedTypes Auto
Formlist Property IH_LearnedTypes Auto

ActorBase Property IH_GetterCritter Auto
ActorBase Property IH_GetterCritterGT Auto
{Same as above except these critters have the Green Thumb perk}

IH_GetterCritterScript[] Property StandbyGetterCritters Auto
{Array of previously spawned critters that are currently idle; probably sparse}
IH_GetterCritterScript[] Property StandbyGetterCrittersGT Auto

IH_GetterCritterScript[] Property ActiveGetterCritters Auto
{Array of critters that are enabled and doing something; probably sparse}

IH_FinderPointerHolderScript[] Property PointerHolders Auto

int standbyCritterCount = 0
int standbyCritterCountGT = 0

int activeCritterCount = 0

; int lastPushable = -1
; Race playerRace

ObjectReference[] Property PackageTargets Auto
bool[] PathingMarkerCheckout

int cacheSize

int leadingIndex = 0
int trailingIndex = 0

; this is hard-coded in a few places for technical reasons, so ctrl+f workerCount and fix those too if changed
; must also be updated in-editor for FinderThreadResultsRefs and FinderThreadResultsInts
int workerCount = 8

; ObjectReference[] FoundFlora
int lastCallbackTime = 0
; int finishedWorkers = 0
; int fruitfulWorkers = 0
; int cachedFlora = 0
ObjectReference[] Property FinderThreadResultsRefs Auto
int[] Property FinderThreadResultsInts Auto

int SMFailureCount = 0

bool busy = false

int Property version Auto

int Function GetVersion()
	return 010205 ; 01.02.05
EndFunction

Event OnInit()
	Init()
EndEvent

Function Init()
	IH_Util.Trace(self + " initializing!")
	StandbyGetterCritters = new IH_GetterCritterScript[128]
	ActiveGetterCritters = new IH_GetterCritterScript[128]
	PathingMarkerCheckout = new bool[64]
	ResyncPointerHolders()
	if (cacheSize < 0)
		cacheSize = GetNumAliases() - pathAliasCount - 1
	endif
EndFunction

Event OnUpdate()
	if (trailingIndex == leadingIndex)
		; cache is already empty (this should normally never run)
		return
	endif
	
	; clear the oldest alias, and increment our index
	int thisIndex = trailingIndex
	
	trailingIndex += 1
	if (trailingIndex >= cacheSize)
		trailingIndex -= cacheSize
	endif
	if (trailingIndex == leadingIndex)
		; cache is empty, so reset our indicies, and stop registering for decay
		trailingIndex = 0
		leadingIndex = 0
	else
		RegisterForSingleUpdate(cacheDecayRate)
	endif
	
	(self.GetAlias(thisIndex) as ReferenceAlias).Clear()
	; IH_Util.Trace("IGN: Cleared ignored object from cache ID " + thisIndex)
EndEvent

Function OnGameLoad()
{Called by other code when the player loads a game}
	CheckUpdates()
	
	if (IH_SearchMode.GetValue() == 2.0)
		SkyPal_References.Change_Collision_Layer_Type(IH_Util.DowncastCritterArr(ActiveGetterCritters), 42)
	endif
	
	ResyncPointerHolders()
	; DumpFormList(IH_LearnedTypes)
	; SyncNonPersistent()
EndFunction

Function AddIgnoredObject(ObjectReference thing)
	if (thing == None)
		IH_Util.Trace("Called AddIgnoredObject with None object? skipping",1)
		return
	endif
	
	int thisIndex = leadingIndex
	; we must delay the actual write until the end of the function to preserve thread safety
	; don't want to mangle up our indicies because the thread unlocks too early

	leadingIndex += 1
	if (leadingIndex >= cacheSize)
		leadingIndex -= cacheSize
	endif
	if (leadingIndex == trailingIndex)
		trailingIndex += 1
		if (trailingIndex >= cacheSize)
			trailingIndex -= cacheSize
		endif
	endif
	
	(self.GetAlias(thisIndex) as ReferenceAlias).ForceRefTo(thing)
	; IH_Util.Trace("IGN: Forced object " + thing + " into ignored alias ID " + thisIndex)
	RegisterForSingleUpdate(cacheDecayRate)
EndFunction

;/ ---------
; The rest of the script was originally in a quest script on IH_FloraLearner, but I was having issues where my
; variables would get nuked every time the quest restarted (I didn't realize the engine did that), but ultimately
; it doesn't really matter where these are stored so I decided to just move them to another existing quest
-----------/;
;Function FloraFinderUpdate(ObjectReference thing, int err)
;	; IH_Util.Trace("\tGot our callback with " + thing + ", err: " + err)
;	if (err == 1)
;		; most common parameter, do nothing
;	elseif (err == 0)
;	;	IH_Util.Trace("\tGot our callback with " + thing + ", added to cache " + fruitfulWorkers)
;		if (fruitfulWorkers >= workerCount)
;			IH_Util.Trace("More worker returns than workers? -- skipping return of " + thing)
;			return
;		endif
;		FoundFlora[fruitfulWorkers] = thing
;		fruitfulWorkers += 1
;	else
;		; v1.0.8: put script-filtered objects in the ignore list, so we don't waste time
;		; retrying them over and over (oops...)
;		AddIgnoredObject(thing)
;	endif
;	finishedWorkers += 1
;EndFunction

Function FloraFinderCallback(int time)
	lastCallbackTime = time
EndFunction

ObjectReference[] Function GetNearbyHarvestables(ObjectReference caster)
{Latent function that returns an array of nearby harvestables. These can be:
	TreeObject, Flora, Ingredient, Activator (Critter or FXfakeCritterScript)}
	if (busy)
		IH_Util.Trace("GetNearbyHarvestables is busy.")
		return new ObjectReference[1]
	endif
	busy = true
	
	; finishedWorkers = 0
	; fruitfulWorkers = 0
	; cachedFlora = 0
	int i
	int searchMode = IH_SearchMode.GetValue() as int
	
	lastCallbackTime = -1
	int sendTime = (Utility.GetCurrentRealTime() as int)
	
	IH_FloraFinderScript finderQuest
	
	if (searchMode == 2) ; SkyPal Mode
		; Get refs in the loaded cell area
		ObjectReference[] refs =  skypal_references.Grid()
		if (refs as bool == false)
			IH_SkyPalNotWorking.Show()
			busy = false
			return new ObjectReference[1]
		endif
		
		Actor casterA = caster as Actor
		
		; Filter for refs whose base types are in IH_LearnedTypes
		refs = skypal_references.Filter_Bases_Form_List(refs, IH_LearnedTypes, "")
		
		; Filter for refs within IH_CurrentSearchRadius units of caster
		refs = skypal_references.Filter_Distance(refs, IH_CurrentSearchRadius.GetValue(), caster, "<")
		
		; Filter disabled refs
		refs = skypal_references.Filter_Enabled(refs, "")
		
		; Filter deleted refs
		refs = skypal_references.Filter_Deleted(refs, "!")
		
		; IH_Util.Trace("Found these things:")
		; IH_Util.DumpObjectArray(refs)
		
		Actor[] a = new Actor[1]
		a[0] = casterA
		refs = skypal_references.Filter_Potential_Thieves(refs, a, "!|")
		
		; IH_Util.Trace("Filtered for thieves, redumping")
		; IH_Util.DumpObjectArray(refs)
		
		Keyword[] kywds = new Keyword[1]
		kywds[0] = IH_IgnoreObject
		; Filter for refs without IH_IgnoreObject
		; IH_Util.Trace("\nBefore keyword filter: ")
		; IH_Util.DumpObjectArray(refs)
		refs = skypal_references.Filter_Keywords(refs, kywds, "!|")
		; IH_Util.Trace("\nAfter keyword filter: ")
		; IH_Util.DumpObjectArray(refs)
		; IH_Util.Trace("\n")
		
		; Sort by closer to caster
		refs = skypal_references.Sort_Distance(refs, caster, "<")
		
		; IH_Util.Trace("After all filters with len:" + refs.Length + "\n" + refs)
		
		; IH_Util.Trace("Filling and running extra filtering, " + refs[i] + ", " + casterA + "," + i + "," + FinderThreadResultsInts + "," + FinderThreadResultsRefs)
		
		i = 0
		int len = refs.Length
		while (i < workerCount && i < len)
			ObjectReference r = None
			FinderThreadResultsInts[i] = -1
			IH_FloraFinderWorkersSkypal[i].FillAndRun(refs[i], casterA, i, FinderThreadResultsRefs, FinderThreadResultsInts)
			i += 1
		endwhile
		
		; if SkyPal finds < 8 refs, set the results array to indicate no result
		while (i < workerCount)
			FinderThreadResultsInts[i] = 1
			FinderThreadResultsRefs[i] = None
			i += 1
		endwhile
		
		; IH_Util.Trace("Filled and ran extra filtering, " + refs[i] + ", " + casterA + "," + i + "," + FinderThreadResultsInts + "," + FinderThreadResultsRefs)
	elseif (searchMode == 1 && caster == PlayerRef) ; Start Mode (only works for player caster)
		IH_Util.Trace("Start()ing search quest...waiting for worker threads to finish. ")
		finderQuest = IH_FloraFinderStart
		if (finderQuest.Start())
			; pass
		else
			if (finderQuest.IsRunning())
				finderQuest.Stop()
				if (finderQuest.Start())
					IH_Util.Trace("Failed to start " + finderQuest + ", was already running, and failed a restart!", 2)
				else
					IH_Util.Trace(finderQuest + " was already running, but successfully forcibly restarted!", 1)
				endif
			else
				IH_Util.Trace(finderQuest + " failed to start, and is not already running! This should never happen.", 1)
			endif
		endif
	else ; Story Manager mode
		IH_Util.Trace("Sent story event...waiting for worker threads to finish.")
		finderQuest = IH_FloraFinderSM
		IH_SMKeyword.SendStoryEvent(akRef1 = caster, aiValue1 = sendTime, aiValue2 = 1)
		
		i = 0
		while (lastCallbackTime < 0 && i < 60) ; 3 second timeout
			Utility.Wait(0.05)
			i += 1
		endwhile
		
		int minTime = (Utility.GetCurrentRealTime() as int) - 5
		int maxTime = minTime + 10
		; IH_Util.Trace("Loop ended: " + i + " " + lastCallbackTime + " " + newTime)
		if (i == 60 || lastCallbackTime > maxTime || lastCallbackTime < minTime)
			; if i == 60 (timeout)  OR  lastCallbackTime > maxTime (also timeout)  OR  lastCallbackTime < minTime (time desync, save was just loaded)
			IH_Util.Trace("IH_FloraFinder failed to start after a few seconds--Story Manager backed up?", 1)
			SMFailureCount += 1
			if (SMFailureCount > 1)
				if (finderQuest.IsRunning())
					IH_Util.Trace("Detected that IH_FloraFinder is probably stuck running - forcibly stopping quest.", 2)
					finderQuest.Stop()
				else
					IH_Util.Trace("Detected that the Story Manager is under high load - showing warning to player.", 1)
					IH_StoryManagerHighLoad.Show()
					
					i = 0
					while (lastCallbackTime < 0 && i < 120)
						Utility.Wait(1.0)
						i += 1
					endwhile
					if (i < 300)
						IH_Util.Trace("Story manager unstuck, after " + i + " seconds!")
					else
						IH_Util.Trace("Timed out after waiting " + i + " seconds for the story manager to unstick.", 2)
					endif
				endif
			endif
			
			busy = false
			return new ObjectReference[1]
		endif
		SMFailureCount = 0
	endif
	
	;/ Right so, right here I'm using a little-known feature of the Story manager—in fact, now that I think about it,
	; I can't remember ever having found another mod in the wild that uses this feature—anyway, our IH_FloraFinder
	; quest is set to start off of a "Script Event". Basically, this allows us to start a quest with some RefAliases
	; filled so early that we can use those RefAliases as conditions for the Story Manager to fill in other aliases.
	; In some circumstances, this can be very powerful, because it allows for much more refined filters when we're
	; using the Story Manager as a "search engine". The reason I'm using it here is so I can make my harvest spell
	; equally usable by the PC _or_ NPCs, instead of making it a hard-coded player-only sort of deal. Specifically,
	; we're passing the caster into SendStoryEventAndWait(), which starts IH_FloraFinder up with the Caster alias
	; pre-filled, who is then used in the GetDistance conditional when the Story Manager fills our FinderRefs. /;
;	if (!IH_SMKeyword.SendStoryEventAndWait(akRef1 = caster))
;		; IH_Util.Trace("IH_SMKeyword.SendStoryEventAndWait(akRef1 = caster) failed. FoundFlora:" + FoundFlora)
;		SMFailureCount += 1
;		
;		if (SMFailureCount > 4)
;			IH_Util.Trace("Detected that IH_FloraFinder is probably stuck running - forcibly stopping quest.", 2)
;			IH_FloraFinder.Stop()
;		endif
;		
;		busy = false
;		return new ObjectReference[1]
;	endif
;	SMFailureCount = 0

	; now wait for our worker threads to fill in the data we want
	;i = 0
	;while (finishedWorkers < 8 && i < 100)
	;;	IH_Util.Trace("finishedWorkers:" + finishedWorkers)
	;	Utility.WaitMenuMode(0.033) ; ~2 frames at 60fps
	;	i += 1 ; failsafe
	;endwhile
	
	i = 0
	while (IH_Util.AreAllIntsAtOrAboveThreshold(FinderThreadResultsInts, 0) == false && i < 200)
	;	IH_Util.Trace("finishedWorkers:" + finishedWorkers)
		Utility.WaitMenuMode(0.05) ; ~3 frames at 60fps
		i += 1 ; failsafe
		
		; IH_Util.Trace("UNFINISHED Results array:\n\t\t" + FinderThreadResultsInts + "\n\t\t" + FinderThreadResultsRefs)
	endwhile
	
	;~_Util.Trace("Workers finished. FoundFlora:" + FoundFlora)
	if (finderQuest)
		finderQuest.Stop()
	endif
	
	; IH_Util.Trace("Results array:\n\t\t" + FinderThreadResultsInts + "\n\t\t" + FinderThreadResultsRefs)
	
	ObjectReference[] toReturn = new ObjectReference[8] ; workerCount
	i = 0
	int j = 0
	while (i < workerCount)
		ObjectReference ref = FinderThreadResultsRefs[i]
		if (FinderThreadResultsInts[i] > 1); -1 = no result yet; 0 = found something; 1 = found nothing; 2+ = filtered
			; unerrored returns (0) will be filtered on critter dispatch
			AddIgnoredObject(ref)
		else
			toReturn[j] = FinderThreadResultsRefs[i]
			j += 1
		endif
		
		FinderThreadResultsRefs[i] = None
		FinderThreadResultsInts[i] = -1
		i += 1
	endwhile
	
	busy = false
	
	return toReturn
EndFunction

;/ To avoid making and destroying actors all of the time, we keep a persistent cache of them instead,
; and just pull preexisting ones out of the cache as they're requested. /;
IH_GetterCritterScript Function GetGetterCritter2(Actor caster, bool gt)
	; IH_Util.Trace("standbyCritterCount: " + standbyCritterCount + " activeCritterCount: " + activeCritterCount)
	IH_GetterCritterScript toReturn
	
	if (activeCritterCount >= IH_CritterCap.GetValue())
		return None
	endif
	
	; v1.0.1: I hate this function now, but I don't want to put like five different checks for gt, because
	; I know the Papyrus compiler won't optimize it out. Hopefully I'll never have to touch this code again, anyway.
	if (gt)
		if (standbyCritterCountGT == 0)
			toReturn = caster.PlaceAtMe(IH_GetterCritterGT, 1, true, true) as IH_GetterCritterScript
			; toReturn.SetPlayerTeammate(true) ; 1.2.2: removed this in favor of the superior SkyPal solution
		else
			toReturn = GetFirstStandbyCritterGT()
			if (!toReturn)
				return None
			endif
			bool result = RemoveStandbyCritterGT(toReturn)
			if (!result)
				IH_Util.Trace("Failed to remove this critter from GT standby cache " + toReturn, 2)
				return None
			endif
		endif
	else
		if (standbyCritterCount == 0)
			toReturn = caster.PlaceAtMe(IH_GetterCritter, 1, true, true) as IH_GetterCritterScript
			; toReturn.SetPlayerTeammate(true) ; 1.2.2: removed this in favor of the superior SkyPal solution
		else
			toReturn = GetFirstStandbyCritter()
			if (!toReturn)
				return None
			endif
			bool result = RemoveStandbyCritter(toReturn)
			if (!result)
				IH_Util.Trace("Failed to remove this critter from standby cache " + toReturn, 2)
				return None
			endif
		endif
	endif
	
	if (!InsertActiveCritter(toReturn))
		IH_Util.Trace("Failed to add this critter to active cache " + toReturn + ", it will be returned to standby instead.", 2)
		InsertStandbyCritter(toReturn)
		return None
	endif
	
	;/ if (activeCritterCount == 1 && IH_SetPlayerNotPushable.GetValue() > 0.0)
		;/ playerRace = PlayerRef.GetRace()
		lastPushable = playerRace.IsNotPushable() as int
		if (lastPushable == 0)
			IH_Util.Trace("Setting not pushable flag on player race " +playerRace)
			playerRace.MakeNotPushable()
		endif
		IH_PlayerCapsuleEffect.Play(PlayerRef)
	endif ; /;
	
	return toReturn
EndFunction

;/ v1.2.0: removed the old note here because I fixed the bug it was complaining about /;
Function ReturnGetterCritter2(IH_GetterCritterScript c, bool gt)
	if (!RemoveActiveCritter(c))
		;IH_Util.Trace("Failed to remove this critter from active cache " + c)
		
		; written like this because we don't want to interrupt the thread lock until all caches are checked
		string[] returnstr = new string[16]
		returnstr[0] = "That weird thing with the caches happened again (return called twice in a row?); forcibly cleansing caches of all " + c + "..."
		int strindex = 1
		if (gt)
			while (RemoveStandbyCritterGT(c))
				returnstr[strindex] = "...removed instance of " + c + " from GT standby cache..."
				strindex += 1
			endwhile
		else
			while (RemoveStandbyCritter(c))
				returnstr[strindex] = "...removed instance of " + c + " from standby cache..."
				strindex += 1
			endwhile
		endif
		
		while (RemoveActiveCritter(c))
			returnstr[strindex] = "...removed instance of " + c + " from active cache..."
			strindex += 1
		endwhile
		returnstr[strindex] = "..caches cleaned, critter will be returned to standby..."
		strindex += 1
		
		; it's safe to make external calls now
		if ((gt && !InsertStandbyCritterGT(c)) || (!gt && !InsertStandbyCritter(c)))
			returnstr[strindex] = "...Failed to return this critter to standby cache " + c + ", it will be deleted instead."
			strindex += 1
			c.Delete()
		else
			returnstr[strindex] = "...critter returned to standby cache " + c + ", all should be fine now."
			strindex += 1
		endif
		
		int i = 0
		while (i < strindex)
			IH_Util.Trace(returnstr[i])
			i += 1
		endwhile
		Debug.TraceStack(self + " printing ReturnGetterCritter stack trace")
	elseif ((gt && !InsertStandbyCritterGT(c)) || (!gt && !InsertStandbyCritter(c)))
		IH_Util.Trace("Failed to return this critter to GT standby cache " + c + ", it will be deleted instead.", 2)
		c.Delete()
	endif
	
	;/ if (activeCritterCount == 0) ;&& lastPushable != -1)
		
		if (lastPushable == 0)
			IH_Util.Trace("Restoring pushable flag on " + playerRace)
			PlayerRef.GetRace().MakePushable()
		endif
		lastPushable = -1 ;
		IH_PlayerCapsuleEffect.Stop(PlayerRef)
	endif ; /;
EndFunction

; --------- Normal critter functions ---------
IH_GetterCritterScript Function GetFirstStandbyCritter()
	int i = 0
	while (i < StandbyGetterCritters.Length)
		if (StandbyGetterCritters[i] != None)
			return StandbyGetterCritters[i]
		endif
		i += 1
	endwhile
	return None
EndFunction

bool Function InsertStandbyCritter(IH_GetterCritterScript c)
	int index = StandbyGetterCritters.Find(None, 0)
	if (index < 0)
		return false
	else
		StandbyGetterCritters[index] = c
		standbyCritterCount += 1
		return true
	endif
EndFunction

bool Function RemoveStandbyCritter(IH_GetterCritterScript c)
	int index = StandbyGetterCritters.Find(c, 0)
	if (index < 0)
		return false
	else
		StandbyGetterCritters[index] = None
		standbyCritterCount -= 1
		return true
	endif
EndFunction
; --------- End normal critter functions ---------

; --------- Green Thumb critter functions ---------
IH_GetterCritterScript Function GetFirstStandbyCritterGT()
	int i = 0
	while (i < StandbyGetterCrittersGT.Length)
		if (StandbyGetterCrittersGT[i] != None)
			return StandbyGetterCrittersGT[i]
		endif
		i += 1
	endwhile
	return None
EndFunction

bool Function InsertStandbyCritterGT(IH_GetterCritterScript c)
	int index = StandbyGetterCrittersGT.Find(None, 0)
	if (index < 0)
		return false
	else
		StandbyGetterCrittersGT[index] = c
		standbyCritterCountGT += 1
		return true
	endif
EndFunction

bool Function RemoveStandbyCritterGT(IH_GetterCritterScript c)
	int index = StandbyGetterCrittersGT.Find(c, 0)
	if (index < 0)
		return false
	else
		StandbyGetterCrittersGT[index] = None
		standbyCritterCountGT -= 1
		return true
	endif
EndFunction
; --------- End Green Thumb critter functions ---------

bool Function InsertActiveCritter(IH_GetterCritterScript c)
	int index = ActiveGetterCritters.Find(None, 0)
	if (index < 0)
		return false
	else
		ActiveGetterCritters[index] = c
		activeCritterCount += 1
		return true
	endif
EndFunction

bool Function RemoveActiveCritter(IH_GetterCritterScript c)
	int index = ActiveGetterCritters.Find(c, 0)
	if (index < 0)
		return false
	else
		ActiveGetterCritters[index] = None
		activeCritterCount -= 1
		return true
	endif
EndFunction

;/ So it turns out that ObjectReference.PathToReference() is bad—really bad, save-corruptingly bad in fact.
; Why? Well, it's a latent function that doesn't return until the pathing request has either finished, failed,
; or... just, never. Occasionally it simply does not return, ever, and there is absolutely nothing that can
; be done to force it to return. 
;
; I tried a load of different ways to try to get it to return, but nothing works.
; If you call PathToReference() in another thread, it'll work, but the original function doesn't return.
; Diabling and enabling the actor doesn't work, killing the actor doesn't work, unloading the actor doesn't work,
; translating, moving, ReevaluatePackage(), and probably some others I've forgotten, none of that works.
;
; UNINSTALLING THE MOD does not even work because the stuck Papyrus thread persists in the save. Even FallrimTools
; barely works, i.e. terminating the thread (NOPing out the in-progress thread) does not work because it
; will remain stuck on the latent function call. The only thing you can do is to delete the active script instance
; entirely, which in itself has a tendency to corrupt the save.
;
; It's possible to just recall the critter and ignore the problem, but the game will destabilize after that point,
; because almost any interaction with a critter that has one of these stuck threads tends to cause a CTD.
;
; So I had to devise a hacky, but safe, workaround, which is to set up a series of AI packages that path to a
; preset xMarker, and then attach each of those AI packages to a RefAlias. Each alias can only be used by one
; actor at a time, so I abstract that big pile of forms into a set of checkout/return functions.
;
; To use this, call CheckoutPathingAlias(); this will reserve an alias, and return the reserved alias ID.
;	If there are no free aliases, this will return -1 and do nothing, so be wary.
; Next, call GetPathingMarker() with your ID and store the ObjectReference
; Move that ObjRef where you want to path.
; Call GetPathingAlias() and store the alias.
; Call ForceRefTo() on the alias, followed by EvaluatePackage() on your actor.
;	Your actor should now be pathfinding to wherever you put the marker.
; Wait for Event OnPackageEnd(Package akOldPackage) to return, either after 12 seconds or pathing success.
; Now call Clear() on your alias, followed by EvaluatePackage() again. This lets your actor go back to doing
;	something other than pathfinding (idling in the case of my Getter Critters).
; If you want to path somewhere else, repeat steps from the ObjRef move to this point as many times as desired.
; When you're finished, you must call ReturnPathingAlias() with your ID to free the resource up again.
;	You should also make sure to clear the ID/ObjRef/RefAlias variables filled earlier, but that's not critical.
; /;
int Function CheckoutPathingAlias()
	int i = PathingMarkerCheckout.Find(false)
	if (i >= 0)
;		Debug.TraceStack("Reserving ID: " + i)
		PathingMarkerCheckout[i] = true
	endif
	return i
EndFunction

ObjectReference Function GetPathingMarker(int id)
	return PackageTargets[id]
EndFunction

ReferenceAlias Function GetPathingAlias(int id)
	return (self.GetAlias(cacheSize + id) as ReferenceAlias)
EndFunction

Function ReturnPathingAlias(int id);, ReferenceAlias a = None)
;	Debug.TraceStack("Returning ID: " + id)
;/	if (a)
		a.Clear()
	else
		(self.GetAlias(cacheSize + id) as ReferenceAlias).Clear()
	endif/;
	PathingMarkerCheckout[id] = false
EndFunction

Function ClearFloraCaches()
	IH_Util.Trace("Clearing all known flora...")
	float time = Utility.GetCurrentRealTime()
	
	IH_FloraLearnerController.LastCell = None
	IH_FloraLearnerController.VerifyState()
	
	IH_LearnedTypes.Revert()
	IH_ExaminedTypes.Revert()
	
	int i = 0
	while (i < cacheSize)
		(self.GetAlias(i) as ReferenceAlias).Clear()
		i += 1
	endwhile
	
	time = Utility.GetCurrentRealTime() - time
	IH_Util.Trace("...Known flora cleared in " + time + "s.")
	IH_OperationFinishedCache.Show(time)
EndFunction

; Mostly for fixing my own save that I made a mess of while playtesting
Function RecallAllCritters()
	float time = Utility.GetCurrentRealTime()
	string st
	busy = true
	
	IH_Util.Trace("Recalling all critters...\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters: ")
	PrintCritterArray(StandbyGetterCritters)
	
	int i = 0
	while (i < ActiveGetterCritters.Length)
		IH_GetterCritterScript c = ActiveGetterCritters[i]
		if (c != None)
			st = ActiveGetterCritters[i].GetState()
			IH_Util.Trace("\tRecalling critter " + c + " in state: " + st)
			ActiveGetterCritters[i].Cleanup()
		endif
		; recheck that the cleanup function did actually do its job, if not forcibly fix cache
		c = ActiveGetterCritters[i]
		if (c != None)
			IH_Util.Trace("\t\t..." + c + " still in cache after recall, forcibly fixing and continuing.")
			ReturnGetterCritter2(c, c.HasGreenThumb)
		endif
		i += 1
	endwhile
	
	activeCritterCount = 0
	
	IH_Util.Trace("...Critters recalled, redumping...\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters:")
	PrintCritterArray(StandbyGetterCritters)
	IH_Util.Trace("...deduping arrays...")
	
	standbyCritterCount = 0
	standbyCritterCountGT = 0
	
	i = 127
	int j
	while (i >= 0)
		DedupeAndCleanIndex(ActiveGetterCritters, "ActiveGetterCritters", i, None)
		
		if (DedupeAndCleanIndex(StandbyGetterCritters, "StandbyGetterCritters", i, "Done"))
			standbyCritterCount += 1
		endif
		
		if (DedupeAndCleanIndex(StandbyGetterCrittersGT, "StandbyGetterCrittersGT", i, "Done"))
			standbyCritterCountGT += 1
		endif
		
		i -= 1
	endwhile
	
	;/temp dev code (that I keep needing to uncomment)
	i = 0
	while (i < StandbyGetterCritters.Length)
		IH_GetterCritterScript c = StandbyGetterCritters[i]
		if (c != None)
			c.SpawnMeasurementMarker()
		endif
		i += 1
	endwhile
	
	pathAliasCount = 64
	; /;
	PathingMarkerCheckout = new bool[64]
	
	time = Utility.GetCurrentRealTime() - time
	IH_Util.Trace("...Recall routine finished in " + time + "s. Active#: " + activeCritterCount + ", Standby#: " + standbyCritterCount + "/" + standbyCritterCountGT + ", Redumping arrays:\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters: ")
	PrintCritterArray(StandbyGetterCritters)
	IH_Util.Trace("Ignore any warnings about \"Skipped return to cache...\" following this line, those are harmless.")
	
	ResyncPointerHolders()
	
	IH_OperationFinishedRecall.Show(time)
	busy = false
EndFunction

bool Function DedupeAndCleanIndex(IH_GetterCritterScript[] arr, string arrName, int i, string expected)
	IH_GetterCritterScript a = arr[i]
	IH_GetterCritterScript b
	int j
	string st
	
	if (a == None)
		return false
	endif

	st = a.GetState()
	if (st == "Done")
		a.CleanErrantGraphics()
	endif
	
	if (st == "Deleted")
		a.Delete()
		arr[i] = None
		IH_Util.Trace("\tRemoved deleted " + a + " from " + arrName + " index " + i)
		return false
	elseif (expected && st != expected)
		IH_Util.Trace("\tWarning: " + a + " from " + arrName + " index " + i + " in state " + st + " instead of expected " + expected + " - check this", 1)
	endif
	
	j = i - 1
	while (j >= 0)
		b =  arr[j]
		if (a == b)
			IH_Util.Trace("\tDeduped " + arrName + " index " + i + "/" + j)
			arr[i] = None
		endif
		j -= 1
	endwhile
	
	return true
EndFunction

Function PrintCritterArray(IH_GetterCritterScript[] arr)
	int l = arr.Length
	int i = 0
	IH_GetterCritterScript c
	string str = "\t"
	while (i < l)
		c = arr[i]
		str += c + ", "
		if ((((c != None) && ((i+1) % 4 == 0)) || ((i+1) % 16 == 0)) || (i == (l - 1))) ; ayy lmao
			IH_Util.Trace(str)
			str = "\t"
		endif
		i += 1
	endwhile
EndFunction

Function TallyCritterStats()
	int critters
	int crittersGT
	
	float fameCritters
	float fameCrittersGT
	
	float top
	float current
	
	int i = 0
	while (i < 128)
		IH_GetterCritterScript c = StandbyGetterCritters[i]
		if (c)
			critters += 1
			current = c.ThingsHarvested
			; current = c.GetActorValueMax("Fame")
			; IH_Util.Trace(c + " " + c.GetActorValue("Fame") + " " + c.GetBaseActorValue("Fame") + " " + c.GetActorValueMax("Fame"))
			fameCritters += current
			
			if (top < current)
				top = current
			endif
		endif
		
		c = StandbyGetterCrittersGT[i]
		if (c)
			crittersGT += 1
			
			current = c.ThingsHarvested
			; current = c.GetActorValueMax("Fame")
			fameCrittersGT += current
			
			if (top < current)
				top = current
			endif
		endif
		
		i += 1
	endwhile
	float totalCritters = critters + crittersGT
	float totalFame = fameCritters + fameCrittersGT
	IH_StatsDisplay.Show(totalCritters, critters, crittersGT, totalFame, fameCritters, fameCrittersGT, totalFame / totalCritters, top) 
EndFunction

Function DeleteGetterCritters()
	if (IH_ModReset.Show() != 1.0)
		return
	endif
	
	float time = Utility.GetCurrentRealTime()
	
	ClearFloraCaches()
	RecallAllCritters()
	
	IH_Util.Trace("Getter critter Final Solution has been put into effect--sending critters to concentration camps...")
	Form[] allCritters = Utility.CreateFormArray(512, None)
	int i = 0
	int last = 0
	Form tmp
	while (i < 128)
		tmp = StandbyGetterCritters[i]
		if (tmp)
			StandbyGetterCritters[i] = None
			allCritters[last] = tmp
			last += 1
		endif
		
		tmp = StandbyGetterCrittersGT[i]
		if (tmp)
			StandbyGetterCrittersGT[i] = None
			allCritters[last] = tmp
			last += 1
		endif
		
		tmp = ActiveGetterCritters[i]
		if (tmp)
			ActiveGetterCritters[i] = None
			allCritters[last] = tmp
			last += 1
		endif
		
		i += 1
	endwhile
	IH_Util.Trace("\t...roundup complete--exterminating...")
	i = 0
	IH_GetterCritterScript c
	while (i < last)
		c = (allCritters[i] as IH_GetterCritterScript)
		if (c != None)
			c.Disable()
			IH_Util.QuarantineObject(c)
			c.Delete()
		endif
		i += 1
	endwhile
	
	int orphans = 0
	if (IH_SearchMode.GetValue() == 2.0)
	;	IH_Util.Trace("\t\tRunning skypal_references.All()...")
	;	ObjectReference[] refs = skypal_references.All()
	;	IH_Util.Trace("\t\tFiltering array (len " + refs.length + ") by FormList...")
	;	refs = skypal_references.Filter_Bases_Form_List(refs, IH_SpawnableBase_01, "")
	;	IH_Util.Trace("\t\tFiltering array (len " + refs.length + ") deleted...")
		
		float time2 = Utility.GetCurrentRealTime()
		
		IH_Util.Trace("\t\tRunning skypal_references.All_Filter_Bases_Form_List(IH_SpawnableBase_01, \"\")...")
		ObjectReference[] refs = skypal_references.All_Filter_Bases_Form_List(IH_SpawnableBase_01, "")
		IH_Util.Trace("\t\tFiltering array (len " + refs.length + ") deleted...")
		refs = skypal_references.Filter_Deleted(refs, "!")
		
		i = refs.length
		IH_Util.Trace("\tFound " + i + " spawned IHarvest objects via SkyPal in " + (Utility.GetCurrentRealTime() - time2) + "s--deleting...")
		i -= 1
		while (i >= 0)
			ObjectReference thing = refs[i]
			if (thing != None)
				Form base = thing.GetBaseObject()
				if (IH_SpawnableBase_01.HasForm(base)) ; just to be safe
					IH_Util.Trace("\t\t...found spawned thing " + thing + " of type " + base + " to delete...")
					thing.Disable()
					IH_Util.QuarantineObject(thing)
					thing.Delete()
					orphans += 1
				else
					IH_Util.Trace("\t\t...skipped thing " + thing)
				endif
			endif
			i -= 1
		endwhile
	else
		IH_Util.Trace("\tLooking for orphaned objects to delete...")
		bool keepDeleting = true
		while (keepDeleting)
			ObjectReference thing = Game.FindClosestReferenceOfAnyTypeInListFromRef(IH_SpawnableBase_01, PlayerRef, 128000.0)
			if (thing == None)
				keepDeleting = false
			else
				IH_Util.Trace("\t\t...found unreferenced spawned thing " + thing + " to delete...")
				thing.Disable()
				IH_Util.QuarantineObject(thing)
				thing.Delete()
				orphans += 1
			endif
		endwhile
	endif
	
	IH_Util.Trace("...critters exterminiated, and " + orphans + " possible orphans cleaned up. Restarting main quest...")
	
	self.Stop()
	
	IH_FloraLearnerController.Stop()
	IH_FloraFinderSM.Stop()
	IH_FloraFinderStart.Stop()
	IH_FloraFinderSkypal.Stop()
	
	IH_Util.Trace(self + " stopped. Restarting...")
	Utility.Wait(2.0)
	self.Start()
	IH_Util.Trace(self + " restarted. Reinitializing some arrays...")
	
	StandbyGetterCritters = new IH_GetterCritterScript[128]
	standbyCritterCount = 0
	
	StandbyGetterCrittersGT = new IH_GetterCritterScript[128]
	standbyCritterCountGT = 0
	
	ActiveGetterCritters = new IH_GetterCritterScript[128]
	activeCritterCount = 0
	
	time = Utility.GetCurrentRealTime() - time
	IH_Util.Trace("...done, mod reset in " + time + "s.")
	
	IH_OperationFinishedDelete.Show(time, orphans)
EndFunction

Function CheckUpdates()
	int versionCurrent = GetVersion()
	
;	Form f
	
	Debug.Trace(self + " Checking if SKSE is installed (this may error)...")
	IH_Util.Trace("Checking if SKSE is installed...")
	int seVR = SKSE.GetVersionRelease()
	int seVS = SKSE.GetScriptVersionRelease()
	if (seVR == 0)
		if (seVS == 0)
			IH_Util.Trace("SKSE appears not to be running.", 2)
			Debug.Trace(self + " SKSE not detected. A warning message will be shown, and this mod will not function.", 2)
			IH_SKSENotInstalled.Show()
		else
			IH_Util.Trace("SKSE appears not to be running, however the SKSE scripts appear to be installed.", 2)
			Debug.Trace(self + " SKSE not detected, however SKSE scripts are installed. A warning message will be shown, and this mod will not function.", 2)
			IH_SKSENotRunning.Show()
		endif
		return
	else
		int seV = SKSE.GetVersion()
		int seVM = SKSE.GetVersionMinor()
		int seVB = SKSE.GetVersionBeta()
		IH_Util.Trace("SKSE version " + seV + "." + seVM + "." + seVB + "." + seVR + ", script version " + seVS + " detected.")
		if (seVR != seVS)
			IH_Util.Trace("...SKSE script/release version mismatch detected. This mod may or may not function correctly.", 1)
			if (CanShowMismatchWarning)
				CanShowMismatchWarning = !(IH_SKSEMismatch.Show(seV, seVM, seVB, seVR, seVS) as bool)
			endif
		endif
	endif
	
	IH_Util.Trace("Checking for updates; last version: " + version + ", current version: " + versionCurrent)
	if (versionCurrent == version)
		IH_Util.Trace("No update this load.")
	elseif (versionCurrent > version)
		if (version == 0)
			; update code to apply on first run
			
			; always fires on first run because I forgot to put a version var in v1.0.0
			IH_Util.Trace("\tv1.0.1: Initializing StandbyGetterCrittersGT array")
			StandbyGetterCrittersGT = new IH_GetterCritterScript[128]
			v10102_UpdateHFSetting(false)
			v10200_SetDefaultSearchMode()
		else
			; update code NOT to apply on first run
			if (version < 10105)
				IH_Util.Trace("\tv1.1.5: Clearing flora cache so updated learner script can re-run")
				ClearFloraCaches()
			;/ elseif (version < 10009)
				f = Game.GetFormFromFile(0x6025B3, "BSAssets.esm")
				if (f)
					IH_ExaminedTypes.RemoveAddedForm(f)
					f = Game.GetFormFromFile(0x6025B4, "BSAssets.esm")
					IH_ExaminedTypes.RemoveAddedForm(f)
					IH_Util.Trace("\tv1.0.9: Removed Beyond Skyrim Wisp Stalks from IH_ExaminedTypes")
				else
					Debug.Trace(self + " Ignore that error about GetFormFromFile")
				endif
			; /;
			endif
			
			if (version < 10102)
				v10102_UpdateHFSetting(true)
			endif
			
			if (version < 10201)
				v10200_SetDefaultSearchMode()
			endif
			
			if (version < 10204)
				v10202_UnsetCrittersTeammate()
				ResyncPointerHolders()
			endif
		endif
		
		IH_Util.Trace("Finished updates. New version is: " + versionCurrent)
		if (version != 0) ; don't show on initial install
			IH_Update.Show(version / 10000.0, versionCurrent / 10000.0)
		endif
	else ;if (versionCurrent < version), i.e. rollback
		IH_UpdateUnsupported.Show(version / 10000.0, versionCurrent / 10000.0)
	endif
	version = versionCurrent
EndFunction

Function v10102_UpdateHFSetting(bool allowReset = false)
	; IH_Util.Trace("\tv1.1.2: Updating properties on IH_FloraLarnerScript instances")
	; int aliasCt = IH_FloraLearner.GetNumAliases()
	; int i = 0
	; while (i < aliasCT)
	; 	(IH_FloraLearner.GetNthAlias(i) as IH_FloraLearnerScript).IH_LearnHearthfire = IH_LearnHearthfire
	; 	i += 1
	; endwhile
	
	; 0xB1987 was added in USSEP v4.2.0, when the relevant fixed was merged, so test for it
	; Failing that, test whether IHarvestVanillaFixes module is installed
	if ((Game.GetFormFromFile(0xB1987, "Unofficial Skyrim Special Edition Patch.esp") != None \
	 || Game.GetFormFromFile(0x800, "IHarvestVanillaFixes.esp") != None) \
	 && IH_LearnHearthfire.GetValue() != 1.0)
		IH_Util.Trace("\tv1.1.2: USSEP v4.2.0+ or IHarvestVanillaFixes detected; enabling HearthFire compat setting and resetting flora cache")
		IH_LearnHearthfire.SetValue(1.0)
		if (allowReset == false)
			ClearFloraCaches()
		endif
	endif
EndFunction

Function v10202_UnsetCrittersTeammate()
	IH_Util.Trace("\tv1.2.4: Gathering up all the getter critters...")
	Form[] allCritters = Utility.CreateFormArray(512, None)
	int i = 0
	int last = 0
	Form tmp
	while (i < 128)
		tmp = StandbyGetterCritters[i]
		if (tmp)
			allCritters[last] = tmp
			last += 1
		endif
		
		tmp = StandbyGetterCrittersGT[i]
		if (tmp)
			allCritters[last] = tmp
			last += 1
		endif
		
		tmp = ActiveGetterCritters[i]
		if (tmp)
			allCritters[last] = tmp
			last += 1
		endif
		
		i += 1
	endwhile
	IH_Util.Trace("\t\t...un-SetPlayerTeammate()ing all " + last + " critters...")
	i = 0
	IH_GetterCritterScript c
	while (i < last)
		c = (allCritters[i] as IH_GetterCritterScript)
		if (c != None)
			c.MigrateFame() ; also calls SetPlayerTeammate(false)
		endif
		i += 1
	endwhile
	IH_Util.Trace("\t...Done.")
EndFunction

Function v10200_SetDefaultSearchMode()
	if (VerifySkypalVersion())
		IH_Util.Trace("Set search mode to 2.0 (SkyPal)")
		IH_SearchMode.SetValue(2.0)
	elseif (IH_SearchMode.GetValue() < 0.0)
		IH_Util.Trace("Set search mode to 0.0 (Story Manager events)")
		IH_SearchMode.SetValue(0.0)
	endif
EndFunction

bool Function VerifySkypalVersion(bool warn = false)
	Debug.Trace(self + " Checking if doticu's SkyPal library is installed (this may error)")
	if (SkyPal.Has_DLL() == false)
		if (warn)
			IH_SkyPalNotWorking.Show()
		endif
		return false
	endif
	if (warn && SkyPal.Has_Version(1,0,1, "<"))
		IH_SkyPalOutOfDate.Show()
		; deliberately return true anyway
	endif
	return true
EndFunction

Function ResyncPointerHolders()
	int i = PointerHolders.length - 1
	while (i >= 0)
		IH_FinderPointerHolderScript ph = PointerHolders[i]
		if (ph.RefPointer != FinderThreadResultsRefs)
			IH_Util.Trace("PointerHolder " + ph + " RefPointer desynced! Fixing.")
			ph.RefPointer = FinderThreadResultsRefs
		endif
		if (ph.IntPointer != FinderThreadResultsInts)
			IH_Util.Trace("PointerHolder " + ph + " IntPointer desynced! Fixing.")
			ph.IntPointer = FinderThreadResultsInts
		endif
		i -= 1
	endwhile
	IH_Util.Trace("PointerHolders synced.")
EndFunction

;/ =========================== \;
; Deprecated function graveyard ;
;\ =========================== /;

; moved to IH_FloraLearnerControllerScript
State Learning
	Event OnUpdate()
		GoToState("")
		RegisterForSingleUpdate(0.0)
	EndEvent
EndState

; moved to IH_FloraLearnerControllerScript
Function LearnHarvestables()
EndFunction

; old functions that are no longer used, but we need to keep them with the original signature for save compatibility
IH_GetterCritterScript Function GetGetterCritter(Actor caster)
	return GetGetterCritter2(caster, false)
EndFunction

Function ReturnGetterCritter(IH_GetterCritterScript c)
	ReturnGetterCritter2(c, false)
EndFunction

; deprecated because I found out that the array Find "function" isn't even a function, so I can optimize out this function entirely,
; but left in place in case in case any saved running threads need to use it
bool Function ReplaceFirstInstance(IH_GetterCritterScript[] arr, IH_GetterCritterScript toFind, IH_GetterCritterScript toReplace) ;, int retries = 3)
	int i = 0
	int l = arr.Length
	IH_GetterCritterScript c
	while (i < l)
		c = arr[i]
		if (c == toFind)
			arr[i] = toReplace
			return true
		endif
		i += 1
	endwhile
	
	return false
EndFunction

Function SyncNonPersistent()
;/
	float config = IH_StaffDrainPerSpawn.GetValue()
	if (config == 15.0)
		IH_Util.Trace("No need to sync configurable staff drain magnitude.")
		return
	endif
	
	IH_StaffDrainLeftSpell.SetNthEffectMagnitude(0, config)
	IH_StaffDrainRightSpell.SetNthEffectMagnitude(0, config)
	IH_Util.Trace("Synced configurable staff drain magnitude.")
/;
EndFunction

