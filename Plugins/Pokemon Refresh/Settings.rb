#===============================================================================
# Pokémon Refresh - settings
#
# Like Pokémon Refresh in Sun & Moon: feed, pet and clean a Gijinka character.
#
# HOW TO USE IT
#   In the character's event (for example after "Show Choices: Talk / Refresh"),
#   add a Script command:
#       pokemonRefresh(:AMA)
#   Their friendship is in a game variable (see :friendship_variable below), so
#   pages and Conditional Branches can check it. From a script:
#       refreshFriendship(:AMA)          -> the number (0 to MAX_FRIENDSHIP)
#
# CONTROLS
#   Mouse: click the buttons, drag a berry to the mouth, click-hold and rub
#   side to side to pet, rub dirt with the cloth.
#   Keyboard/controller: arrows move the hand, hold Enter to "click and hold",
#   Esc closes a panel / puts the cloth away / leaves.
#
# ART (Graphics/Pictures/Refresh/)
#   RefreshBG.png                       Background (512 x 384)
#   Refresh<graphic>N/A/B/C.png         The character, 512 x 384 each:
#                                       N = normal, A/B/C = the faces below
#   RefreshDirt.png, RefreshHeart.png   A dirt splotch and a heart
#   RefreshCursor.png, RefreshCloth.png The hand and the cleaning cloth
#                                       (placeholders: swap in your own art)
#
# All positions are in screen pixels (the screen is 512 x 384), with 0,0 at the
# top-left. Rectangles are [x, y, width, height]. In debug mode press F7 on the
# Refresh screen to see every spot drawn over the character.
#===============================================================================
module PokemonRefresh
    FOLDER     = "Graphics/Pictures/Refresh/"
    BACKGROUND = "RefreshBG"

    #---------------------------------------------------------------------------
    # Characters
    #---------------------------------------------------------------------------
    CHARACTERS = {
        :AMA => {
            :name                => "Ama",
            :graphic             => "Ama",
            :friendship_variable => 95,
            :can_get_dirty       => false,
            :mouth               => [237, 138, 40, 26],
            :spots => [
                [:soft,  [205, 0, 120, 95]],
                [:hated, [200, 262, 110, 56]],
            ],
            :elsewhere => :neutral
        },
        :GIRRA => {
            :name                => "Girra",
            :graphic             => "Girra",
            :friendship_variable => 96,
            :can_get_dirty       => true,
            :mouth               => [236, 132, 40, 24],
            :spots => [
                [:soft,    [196, 300, 110, 70]],
                [:neutral, [214, 120, 30, 32]],
                [:neutral, [270, 120, 30, 32]],
            ],
            :elsewhere => :hated
        },
    }

    FACES = {
        :soft    => "B",
        :neutral => "C",
        :hated   => "A",
        :eat     => "Eat",
        :after_eat => "B",
        :clean   => "B",
        :full    => "C",
    }

    #---------------------------------------------------------------------------
    # Friendship
    #---------------------------------------------------------------------------
    MAX_FRIENDSHIP      = 255
    FEED_FRIENDSHIP     = 3
    PET_FRIENDSHIP      = 2
    CLEAN_FRIENDSHIP    = 3
    HATED_FRIENDSHIP    = -1
    PET_LIMIT_PER_VISIT = 10

    #---------------------------------------------------------------------------
    # Feeding
    #---------------------------------------------------------------------------
    BERRIES_UNTIL_FULL = 3
    STEPS_PER_BERRY    = 128
    BERRIES_USED_UP    = true

    #---------------------------------------------------------------------------
    # Dirt
    #---------------------------------------------------------------------------
    DIRT_CHANCE = 30
    DIRT_MIN    = 1
    DIRT_MAX    = 3
    DIRT_LOWEST_Y = 330
    CLEAN_SPEED = 5

    #---------------------------------------------------------------------------
    # Petting
    #---------------------------------------------------------------------------
    RUB_DISTANCE    = 6
    RUBS_FOR_HEARTS = 6
    RUBS_FOR_HATED  = 4
    FACE_HOLD_FRAMES = 40
    EAT_FRAMES       = 40

    #---------------------------------------------------------------------------
    # Controls and look
    #---------------------------------------------------------------------------
    KEYBOARD_CURSOR = true
    CURSOR_SPEED    = 6
    DEBUG_KEY       = :F7

    BUTTONS = {
        :berries => [6, 6, 84, 28],
        :clean   => [6, 40, 84, 28],
        :exit    => [6, 74, 84, 28],
    }
    BUTTON_COLOR      = Color.new(40, 52, 58, 220)
    BUTTON_HOVER      = Color.new(255, 214, 40, 235)
    BUTTON_TEXT       = Color.new(248, 248, 248)
    BUTTON_TEXT_HOVER = Color.new(40, 40, 40)
    BERRY_PANEL       = [6, 108, 84, 240]
end
