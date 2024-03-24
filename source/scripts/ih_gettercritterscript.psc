Scriptname IH_GetterCritterScript extends Actor Conditional

IH_PersistentDataScript Property IH_PersistentData Auto
VisualEffect Property IH_FXGetterCritterMeshEffect Auto
VisualEffect Property IH_AbsorbGreenTargetVFX Auto
VisualEffect Property IH_AbsorbGreenCastVFX Auto
; Sound Property IH_SFXGetterCritterSpawn Auto
Sound Property IH_SFXGetterCritterDespawn Auto
Form Property IH_FXGetterCritterSpawnPoof Auto
Package Property IH_GetterCritterIdle Auto

GlobalVariable Property IH_NotificationSpam Auto
GlobalVariable Property IH_OffsetReturnPoint Auto

Actor Property Caster Auto
ObjectReference Property Target Auto
ObjectReference Property SpawnExplosion Auto
Static Property XMarker Auto

bool Property HasGreenThumb Auto

bool active = false
bool waitForTranslation = false
bool waitForPathing = false
float lastX = 0.0
float lastY = 0.0
float lastZ = 0.0
float stucktime = 0.0
float casterSpeedMult = 1.0
float returnPointOffset = 0.0
ObjectReference CurrentPathTarget
ReferenceAlias CurrentPathAlias
ObjectReference PathingMarker
ObjectReference MeasurementMarker
int pathingMarkerID = -1

Event OnInit()
	; this effect plays when the critter is "spawned", which actually means "recycled from the cache" most of the time
	; allows us to just reuse the same animation object every time we "spawn" to avoid having to create any refs each "cast"
	CheckPersistentSpawns()
	GoToState("Done")
EndEvent

bool Function SetTargets2(Actor c, ObjectReference t, float speed)
	IH_Util.Trace(self + " SetTargets called in wrong state " + GetState() + "; ignoring call and dumping stack trace.", 1)
	Debug.TraceStack(self + " printing SetTargets stack trace")
	return false
EndFunction

