#===============================================================================
# Tribes Switch - settings
#
# Turns Chasm's tribe system on or off for the whole game, without editing any
# Chasm file. The tribe data in the PBS files is kept, so switching back to true
# brings everything back.
#
# With ENABLED = false:
#   Gameplay: no tribal bonuses of any kind
#   Screens: tribes are removed from
#     - the pause menu (Info list, and Chasm's original menu if it's used)
#     - the in-battle Documents menu
#     - the Summary (page 3) and the MasterDex info page (text and icon)
#     - the storage "Search how?" list and the MasterDex search screen
#     - the party showcase bottom bar and the battle info panel
#     - the Battle Guide topic list
#     - PokEstate awards and the Collection Rewards "Tribe" page
#===============================================================================
module TribesSwitch
    ENABLED = false
end
