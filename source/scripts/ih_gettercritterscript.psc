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

Actor Property Caster Auto
ObjectReference Property Target Auto
ObjectReference Property SpawnExplosion Auto
Static Property XMarker Auto

bool active = false
bool waitForTranslation = false
bool waitForPathing = false
float lastX = 0.0
float lastY = 0.0
float lastZ = 0.0
float stucktime = 0.0
ObjectReference CurrentPathTarget
ReferenceAlias CurrentPathAlias
ObjectReference PathingMarker
ObjectReference MeasurementMarker
int pathingMarkerID = -1

Event OnInit()
	; this effect plays when the critter is "spawned", which actually means "recycled from the cache" most of the time
	; allows us to just reuse the same animation object every time we "spawn" to avoid having to create any refs each "cast"
	SpawnExplosion = PlaceAtMe(IH_FXGetterCritterSpawnPoof, 1, false, false)
	SpawnMeasurementMarker()
	SpawnExplosion.SetScale(0.225)
	GoToState("Done")
EndEvent

bool Function SetTargets(Actor c, ObjectReference t)
	IH_Util.Trace(self + " SetTargets called in wrong state " + GetState() + "; ignoring call and dumping stack trace.")
	Debug.TraceStack(self + " printing SetTargets stack trace")
	return false
EndFunction

