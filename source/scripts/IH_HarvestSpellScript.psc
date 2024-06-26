Scriptname IH_HarvestSpellScript extends ActiveMagicEffect

Actor Property PlayerRef Auto

Keyword Property IH_SMKeyword Auto

IH_PersistentDataScript Property IH_PersistentData Auto
IH_FloraLearnerControllerScript Property IH_FloraLearnerController Auto

Perk Property GreenThumb Auto
GlobalVariable Property IH_InheritGreenThumb Auto
GlobalVariable Property IH_CastExp Auto
GlobalVariable Property IH_SpawnDistanceMult Auto

GlobalVariable Property IH_CurrentSearchRadius Auto

Actor caster

ObjectReference[] cachedFlora
int cachedFloraCount
int nextIndex

int Property MaxDelay = 1000000 Auto
{These settings control the "refire" rate of the spell, which we do in-script
 All times are in μs, because Papyrus handles floats stupidly past 2 decimal places
 Starting delay}
int Property MinDelayBase = 400000 Auto
{Min delay, with no bonuses}
int Property MinDelayBonusPerAlteration = 100 Auto
{How much to reduce MinDelay per point of Alteration}
int Property MinDelayBonusPerAlchemy = 50 Auto
{How much to reduce MinDelay per point of Alchemy}
int Property AccelerationBase = 50000 Auto
{Each update will reduce the current delay by this much}
int Property AccelerationBonusPerAlteration = 1000 Auto
{How much to increase AccelerationBase per point of Alteration}
int Property AccelerationBonusPerAlchemy = 500 Auto
{How much to increase AccelerationBase per point of Alchemy}
int Property DualCastAccelMultiplier = 85 Auto
{}
int Property DualCastMinDelayMultiplier = 75 Auto
{}
;int Property SlowModeMultiplier = 4 Auto
;{Multiplier on updates after we run out of flora, to avoid unnecessary processing}

float usDivisor = 1000000.0

int delay
int minDelay
float accel

