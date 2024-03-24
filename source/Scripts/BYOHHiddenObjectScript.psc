Scriptname BYOHHiddenObjectScript extends ObjectReference  
{scripted object that adds specified item to player's inventory when added to player}

Potion Property itemToAddPotion  Auto  
{item to add to player - potion}

Ingredient Property itemToAddIngredient  Auto  
{item to add to player - ingredient}

Int Property ItemCount = 1 Auto  
{how many to add?}

MiscObject Property myBase Auto
{ my base object - can't access this from inventory scripts }

Event OnContainerChanged(ObjectReference akNewContainer, ObjectReference akOldContainer)
	if akNewContainer != None
		; if 2 or more of these are added to an inventory at the same time, the
		; OnContainerChanged event will only fire on one of them, so we need to
		; handle each individual item in the one script instance that does fire
		int myCount = akNewContainer.GetItemCount(myBase)
		akNewContainer.RemoveItem(myBase, myCount, true)
		if itemToAddPotion
			akNewContainer.AddItem(itemToAddPotion, itemCount * myCount, true)
		endif
		if itemToAddIngredient
			akNewContainer.AddItem(itemToAddIngredient, itemCount * myCount, true)
		endif
	endif
EndEvent