State Init
	;This needs to run async from the thread that spawned it, so we just send a single update with no delay to kick it off	
	Event OnUpdate()
		;~_Util.Trace(self + " Critter's thread started")
		; place in front of the caster
		float angle = Caster.GetAngleZ()
		; float zOffset = 128 / Math.tan(Caster.GetAngleX())
		;;~ebug.TraceUser("IHarvest", zOffset)
		MoveTo(Caster, 196.0 * Math.sin(angle), 196.0 * Math.cos(angle), 0.0)
		; SetPosition(Caster.GetPositionX() + 128.0 * Math.sin(angle), Caster.GetPositionY() + 128.0 * Math.cos(angle), Caster.GetPositionZ() + zOffset)
		; MoveTo totally ignores the zOffset argument apparently, and SetPosition does insane things *shrug*
		
		EnableNoWait(false)
		;~_Util.Trace(self + " Enabled")
		
		int i = 0
		SpawnExplosion.Enable(false)
		while (Is3DLoaded() == false && i < 25)
			Utility.Wait(0.01)
			i += 1
		endWhile
		if (i == 25)
			IH_Util.Trace("\t" + self + " 3D never loaded after 25 checks; abandoning spawn attempt and cleaing up")
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
		angle += 720 ; make sure we're not dealing with annoying wraparound
		float tgtAngle = angle + GetHeadingAngle(Target)
		if (tgtAngle > angle + 135.0)
		;	IH_Util.Trace("capped to +135")
			tgtAngle = angle + 135.0
		elseif (tgtAngle < angle - 135.0)
		;		IH_Util.Trace("capped to -135")
			tgtAngle = angle - 135.0
		endif
		tgtAngle = IH_Util.NormalizeAngle(tgtAngle)
		
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
			; not sure if I need this, but I've noticed that my cache will very slowly corrupt over time for some reason from
			; checked out aliases never getting checked back in, 
			IH_PersistentData.ReturnPathingAlias(pathingMarkerID)
			IH_Util.Trace("\t" + self + " wtf? pathingMarkerID >= 0 before checking out path marker; returned old marker to cache.")
		endif
		
		;PathToReference(Target, 1.0) bad bad bad never use this function (see CheckoutPathingAlias() in IH_PersistentDataScript)
		pathingMarkerID = IH_PersistentData.CheckoutPathingAlias()
		if (pathingMarkerID < 0)
			IH_Util.Trace("\t" + self + " Failed to checkout pathing marker; falling back to translates.")
			
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
		if (targetBase as Ingredient)
			; activating ingredient works, but always cuts the stack size down to 1 for some reason
			AddItem(Target)
		;/	if (Target != None)
				;~_Util.Trace(self + " Target " + Target + " is not None, why? " + GetItemCount(targetBase))
			else
				;~_Util.Trace(self + " Target went None like it should.")
			endif
		/;
		else
			Target.Activate(self)
			IH_AbsorbGreenTargetVFX.Stop(Target)
		endif
		IH_AbsorbGreenCastVFX.Stop(self)
		
		if (pathingMarkerID >= 0)
			; set up the pathing marker while translating
			CurrentPathTarget = Caster
			PathingMarker.MoveTo(CurrentPathTarget)
			; Hoped this would make the critter smash into the player less, but turns out it's the same except slower
			; MoveToClosestRadius(PathingMarker, CurrentPathTarget, 64.0, 96.0)
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
		
		TranslateWithinRadius(Caster, 0.0, 128.0, 384.0, 800.0, true, 0, 1.5)
		
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
		
		if (IH_NotificationSpam.GetValue())
			; can't just use RemoveAllItems because I want notification messages for the player
			; (RemoveAllItems doesn't have a silent parameter until FO4)
			int itemct = GetNumItems()
			while (itemct > 0)
				itemct -= 1
				Form item = GetNthForm(itemct)
				;IH_Util.Trace("thing:" + item)
				;RemoveItem(GetNthForm(itemct), 65535, false, Caster)
				Caster.AddItem(item, GetItemCount(item), false)
			endwhile
			RemoveAllItems(None, false, true)
		else
			RemoveAllItems(Caster, true, true)
		endif
		
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
			elseif (thistime > stucktime + 1.25)
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
				;MoveToClosestRadius(PathingMarker, CurrentPathTarget, 64.0, 96.0)
				if (PathingMarker) ; (pathingMarkerID >= 0)
					PathingMarker.MoveTo(CurrentPathTarget)
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
	bool Function SetTargets(Actor c, ObjectReference t)
		;~_Util.Trace(self + " going after " + t)
		Caster = c
		Target = t
		active = true
		GotoState("Init")
		RegisterForSingleUpdate(0.0)
		return true
	EndFunction
	
	Event OnUpdate()
		float thistime = Utility.GetCurrentRealTime()
		if (thistime > stucktime + 1.5)
			if (SpawnExplosion)
				SpawnExplosion.DisableNoWait()
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
Function SpawnMeasurementMarker()
	if (MeasurementMarker == None)
		MeasurementMarker = PlaceAtMe(XMarker, 1, true, true)
	endif
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
	
	if (recursionDepth < 20)
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
	
	float[] targetCoords = GetClosestPointAtRadius(posX, posY, posZ, targetX, targetY, targetZ, radius, dist)
	
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
	int i = 0
	while (waitForTranslation)
		Utility.Wait(0.005) ; min wait time is 1 frame
		if (i % 20 == 0)
			if (Utility.GetCurrentRealTime() >= starttime + 15.0)
				return false
			endif
		endif
		i += 1
	endwhile
	return true
EndFunction

; cylindrical instead of spherical radius because I can't be bothered calculating a sphere
float[] Function GetClosestPointAtRadius(float startX, float startY, float startZ, float targetX, float targetY, float targetZ, float radius, float distance = -1.0)
	if (distance > 0.0)
		distance = IH_Util.GetObjectDistance(startX, startY, startZ, targetX, targetY, targetZ)
	endif
	float[] out = new float[4]
	
	; can't just GetHeadingAngle, so we have to calc atan2 manually
	float xDiff = targetX - startX
	float yDiff = targetY - startY
	float atan2 = 0.0
	if (yDiff > 0.01 || yDiff < -0.01) ; checking == 0.0 still causes div by 0 errors sometimes
		atan2 = xDiff*xDiff + yDiff*yDiff
		if (atan2 > 0.01)
			; same as above, without this check this line will produce div by 0 errors sometimes `\_@_/`
			; this is despite Math.sqrt(0) not even being a mathematically invalid operation anyway
			atan2 = Math.sqrt(atan2) - xDiff
		else
			atan2 -= xDiff
		endif
		
		atan2 /= yDiff
		atan2 = Math.atan(atan2) * 2
	elseif (xDiff > 0.01 || xDiff < -0.01)
		atan2 = Math.atan(yDiff / xDiff)
		if (xDiff < 0.0)
			atan2 += 180.0
		endif
	endif
;	IH_Util.Trace("Calculated angle between (" + startX + "," + startY + ") and (" + targetX + "," + targetY + ") as " + atan2)
	
	float scale = radius / distance
	targetX -= (targetX - startX) * scale
	targetY -= (targetY - startY) * scale
	targetZ -= (targetZ - startZ) * scale
	
	out[0] = targetX
	out[1] = targetY
	out[2] = targetZ
	out[3] = atan2
	return out
EndFunction

Function MoveToClosestRadius(ObjectReference ref, ObjectReference tgt, float radius, float skipRadius)
	; It's generally a bad idea to constantly poll an actor's position, especially the player, because it'll lead to
	; lock issues with other threads—however, we do still need to measure our target's coordinates frequently.
	; So, if we create a ref that we just move to the target and measure from that, we can get the same coordinates,
	; just faster because no other thread will be trying to interact with it too.
	if (ref.GetDistance(tgt) < skipRadius)
		return
	endif
	float posX = GetPositionX() ; not to be confused with POSIX
	float posY = GetPositionY()
	float posZ = GetPositionZ()
	
	MeasurementMarker.MoveTo(tgt)
	float targetX = MeasurementMarker.GetPositionX()
	float targetY = MeasurementMarker.GetPositionY()
	float targetZ = MeasurementMarker.GetPositionZ()
	
	float[] targetCoords = GetClosestPointAtRadius(posX, posY, posZ, targetX, targetY, targetZ, radius)
	ref.SetPosition(targetCoords[0], targetCoords[1], targetCoords[2]) 
EndFunction

bool Function WaitForPath(float timeout = 15.0)
	waitForPathing = true
	float starttime = Utility.GetCurrentRealTime()
	int i = 0
	while (waitForPathing)
;		IH_Util.Trace(self + " ...waiting for pathing...")
		if (!Is3dLoaded())
			StopPathing()
			return false
		endif
		Utility.Wait(0.1)
		
		if (i % 20 == 0 && Utility.GetCurrentRealTime() >= starttime + timeout)
			StopPathing()
			return false
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
		IH_PersistentData.ReturnGetterCritter(self)
	else
		IH_Util.Trace(self + " Skipped return to cache becasue \"active\" is false, which would likely have caused cache confusion.")
	endif
	
	active = false
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
