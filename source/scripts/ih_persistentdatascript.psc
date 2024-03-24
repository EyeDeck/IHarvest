Scriptname IH_PersistentDataScript extends Quest

Actor Property PlayerRef Auto

IH_FloraLearnerControllerScript Property IH_FloraLearnerController Auto

bool Property CanShowMismatchWarning = true Auto

Message Property IH_SKSENotInstalled		Auto
Message Property IH_SKSENotRunning			Auto
Message Property IH_SKSEMismatch			Auto
Message Property IH_Update					Auto
Message Property IH_UpdateUnsupported		Auto

Message Property IH_StatsDisplay			Auto
Message Property IH_OperationFinishedCache	Auto
Message Property IH_OperationFinishedRecall	Auto

FormList Property IH_SpawnableBase			Auto

GlobalVariable Property IH_CritterCap Auto
GlobalVariable Property IH_SetPlayerNotPushable Auto

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
Quest Property IH_FloraFinder Auto
Quest Property IH_FloraLearner Auto

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

int workerCount = 8 ; must be hard-coded—if changed, also update the array init size in OnQuestInit()
ObjectReference[] FoundFlora
int finishedWorkers = 0
int fruitfulWorkers = 0
int cachedFlora = 0

int SMFailureCount = 0

bool busy = false

int Property version Auto

int Function GetVersion()
	return 010105 ; 01.01.05
EndFunction

Event OnInit()
	Init()
EndEvent

Function Init()
	StandbyGetterCritters = new IH_GetterCritterScript[128]
	ActiveGetterCritters = new IH_GetterCritterScript[128]
	PathingMarkerCheckout = new bool[64]
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
	;~_Util.Trace("IGN: Cleared ignored object from cache ID " + thisIndex)
EndEvent

Function OnGameLoad()
{Called by other code when the player loads a game}
	CheckUpdates()
; SyncNonPersistent()
EndFunction

Function AddIgnoredObject(ObjectReference thing)
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
	;~_Util.Trace("IGN: Forced object " + thing + " into ignored alias ID " + thisIndex)
	RegisterForSingleUpdate(cacheDecayRate)
EndFunction

