#===============================================================================
# Dialogue Portraits
#===============================================================================
module DialoguePortraits
    #---------------------------------------------------------------------------
    # Settings
    #---------------------------------------------------------------------------
    FOLDER          = "Graphics/Portraits/"
    EDGE_MARGIN     = 8      # Gap between a portrait and the screen edge, in pixels
    SLIDE_SECONDS   = 0.25   # How long a slide in or out takes
    DIM_COLOR       = Color.new(0, 0, 0, 110) # Overlay on the portrait that isn't talking
    DIM_SECONDS     = 0.1    # How long dimming / undimming takes
    Z               = 99_999 # Just below the message box (99_999)
    NAME_TAG_GAP    = 4      # Gap between a portrait and the speaker name tag
    HIDE_AT_EVENT_END = true # Slide portraits out when a map event finishes

    SIDES = [:left, :right].freeze

    #---------------------------------------------------------------------------
    # One portrait slot (left or right)
    #---------------------------------------------------------------------------
    class Slot
        attr_reader :side, :name

        def initialize(side)
            @side    = side
            @name    = nil
            @sprite  = nil
            @state   = :hidden # :hidden, :sliding_in, :shown, :sliding_out
            @dim     = 0.0     # 0.0 = full colour, 1.0 = fully dimmed
            @dimGoal = 0.0
        end

        def shown?
            return @state != :hidden && @state != :sliding_out
        end

        def visible?
            return @state != :hidden
        end

        def sliding?
            return @state == :sliding_in || @state == :sliding_out
        end

        def width
            return (sprite_ready?) ? @sprite.bitmap.width : 0
        end

        def x
            return (sprite_ready?) ? @sprite.x : 0
        end

        def show(name)
            bitmap = DialoguePortraits.load_bitmap(name)
            return false unless bitmap
            ensure_sprite
            @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
            @sprite.bitmap = bitmap
            @name = name
            @sprite.y = DialoguePortraits.baseline - bitmap.height
            @sprite.visible = true
            case @state
            when :hidden
                @sprite.x = offscreen_x
                @state = :sliding_in
            when :sliding_out
                @state = :sliding_in # Turn around from wherever it is now
            end
            return true
        end

        def hide(instant = false)
            return if @state == :hidden
            if instant || !sprite_ready?
                clear
            else
                @state = :sliding_out
            end
        end

        def clear
            @state = :hidden
            @name  = nil
            @dim = @dimGoal = 0.0
            if sprite_ready?
                @sprite.visible = false
                @sprite.bitmap.dispose
                @sprite.bitmap = nil
            end
        end

        def dimmed=(value)
            @dimGoal = value ? 1.0 : 0.0
        end

        # Used while a battle is on screen
        def suspend
            @sprite.visible = false if sprite_ready?
        end

        def resume
            @sprite.visible = true if sprite_ready? && visible?
        end

        def update
            return unless sprite_ready?
            update_slide
            update_dim
            @sprite.y = DialoguePortraits.baseline - @sprite.bitmap.height if visible?
        end

        def dispose
            if @sprite && !@sprite.disposed?
                @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
                @sprite.dispose
            end
            @sprite = nil
            @state  = :hidden
            @name   = nil
        end

        # Where the portrait stands once it has finished sliding in
        def home_x
            return EDGE_MARGIN if @side == :left
            return Graphics.width - width - EDGE_MARGIN
        end

        private

        def sprite_ready?
            return @sprite && !@sprite.disposed? && @sprite.bitmap && !@sprite.bitmap.disposed?
        end

        def ensure_sprite
            return if @sprite && !@sprite.disposed?
            @sprite = Sprite.new
            @sprite.z = Z
            @sprite.visible = false
        end

        def offscreen_x
            return -width if @side == :left
            return Graphics.width
        end

        def slide_step
            distance = (home_x - offscreen_x).abs
            frames = [(SLIDE_SECONDS * Graphics.frame_rate).round, 1].max
            return [(distance / frames.to_f).ceil, 1].max
        end

        def update_slide
            case @state
            when :sliding_in
                target = home_x
            when :sliding_out
                target = offscreen_x
            else
                @sprite.x = home_x if @state == :shown # Keep in place if the image width changed
                return
            end
            step = slide_step
            if (target - @sprite.x).abs <= step
                @sprite.x = target
                if @state == :sliding_in
                    @state = :shown
                else
                    clear
                end
            else
                @sprite.x += (target > @sprite.x) ? step : -step
            end
        end

        def update_dim
            if @dim != @dimGoal
                frames = [(DIM_SECONDS * Graphics.frame_rate).round, 1].max
                step = 1.0 / frames
                if (@dimGoal - @dim).abs <= step
                    @dim = @dimGoal
                else
                    @dim += (@dimGoal > @dim) ? step : -step
                end
            end
            alpha = (DIM_COLOR.alpha * @dim).round
            color = @sprite.color
            if color.alpha != alpha
                @sprite.color = Color.new(DIM_COLOR.red, DIM_COLOR.green, DIM_COLOR.blue, alpha)
            end
        end
    end

    #---------------------------------------------------------------------------
    # Manager
    #---------------------------------------------------------------------------
    @slots     = {}
    @talking   = nil
    @suspended = false
    @baselines = {}

    module_function

    def slot(side)
        side = normalize_side(side)
        @slots[side] ||= Slot.new(side)
        return @slots[side]
    end

    def normalize_side(side)
        value = side.to_s.downcase.to_sym
        return value if SIDES.include?(value)
        raise ArgumentError.new(_INTL("Portrait side must be :left or :right, not {1}.", side.inspect))
    end

    def show(side, name)
        side = normalize_side(side)
        return hide(side) if name.nil? || name.to_s.strip.empty?
        return unless slot(side).show(name.to_s.strip)
        @talking = side
        refresh_dimming
    end

    def hide(side, instant = false)
        side = normalize_side(side)
        slot(side).hide(instant)
        @talking = nil if @talking == side
        refresh_dimming
    end

    def hide_all(instant = false)
        SIDES.each { |side| slot(side).hide(instant) }
        @talking = nil
        refresh_dimming
    end

    # side: :left, :right, or nil for nobody (both at full colour)
    def talking=(side)
        @talking = side.nil? || side == :none ? nil : normalize_side(side)
        refresh_dimming
    end

    def talking
        return @talking
    end

    def any_visible?
        return @slots.values.any? { |s| s.visible? }
    end

    def sliding?
        return @slots.values.any? { |s| s.sliding? }
    end

    def refresh_dimming
        both = SIDES.all? { |side| slot(side).shown? }
        SIDES.each do |side|
            slot(side).dimmed = both && !@talking.nil? && @talking != side
        end
    end

    # Called every frame from Graphics.update
    def update
        return if @suspended
        return if @slots.empty?
        @slots.each_value { |s| s.update }
    end

    # Hide portraits while a battle is on screen, then bring them back
    def suspend
        @suspended = true
        @slots.each_value { |s| s.suspend }
    end

    def resume
        @suspended = false
        @slots.each_value { |s| s.resume }
    end

    def reset
        @slots.each_value { |s| s.dispose }
        @slots.clear
        @talking = nil
        @suspended = false
    end

    def baseline
        skin = MessageConfig.pbGetSpeechFrame
        @baselines[skin] ||= begin
            window = Window_AdvancedTextPokemon.new("")
            window.setSkin(skin)
            border = window.borderY
            window.dispose
            linecount = (Graphics.height > 400) ? 3 : 2
            Graphics.height - (32 * linecount + border) + skin_top_padding(skin)
        end
        return @baselines[skin]
    end

    def skin_top_padding(skin)
        path = pbResolveBitmap(skin)
        return 0 unless path
        bitmap = Bitmap.new(path)
        x = bitmap.width / 2
        padding = 0
        padding += 1 while padding < bitmap.height / 2 && bitmap.get_pixel(x, padding).alpha == 0
        bitmap.dispose
        return padding
    end

    def load_bitmap(name)
        path = pbResolveBitmap(FOLDER + name)
        # The engine turns "Pokemon" into "Pokémon" in all text, file names included
        path ||= pbResolveBitmap(FOLDER + name.tr("éÉ", "eE").delete(" "))
        unless path
            echoln("Dialogue Portraits: can't find #{FOLDER}#{name}")
            return nil
        end
        return Bitmap.new(path)
    end

    #---------------------------------------------------------------------------
    # Speaker name tag: move it beside the talking portrait so it doesn't cover the art
    #---------------------------------------------------------------------------
    @tagFitWidths = {}

    def anchor_side
        left  = slot(:left).shown?
        right = slot(:right).shown?
        return :right if right && (@talking == :right || !left)
        return :left if left
        return nil
    end

    def place_name_tag(msgwindow)
        tag = $SpeakerNameWindow
        return unless tag && !tag.disposed? && tag.visible
        return unless msgwindow && !msgwindow.disposed?
        side = (@suspended) ? nil : anchor_side
        if side.nil?
            restore_name_tag_width(tag)
            return
        end
        width = fit_width(tag)
        tag.width = width if tag.width != width
        portrait = slot(side)
        # Use where the portrait stands, not where it is mid-slide, so the tag doesn't move
        if side == :left
            tag.x = portrait.home_x + portrait.width + NAME_TAG_GAP
        else
            tag.x = portrait.home_x - tag.width - NAME_TAG_GAP
        end
        tag.x = [[tag.x, 0].max, Graphics.width - tag.width].min
        @tagShrunk = true
    end

    def restore_name_tag_width(tag)
        return unless @tagShrunk
        @tagShrunk = false
        refreshSpeakerWindow # The engine's own sizing
        tag.visible = true
    end

    #---------------------------------------------------------------------------
    # Choice boxes: keep them clear of the speaker name tag
    #---------------------------------------------------------------------------
    def stackable_box?(window)
        return true if window.is_a?(Window_DrawableCommand)
        return true if window.is_a?(Window_InputNumberPokemon)
        return true if defined?(Window_TextEntry) && window.is_a?(Window_TextEntry)
        return false
    end

    def windows_overlap?(a, b)
        return false if a.x >= b.x + b.width  || b.x >= a.x + a.width
        return false if a.y >= b.y + b.height || b.y >= a.y + a.height
        return true
    end

    def stack_above_name_tag(box, msgwindow)
        return unless box && !box.disposed? && stackable_box?(box)
        tag = $SpeakerNameWindow
        return unless tag && !tag.disposed? && tag.visible
        return if box.equal?(tag)
        # Instant (not letter-by-letter) messages end before the frame update that
        # moves the tag beside the portrait, so make sure it's in place first
        place_name_tag(msgwindow) if msgwindow && !@suspended && anchor_side
        return unless windows_overlap?(box, tag)
        if tag.y - box.height >= 0
            box.y = tag.y - box.height
        else
            box.z = [box.z, tag.z + 1].max # No room above: cover the tag instead
        end
    end

    def fit_width(tag)
        text = tag.text.to_s
        @tagFitWidths[text] ||= begin
            dims = tag.resizeToFitInternal(text, Graphics.width)
            dims[0] + tag.borderX + SpriteWindow_Base::TEXTPADDING
        end
        return @tagFitWidths[text]
    end
end
