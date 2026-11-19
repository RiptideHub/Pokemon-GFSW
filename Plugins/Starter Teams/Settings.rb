#===============================================================================
# Starter Teams - settings
#
# Lets any trainer use a different team depending
# on which starter the player chose.
#
# 1. In trainers.txt, give the trainer one team per starter. The version number
#    is the fight number times 10, plus the starter's position in STARTERS:
#
#      ["TRAINERCLASS","name",10]   <- fight 1, shared team used for every starter
#      ["TRAINERCLASS","name",11]   <- fight 1, player chose the 1st starter 
#      ["TRAINERCLASS","name",12]   <- fight 1, player chose the 2nd starter
#      ["TRAINERCLASS","name",13]   <- fight 1, player chose the 3rd starter 
#      ["TRAINERCLASS","name",20]   <- fight 2, shared team used for every starter
#      ["TRAINERCLASS","name",21]   <- fight 2, player chose the 1st starter 
#      ["TRAINERCLASS","name",22]   <- fight 2, player chose the 2nd starter
#      ["TRAINERCLASS","name",23]   <- fight 2, player chose the 3rd starter 
#
#    A version ending in 0 (10, 20, 30...) is the fight's shared team. It's used
#    when there's no team for the player's starter, so a fight where the team
#    doesn't change only needs that one entry.
#
# 2. In the event, start the battle with a Script command:
#
#      starterBattle(:"TRAINERCLASS", "name", 1)
#
#    Optional settings.
#      starterBattle(:"TRAINERCLASS", "name", 2) canLose: true, outcomeVar: 1,
#                    endSpeech: "...", doubleBattle: false)
#
#    It returns true if the player won, so it also works as the condition of a
#    Conditional Branch (Script).
#
# Other script commands:
#   setStarter(:TOTODILE)      Record the starter by hand (or setStarter(1) by position)
#   starterIs?(:TOTODILE)      true/false, for Conditional Branches and dialogue
#   starterSpecies           The chosen starter's species, or nil if none yet
#   starterSlot              Its position in STARTERS (1, 2, 3...), or 0 if none yet
#   starterTeamVersion(2)    The version starterBattle would use for fight 2
#                            (for other battle commands, like pbDoubleTrainerBattle)
#===============================================================================
module StarterTeams
    # Game variable that stores the chosen starter: 1 = first in STARTERS,
    # 2 = second, and so on. 0 means no starter has been chosen yet.
    # Variable 7 is the one named "Starter choice".
    VARIABLE = 7

    # The starters, in order. A starter's position decides its team version.
    # If you change the starters, keep the order matching your trainers.txt teams.
    STARTERS = [:CHIKORITA, :CYNDAQUIL, :TOTODILE]

    # Record the starter automatically the first time the player receives one of
    # the STARTERS (through pbAddPokemon or pbAddPokemonSilent), so the starter
    # event needs no extra command.
    AUTO_RECORD = true
end
