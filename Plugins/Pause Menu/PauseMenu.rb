#===============================================================================
# Pause Menu - logic. Settings and usage are in Settings.rb.
#
# The scene inherits from Chasm's TilingCardsPauseMenu_Scene so every button
# reuses Chasm's own actions (party, bag, options, save/quit, DexNav, debug,
# tribes). Only the look, the animation and the input loop are new.
#===============================================================================
module PauseMenu
    FOLDER = "Graphics/Pictures/PauseMenu/"

    module_function

    def path(name)
        return FOLDER + name
    end

    def custom_image(name)
        return pbResolveBitmap(path(name))
    end

    def frames(seconds)
        return [(seconds * Graphics.frame_rate).round, 1].max
    end

    def ease_out(t)
        t = t.clamp(0.0, 1.0)
        return 1 - (1 - t)**3
    end

    def font_name
        return FONT_NAME || MessageConfig.pbGetSystemFontName
    end

    def tribes_enabled?
        return true unless defined?(TribesSwitch)
        return TribesSwitch.enabled?
    end

    def banner_bottom(x)
        sx0, sy0 = BANNER_STEP_TOP
        sx1, sy1 = BANNER_STEP_BOTTOM
        if x <= sx0
            return BANNER_LEFT_BOTTOM + (sy0 - BANNER_LEFT_BOTTOM) * x.to_f / sx0
        elsif x <= sx1
            return sy0 + (sy1 - sy0) * (x - sx0).to_f / (sx1 - sx0)
        end
        return BANNER_RIGHT_BOTTOM.to_f
    end

    def outline_bottom(x)
        r = BANNER_OUTLINE
        best = 0.0
        (-r..r).each do |d|
            reach = banner_bottom((x + d).clamp(0, Graphics.width - 1)) + Math.sqrt(r * r - d * d)
            best = reach if reach > best
        end
        return best
    end

    def banner_height
        return BANNER_LEFT_BOTTOM + BANNER_OUTLINE + 4
    end
end