State Init
	;This needs to run async from the thread that spawned it, so we just send a single update with no delay to kick it off	
	Event OnUpdate()
		if (Caster == None || Target == None)
			IH_Util.Trace("\t" + self + " OnUpdate() called in Init state, but Caster = " + Caster + ", and Target = " + Target + ", which is invalid. Ignoring.", 1)
			Cleanup()
			return
		endif
		GoToState("Started")
		
		CheckPersistentSpawns()
		
		;~_Util.Trace(self + " Critter's thread started")
		
		; place in front of the caster
		float angle = Caster.GetAngleZ()
		; float zOffset = 128 / Math.tan(Caster.GetAngleX())
		;;~ebug.TraceUser("IHarvest", zOffset)
		
		; if (isVR)
		; 	MeasurementMarker.MoveTo(Caster)
		; 	MoveTo(Caster, \
		; 	controllerX - MeasurementMarker.GetPositionX() + 192.0 * casterSpeedMult * Math.sin(controllerHeading), \
		; 	controllerY - MeasurementMarker.GetPositionY() + 192.0 * casterSpeedMult * Math.cos(controllerHeading), 0.0, true)
		; else
		MoveTo(Caster, 192.0 * casterSpeedMult * Math.sin(angle), 192.0 * casterSpeedMult * Math.cos(angle), 0.0, true)
		; endif
				
		; SetPosition(Caster.GetPositionX() + 128.0 * Math.sin(angle), Caster.GetPositionY() + 128.0 * Math.cos(angle), Caster.GetPositionZ() + zOffset)
		; MoveTo totally ignores the zOffset argument apparently, and SetPosition does insane things *shrug*
		
		EnableNoWait(false)
		;~_Util.Trace(self + " Enabled")
		
		int i = 0
		SpawnExplosion.Enable(false)
		while (Is3DLoaded() == false && i < 50)
			Utility.Wait(0.02)
			i += 1
		endWhile
		if (i == 50)
			IH_Util.Trace("\t" + self + " 3D never loaded after 25 checks; abandoning spawn attempt and cleaning up", 2)
			Cleanup()
			return
		endif
		;~_Util.Trace(self + "Took " + i + " loops for 3d to load")
		SpawnExplosion.MoveToNode(self, "Witchlight Body Lag")
		; IH_Util.Trace(SpawnExplosion.Is3dLoaded())
		
		; IH_Util.Trace("anim:" + PlaceAtMe(IH_FXGetterCritterSpawnPoof).)
		IH_FXGetterCritterMeshEffect.Play(self, -1)
		; IH_SFXGetterCritterSpawn.Play(self)
		
		; this will only work if played slightly after the MoveToNode(), starting the mesh effect first is enough delay
		i = 0
		while (SpawnExplosion.Is3DLoaded() == false && i < 5)
			i += 1
		endWhile
		if (i < 5)
			SpawnExplosion.PlayGamebryoAnimation("SpecialIdle_AreaEffect", true, 0.5)
		endif
		
		; get the critter started, but not directly back into the caster's face
		float ha = GetHeadingAngle(Target)
		if (casterSpeedMult >= 0.0)
			if (ha >= 0.0)
				if (ha > 140.0)
					ha = 140.0
				endif
			else
				if (ha < -140.0)
					ha = -140.0
				endif
			endif
		else
			if (ha >= 0.0)
				if (ha < 40.0)
					ha = 40.0
				endif
			else
				if (ha > -40.0)
					ha = -40.0
				endif
			endif
			SetAngle(0.0, 0.0, GetAngleZ() - 180.0)
		endif
		float tgtAngle = angle + ha
		; IH_Util.Trace(angle + " " + ha + " " + tgtAngle)
		
		SplineTranslateTo(GetPositionX() + 320.0 * Math.sin(tgtAngle), GetPositionY() + 320.0 * Math.cos(tgtAngle), GetPositionZ() + 64.0, 0.0, 0.0, tgtAngle, 452.5483399, 500.0, 0.0)
		
		if (Target == None)
			;~_Util.Trace(self + " Target went None before VFX plays, so bailing out")
			Cleanup()
			return
		endif
		
		Form targetBase = Target.GetBaseObject()
		; Utility.Wait(0.1)
		
		if (Target == None)
			;~_Util.Trace(self + " Target went None before path, so bailing out")
			Cleanup()
			return
		endif
		
		CurrentPathTarget = Target
		
		if (pathingMarkerID >= 0)
			; on rare occasions, this script fails to check markers back in properly for some reason,
			; so make sure our marker ID gets put back before we check out a new one, otherwise
			; the tracker array slowly gets corrupted and this will eventually stop working right
			IH_Util.Trace("\t" + self + " wtf? pathingMarkerID >= 0 before checking out path marker; returned old marker to cache.", 1)
			IH_PersistentData.ReturnPathingAlias(pathingMarkerID)
		endif
		
		;PathToReference(Target, 1.0) bad bad bad never use this function (see CheckoutPathingAlias() in IH_PersistentDataScript)
		pathingMarkerID = IH_PersistentData.CheckoutPathingAlias()
		if (pathingMarkerID < 0)
			IH_Util.Trace("\t" + self + " Failed to checkout pathing marker; falling back to translates.", 1)
			
			CheckAndPlayDrainVFX()
		else
			GotoState("Pathing")
			stucktime = 0.0
			RegisterForSingleUpdate(0.0)
			PathingMarker = IH_PersistentData.GetPathingMarker(pathingMarkerID)
			PathingMarker.MoveTo(CurrentPathTarget)
			CurrentPathAlias = IH_PersistentData.GetPathingAlias(pathingMarkerID)
			CurrentPathAlias.ForceRefTo(self)
			EvaluatePackage()
			
			CheckAndPlayDrainVFX()
			
			WaitForPath()
			CurrentPathAlias.Clear()
			UnregisterForUpdate()
		endif
		
		float toReturnX = GetPositionX()
		float toReturnY = GetPositionY()
		float toReturnZ = GetPositionZ()
		
		; translate -near- the reference, quickly, if we're not already there
		TranslateWithinRadius(Target, 0.0, 96.0, 128.0, 2000.0, true)
		
		; float thght = Target.GetHeight()
		; IH_Util.Trace(Target + " height: " + thght + " self: " + GetPositionZ() + " formula: " + (thght / 2.0 - 85))
		; translate -into- the reference (kind of a "picking" animation)
		if (Target == None)
			;~_Util.Trace(self + " Target went None before translate, so bailing out")
			Cleanup()
			return
		endif
		TranslateWithinRadius(Target, Target.GetHeight() / 2.0 - 85.0, 10.0, 1.0, 250.0, true)
		
		if (Target == None)
			;~_Util.Trace(self + " Target went None before pickup, so bailing out")
			Cleanup()
			return
		endif
		GotoState("Harvesting")
		IH_AbsorbGreenTargetVFX.Stop(Target)
		if (targetBase as TreeObject || targetBase as Flora || targetBase as Activator)
			Target.Activate(self)
		elseif (targetBase as Ingredient || targetBase as Ammo || targetBase as Armor || targetBase as Book || targetBase as MiscObject || targetBase as Potion || targetBase as Scroll || targetBase as Weapon)
			; any item that can be picked up must be specially handled, otherwise making an Actor Activate() the item
			; can potentially delete items (stacked items will only pick up exactly one item from the stavk)
			AddItem(Target)
		else
			Target.Activate(self)
		endif
		IH_AbsorbGreenCastVFX.Stop(self)
		
		if (pathingMarkerID >= 0)
			; set up the pathing marker while translating
			CurrentPathTarget = Caster
			if (returnPointOffset > 0.0)
