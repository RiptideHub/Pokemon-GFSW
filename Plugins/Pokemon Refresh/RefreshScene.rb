#===============================================================================
# Pokémon Refresh - the screen
#===============================================================================
module PokemonRefresh
    class Scene
        CELL       = 38
        PAGE_ROW_H = 22

        def initialize(character)
            @character = character
            @data = PokemonRefresh.config(character)
            @state = PokemonRefresh.state(character)
        end

        def main
            start
            loop do
                Graphics.update
                Input.update
                update_pointer
                break if update_input == :exit
                update_effects
            end
            finish
        ensure
            dispose
        end

        #-----------------------------------------------------------------------
        # Setup
        #-----------------------------------------------------------------------
        def start
            @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
            @viewport.z = 99_999
            @bitmaps = []
            @faces = {}
            %w[N A B C].each { |f| @faces[f] = load_bitmap("Refresh#{@data[:graphic]}#{f}") }
            @bg = new_sprite(load_bitmap(BACKGROUND), 0)
            @char = new_sprite(@faces["N"], 1)
            @dirt_bitmap = load_bitmap("RefreshDirt")
            @heart_bitmap = load_bitmap("RefreshHeart")
            @hand_bitmap = load_bitmap("RefreshCursor")
            @cloth_bitmap = load_bitmap("RefreshCloth")
            @ui = new_sprite(Bitmap.new(Graphics.width, Graphics.height), 10)
            pbSetSystemFont(@ui.bitmap)
            @debug = new_sprite(Bitmap.new(Graphics.width, Graphics.height), 20)
            pbSetSystemFont(@debug.bitmap)
            @debug.visible = false
            @held = new_sprite(nil, 30)
            @cursor = new_sprite(@hand_bitmap, 40)
            @icons = {}
            @hearts = []
            @message = nil
            @message_timer = 0
            @face = "N"
            @face_timer = 0
            @mode = :hand
            @panel_open = false
            @page = 0
            @held_item = nil
            @eating = nil
            @petting = false
            @rubbing = Rubbing.new
            @rub_counts = Hash.new(0)
            @pet_gain = 0
            @px = Graphics.width / 2
            @py = Graphics.height / 2
            @last_mouse = nil
            @down = pointer_down?
            @keyboard_used = false
            hide_system_pointer
            @state[:dirt] = PokemonRefresh.make_dirt(@character, method(:on_character?)) if @state[:dirt].empty?
            @dirt = @state[:dirt].map do |x, y, opacity|
                s = new_sprite(@dirt_bitmap, 2)
                s.ox = @dirt_bitmap.width / 2
                s.oy = @dirt_bitmap.height / 2
                s.x = x
                s.y = y
                s.opacity = opacity
                [s, x, y]
            end
            redraw_ui
            fade(255, 0)
        end

        def finish
            @state[:dirt] = @dirt.map { |s, x, y| [x, y, s.opacity] }
            fade(0, 255)
        end

        def dispose
            show_system_pointer
            return unless @viewport
            @hearts.each { |h| h[0].dispose }
            [@bg, @char, @ui, @debug, @held, @cursor].each { |s| s.dispose if s && !s.disposed? }
            (@dirt || []).each { |s, _, _| s.dispose }
            @ui.bitmap.dispose if @ui && @ui.bitmap && !@ui.bitmap.disposed?
            @debug.bitmap.dispose if @debug && @debug.bitmap && !@debug.bitmap.disposed?
            @bitmaps.each { |b| b.dispose unless b.disposed? }
            @icons.each_value { |b| b.dispose unless b.disposed? }
            @viewport.dispose
            @viewport = nil
        end

        def load_bitmap(name)
            bitmap = Bitmap.new(FOLDER + name)
            @bitmaps.push(bitmap)
            return bitmap
        end

        def new_sprite(bitmap, z)
            s = Sprite.new(@viewport)
            s.bitmap = bitmap
            s.z = z
            return s
        end

        def fade(from, to)
            frames = (Graphics.frame_rate * 0.25).floor
            (0..frames).each do |i|
                alpha = from + (to - from) * i / frames
                @viewport.color = Color.new(0, 0, 0, alpha)
                Graphics.update
            end
        end

        #-----------------------------------------------------------------------
        # Only one pointer on screen: the system's mouse pointer is hidden while
        # Refresh is open (if this mkxp-z can), so the hand/cloth is the pointer.
        # If it can't, the hand only shows while the keyboard is being used.
        #-----------------------------------------------------------------------
        def can_hide_system_pointer?
            return Graphics.respond_to?(:show_cursor=)
        end

        def hide_system_pointer
            return unless can_hide_system_pointer?
            @pointer_was_shown = Graphics.respond_to?(:show_cursor) ? Graphics.show_cursor : true
            Graphics.show_cursor = false
            @pointer_hidden = true
        end

        def show_system_pointer
            return unless @pointer_hidden
            Graphics.show_cursor = @pointer_was_shown.nil? ? true : @pointer_was_shown
            @pointer_hidden = false
        end

        #-----------------------------------------------------------------------
        # Pointer: the mouse, or the hand moved with the arrows
        #-----------------------------------------------------------------------
        def pointer_down?
            mouse = defined?(Input::MOUSELEFT) && Input.press?(Input::MOUSELEFT)
            keys = KEYBOARD_CURSOR && Input.press?(Input::USE)
            return mouse || keys ? true : false
        end

        def update_pointer
            pos = (Mouse.getMousePos rescue nil)
            if pos && pos != @last_mouse
                @px, @py = pos[0], pos[1]
                @keyboard_used = false if @last_mouse
                @last_mouse = pos
            end
            if KEYBOARD_CURSOR
                arrows = [Input::RIGHT, Input::LEFT, Input::DOWN, Input::UP].any? { |k| Input.press?(k) }
                @keyboard_used = true if arrows || Input.press?(Input::USE)
                @px += CURSOR_SPEED if Input.press?(Input::RIGHT)
                @px -= CURSOR_SPEED if Input.press?(Input::LEFT)
                @py += CURSOR_SPEED if Input.press?(Input::DOWN)
                @py -= CURSOR_SPEED if Input.press?(Input::UP)
            end
            @px = [[@px, 0].max, Graphics.width - 1].min
            @py = [[@py, 0].max, Graphics.height - 1].min
            down = pointer_down?
            @pressed = down && !@down
            @released = !down && @down
            @down = down
            @cursor.bitmap = @mode == :cloth ? @cloth_bitmap : @hand_bitmap
            @cursor.ox = @mode == :cloth ? @cloth_bitmap.width / 2 : 0
            @cursor.oy = @mode == :cloth ? @cloth_bitmap.height / 2 : 0
            @cursor.x = @px
            @cursor.y = @py
            @cursor.visible = @pointer_hidden || @mode == :cloth || @keyboard_used
        end

        def on_character?(x, y)
            return false if x < 0 || y < 0 || x >= @faces["N"].width || y >= @faces["N"].height
            return @faces["N"].get_pixel(x, y).alpha > 0
        end

        #-----------------------------------------------------------------------
        # Input
        #-----------------------------------------------------------------------
        def update_input
            if $DEBUG && Input.triggerex?(DEBUG_KEY)
                @debug.visible = !@debug.visible
                redraw_debug if @debug.visible
            end
            if Input.trigger?(Input::BACK)
                if @held_item
                    drop_berry
                elsif @panel_open
                    @panel_open = false
                    redraw_ui
                elsif @mode == :cloth
                    @mode = :hand
                    redraw_ui
                else
                    pbPlayCancelSE
                    return :exit
                end
            end
            redraw_ui if hover_changed?
            return click if @pressed
            hold if @down
            release if @released
            return nil
        end

        def click
            button = button_at(@px, @py)
            if button
                pbPlayDecisionSE
                case button
                when :exit then return :exit
                when :berries
                    if PokemonRefresh.berries_in_bag.empty?
                        show_message(_INTL("You don't have any Berries."))
                    else
                        @panel_open = !@panel_open
                        @page = 0
                    end
                when :clean
                    @mode = @mode == :cloth ? :hand : :cloth
                    @panel_open = false
                end
                redraw_ui
                return nil
            end
            if @panel_open
                item = berry_at(@px, @py)
                if item.is_a?(Symbol) && item.to_s.start_with?("page_")
                    turn_page(item == :page_next ? 1 : -1)
                elsif item
                    pick_berry(item) unless @eating
                elsif !in_panel?(@px, @py)
                    @panel_open = false
                    redraw_ui
                end
                return nil
            end
            @petting = true
            @rubbing.reset
            return nil
        end

        def hold
            if @held_item
                @held.x = @px
                @held.y = @py
                return
            end
            return unless @petting
            moved = @last_px ? (@px - @last_px).abs + (@py - @last_py).abs : 0
            @last_px = @px
            @last_py = @py
            if @mode == :cloth
                wipe(moved) if moved > 0
                return
            end
            spot = PokemonRefresh.spot_at(@character, @px, @py, method(:on_character?))
            unless spot
                @rubbing.reset
                return
            end
            show_face(FACES[spot]) if moved > 0
            rub(spot) if @rubbing.update(@px)
        end

        def release
            feed_or_drop if @held_item
            @petting = false
            @last_px = nil
        end

        #-----------------------------------------------------------------------
        # Petting
        #-----------------------------------------------------------------------
        def rub(spot)
            @rub_counts[spot] += 1
            case spot
            when :soft
                return unless @rub_counts[:soft] % RUBS_FOR_HEARTS == 0
                hearts(@px, @py, 3)
                amount = PET_FRIENDSHIP
                amount = [amount, PET_LIMIT_PER_VISIT - @pet_gain].min if PET_LIMIT_PER_VISIT
                if amount > 0
                    @pet_gain += amount
                    PokemonRefresh.add_friendship(@character, amount)
                end
            when :hated
                return unless @rub_counts[:hated] % RUBS_FOR_HATED == 0
                PokemonRefresh.add_friendship(@character, HATED_FRIENDSHIP)
            end
            redraw_debug if @debug.visible
        end

        #-----------------------------------------------------------------------
        # Cleaning
        #-----------------------------------------------------------------------
        def wipe(moved)
            @dirt.each do |entry|
                sprite, x, y = entry
                next if sprite.nil?
                next if (x - @px).abs > 18 || (y - @py).abs > 18
                sprite.opacity -= (CLEAN_SPEED * [moved, 4].min / 2.0).ceil
                next if sprite.opacity > 0
                sprite.dispose
                entry[0] = nil
                hearts(x, y, 3)
                show_face(FACES[:clean])
                PokemonRefresh.add_friendship(@character, CLEAN_FRIENDSHIP)
            end
            return unless @dirt.any? { |s, _, _| s.nil? }
            @dirt.reject! { |s, _, _| s.nil? }
            if @dirt.empty?
                @mode = :hand
                @petting = false
                show_message(_INTL("{1} is all clean!", @data[:name]))
            end
            redraw_ui
            redraw_debug if @debug.visible
        end

        #-----------------------------------------------------------------------
        # Feeding
        #-----------------------------------------------------------------------
        def pick_berry(item)
            @held_item = item
            @held.bitmap = icon(item)
            @held.ox = @held.bitmap.width / 2
            @held.oy = @held.bitmap.height / 2
            @held.zoom_x = @held.zoom_y = 1.0
            @held.x = @px
            @held.y = @py
            @held.visible = true
        end

        def drop_berry
            @held_item = nil
            @held.visible = false
        end

        def feed_or_drop
            item = @held_item
            unless PokemonRefresh.mouth?(@character, @px, @py)
                drop_berry
                return
            end
            if PokemonRefresh.full?(@character)
                drop_berry
                show_face(FACES[:full])
                show_message(_INTL("{1} is full!", @data[:name]))
                return
            end
            $PokemonBag.pbDeleteItem(item) if BERRIES_USED_UP
            PokemonRefresh.ate_berry(@character)
            PokemonRefresh.add_friendship(@character, FEED_FRIENDSHIP)
            @held_item = nil
            @eating = 16
            show_face(FACES[:eat])
            hearts(@px, @py - 10, 2)
            if PokemonRefresh.full?(@character)
                show_message(_INTL("{1} is full now!", @data[:name]))
            end
            @panel_open = false if PokemonRefresh.berries_in_bag.empty?
            redraw_ui
            redraw_debug if @debug.visible
        end

        #-----------------------------------------------------------------------
        # Effects
        #-----------------------------------------------------------------------
        def update_effects
            if @eating
                @eating -= 1
                @held.zoom_x = @held.zoom_y = [@eating / 16.0, 0].max
                if @eating <= 0
                    @eating = nil
                    @held.visible = false
                end
            end
            @hearts.each do |h|
                sprite = h[0]
                sprite.x += h[1]
                sprite.y += h[2]
                h[3] -= 1
                sprite.opacity = [h[3] * 255 / 20, 255].min
            end
            @hearts.reject! do |h|
                next false if h[3] > 0
                h[0].dispose
                true
            end
            if @face_timer > 0
                @face_timer -= 1
                set_face("N") if @face_timer == 0
            end
            if @message_timer > 0
                @message_timer -= 1
                if @message_timer == 0
                    @message = nil
                    redraw_ui
                end
            end
        end

        def show_face(letter)
            set_face(letter)
            @face_timer = FACE_HOLD_FRAMES
        end

        def set_face(letter)
            return if @face == letter
            @face = letter
            @char.bitmap = @faces[letter] || @faces["N"]
        end

        def hearts(x, y, count)
            count.times do
                s = new_sprite(@heart_bitmap, 25)
                s.ox = @heart_bitmap.width / 2
                s.oy = @heart_bitmap.height / 2
                s.x = x + rand(41) - 20
                s.y = y + rand(21) - 10
                s.zoom_x = s.zoom_y = 0.7 + rand(4) / 10.0
                @hearts.push([s, (rand(13) - 6) / 10.0, -1.2 - rand(9) / 10.0, 50])
            end
        end

        def show_message(text, frames = 100)
            @message = text
            @message_timer = frames
            redraw_ui
        end

        #-----------------------------------------------------------------------
        # Buttons and the berry panel
        #-----------------------------------------------------------------------
        def visible_buttons
            list = [:berries]
            list.push(:clean) unless @dirt.empty?
            list.push(:exit)
            return list
        end

        def button_rect(button)
            index = visible_buttons.index(button)
            base = BUTTONS[:berries]
            step = BUTTONS[:clean][1] - base[1]
            return [base[0], base[1] + step * index, base[2], base[3]]
        end

        def button_at(x, y)
            visible_buttons.each { |b| return b if PokemonRefresh.in_rect?(button_rect(b), x, y) }
            return nil
        end

        def panel_rect
            top = button_rect(visible_buttons.last)
            y = top[1] + top[3] + 6
            return [BERRY_PANEL[0], y, BERRY_PANEL[2], BERRY_PANEL[3]]
        end

        def in_panel?(x, y)
            return PokemonRefresh.in_rect?(panel_rect, x, y)
        end

        def per_page
            r = panel_rect
            return (r[2] / CELL) * ((r[3] - PAGE_ROW_H) / CELL)
        end

        def page_berries
            all = PokemonRefresh.berries_in_bag
            pages = [(all.length + per_page - 1) / per_page, 1].max
            @page = [[@page, 0].max, pages - 1].min
            return all[@page * per_page, per_page] || [], pages
        end

        def turn_page(dir)
            _, pages = page_berries
            @page = (@page + dir) % pages
            pbPlayDecisionSE
            redraw_ui
        end

        def berry_at(x, y)
            r = panel_rect
            return nil unless PokemonRefresh.in_rect?(r, x, y)
            if y >= r[1] + r[3] - PAGE_ROW_H
                return x < r[0] + r[2] / 2 ? :page_prev : :page_next
            end
            cols = r[2] / CELL
            col = (x - r[0]) / CELL
            row = (y - r[1]) / CELL
            return nil if col >= cols
            berries, _ = page_berries
            return berries[row * cols + col]
        end

        def icon(item)
            @icons[item] ||= Bitmap.new(GameData::Item.icon_filename(item))
            return @icons[item]
        end

        def hover_changed?
            key = [button_at(@px, @py), @panel_open ? berry_at(@px, @py) : nil]
            return false if key == @hover
            @hover = key
            return true
        end

        def redraw_ui
            b = @ui.bitmap
            b.clear
            hover = button_at(@px, @py)
            visible_buttons.each do |button|
                x, y, w, h = button_rect(button)
                active = (button == :berries && @panel_open) || (button == :clean && @mode == :cloth)
                lit = hover == button || active
                b.fill_rect(x, y, w, h, lit ? BUTTON_HOVER : BUTTON_COLOR)
                label = { :berries => _INTL("Berries"), :clean => _INTL("Clean"), :exit => _INTL("Exit") }[button]
                pbDrawShadowText(b, x, y - 6, w, h, label, lit ? BUTTON_TEXT_HOVER : BUTTON_TEXT, nil, 1)
            end
            draw_panel(b) if @panel_open
            draw_message(b)
        end

        def draw_panel(b)
            r = panel_rect
            b.fill_rect(r[0], r[1], r[2], r[3], BUTTON_COLOR)
            berries, pages = page_berries
            cols = r[2] / CELL
            hovered = berry_at(@px, @py)
            berries.each_with_index do |item, i|
                cx = r[0] + (i % cols) * CELL
                cy = r[1] + (i / cols) * CELL
                b.fill_rect(cx + 1, cy + 1, CELL - 2, CELL - 2, BUTTON_HOVER) if hovered == item
                bmp = icon(item)
                b.stretch_blt(Rect.new(cx + 3, cy + 3, CELL - 6, CELL - 6), bmp, Rect.new(0, 0, bmp.width, bmp.height))
                b.font.size = 18
                pbDrawShadowText(b, cx, cy + 12, CELL - 3, 20, $PokemonBag.pbQuantity(item).to_s,
                                 BUTTON_TEXT, Color.new(0, 0, 0), 2)
            end
            y = r[1] + r[3] - PAGE_ROW_H
            pbSetSystemFont(b)
            if pages > 1
                pbDrawShadowText(b, r[0], y - 6, r[2], PAGE_ROW_H, "<  #{@page + 1}/#{pages}  >", BUTTON_TEXT, nil, 1)
            end
            if hovered.is_a?(Symbol) && !hovered.to_s.start_with?("page_") && !@message
                draw_box(b, GameData::Item.get(hovered).name)
            end
        end

        def draw_message(b)
            draw_box(b, @message) if @message
        end

        def draw_box(b, text)
            pbSetSystemFont(b)
            w = [b.text_size(text).width + 32, 200].max
            x = (Graphics.width - w) / 2
            y = Graphics.height - 46
            b.fill_rect(x, y, w, 38, BUTTON_COLOR)
            pbDrawShadowText(b, x, y - 2, w, 38, text, BUTTON_TEXT, nil, 1)
        end

        #-----------------------------------------------------------------------
        # Debug view (F7 in debug mode): the spots, the mouth and the numbers
        #-----------------------------------------------------------------------
        DEBUG_COLORS = {
            :soft    => Color.new(255, 120, 180),
            :neutral => Color.new(200, 200, 200),
            :hated   => Color.new(255, 60, 60),
            :mouth   => Color.new(255, 230, 0),
        }

        def redraw_debug
            b = @debug.bitmap
            b.clear
            @data[:spots].each { |kind, rect| debug_rect(b, rect, DEBUG_COLORS[kind]) }
            debug_rect(b, @data[:mouth], DEBUG_COLORS[:mouth])
            lines = [
                _INTL("Elsewhere on {1}: {2}", @data[:name], @data[:elsewhere]),
                _INTL("Friendship: {1}/{2}", PokemonRefresh.friendship(@character), MAX_FRIENDSHIP),
                _INTL("Full: {1}/{2} ({3}/{4} steps)", @state[:full], BERRIES_UNTIL_FULL, @state[:steps], STEPS_PER_BERRY),
            ]
            b.font.size = 20
            lines.each_with_index do |line, i|
                pbDrawShadowText(b, 250, 2 + i * 20, 256, 22, line, Color.new(255, 255, 255), Color.new(0, 0, 0), 2)
            end
        end

        def debug_rect(b, rect, color)
            x, y, w, h = rect
            b.fill_rect(x, y, w, h, Color.new(color.red, color.green, color.blue, 70))
            b.fill_rect(x, y, w, 2, color)
            b.fill_rect(x, y + h - 2, w, 2, color)
            b.fill_rect(x, y, 2, h, color)
            b.fill_rect(x + w - 2, y, 2, h, color)
        end
    end
end