;/ ---------
; The rest of the script was originally in a quest script on IH_FloraLearner, but I was having issues where my
; variables would get nuked every time the quest restarted (I didn't realize the engine did that), but ultimately
; it doesn't really matter where these are stored so I decided to just move them to another existing quest
-----------/;
Function FloraFinderUpdate(ObjectReference thing, int err)
	; IH_Util.Trace("\tGot our callback with " + thing + ", err: " + err)
	if (err == 1)
		; most common parameter, do nothing
	elseif (err == 0)
	;	IH_Util.Trace("\tGot our callback with " + thing + ", added to cache " + fruitfulWorkers)
		FoundFlora[fruitfulWorkers] = thing
		fruitfulWorkers += 1
	else
		; v1.0.8: put script-filtered objects in the ignore list, so we don't waste time
		; retrying them over and over (oops...)
		AddIgnoredObject(thing)
	endif
	finishedWorkers += 1
EndFunction

ObjectReference[] Function GetNearbyHarvestables(ObjectReference caster)
{Latent function that returns an array of nearby harvestables. These can be:
	TreeObject, Flora, Ingredient, Activator (Critter or FXfakeCritterScript)}
	if (busy)
		;~_Util.Trace("GetNearbyHarvestables is busy.")
		return new ObjectReference[1]
	endif
	busy = true
	FoundFlora = new ObjectReference[8]
	finishedWorkers = 0
	fruitfulWorkers = 0
	cachedFlora = 0
	
	;/ Right so, right here I'm using a little-known feature of the Story manager—in fact, now that I think about it,
	; I can't remember ever having found another mod in the wild that uses this feature—anyway, our IH_FloraFinder
	; quest is set to start off of a "Script Event". Basically, this allows us to start a quest with some RefAliases
	; filled so early that we can use those RefAliases as conditions for the Story Manager to fill in other aliases.
	; In some circumstances, this can be very powerful, because it allows for much more refined filters when we're
	; using the Story Manager as a "search engine". The reason I'm using it here is so I can make my harvest spell
	; equally usable by the PC _or_ NPCs, instead of making it a hard-coded player-only sort of deal. Specifically,
	; we're passing the caster into SendStoryEventAndWait(), which starts IH_FloraFinder up with the Caster alias
	; pre-filled, who is then used in the GetDistance conditional when the Story Manager fills our FinderRefs. /;
	if (!IH_SMKeyword.SendStoryEventAndWait(akRef1 = caster))
		;~_Util.Trace("IH_SMKeyword.SendStoryEventAndWait(akRef1 = caster) failed. FoundFlora:" + FoundFlora)
		SMFailureCount += 1
		
		if (SMFailureCount > 4)
			IH_Util.Trace("Detected that IH_FloraFinder is probably stuck running - forcibly stopping quest.", 2)
			IH_FloraFinder.Stop()
		endif
		
		busy = false
		return new ObjectReference[1]
	endif
	SMFailureCount = 0
	
;	IH_Util.Trace("Sent story event...waiting for worker threads to finish.")
	; now wait for our worker threads to fill in the data we want
	int i = 0
	while (finishedWorkers < 8 && i < 20)
	;	IH_Util.Trace("finishedWorkers:" + finishedWorkers)
		Utility.WaitMenuMode(0.033) ; ~2 frames at 60fps
		i += 1 ; failsafe
	endwhile
	;~_Util.Trace("Workers finished. FoundFlora:" + FoundFlora)
	IH_FloraFinder.Stop()
	busy = false
	return FoundFlora
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
			toReturn.SetPlayerTeammate(true)
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
			toReturn.SetPlayerTeammate(true)
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

;/ Keep having troubles with this function, or maybe something else; either critters are occasionally getting selected from the standby
; cache without getting removed from it (which the log evidence doesn't support), or this function gets called twice in a row sometimes.
; This ultimately ends up causing a duplicate to end up in the standby cache, and when that happens the critter can get called on
; more than once simultaneously, which means the critter will probably get very confused, and possibly make a mess of other data etc...
; I thought it might be a thread lock issue, but I put spin locks in all of the spots that could cause this and they never triggered,
; so I really don't know what is going wrong here.
; Until I can find the underlying issue, we'll just detect when things go wrong and forcibly fix the caches right then.
/;
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
	
	IH_OperationFinishedRecall.Show(time)
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
			current = c.GetActorValueMax("Fame")
			; IH_Util.Trace(c + " " + c.GetActorValue("Fame") + " " + c.GetBaseActorValue("Fame") + " " + c.GetActorValueMax("Fame"))
			fameCritters += current
			
			if (top < current)
				top = current
			endif
		endif
		
		c = StandbyGetterCrittersGT[i]
		if (c)
			crittersGT += 1
			
			current = c.GetActorValueMax("Fame")
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
			c.Delete()
		endif
		i += 1
	endwhile
	
	StandbyGetterCritters = new IH_GetterCritterScript[128]
	standbyCritterCount = 0
	
	StandbyGetterCrittersGT = new IH_GetterCritterScript[128]
	standbyCritterCountGT = 0
	
	ActiveGetterCritters = new IH_GetterCritterScript[128]
	activeCritterCount = 0
	
	bool keepDeleting = true
	while (keepDeleting)
		ObjectReference thing = Game.FindRandomReferenceOfAnyTypeInListFromRef(IH_SpawnableBase, PlayerRef, 2000000.0)
		if (thing == None)
			keepDeleting = false
		else
			IH_Util.Trace("...found unreferenced spawned thing " + thing + " to delete...")
			thing.Disable()
			thing.Delete()
		endif
	endwhile
	
	IH_Util.Trace("...critters have been exterminated.")
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
				v10102_SetCrittersTeammate()
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
	if (Game.GetFormFromFile(0xB1987, "Unofficial Skyrim Special Edition Patch.esp") != None \
	 || Game.GetFormFromFile(0x800, "IHarvestVanillaFixes.esp") != None)
		IH_Util.Trace("\tv1.1.2: USSEP v4.2.0+ or IHarvestVanillaFixes detected; enabling HearthFire compat setting and resetting flora cache")
		IH_LearnHearthfire.SetValue(1.0)
		ClearFloraCaches()
	endif
EndFunction

Function v10102_SetCrittersTeammate()
	IH_Util.Trace("\tv1.1.2: Gathering up all the getter critters...")
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
	IH_Util.Trace("\t\t...SetPlayerTeammate()ing all " + last + " critters...")
	i = 0
	IH_GetterCritterScript c
	while (i < last)
		c = (allCritters[i] as IH_GetterCritterScript)
		if (c != None)
			c.SetPlayerTeammate(true)
		endif
		i += 1
	endwhile
	IH_Util.Trace("\t...Done.")
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
