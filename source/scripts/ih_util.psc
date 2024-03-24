ScriptName IH_Util

;/ Recursive function that takes a form (Ingredient, FormList or LeveledItem),
; and determines whether that form can produce alchemy ingredients /;
bool Function ProducesIngredient(Form f, bool food) Global
	Form[] seen = new Form[128]
	return ProducesIngredientInternal(f, food, seen, 0)
EndFunction

;/ Realized I had to add an infinite recursion check, otherwise Bad Things could happen;
; best way to do that was to make the original function into a proxy /;
bool Function ProducesIngredientInternal(Form f, bool food, Form[] seen, int seenEnd) Global
	IH_Util.Trace("Examining Form " + f)
	if (seen.RFind(f, seenEnd) >= 0)
		DEBUG.Trace("IHarvest: Skipped a circular FormList/LeveledItem " + f + " in ProducesIngredient() - you may want to investigate this as this may cause crashes elsewhere!", 1)
		return false
	endif
	
	if (f as Ingredient)
		return true
	endif
	
	if (food)
		Potion fP = f as Potion
		if (fP && fP.IsFood())
			return true
		endif
	endif
	
	LeveledItem fLI = f as LeveledItem
	if (fLI != None)
		seen[seenEnd] = f
		seenEnd += 1
		
		if (fLI.GetChanceNone() >= 100)
			; This probably never actually comes up, but might as well check for it anyway
			return false
		endif
		int ct = fLI.GetNumForms()
		int i = 0
		while (i < ct)
			if (fLI.GetNthCount(i) > 0 && ProducesIngredientInternal(fLI.GetNthForm(i), food, seen, seenEnd))
				return true
			endif
			i += 1
		endwhile
		return false
	endif
	FormList fFL = f as FormList
	if (fFL != None)
		seen[seenEnd] = f
		seenEnd += 1
		
		int ct = fFL.GetSize()
		int i = 0
		while (i < ct)
			if (ProducesIngredientInternal(fFL.GetAt(i), food, seen, seenEnd))
				return true
			endif
			i += 1
		endwhile
		return false
	endif
	;/ https://afktrack.afkmods.com/index.php?a=issues&i=27196
	; I almost included handling for BYOHHiddenObjectScript, but after looking more closely at the implementation,
	; I decided that it was such a trainwreck that I would rather fix the implementation than add a nasty workaround
	; in my script. Whether or not USSEP merges my changes, I will include an optional "vanilla fixes" file along
	; with the mod, which will be required for full Hearthfire support.
;	BYOHHiddenObjectScript = f as BYOHHiddenObjectScript
	/;
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

Function Trace(string str) Global
	DEBUG.TraceUser("IHarvest", str)
EndFunction