#===============================================================================
# The menu
#===============================================================================
class PauseMenu_Scene < TilingCardsPauseMenu_Scene
    BUTTON_IDS = [:POKEMON, :BAG, :DOCUMENTS, :INFO, :OPTIONS, :SAVE]

    def initializeMenuButtons
        super
        @chasmButtons = @cardButtons
        labels = {
            :POKEMON => _INTL("Party"),
            :BAG     => _INTL("Bag"),
            :DOCUMENTS => _INTL("Documents"),
            :INFO    => _INTL("Info"),
            :OPTIONS => _INTL("Options"),
            :SAVE    => _INTL("Save"),
        }
        @cardButtons = {}
        BUTTON_IDS.each do |id|
            if id == :DOCUMENTS
                @cardButtons[id] = { :press_proc => proc { |scene| scene.pbDocuments } }
            elsif id == :INFO
                @cardButtons[id] = { :press_proc => proc { |scene| scene.pbInfoMenu } }
            else
                @cardButtons[id] = @chasmButtons[id].dup
            end
            @cardButtons[id][:label] = labels[id]
        end
    end

    #---------------------------------------------------------------------------
    # Setting up and closing
    #---------------------------------------------------------------------------
    def pbStartScene
        initializeMenuButtons
        @ended = false
        @closeAnimated = false
        @bitmaps = []
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_999
        $viewport4 = @viewport
        @sprites = {}
        createBlur
        createArt
        @sprites["buttons"] = Sprite.new(@viewport)
        @sprites["buttons"].bitmap = keep(Bitmap.new(Graphics.width, Graphics.height))
        @sprites["buttons"].z = 2
        @sprites["banner"] = Sprite.new(@viewport)
        @sprites["banner"].z = 3
        loadButtonImages
        @buttonSelectionIndex = defaultCursorPosition.to_i.clamp(0, BUTTON_IDS.length - 1)
        drawButtons
        pbSEPlay("GUI menu open")
        animate(true)
    end

    def pbEndScene
        return if @ended
        animate(false) if @closeAnimated
        @ended = true
        pbDisposeSpriteHash(@sprites)
        @bitmaps.each { |b| b.dispose unless b.disposed? }
        @viewport.dispose
    end

    def ended?
        return @ended
    end

    def keep(bitmap)
        @bitmaps.push(bitmap)
        return bitmap
    end

    def createBlur
        return unless PauseMenu::BLUR_BACKGROUND
        snapshot = Graphics.snap_to_bitmap
        if snapshot.respond_to?(:blur)
            PauseMenu::BLUR_STRENGTH.times { snapshot.blur }
        end
        @sprites["blur"] = Sprite.new(@viewport)
        @sprites["blur"].bitmap = keep(snapshot)
        @sprites["blur"].z = 0
    rescue StandardError => e
        echoln("Pause Menu: couldn't blur the background (#{e.message})")
    end

    def createArt
        info = PauseMenu::ART[$Trainer.trainer_type]
        return unless info
        file = PauseMenu.custom_image(info[0])
        return unless file
        @artX = info[1]
        @sprites["art"] = Sprite.new(@viewport)
        @sprites["art"].bitmap = keep(Bitmap.new(file))
        @sprites["art"].x = info[1]
        @sprites["art"].y = info[2]
        @sprites["art"].z = 1
    end

    def loadButtonImages
        @buttonImages = {}
        ["button", "button_selected", "button_disabled"].each do |name|
            file = PauseMenu.custom_image(name)
            @buttonImages[name] = keep(Bitmap.new(file)) if file
        end
    end

    #---------------------------------------------------------------------------
    # Drawing
    #---------------------------------------------------------------------------
    def drawButtons
        return if @ended
        drawBanner
        bitmap = @sprites["buttons"].bitmap
        bitmap.clear
        bitmap.font.name = PauseMenu.font_name
        bitmap.font.size = PauseMenu::BUTTON_FONT_SIZE
        BUTTON_IDS.each_with_index do |id, index|
            x = PauseMenu::BUTTON_X
            y = PauseMenu::BUTTON_TOPS[index]
            w = PauseMenu::BUTTON_WIDTH
            h = PauseMenu::BUTTON_HEIGHT
            active = buttonActive?(id)
            state = !active ? "button_disabled" : (index == @buttonSelectionIndex ? "button_selected" : "button")
            image = @buttonImages[state]
            if image
                bitmap.blt(x, y, image, image.rect)
            else
                fill = { "button" => PauseMenu::BUTTON_BLUE, "button_selected" => PauseMenu::SELECTED_YELLOW,
                         "button_disabled" => PauseMenu::DISABLED_GREY }[state]
                border = PauseMenu::BUTTON_BORDER
                bitmap.fill_rect(x, y, w, h, PauseMenu::OUTLINE)
                bitmap.fill_rect(x + border, y + border, w - border * 2, h - border * 2, fill)
            end
            bitmap.font.color = active ? PauseMenu::TEXT : PauseMenu::DISABLED_TEXT
            textX = PauseMenu::BUTTON_TEXT_X
            bitmap.draw_text(x + textX, y + PauseMenu::BUTTON_TEXT_Y, w - textX * 2, h, @cardButtons[id][:label], 0)
        end
    end

    def drawBanner
        sprite = @sprites["banner"]
        sprite.bitmap.dispose if sprite.bitmap && !sprite.bitmap.disposed?
        custom = PauseMenu.custom_image("banner")
        if custom
            bitmap = Bitmap.new(custom)
        else
            bitmap = Bitmap.new(Graphics.width, PauseMenu.banner_height)
            Graphics.width.times do |x|
                blue = PauseMenu.banner_bottom(x).round
                black = PauseMenu.outline_bottom(x).round
                bitmap.fill_rect(x, 0, 1, black, PauseMenu::OUTLINE)
                bitmap.fill_rect(x, 0, 1, blue, PauseMenu::BLUE)
            end
        end
        bitmap.font.name = PauseMenu.font_name
        bitmap.font.color = PauseMenu::TEXT
        bitmap.font.size = PauseMenu::NAME_FONT_SIZE
        nx, ny, nw, nh = PauseMenu::NAME_POSITION
        bitmap.draw_text(nx, ny, nw, nh, $Trainer.name, 0)
        bitmap.font.size = PauseMenu::MONEY_FONT_SIZE
        mx, my, mw, mh = PauseMenu::MONEY_POSITION
        bitmap.draw_text(mx, my, mw, mh, _INTL("${1}", $Trainer.money.to_s_formatted), 2)
        sprite.bitmap = bitmap
    end

    #---------------------------------------------------------------------------
    # Opening and closing animation
    #---------------------------------------------------------------------------
    def animate(opening)
        slide = PauseMenu.frames(PauseMenu::SLIDE_TIME)
        stagger = PauseMenu.frames(PauseMenu::STAGGER)
        delays = opening ? { :banner => 0, :buttons => stagger, :art => stagger * 2 } :
                           { :art => 0, :buttons => stagger, :banner => stagger }
        total = delays.values.max + slide
        (0..total).each do |frame|
            progress = {}
            delays.each do |piece, delay|
                t = PauseMenu.ease_out((frame - delay).to_f / slide)
                progress[piece] = opening ? t : 1 - t
            end
            placePieces(progress)
            Graphics.update
        end
    end

    def placePieces(progress)
        out = 1 - progress[:banner]
        @sprites["banner"].y = (-PauseMenu.banner_height * out).round
        out = 1 - progress[:buttons]
        @sprites["buttons"].x = ((Graphics.width - PauseMenu::BUTTON_X) * out).round
        art = @sprites["art"]
        if art
            out = 1 - progress[:art]
            art.x = (@artX - (@artX + art.bitmap.width) * out).round
        end
    end

    #---------------------------------------------------------------------------
    # Input
    #---------------------------------------------------------------------------
    def promptButtons
        count = BUTTON_IDS.length
        loop do
            Graphics.update
            Input.update
            return if @ended
            previous = @buttonSelectionIndex
            if Input.trigger?(Input::BACK)
                onMenuClose
                pbPlayCloseMenuSE
                @closeAnimated = true
                return
            elsif Input.trigger?(Input::USE)
                unless buttonActive?(@buttonSelectionIndex)
                    pbPlayBuzzerSE
                    next
                end
                closeMenu = pressButton(@buttonSelectionIndex)
                if @ended || closeMenu
                    onMenuClose
                    return
                end
            elsif Input.repeat?(Input::UP)
                @buttonSelectionIndex = (@buttonSelectionIndex - 1) % count
            elsif Input.repeat?(Input::DOWN)
                @buttonSelectionIndex = (@buttonSelectionIndex + 1) % count
            end
            if @buttonSelectionIndex != previous
                pbPlayCursorSE
                drawButtons
            end
        end
    end

    def pbShowMenu
        @sprites.each_value { |s| s.visible = true unless s.disposed? }
    end

    def pbHideMenu
        @sprites.each_value { |s| s.visible = false unless s.disposed? }
    end

    def visible=(value)
        value ? pbShowMenu : pbHideMenu
    end

    def update
        @sprites.each_value { |s| s.update unless s.disposed? }
    end

    #---------------------------------------------------------------------------
    # Documents list
    #---------------------------------------------------------------------------
    def pbDocuments
        pbPlayDecisionSE
        entries = documentEntries
        window = Window_CommandPokemon.new(entries.map { |e| e[0] })
        window.viewport = @viewport
        window.z = 10
        window.index = (@infoIndex || 0).clamp(0, entries.length - 1)
        window.x = [PauseMenu::BUTTON_X - window.width - 4, 0].max
        window.y = PauseMenu::BUTTON_TOPS[0]
        closeMenu = false
        loop do
            window.update
            Graphics.update
            Input.update
            if Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                break
            elsif Input.trigger?(Input::USE)
                @infoIndex = window.index
                action = entries[window.index][1]
                if action.nil? # Cancel
                    pbPlayCloseMenuSE
                    break
                end
                window.visible = false
                result = action.call
                if @ended || result == true
                    closeMenu = true
                    break
                end
                entries = documentEntries
                window.commands = entries.map { |e| e[0] }
                window.index = window.index.clamp(0, entries.length - 1)
                window.visible = true
            end
        end
        window.dispose
        return closeMenu
    end

    def documentEntries
        list2 = []
        list2.push([_INTL("MasterDex"), proc {
            pbFadeOutIn {
                screen = PokemonPokedexScreen.new(PokemonPokedex_Scene.new)
                screen.pbStartScreen
                drawButtons
            }
        }])
        list2.push([_INTL("MoveDex"), proc { openMoveDex }])
        list2.push([_INTL("Battle Guide"), proc { showBattleGuide }])
        if PauseMenu.tribes_enabled? && @chasmButtons[:TRIBAL_BONUS]
            list2.push([_INTL("Tribes"), proc { @chasmButtons[:TRIBAL_BONUS][:press_proc].call(self) }])
        end
        if @chasmButtons[:DEXNAV] && dexNavActive?
            list2.push([_INTL("DexNav"), proc { @chasmButtons[:DEXNAV][:press_proc].call(self) }])
        end
        list2.push([_INTL("Cancel"), nil])
        return list2
    end

    #---------------------------------------------------------------------------
    # Info list
    #---------------------------------------------------------------------------
    def pbInfoMenu
        pbPlayDecisionSE
        entries = infoEntries
        window = Window_CommandPokemon.new(entries.map { |e| e[0] })
        window.viewport = @viewport
        window.z = 10
        window.index = (@infoIndex || 0).clamp(0, entries.length - 1)
        window.x = [PauseMenu::BUTTON_X - window.width - 4, 0].max
        window.y = PauseMenu::BUTTON_TOPS[0]
        closeMenu = false
        loop do
            window.update
            Graphics.update
            Input.update
            if Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                break
            elsif Input.trigger?(Input::USE)
                @infoIndex = window.index
                action = entries[window.index][1]
                if action.nil? # Cancel
                    pbPlayCloseMenuSE
                    break
                end
                window.visible = false
                result = action.call
                if @ended || result == true
                    closeMenu = true
                    break
                end
                entries = infoEntries
                window.commands = entries.map { |e| e[0] }
                window.index = window.index.clamp(0, entries.length - 1)
                window.visible = true
            end
        end
        window.dispose
        return closeMenu
    end

    def infoEntries
        list = []
        list.push([_INTL("{1}'s Card", $Trainer.name), proc {
            pbPlayDecisionSE
            pbFadeOutIn {
                screen = PokemonTrainerCardScreen.new(PokemonTrainerCard_Scene.new)
                screen.pbStartScreen
                drawButtons
            }
        }])
        if LEVEL_CAPS_USED && getLevelCap > 0 && $Trainer.party_count > 0
            list.push([_INTL("Level Cap"), proc { showLevelCapInfo }])
        end
        if defined?($main_quest_tracker) && $main_quest_tracker
            list.push([_INTL("What Next?"), proc {
                pbMessage("\\l[7]<b>" + $main_quest_tracker.getCurrentStageName() + "</b>\n" + $main_quest_tracker.getCurrentStageHelp())
            }])
        end
        list.push([_INTL("Quest Log"), proc {
            pbPlayDecisionSE
            pbFadeOutIn {
                screen = QuestList_Screen.new(QuestList_Scene.new)
                screen.pbStartScreen
                drawButtons
            }
        }])
        if $DEBUG && @chasmButtons[:DEBUG]
            list.push([_INTL("Debug"), proc { @chasmButtons[:DEBUG][:press_proc].call(self) }])
        end
        list.push([_INTL("Cancel"), nil])
        return list
    end
	
    def showLevelCapInfo
        cap = getLevelCap
        msgwindow = pbCreateMessageWindow
        pbMessageDisplay(msgwindow, _INTL("The current level cap is {1}.", cap))
        if cap == GameData::GrowthRate.max_level
            pbMessageDisplay(msgwindow, _INTL("This is the final level cap. It cannot be raised.", cap))
        else
            case RARE_CANDY_LEVEL_CAP_BEHAVIOUR
            when :SAME_CAP
                pbMessageDisplay(msgwindow, _INTL("Once at level {1}, your Pokémon cannot gain experience or have Candies used on them.", cap))
            when :SEPARATE_CAP
                pbMessageDisplay(msgwindow, _INTL("Once at level {1}, your Pokémon cannot gain experience or have EXP Candies used on them.", cap))
                pbMessageDisplay(msgwindow, _INTL("Rare Candies can be used, but only {1} times, up to level {2}.", RARE_CANDY_LEVEL_CAP_OFFSET, getRareCandyLevelCap))
            when :IGNORE_CAP
                pbMessageDisplay(msgwindow, _INTL("Once at level {1}, your Pokémon cannot gain experience or have EXP Candies used on them.", cap))
                pbMessageDisplay(msgwindow, _INTL("Rare Candies can still be used, however."))
            end
            pbMessageDisplay(msgwindow, _INTL("The level cap can be raised by reading Battle Reports (a consumable item)."))
            pbMessageDisplay(msgwindow, _INTL("You'll earn Battle Reports after defeating Gym Leaders and major story battles."))
        end
        pbDisposeMessageWindow(msgwindow)
    end
end

#===============================================================================
#fucking f12 fix
#===============================================================================
class Scene_Map
    pause_menu_current = (instance_method(:call_menu) rescue nil)
    unless method_defined?(:pause_menu_original_call_menu) && pause_menu_current &&
           pause_menu_current.source_location.to_a[0] == __FILE__
        alias pause_menu_original_call_menu call_menu
    end

    def call_menu
        return pause_menu_original_call_menu unless PauseMenu::ENABLED
        $game_temp.menu_calling = false
        $game_temp.in_menu = true
        $game_player.straighten
        $game_map.update
        screen = TilingCardsPauseMenu.new(PauseMenu_Scene.new)
        screen.pbStartPokemonMenu
        $game_temp.in_menu = false
    end
end
