Scriptname IH_PersistentDataScript extends Quest

Actor Property PlayerRef Auto

GlobalVariable Property IH_CritterCap Auto

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
IH_GetterCritterScript[] Property StandbyGetterCritters Auto
{Array of previously spawned critters that are currently idle; probably sparse}
IH_GetterCritterScript[] Property ActiveGetterCritters Auto
{Array of critters that are enabled and doing something; probably sparse}
int standbyCritterCount = 0
int activeCritterCount = 0

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

bool busy = false

int lastExaminedTypesSize = 0
Cell lastLearnedCell
bool learnerRunning = false

Event OnInit()
	Init()
EndEvent

Function Init()
	StandbyGetterCritters = new IH_GetterCritterScript[128]
	ActiveGetterCritters = new IH_GetterCritterScript[128]
	PathingMarkerCheckout = new bool[64]
	if (cacheSize < 0)
		cacheSize = GetNumAliases() - pathAliasCount
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
	
	(self.GetNthAlias(thisIndex) as ReferenceAlias).Clear()
	;~_Util.Trace("IGN: Cleared ignored object from cache ID " + thisIndex)
EndEvent


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
	
	(self.GetNthAlias(thisIndex) as ReferenceAlias).ForceRefTo(thing)
	;~_Util.Trace("IGN: Forced object " + thing + " into ignored alias ID " + thisIndex)
	RegisterForSingleUpdate(cacheDecayRate)
EndFunction

;/ ---------
; The rest of the script was originally in a quest script on IH_FloraLearner, but I was having issues where my
; variables would get nuked every time the quest restarted (I didn't realize the engine did that), but ultimately
; it doesn't really matter where these are stored so I decided to just move them to another existing quest
-----------/;
Function FloraFinderUpdate(ObjectReference thing, int err)
	if (!err)
;		IH_Util.Trace("\tGot our callback with " + thing + ", added to cache " + fruitfulWorkers)
		FoundFlora[fruitfulWorkers] = thing
		fruitfulWorkers += 1
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
		busy = false
		return new ObjectReference[1]
	endif
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

; int cacheGetSpinLock = 0
;/ To avoid making and destroying actors all of the time, we keep a persistent cache of them instead,
; and just pull preexisting ones out of the cache as they're requested. /;
IH_GetterCritterScript Function GetGetterCritter(Actor caster)
	; IH_Util.Trace("standbyCritterCount: " + standbyCritterCount + " activeCritterCount: " + activeCritterCount)
	if (standbyCritterCount + activeCritterCount >= 128 || activeCritterCount >= IH_CritterCap.GetValue())
		return None
	endif
	IH_GetterCritterScript toReturn
	if (standbyCritterCount == 0)
		toReturn = caster.PlaceAtMe(IH_GetterCritter, 1, false, true) as IH_GetterCritterScript
	else
		
	;/	while (cacheGetSpinLock > 0)
			IH_Util.Trace("GetGetterCritter waiting in a spin lock; count: " + cacheGetSpinLock)
			Utility.Wait(cacheGetSpinLock * 0.033)
		endwhile
		cacheGetSpinLock += 1/;
		
		toReturn = GetFirstStandbyCritter()
		if (!toReturn)
	;		cacheGetSpinLock -= 1
			return None
		endif
		bool result = RemoveStandbyCritter(toReturn)
	;	cacheGetSpinLock -= 1
		if (!result)
			IH_Util.Trace("Failed to remove this critter from standby cache " + toReturn)
			return None
		endif
	endif
	if (!InsertActiveCritter(toReturn))
		IH_Util.Trace("Failed to add this critter to active cache " + toReturn + ", it will be returned to standby instead.")
		InsertStandbyCritter(toReturn)
		return None
	endif
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
Function ReturnGetterCritter(IH_GetterCritterScript c)
	if (!RemoveActiveCritter(c))
		;IH_Util.Trace("Failed to remove this critter from active cache " + c)
		
		; written like this because we don't want to interrupt the thread lock until all caches are checked
		string[] returnstr = new string[16]
		returnstr[0] = "That weird thing with the caches happened again (return called twice in a row?); forcibly cleansing caches of all " + c + "..."
		int strindex = 1
		while (RemoveStandbyCritter(c))
			returnstr[strindex] = "...removed instance of " + c + " from standby cache..."
			strindex += 1
		endwhile
		while (RemoveActiveCritter(c))
			returnstr[strindex] = "...removed instance of " + c + " from active cache..."
			strindex += 1
		endwhile
		returnstr[strindex] = "..caches cleaned, critter will be returned to standby..."
		strindex += 1
		
		if (!InsertStandbyCritter(c))
			; it's safe to make external calls now
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
	elseif (!InsertStandbyCritter(c))
		IH_Util.Trace("Failed to return this critter to standby cache " + c + ", it will be deleted instead.")
		c.Delete()
	endif
EndFunction

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
	if (ReplaceFirstInstance(StandbyGetterCritters, None, c))
		standbyCritterCount += 1
		return true
	endif
	return false
EndFunction

bool Function RemoveStandbyCritter(IH_GetterCritterScript c)
	if (ReplaceFirstInstance(StandbyGetterCritters, c, None))
		standbyCritterCount -= 1
		return true
	endif
	return false
EndFunction

bool Function InsertActiveCritter(IH_GetterCritterScript c)
	if (ReplaceFirstInstance(ActiveGetterCritters, None, c))
		activeCritterCount += 1
		return true
	endif
	return false
EndFunction

bool Function RemoveActiveCritter(IH_GetterCritterScript c)
	if (ReplaceFirstInstance(ActiveGetterCritters, c, None))
		activeCritterCount -= 1
		return true
	endif
	return false
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
	int i = 0
	int l = PathingMarkerCheckout.Length
	while (i < l)
		if (PathingMarkerCheckout[i] == false)
			PathingMarkerCheckout[i] = true
;			Debug.TraceStack("Reserving ID: " + i)
			return i
		endif
		i += 1
	endwhile
	return -1
EndFunction

ObjectReference Function GetPathingMarker(int id)
	return PackageTargets[id]
EndFunction

ReferenceAlias Function GetPathingAlias(int id)
	return (self.getNthAlias(cacheSize + id) as ReferenceAlias)
EndFunction

Function ReturnPathingAlias(int id);, ReferenceAlias a = None)
;	Debug.TraceStack("Returning ID: " + id)
;/	if (a)
		a.Clear()
	else
		(self.getNthAlias(cacheSize + id) as ReferenceAlias).Clear()
	endif/;
	PathingMarkerCheckout[id] = false
