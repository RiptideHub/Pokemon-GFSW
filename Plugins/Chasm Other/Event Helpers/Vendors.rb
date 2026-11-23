def payMoney(cost, showMessage = true)
	raise _INTL("A money cost can't be negative!") if cost < 0
	if $Trainer.money >= cost
		$Trainer.money = $Trainer.money - cost
		pbMessage(_INTL("You hand over ${1}.",cost)) if showMessage
		return true
	else
		return false
	end
end

def payEvolutionStone(showMessage = true)
	pbChooseEvolutionStone(1)
	itemID = pbGet(1)
	if itemID != :NONE
		$PokemonBag.pbDeleteItem(itemID)
		pbMessage(_INTL("You hand over the {1}.",getItemName(itemID))) if showMessage
		return true
	else
		return false
	end
end

######################################################
# Mart vendors
######################################################
BASIC_MART_STOCK = %i[POKEBALL ABILITYCAPSULE REPEL EXPCANDYXS]

THREE_GYM_BADGES = %i[SLICEBALL POTIONBALL DISABLEBALL LEECHBALL EXPCANDYS]

FIVE_GYM_BADGES = %i[GREATBALL QUICKBALL REPEATBALL TIMERBALL FRIENDBALL EXPCANDYM]

SEVEN_GYM_BADGES = %i[ULTRABALL DREAMBALL EXPCANDYL]

EIGHT_GYM_BADGES = %i[EXPCANDYXL]

def martStock
    stock = BASIC_MART_STOCK.clone
    stock += THREE_GYM_BADGES.clone if getBadgeCount >= 3
    stock += FIVE_GYM_BADGES.clone  if getBadgeCount >= 5
    stock += SEVEN_GYM_BADGES.clone if getBadgeCount >= 7
    stock += EIGHT_GYM_BADGES.clone if getBadgeCount >= 8
    return stock
end

def basicPokeMart
    pbPokemonMart(martStock)
end