;				IH_Util.Trace(CurrentPathTarget)
				MoveToClosestRadius(PathingMarker, CurrentPathTarget, returnPointOffset, returnPointOffset * 1.25)
			else
				PathingMarker.MoveTo(CurrentPathTarget)
			endif
		endif
		
		; now go back to the point before we took over with translates
		; I suspect that trying to pathfind back to the player out of a weird spot is the cause of some CTDs I've noticed,
		; and there's a very good chance that we're nowhere near a good spot on the navmesh right now
		; Navmesh/pathfinding issues are a common cause of "random" CTDs, but they're hard to diagnose so few players/modders realize
		TranslateWithinRadiusCoords(toReturnX, toReturnY, toReturnZ, 96.0, 128.0, 2000.0, false)
		TranslateWithinRadiusCoords(toReturnX, toReturnY, toReturnZ, 0.0, 0.0, 350.0, false)
		
		; PathToReference(Caster, 1.0)
		if (pathingMarkerID >= 0)
			GotoState("Pathing")
			stucktime = 0.0
			RegisterForSingleUpdate(0.0)
			CurrentPathAlias.ForceRefTo(self)
			EvaluatePackage()
			WaitForPath()
			UnregisterForUpdate()
			CurrentPathAlias.Clear()
			IH_PersistentData.ReturnPathingAlias(pathingMarkerID)
		endif
		
		if (returnPointOffset < 192.0)
			TranslateWithinRadius(Caster, 0.0, 192.0, 384.0, 800.0, true, 0, 1.5)
		else
			TranslateWithinRadius(Caster, 0.0, returnPointOffset, returnPointOffset + 192.0, 800.0, true, 0, 1.5)
		endif
		
		if (Is3dLoaded())
			SpawnExplosion.MoveToNode(self, "Witchlight Body Lag")
			DisableNoWait()
			i = 0
			while (SpawnExplosion.Is3DLoaded() == false && i < 8)
				i += 1
			endWhile
			if (i < 8)
				SpawnExplosion.PlayGamebryoAnimation("SpecialIdle_AreaEffect", true, 0.5)
				IH_SFXGetterCritterDespawn.Play(SpawnExplosion)
			endif
		else
			DisableNoWait()
		endif
		
		bool silent = IH_NotificationSpam.GetValue() <= 0.0
		; can't just use RemoveAllItems because I want notification messages for the player
		; (RemoveAllItems doesn't have a silent parameter until FO4)
		int itemct = GetNumItems()
		while (itemct > 0)
			itemct -= 1
			Form item = GetNthForm(itemct)
			if (item as ObjectReference)
				; This is very slightly faster as we don't have to wait in the caster's queue.
				; More importantly, it keeps us from accidentally deleting a persistent reference in
				; case a quest or something is using it. It never displays an Added message, though.
				RemoveItem(item, 65535, silent, Caster)
			else
				Caster.AddItem(item, GetItemCount(item), silent)
			endif
				
			;IH_Util.Trace("thing:" + item)
		endwhile
		
		; the last block is actually duping anything non-persistent, so the inventory
		; needs to be manually cleaned before returning to the cache
		RemoveAllItems(None, false, true)
		
		Cleanup()
	EndEvent
EndState

State Pathing
	Event OnUpdate()
		if (!self)
			return
		endif
		
		float thisX = GetPositionX()
		float thisY = GetPositionY()
		float thisZ = GetPositionZ()
		
;		IH_Util.Trace("\t\t" + self + " (" + thisX + "/" + lastX + "," + thisY + "/" + lastY + "," + thisZ + "/" + lastZ + "), stucktime: " + stucktime)
		
		float variance = 8.0
		
		if (thisX > lastX - variance && thisX < lastX + variance \
		 && thisY > lastY - variance && thisY < lastY + variance \
		 && thisZ > lastZ - variance && thisZ < lastZ + variance)
			float thistime = Utility.GetCurrentRealTime()
			;IH_Util.Trace(thistime + " " + stucktime)
			if (stucktime == 0.0)
				stucktime = thistime
			elseif (thistime > stucktime + 1.75)
				;~_Util.Trace("Getter Critter " + self + " got stuck while pathing; interrupting")
				StopPathing()
				return
			endif
		else
			stucktime = 0.0
		endif
		lastX = thisX
		lastY = thisY
		lastZ = thisZ
		
		if (CurrentPathTarget)
			if (CurrentPathTarget == Caster)
				if (PathingMarker) ; (pathingMarkerID >= 0)
					if (returnPointOffset > 0.0)
						MoveToClosestRadius(PathingMarker, CurrentPathTarget, returnPointOffset, returnPointOffset * 1.25)
					else
						PathingMarker.MoveTo(CurrentPathTarget)
					endif
				endif
				RegisterForSingleUpdate(0.125)
			else
				if (PathingMarker) ; (pathingMarkerID >= 0)
					PathingMarker.MoveTo(CurrentPathTarget)
				endif
				RegisterForSingleUpdate(0.25)
			endif
		else
			IH_Util.Trace("\t" + self + " CurrentPathTarget went None, stopping pathing")
			StopPathing()
			return
		endif
	EndEvent
	
;	Event OnPackageStart(Package akNewPackage)
;		IH_Util.Trace(self + " started new package: " + akNewPackage)
;	EndEvent
	
	Event OnPackageEnd(Package akOldPackage)
		;IH_Util.Trace(self + " ended package: " + akOldPackage + " in state " + GetState())
		if (akOldPackage != IH_GetterCritterIdle)
			StopPathing()
		endif
	EndEvent
EndState

State Translating
	Event OnTranslationAlmostComplete()
		waitForTranslation = false
	EndEvent
EndState

State Done
	bool Function SetTargets2(Actor c, ObjectReference t, float speed)
		active = true
		
		;~_Util.Trace(self + " going after " + t)
		casterSpeedMult = speed / 100.0
		returnPointOffset = IH_OffsetReturnPoint.GetValue()
		Caster = c
		Target = t
		GotoState("Init")
		RegisterForSingleUpdate(0.0)
		return true
	EndFunction
	
	Function CleanErrantGraphics()
		Disable()
		if (SpawnExplosion)
			SpawnExplosion.Disable()
		endif
	EndFunction
	
	Event OnUpdate()
		float thistime = Utility.GetCurrentRealTime()
		if (thistime > stucktime + 1.5 || thistime < stucktime)
			if (SpawnExplosion)
				SpawnExplosion.Disable()
			endif
		else
			; I have no idea why this is needed—maybe some external script is registering us for updates for some reason?
			; Anyway, unless we have this check, the spawn poof disables itself too early, and causes a small audial/visual bug
			;~_Util.Trace(self + " \"Done\" update came early! But why? Ignoring this update.")
			RegisterForSingleUpdate(stucktime - thistime + 1.5)
		endif
	EndEvent
EndState

Function CheckAndPlayDrainVFX()
	if (Target.Is3DLoaded())
		IH_AbsorbGreenTargetVFX.Play(Target, 60.0, self)
	endif
	IH_AbsorbGreenCastVFX.Play(self, 60.0, Target)
EndFunction

; separated out of OnInit() so I could update a dev save
Function CheckPersistentSpawns()
	if (SpawnExplosion == None)
		SpawnExplosion = PlaceAtMe(IH_FXGetterCritterSpawnPoof, 1, true, false)
		SpawnExplosion.SetScale(0.225)
	endif
	
	if (MeasurementMarker == None)
		MeasurementMarker = PlaceAtMe(XMarker, 1, true, true)
	endif
EndFunction

Function MoveToClosestRadius(ObjectReference ref, ObjectReference tgt, float radius, float skipRadius)
	if (ref.GetDistance(tgt) < skipRadius)
		return
	endif
	float posX = ref.GetPositionX() ; not to be confused with POSIX
	float posY = ref.GetPositionY()
	float posZ = ref.GetPositionZ()
	
	; It's generally a bad idea to constantly poll an actor's position, especially the player, because it'll lead to
	; lock issues with other threads—however, we do still need to measure our target's coordinates frequently.
	; So, if we create a ref that we just move to the target and measure from that, we can get the same coordinates,
	; just faster because no other thread will be trying to interact with it too.
	MeasurementMarker.MoveTo(tgt)
	float targetX = MeasurementMarker.GetPositionX()
	float targetY = MeasurementMarker.GetPositionY()
	float targetZ = MeasurementMarker.GetPositionZ()
	
	float[] targetCoords = IH_Util.GetClosestPointAtRadius(posX, posY, posZ, targetX, targetY, targetZ, radius)
	ref.SetPosition(targetCoords[0], targetCoords[1], targetCoords[2])
	; IH_Util.Trace("from ref: (" + posX + "," + posY + "," + posZ + "), toRef: (" + targetX + "," + targetY + "," + targetZ + "), radius: " + radius + "; output: (" + targetCoords[0] + "," + targetCoords[1] + "," + targetCoords[2] + ")")
EndFunction

;/ This nifty function could pretty easily be adapted into a generic one that works on anything,
; but having it run "first person" with self calls is way faster than external calls on the object being moved /;
Function TranslateWithinRadius(ObjectReference tgt, float zOffset, float radius, float skipRadius, float speed, bool faceTargetFirst = false, int recursionDepth = -1, float recurseSpeedMult = 1.0)
	if (tgt == None)
		return
	endif
	float dist = GetDistance(tgt)
	if (dist == 0.0)
		; there's two reasons for this check:
		; 1. There will never be a reason to translate if we're already exactly at the same coords as the target, so just bail
		; 2. More importantly, if tgt goes missing (e.g. it's an item that the player picked up before the critter got to it),
		; the script locks up and prints loads of errors to the console, and if it's 0.0 then this might have happened
		return
	endif
	
	if (skipRadius > 0.0 && dist < skipRadius)
		return
	endif
	
	float targetX = tgt.GetPositionX()
	float targetY = tgt.GetPositionY()
	float targetZ = tgt.GetPositionZ()
	
	; float angleX = GetAngleX()
	float angleZ = GetAngleZ() + GetHeadingAngle(tgt)
	if (faceTargetFirst)
		SetAngle(0.0, 0.0, angleZ)
	endif
	
	float scale = radius / dist
	targetX -= (targetX - GetPositionX()) * scale
	targetY -= (targetY - GetPositionY()) * scale
	targetZ -= (targetZ - GetPositionZ()) * scale - zOffset
	if (!SplineTranslateToLatent(targetX , targetY, targetZ, 0.0, 0.0, angleZ, dist-radius, speed))
		return
	endif
	
	if (recursionDepth < 3)
		if (recursionDepth >= 0)
			TranslateWithinRadius(tgt, zOffset, radius, skipRadius, speed * recurseSpeedMult, faceTargetFirst, recursionDepth + 1, recurseSpeedMult)
		endif
	else
		MoveTo(tgt)
	endif
EndFunction

;/ Alternative to the above that takes an (x,y,z) instead of a ref
; Also lacks the recursive "chasing" feature since coordinates don't move/;
Function TranslateWithinRadiusCoords(float targetX, float targetY, float targetZ, float radius, float skipRadius, float speed, bool faceTargetFirst = false)
	float posX = GetPositionX()
	float posY = GetPositionY()
	float posZ = GetPositionZ()
	
	float dist = IH_Util.GetObjectDistance(targetX, targetY, targetZ, posX, posY, posZ)

	if (skipRadius > 0.0 && skipRadius > dist)
		return
	endif
	
	float[] targetCoords = IH_Util.GetClosestPointAtRadius(posX, posY, posZ, targetX, targetY, targetZ, radius, dist)
	
	if (faceTargetFirst)
		SetAngle(0.0, 0.0, targetCoords[3])
	endif
	
;	IH_Util.Trace("from " + posX + " " + posY + " " + posZ + " to " + targetX + " " + targetY + " " + targetZ + " 0.0, 0.0, " + atan2 + " " + (dist-radius) + " " + speed)
	SplineTranslateToLatent(targetCoords[0] , targetCoords[1], targetCoords[2], 0.0, 0.0, targetCoords[3], dist-radius, speed)
EndFunction

bool Function SplineTranslateToLatent(float targetX, float targetY, float targetZ, float angleX, float angleY, float angleZ, float tangent, float speed)
	waitForTranslation = true
	GotoState("Translating")
	
	if (!Is3DLoaded())
		;~_Util.Trace(self + " Bailing out of SplineTranslateToLatent because 3D unloaded")
		return false
	endif
	
	; in oldrim this would break the actor's collision, which would be really useful, but doesn't work in SSE dammit
	SplineTranslateTo(targetX, targetY, targetZ, angleX, angleY, angleZ, tangent, speed, 0.0)
	
	float starttime = Utility.GetCurrentRealTime()
	float lasttime = starttime
	float thistime = starttime
	int i = 0
	while (waitForTranslation)
		Utility.Wait(0.02) ; min wait time is 1 frame
		
		if (i % 20 == 0)
			thistime = Utility.GetCurrentRealTime()
			if (thistime < lasttime)
				; cover the case where the game is restarted during this loop
				IH_Util.Trace(self + " Time ran backwards! Correcting for temporal anomaly.")
				starttime += thistime - lasttime
			endif
			
			if (thistime >= starttime + 15.0 || !Is3DLoaded())
				return false
			endif
			lasttime = thistime
		endif
		
		i += 1
	endwhile
	return true
EndFunction

bool Function WaitForPath(float timeout = 15.0)
	waitForPathing = true
	
	float starttime = Utility.GetCurrentRealTime()
	float lasttime = starttime
	float thistime = starttime
	
	int i = 0
	while (waitForPathing)
		Utility.Wait(0.02)
		
		if (i % 20 == 0)
			thistime = Utility.GetCurrentRealTime()
			if (thistime < lasttime)
				; cover the case where the game is restarted during this loop
				IH_Util.Trace(self + " Time ran backwards! Correcting for temporal anomaly.")
				starttime += thistime - lasttime
			endif
			
			if (thistime >= starttime + timeout || !Is3dLoaded())
				StopPathing()
				return false
			endif
			
			lasttime = thistime
		endif
		i += 1
	endwhile
	return true
EndFunction

Function StopPathing()
	if (CurrentPathAlias)
		CurrentPathAlias.Clear()
	endif
	EvaluatePackage()
	waitForPathing = false
EndFunction

Function Cleanup()
	DisableNoWait()
	if (Target != None)
		IH_AbsorbGreenTargetVFX.Stop(Target)
	endif
	IH_AbsorbGreenCastVFX.Stop(self)
	
	Caster = None
	Target = None
	CurrentPathTarget = None
	CurrentPathAlias = None
	
	; kill any looping threads waiting for latent functions
	waitForTranslation = false
	waitForPathing = false
	
	if (pathingMarkerID >= 0)
		int toReturn = pathingMarkerID
		pathingMarkerID = -1
		IH_PersistentData.ReturnPathingAlias(toReturn)
	endif
	PathingMarker = None
	
	UnregisterForUpdate()
	stucktime = Utility.GetCurrentRealTime()
	GotoState("Done")
	RegisterForSingleUpdate(2.0) ; disable the poof object
	ModActorValue("Fame", 1.0)
	
	if (active)
		active = false
		IH_PersistentData.ReturnGetterCritter2(self, HasGreenThumb)
	else
		IH_Util.Trace(self + " Skipped return to cache becasue \"active\" is false, which would likely have caused cache confusion.", 1)
	endif
	
	; the game seems to occasionally ignore the DisableNoWait(),
	; so do it again just to be sure
	Disable() 
EndFunction

Function Delete()
	Cleanup()
	
	SpawnExplosion.Delete()
	SpawnExplosion = None
	MeasurementMarker.Delete()
	MeasurementMarker = None
	
	GoToState("Deleted")
	parent.Delete()
EndFunction

Function CleanErrantGraphics()
EndFunction

;/ =========================== \;
; Deprecated function graveyard ;
;\ =========================== /;

; changed the function signature
bool Function SetTargets(Actor c, ObjectReference t)
	return SetTargets2(c, t, 1.0)
EndFunction

; moved to IH_Util because this function was pure math anyway
float[] Function GetClosestPointAtRadius(float startX, float startY, float startZ, float targetX, float targetY, float targetZ, float radius, float distance = -1.0)
	return IH_Util.GetClosestPointAtRadius(startX, startY, startZ, targetX, targetY, targetZ, radius, distance)
EndFunction
