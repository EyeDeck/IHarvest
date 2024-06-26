ScriptName IH_Util

;/ Recursive function that takes a form (Ingredient, FormList or LeveledItem),
; and determines whether that form can produce alchemy ingredients /;
bool Function ProducesIngredient(Form f, bool food, bool hf) Global
	Form[] seen = new Form[128]
	return ProducesIngredientInternal(f, food, hf, seen)
EndFunction

;/ Realized I had to add an infinite recursion check, otherwise Bad Things could happen;
; best way to do that was to make the original function into a proxy /;
bool Function ProducesIngredientInternal(Form f, bool food, bool hf, Form[] seen) Global
	int last
	; IH_Util.Trace("Examining Form " + f)
	if (f == None)
		IH_Util.Trace("None form passed to ProducesIngredientInternal? Weird.", 1)
		return false
	endif
	
	if (seen.Find(f) >= 0)
		string s = "IHarvest: Skipped a circular FormList/LeveledItem " + f + " in ProducesIngredient() - you may want to investigate this as this may cause crashes elsewhere!"
		DEBUG.Trace(s, 1)
		IH_Util.Trace(s, 1)
		return false
	endif
	
	if (f as Ingredient)
		return true
	endif
	
	if (food)
		Potion fP = f as Potion
		if (fP)
			if (fP.IsFood())
				return true
			else
				return false
			endif
		endif
	endif
	
	if (hf)
		BYOHHiddenObjectScript ho = f as BYOHHiddenObjectScript
		if (ho)
			if (ho.itemToAddPotion && ProducesIngredientInternal(ho.itemToAddPotion, food, hf, seen))
				return true
			elseif (ho.itemToAddIngredient && ProducesIngredientInternal(ho.itemToAddIngredient, food, hf, seen))
				return true
			endif
			return false
		endif
	endif
	
	LeveledItem fLI = f as LeveledItem
	if (fLI != None)
		last = seen.Find(None)
		seen[last] = f
		
		if (fLI.GetChanceNone() >= 100)
			; This probably never actually comes up, but might as well check for it anyway
			return false
		endif
		int ct = fLI.GetNumForms()
		int i = 0
		while (i < ct)
			if (fLI.GetNthCount(i) > 0 && ProducesIngredientInternal(fLI.GetNthForm(i), food, hf, seen))
				return true
			endif
			i += 1
		endwhile
		return false
	endif
	
	FormList fFL = f as FormList
	if (fFL != None)
		last = seen.Find(None)
		seen[last] = f
		
		int ct = fFL.GetSize()
		int i = 0
		while (i < ct)
			if (ProducesIngredientInternal(fFL.GetAt(i), food, hf, seen))
				return true
			endif
			i += 1
		endwhile
		return false
	endif
	
	return false
EndFunction

; sometimes math needs to be done with angles explicitly within the proper range
float Function NormalizeAngle(float angle) Global
	float d = angle - angle as int
	angle = (angle as int % 360) as float
	if (angle < 0.0)
		angle += 360.0
	endif
	return angle + d
EndFunction

; +x = e, +y = n, +z = up
float Function GetObjectDistance(float x1, float y1, float z1, float x2, float y2, float z2) Global
	float x = x1-x2
	float y = y1-y2
	float z = z1-z2
	if (x > -0.01 && x < 0.01 && y > -0.01 && y < 0.01 && z > -0.01 && z < 0.01)
		; Papyrus is dumb and throws div by zero errors on Math.sqrt() sometimes, which is stupid.
		; This can even happen when the number passed into it is not zero; there must be some weird optimization in the native code somewhere.
		return 0.0
	endif
	return Math.sqrt(x*x + y*y + z*z)
EndFunction

; cylindrical instead of spherical radius because I can't be bothered calculating a sphere
float[] Function GetClosestPointAtRadius(float startX, float startY, float startZ, float targetX, float targetY, float targetZ, float radius, float distance = -1.0) Global
	if (distance < 0.0)
		distance = IH_Util.GetObjectDistance(startX, startY, startZ, targetX, targetY, targetZ)
	endif
	if (distance <= 0.0)
		distance = 1.0 ; failsafe
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
		atan2 = Math.atan(atan2) * 2.0
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

Function QuarantineObject(ObjectReference thing) Global
	thing.MoveTo(Game.GetForm(0x1037F2) as ObjectReference) ; a marker in WIDeadBodyCleanupCell
	IH_Util.Trace("Moved deleted object " + thing + " into quarantine cell")
EndFunction