EndFunction

; int RFIspinlock = 0
; Sadly this can't just be a generic function taking Form[] in Skyrim, though it could be in FO4
bool Function ReplaceFirstInstance(IH_GetterCritterScript[] arr, IH_GetterCritterScript toFind, IH_GetterCritterScript toReplace) ;, int retries = 3)
	;/ I was pretty sure this is supposed to be guaranteed by the language spec not to be needed here; turns out I was right,
	; as I've never seen that line in the debug log, so I've commented it out
	while (RFIspinlock > 0)
		IH_Util.Trace("ReplaceFirstInstance waiting in a spin lock (why?!); count: " + RFIspinlock)
		Utility.Wait(RFIspinlock * 0.033)
	endwhile
	RFIspinlock += 1 ; /;
	
	int i = 0
	int l = arr.Length
	IH_GetterCritterScript c
	while (i < l)
		c = arr[i]
		if (c == toFind)
			arr[i] = toReplace
			;RFIspinlock -= 1
			return true
		endif
		i += 1
	endwhile
	
	;IH_Util.Trace("ReplaceFirstInstance(<arr> (see below), " + toFind + ", " + toReplace + ") failed.")
	;PrintCritterArray(arr)
	return false
	
	;/
	string s = IH_Util.Trace("ReplaceFirstInstance(<arr> (see below), " + toFind + ", " + toReplace + ", " + retries + ") failed.")
	PrintCritterArray(arr)
	;RFIspinlock -= 1
	if (retries > 0)
		IH_Util.Trace(s + " Waiting and retrying.")
		return ReplaceFirstInstance(arr, toFind, toReplace, retries - 1)
	else
		IH_Util.Trace(s + " Retry count exhausted, giving up.")
		return false
	endif ; /;
