#===============================================================================
# Pause Menu - settings
#
# The pause menu from the design lead's video: a blue banner with the player's
# name and money, the player's art on the left, and five buttons on the right
# (Party, Bag, Options, Info, Save). Info opens a list with everything else
# (trainer card, level cap, What Next?, quest log, MasterDex, MoveDex,
# Battle Guide, Tribes, DexNav and, in debug mode, Debug).
#
# All positions are in game pixels (the screen is 512 x 384).
#
# Using your own art instead of the drawn shapes:
#   Put any of these files in Graphics/Pictures/PauseMenu/ and they're used
#   automatically instead of the shapes drawn in code:
#     banner.png            The whole top banner, drawn at 0,0
#     button.png            One button (any size; text is drawn on top)
#     button_selected.png   The selected button
#     button_disabled.png   A button that can't be used right now
#===============================================================================
module PauseMenu
    # Set to false to use Chasm's original tile menu again.
    ENABLED = true

    #---------------------------------------------------------------------------
    # Player art
    #---------------------------------------------------------------------------
    # Which picture each player trainer type shows, from Graphics/Pictures/PauseMenu/,
    # and where its top-left corner goes.
    ART = {
        :POKEMONTRAINER_Masculine   => ["Player_Masculine", 20, 63],
        :POKEMONTRAINER_Feminine    => ["Player_Feminine",  20, 79],
        :POKEMONTRAINER_Androgynous => ["Player_Feminine",  20, 79],
    }

    #---------------------------------------------------------------------------
    # Colours
    #---------------------------------------------------------------------------
    BLUE            = Color.new(0, 159, 253)    # Banner
    BUTTON_BLUE     = Color.new(7, 162, 255)    # Buttons
    SELECTED_YELLOW = Color.new(255, 214, 40)   # Selected button
    DISABLED_GREY   = Color.new(130, 150, 170)  # Button that can't be used right now
    OUTLINE         = Color.new(0, 0, 0)
    TEXT            = Color.new(16, 16, 16)
    DISABLED_TEXT   = Color.new(70, 80, 90)

    #---------------------------------------------------------------------------
    # Banner
    #---------------------------------------------------------------------------
    # The blue area's bottom edge: from the left edge, along a slight slope to
    # the start of the diagonal, up the diagonal, then flat to the right edge.
    BANNER_LEFT_BOTTOM      = 64    # Bottom of the blue at x = 0
    BANNER_STEP_TOP         = [134, 59]  # Where the diagonal starts (x, y)
    BANNER_STEP_BOTTOM      = [171, 25]  # Where the diagonal ends (x, y)
    BANNER_RIGHT_BOTTOM     = 25    # Bottom of the blue on the right side
    BANNER_OUTLINE          = 9     # Black outline thickness under the blue

    NAME_POSITION    = [18, 2, 200, 44]     # Player name box: x, y, width, height
    NAME_FONT_SIZE   = 58
    MONEY_POSITION   = [266, -3, 200, 30]   # Money box (text is right-aligned)
    MONEY_FONT_SIZE  = 34

    #---------------------------------------------------------------------------
    # Buttons
    #---------------------------------------------------------------------------
    BUTTON_X         = 345
    BUTTON_WIDTH     = 143
    BUTTON_HEIGHT    = 50
    BUTTON_TOPS      = [46, 107, 167, 237, 313]   # Party, Bag, Options, Info, Save
    BUTTON_BORDER    = 7
    BUTTON_TEXT_X    = 14                       # Text indent inside a button
    BUTTON_TEXT_Y    = 8                        # Moves button text down (the game draws this font high in its box)
    BUTTON_FONT_SIZE = 34

    #---------------------------------------------------------------------------
    # Background
    #---------------------------------------------------------------------------
    BLUR_BACKGROUND = true
    BLUR_STRENGTH   = 2     # How many blur passes (more is blurrier)

    #---------------------------------------------------------------------------
    # Animation, in seconds (timed from the video)
    #---------------------------------------------------------------------------
    SLIDE_TIME  = 0.10   # How long each piece takes to slide in or out
    STAGGER     = 0.033  # Delay between the banner, the buttons and the art

    #---------------------------------------------------------------------------
    # Font. nil uses the game's normal font (MessageConfig).
    #---------------------------------------------------------------------------
    FONT_NAME = nil
end
