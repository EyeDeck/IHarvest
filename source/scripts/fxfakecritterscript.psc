Scriptname FXfakeCritterScript extends ObjectReference  
{Make fake critters shootable}

container Property myContainer Auto
Flora Property myFlora Auto
ingredient Property myIngredient Auto
potion Property myFood Auto
string Property myLocationOffset Auto
string Property myFakeForceExplosionOffset Auto
Explosion Property myExplosion Auto
Explosion Property myFakeForceExplosion Auto
objectReference myContainerRef
objectReference myIngredientRef
objectReference myExplosionRef
objectReference myFakeForceExplosionRef
objectReference myFloraRef
int Property numberOfIngredientsOnCatch Auto
int doOnce
import utility
int property hoursBeforeReset = 72 auto

bool readyToReset


Event OnActivate(ObjectReference akActionRef)
	self.disable()
	if myFood 
		akActionRef.additem(myFood, numberOfIngredientsOnCatch)
	endif
	if  myIngredient
		akActionRef.additem(myIngredient, numberOfIngredientsOnCatch)
	endif
	RegisterForSingleUpdateGameTime(hoursBeforeReset)
;!	utility.waitGameTime(hoursBeforeReset)
;!	readyToReset = TRUE
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked)
;~ 		debug.trace(self + " hit!!!!!!1")
		if akAggressor == game.getplayer()
			if doOnce == 0
				doOnce = 1
				if myContainer 
					if myContainerRef
						; [USKP 2.0.1] fix persistent reference to previous object
						myContainerRef.delete()
					endif
					myContainerRef = self.placeAtMe(myContainer, 1, false, true)
					utility.wait(0.01)
					myContainerRef.enable(false)
					myContainerRef.MoveToNode(self, myLocationOffset)	
				endIf
				if myFlora 
					if myFloraRef
						; [USKP 2.0.1] fix persistent reference to previous object
						myFloraRef.delete()
					endif
					myFloraRef = self.placeAtMe(myFlora, 1, false, true)
					utility.wait(0.01)
					myFloraRef.enable(false)
					myFloraRef.MoveToNode(self, myLocationOffset)	
				endIf
				;if myIngredient 
				;	myIngredientRef = self.placeAtMe(myIngredient)
				;	myIngredientRef.MoveToNode(self, myLocationOffset)	
				;endIf
				; If myExplosion 
					; myExplosionRef = self.placeAtMe(myExplosion)
					; myExplosionRef.MoveToNode(self, myLocationOffset)	
				; endIf
				; If myFakeForceExplosion 
					; myFakeForceExplosionRef = self.placeAtMe(myFakeForceExplosion)
					; myFakeForceExplosionRef.MoveToNode(self, myFakeForceExplosionOffset)	
				; endIf
				utility.wait(0.1)
				self.disable()
				RegisterForSingleUpdateGameTime(hoursBeforeReset)
			;!	utility.waitGameTime(hoursBeforeReset)
			;!	readyToReset = TRUE
			endIf
		endIf
ENDEVENT

EVENT onCellAttach()
	if readyToReset == TRUE
;~ 		debug.trace(self + "onCellAttach() readyToReset")
		UnregisterForUpdateGameTime(); 
		doOnce = 0 ; [USKP 1.2.7] new instance not empty
		enable()
		if myContainerRef
			myContainerRef.disable()
			myContainerRef.delete() ; [USKP 1.3.0] This was a PlaceAtMe object.
			myContainerRef = None; [USKP 2.0.1] fix persistent reference to deleted object
		endif
		if myFloraRef
			myFloraRef.disable()
			myFloraRef.delete() ; [USKP 1.3.0] This was a PlaceAtMe object.
			myFloraRef = None; [USKP 2.0.1] fix persistent reference to deleted object
		endif
		if myIngredientRef
			myIngredientRef.disable()
			myIngredientRef.delete() ; [USKP 1.3.0] This was a PlaceAtMe object.
			myIngredientRef = None; [USKP 2.0.1] fix persistent reference to deleted object
		endif
		readyToReset = FALSE
	elseif !isDisabled()
		if myContainerRef && myContainerRef.isDisabled()
			; [USKP 2.0.1] fix persistent reference to deleted/disabled object
			myContainerRef.delete()
			myContainerRef = None
		endif
		if myFloraRef && myFloraRef.isDisabled()
			; [USKP 2.0.1] fix persistent reference to deleted/disabled object
			myFloraRef.delete()
			myFloraRef = None
		endif
		if myIngredientRef && myIngredientRef.isDisabled()
			; [USKP 2.0.1] fix persistent reference to deleted/disabled object
			myIngredientRef.delete()
			myIngredientRef = None
		endif
	endif
ENDEVENT

;/*** [USKP 2.0.1]
;*	reduce save bloat
;*	onCellAttach pending readyToReset on old saves
;*	onCellAttach may not occur, as player may never re-visit
;*	credit BlueDanieru
/;
EVENT OnUpdateGameTime()
;~ 	debug.trace(self + "OnUpdateGameTime()")
	readyToReset = TRUE
	onCellAttach()
endEVENT