EndFunction

Function ClearFloraCaches()
	IH_Util.Trace("Clearing all known flora...")
	IH_ExaminedTypes.Revert()
	IH_LearnedTypes.Revert()
	
	int i = 0
	while (i < cacheSize)
		(self.GetNthAlias(i) as ReferenceAlias).Clear()
		i += 1
	endwhile
	IH_Util.Trace("...Known flora cleared.")
EndFunction

; Mostly for fixing my own save that I made a mess of while playtesting
Function RecallAllCritters()
	IH_Util.Trace("Recalling all critters...\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters: ")
	PrintCritterArray(StandbyGetterCritters)
	
	activeCritterCount = 0
	
	int i = 0
	while (i < ActiveGetterCritters.Length)
		IH_GetterCritterScript c = ActiveGetterCritters[i]
		if (c != None)
			IH_Util.Trace("\tRecalling critter " + c + " in state: " + ActiveGetterCritters[i].GetState())
			ActiveGetterCritters[i].Cleanup()
		endif
		i += 1
	endwhile
	
	IH_Util.Trace("...Critters recalled, redumping...\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters:")
	PrintCritterArray(StandbyGetterCritters)
	IH_Util.Trace("...deduping arrays...")
	
	standbyCritterCount = 0
	
	i = 127
	int j
	while (i >= 0)
		IH_GetterCritterScript a = ActiveGetterCritters[i]
		IH_GetterCritterScript b
		if (a != None)
			j = i - 1
			while (j >= 0)
				b = ActiveGetterCritters[j]
				if (a == b)
					IH_Util.Trace("\tDeduped ActiveGetterCritters index " + i + "/" + j)
					ActiveGetterCritters[i] = None
				endif
			endwhile
		endif
		
		a = StandbyGetterCritters[i]
		if (a != None)
			j = i - 1
			while (j >= 0)
				b =  StandbyGetterCritters[j]
				if (a == b)
					IH_Util.Trace("\tDeduped StandbyGetterCritters index " + i + "/" + j)
					StandbyGetterCritters[i] = None
					standbyCritterCount -= 1
				endif
				j -= 1
			endwhile
			
			standbyCritterCount += 1
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
	
	IH_Util.Trace("...Recall routine finished. Active#: " + activeCritterCount + ", Standby#: " + standbyCritterCount + ", Redumping arrays:\n\tActiveGetterCritters:")
	PrintCritterArray(ActiveGetterCritters)
	IH_Util.Trace("\n\tStandbyGetterCritters: ")
	PrintCritterArray(StandbyGetterCritters)
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

Function LearnHarvestables()
	if (GetState() != "Learning")
		GoToState("Learning")
		RegisterForSingleUpdate(0.0)
	endif
EndFunction

State Learning
	Event OnUpdate()
		if (learnerRunning)
			IH_FloraLearner.Stop()
			learnerRunning = false
		endif
		int examinedTypesSize = IH_ExaminedTypes.GetSize()
		Cell currentCell = PlayerRef.GetParentCell()
		
		; did the last run not find anything, or was it cast with the same cells loaded?
		; if yes to both, don't bother running, because starting that quest is very expensive (and potentially crashy)
		if (lastExaminedTypesSize != examinedTypesSize || currentCell != lastLearnedCell)
			IH_Util.Trace("Starting learner threads; cell: " + currentCell + " / last count: " + examinedTypesSize)
			learnerRunning = true
			IH_FloraLearner.Start()
			RegisterForSingleUpdate(0.5)
		else
			IH_Util.Trace("Skipping/ending learner routine; cell: " + currentCell + " / last count: " + examinedTypesSize)
			; back to business as usual
			GoToState("")
			RegisterForSingleUpdate(cacheDecayRate)
		endif
		
		lastExaminedTypesSize = examinedTypesSize
		lastLearnedCell = currentCell
	EndEvent
EndState
