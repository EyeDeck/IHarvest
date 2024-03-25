Scriptname FCaddIngrediantAndDeleteSCRIPT extends ObjectReference  
{For the fake critters you add the given ingrdient and delet the object.}

ingredient Property myIngredient Auto
potion Property myFood Auto
int Property numberOfIngredients = 1 Auto
int Property numberOfFood= 1 Auto
;/ objectReference myPlayer

Event OnActivate(ObjectReference akActionRef)
	myPlayer = game.getPlayer()
	if akActionRef == myPlayer
		if myIngredient
			myPlayer.addItem(myIngredient, numberOfIngredients)
		endIf
		if myFood
			myPlayer.addItem(myFood, numberOfFood)
		endIf
		self.disable()
		utility.wait(0.1)
		self.delete()		
	endif
EndEvent
/;

; IHarvest: removed player check, and tweaked order of operations to feel more responsive
Event OnActivate(ObjectReference akActionRef)
	self.Disable()
	if myIngredient
		akActionRef.AddItem(myIngredient, numberOfIngredients)
	endif
	if myFood
		akActionRef.AddItem(myFood, numberOfFood)
	endif
	Utility.Wait(0.1)
	self.Delete()
EndEvent