int Property MinRadius = 750 Auto
{Initial search radius at start of cast /
 Gradually increases to the calculated max radius over the spell's cast time.}
int Property MaxRadiusBase = 1500 Auto
{Max radius of spell with no bonuses}
int Property MaxRadiusBonusPerAlteration = 15 Auto
{How much to increase max radius per point of Alteration}
int Property MaxRadiusBonusPerAlchemy = 10 Auto
{How much to increase max radius per point of Alchemy}
int Property DualCastRadiusMult = 150 Auto

int radius
int maxRadius

int slowMode = 0

bool dualCasting = false

bool hasGreenThumb = false

float baseCost = 5.0
float alterationMod = 1.0

float casterSpeedMult = 100.0
bool casterIsRunning = false

bool Property IsStaff = false Auto
{Controls whether to run staff charge, or magicka drain code}
Keyword Property IH_IsHarvestStaff Auto
bool staffHand

GlobalVariable Property IH_StaffDrainPerSpawn Auto
GlobalVariable Property IH_MagickaDrainPerSpawn Auto
float Property MinSpellReduction Auto
{Spell (not staff) critter spawns will always cost at least this % of base}

Event OnEffectStart(Actor akTarget, Actor akCaster)
;	IH_Util.Trace("Cast effect starting")
	cachedFloraCount = 0
	caster = akCaster
	
	if (IsStaff)
		Weapon left = caster.GetEquippedWeapon(false)
		if (left && left.HasKeyword(IH_IsHarvestStaff))
			staffHand = false
		else
			staffHand = true
		endif
		baseCost = IH_StaffDrainPerSpawn.GetValue()
	else
		if (caster.GetAnimationVariableBool("IsCastingDual"))
			dualCasting = true
		endif
		baseCost = IH_MagickaDrainPerSpawn.GetValue()
	endif
	alterationMod = (100.0 - caster.GetActorValue("AlterationMod")) / 100
	if (alterationMod < MinSpellReduction)
		alterationMod = MinSpellReduction
	endif
	
	if (IH_InheritGreenThumb.GetValue() > 0.0 && caster.HasPerk(GreenThumb))
		hasGreenThumb = true
	endif
	
	float distMult = IH_SpawnDistanceMult.GetValue()
	if (distMult > 0.0)
		; don't bother adjusting for move speed if the critters are set to spawn behind the player
		casterSpeedMult = caster.GetActorValue("SpeedMult")
		casterIsRunning = caster.IsRunning()
		
		if (self != None)
			RegisterForAnimationEvent(caster, "tailCombatLocomotion")
			RegisterForAnimationEvent(caster, "tailSneakLocomotion")
			RegisterForAnimationEvent(caster, "tailCombatIdle")
			RegisterForAnimationEvent(caster, "tailSneakIdle")
		endif
	endif
	
	int alt = caster.GetActorValue("Alteration") as int
	int alch = caster.GetActorValue("Alchemy") as int
	delay = MaxDelay
	minDelay = MinDelayBase - (MinDelayBonusPerAlteration * alt) - (MinDelayBonusPerAlchemy * alch)
	accel = 0.85 - ((AccelerationBonusPerAlteration * alt) + (AccelerationBonusPerAlchemy * alch)) / usDivisor
	
	;radius = MinRadius
	maxRadius = MaxRadiusBase + (MaxRadiusBonusPerAlteration * alt) + (MaxRadiusBonusPerAlchemy * alch)
	
	if (dualCasting)
		maxRadius = maxRadius * DualCastRadiusMult / 100
		accel = accel * DualCastAccelMultiplier / 100
		minDelay = minDelay * DualCastMinDelayMultiplier / 100
	endif
	
	radius = maxRadius
	
;	if (allowReg)
	RegisterForSingleUpdate(delay / usDivisor)
	IH_Util.Trace("Casting by " + caster + ", alt=" + alt + ", alch=" + alch + ", delay=" + delay + ", minDelay=" + minDelay + ", accel=" + accel + ", radius=" + radius + ", maxRadius=" + maxRadius + ", dual=" + dualCasting)
	DoCast()
;	endif
EndEvent

; updates our casterIsRunning value via event, instead of constantly running delayed function calls on the caster (which is almost always the player)
Event OnAnimationEvent(ObjectReference akSource, string asEventName)
	if (asEventName == "tailCombatLocomotion" || asEventName == "tailSneakLocomotion")
		casterIsRunning = true
	else ; tailCombatIdle or tailSneakIdle
		casterIsRunning = false
	endif
EndEvent

;bool allowReg = true
;Event OnEffectFinish(Actor akTarget, Actor akCaster)
;	allowReg = false
;EndEvent

Event OnUpdate()
	if (delay != minDelay)
		delay = (delay * accel) as int
		if (delay < minDelay)
			delay = minDelay
		endif
	endif
	float thisDelay = delay / usDivisor
	if (slowMode > 0)
		thisDelay *= Math.pow(slowMode, 0.66)
	endif
	; IH_Util.Trace("Delay: " + thisdelay)
;	if (allowReg)
	;/ This line errors sometimes and I'm not sure I can fix it:
	; >>https://www.afkmods.com/index.php?/topic/4129-skyrim-interpreting-papyrus-log-errors/
	; >There is largely nothing that can be done about errors of this type. When a magic effect is ready to expire, the Papyrus VM will aggressively destroy the instance of the script. It will generate errors like this if the script had an event pending before this happened. Ignore these unless you know for certain what's causing it. 
	; It's 100% harmless though, if annoying, so I just have to ignore it /;
	RegisterForSingleUpdate(thisDelay)
	DoCast()
;	endif
EndEvent

Function DoCast()
	float cost = baseCost*alterationMod
	if (IsStaff)
		if ((staffHand && caster.GetActorValue("LeftItemCharge") < cost) || (!staffHand && caster.GetActorValue("RightItemCharge") < cost))
			; caster.RemoveSpell(IH_HarvestStaffAbility)
			self.Dispel()
			return
		endif
	else
		if (caster.GetActorValue("Magicka") < cost)
			caster.InterruptCast()
			return
		endif
	endif
	
;	IH_Util.Trace("Casting; current radius: " + radius + "/" + maxRadius + "; current delay:" + delay + "/" + minDelay + ", accel: " + accel)
	ObjectReference thing = GetHarvestable()
	
	if (thing == None)
		IH_Util.Trace("\tNo harvestables found.")
		slowMode += 1 
		return
	else
		slowMode = 0
	endif
	
;	IH_Util.Trace("Getting critter")
	IH_GetterCritterScript getterCritter = IH_PersistentData.GetGetterCritter2(caster, hasGreenThumb)
	if (getterCritter == None)
		IH_Util.Trace("\tFailed to get a critter from IH_PersistentData (most likely at concurrency cap); aborting cast.", 1)
		slowMode += 3
		return
	endif
	
	IH_Util.Trace("Found thing " + thing + ", dispatching critter " + getterCritter)
	IH_PersistentData.AddIgnoredObject(thing)
	
;	IH_Util.Trace("Got critter " + getterCritter)
	
	; affects how quickly
	float speed = 100.0
	float distMult = IH_SpawnDistanceMult.GetValue()
	if (distMult > 0.0 && casterIsRunning)
		speed = casterSpeedMult * 2.0
	endif
	speed *= IH_SpawnDistanceMult.GetValue()
	if (speed > 300.0)
		speed = 300.0
	elseif (speed < -300.0)
		speed = -300.0
	endif
	
	; set up the critter's state and start its thread asynchronously (it's autonomous after this point)
	if (!getterCritter.SetTargets2(caster, thing, speed))
		; don't let the critter leak in case it's in a state where it ignores SetTargets
		IH_Util.Trace("Grabbed critter in incorrect state; bailing out of cast: " + getterCritter)
		IH_PersistentData.ReturnGetterCritter2(getterCritter, hasGreenThumb)
		return
	endif