Function Trace(string str, int severity = 0) Global
{ 0 = Info, 1 = Warning, 2 = Error }
	DEBUG.TraceUser("IHarvest", str, severity)
EndFunction

int Function MaxI(int i, int j) Global
	if (i > j)
		return i
	else
		return j
	endif
EndFunction

int Function MinI(int i, int j) Global
	if (i < j)
		return i
	else
		return j
	endif
EndFunction

Function AddFormsToFormList(Form[] forms, FormList list) Global
	int i = forms.Length - 1
	while (i >= 0)
		list.AddForm(forms[i])
		i -= 1
	endwhile
EndFunction

; forgot how crap Papyrus arrays are in Skyrim, so this doesn't work without hardcoded array sizes
;ObjectReference[] Function CopyRefArray(ObjectReference[] refs) Global
;	ObjectReference[] refsNew = new ObjectReference[1]
;	refsNew[1] = refs[1]
;	int len = refs.Length
;	int i = 1
;	while (i < len)
;		refsNew.Add(refs[i])
;		i += 1
;	endwhile
;	return refsNew
;EndFunction

bool Function IsRefArrayFilled(ObjectReference[] refs, ObjectReference dummy) Global
	int i = refs.Length - 1
	while (i >= 0)
		ObjectReference ref = refs[i]
		if (ref == None || ref == dummy)
			return false
		endif
		i -= 1
	endwhile
	return true
EndFunction

bool Function AreAllIntsAtOrAboveThreshold(int[] ints, int threshold) Global
	int i = ints.Length - 1
	while (i >= 0)
		if (ints[i] < threshold)
			return false
		endif
		i -= 1
	endwhile
	return true
EndFunction

; useful for clearing an array without changing its size
Function SetRefArray(ObjectReference[] refs, ObjectReference value) Global
	int i = refs.Length - 1
	while (i >= 0)
		refs[i] = value
		i -= 1
	endwhile
EndFunction

Function SetIntArray(int[] ints, int value) Global
	int i = ints.Length - 1
	while (i >= 0)
		ints[i] = value
		i -= 1
	endwhile
EndFunction

ObjectReference[] Function DowncastCritterArr(IH_GetterCritterScript[] g) Global
	ObjectReference[] r = new ObjectReference[128]
	int i = 0
	while (i < 128)
		r[i] = g[i]
		i += 1
	endwhile
	return r
EndFunction

Function DumpFormList(FormList f) Global
	int size = f.GetSize()
	IH_Util.Trace("Dumping FormList " + f + " of size " + size)
	int i = 0
	while (i < size)
		IH_Util.Trace("\t" + i + ": " + f.GetAt(i))
		i += 1
	endwhile
	IH_Util.Trace("Finished dumping " + f)
EndFunction

Function DumpObjectArray(ObjectReference[] refs) Global
	int len = refs.length
	IH_Util.Trace("Dumping an array of size " + len)
	int i = 0
	while (i < len)
		IH_Util.Trace("\t" + i + ": " + refs[i])
		i += 1
	endwhile
	IH_Util.Trace("Finished dumping array")
EndFunction

bool Function AllowedToTake(ObjectReference object, Actor taker, ActorBase base) Global
	; annoyingly simplified, and doesn't take all cases into account because the ownership
	; system is extremely convoluted and only some parts are exposed to Papyrus
	
	ActorBase owner = object.GetActorOwner()
	if (owner != None)
		; IH_Util.Trace("\t\t\tOwnership check of " + object + " for " + taker + "/" + base + " for direct owner " + owner == base)
		return owner == base
	endif
	
	Faction factionOwner = object.GetFactionOwner()
	if (factionOwner != None)
		; IH_Util.Trace("\t\t\tOwnership check of " + object + " for " + taker + "/" + base + " for object faction " + taker.IsInFaction(factionOwner) + " owner=" + owner + ", faction=" + factionOwner + " value=" + object.GetBaseObject().GetGoldValue())
		return taker.IsInFaction(factionOwner)
	endif
	
	Cell thisCell = object.GetParentCell()
	owner = thisCell.GetActorOwner()
	if (owner != None)
		; IH_Util.Trace("\t\t\tOwnership check of " + object + " for " + taker + "/" + base + " for cell owner " + owner == base)
		return owner == base
	endif
	
	factionOwner = thisCell.GetFactionOwner()
	if (factionOwner != None)
		; IH_Util.Trace("\t\t\tOwnership check of " + object + " for " + taker + "/" + base + " for cell faction " + taker.IsInFaction(factionOwner))
		return taker.IsInFaction(factionOwner)
	endif
	
	return true
EndFunction