;	IH_Util.Trace("Set critter's targets: " + caster + ", " + thing)
	
	if (cachedFloraCount == 0) ; precache for next run
		TryCacheHarvestables()
	endif
	
	if (caster == PlayerRef)
		float exp = IH_CastExp.GetValue()
		if (exp > 0.0)
			Game.AdvanceSkill("Alteration", IH_CastExp.GetValue())
		endif
		;~_Util.Trace("Raised Alteration by " + SkillAdvancement)
	endif
	
	if (IsStaff)
		if (staffHand)
			caster.DamageActorValue("LeftItemCharge", cost)
		else
			caster.DamageActorValue("RightItemCharge", cost)
		endif
	else
		caster.DamageActorValue("Magicka", cost)
	endif
EndFunction

ObjectReference Function GetHarvestable()
	; IH_Util.Trace("ct: " + cachedFloraCount + " :" + cachedFlora)
	if (cachedFloraCount <= 0)
		if (TryCacheHarvestables() == false)
			return None
		endif
		; if (cachedFloraCount < 8 && radius < maxRadius)
		; 	; IH_Util.Trace("radius=" + radius + ", maxRadius=" + maxRadius)
		; 	; if the cache is not full, increase the radius for the next check to try to avoid expensive total misses
		; 	radius = (radius * 1.5) as int
		; 	if (radius > maxRadius)
		; 		radius = maxRadius
		; 	endif
		; 	;~_Util.Trace("Bumped search radius to " + radius)
		; 	if (cachedFloraCount == 0)
		; 		; just recurse until we do find something, or exhaust our radius, whichever comes first
		; 		return GetHarvestable()
		; 	endif
		; endif
		if (cachedFloraCount <= 0)
			IH_Util.Trace("GetHarvestable() could not find any flora; running learning routine and returning None")
			IH_FloraLearnerController.Run()
			return None
		endif
	endif
	
	; IH_Util.Trace("cachedFloraCount=" + cachedFloraCount + ", nextIndex=" + nextIndex + ", cachedFlora=" + cachedFlora)
	
	cachedFloraCount -= 1
	ObjectReference toReturn = cachedFlora[nextIndex]
	cachedFlora[nextIndex] = None
	nextIndex += 1
	return toReturn
EndFunction

bool Function TryCacheHarvestables()
	; IH_Util.Trace("Called TryCacheHarvestables--getting things from CacheHarvestables()")
	int i = CacheHarvestables()
	if (i < 0)
		return false
	endif
	
	; IH_Util.Trace("Got " + i + " things back from CacheHarvestables():")
	; IH_Util.DumpObjectArray(cachedFlora)
	
	cachedFloraCount = i
	nextIndex = 0
	return true
EndFunction

int Function CacheHarvestables()
	IH_CurrentSearchRadius.SetValue(radius as float)
	
	ObjectReference[] temp = IH_PersistentData.GetNearbyHarvestables(caster as ObjectReference)
	if (temp.Length == 1)
		; GetNearbyHarvestables failed, so tell caller to do nothing
		return -1
	endif
	cachedFlora = temp
	
	; please ignore how ugly this block of optimized code looks kthx
	; it's just an unrolled + optimized binary search to find the end of the array
	; I don't know why I thought I needed to do this, but I'm not un-writing it
	if (cachedFlora[0] == None)
		; nothing at all found
		return 0
	elseif (cachedFlora[7])
		; array is full (second most common outcome)
		return 8
	elseif (cachedFlora[3])
		if (cachedFlora[5])
			if (cachedFlora[6])
				return 7
			else
				return 6
			endif
		else
			if (cachedFlora[4])
				return 5
			else
				return 4
			endif
		endif
	else
		if (cachedFlora[1])
			if (cachedFlora[2])
				return 3
			else
				return 2
			endif
		else
			return 1
		endif
	endif
EndFunction
