#===============================================================================
# Compatibility Fixes - Easy Debug Terminal key (F3)
#
# The problem: Easy Debug Terminal checks for F3 inside Input.update. Chasm
# Speedup loads later and replaces Input.update with its own version (for Tab
# and F8), so the terminal's F3 check was thrown away and F3 did nothing.
#
# The fix: neither plugin is changed. Once the game is running (after every
# plugin has loaded), this wraps whatever Input.update is in use and checks F3
# after it. If anything replaces Input.update again later, it wraps it again.
#
# If Chasm Speedup is ever changed to wrap Input.update instead of replacing
# it, the terminal's own check works again; this one then stays out of the way
# (it never opens the terminal twice).
#===============================================================================
module CompatibilityFixes
    DEBUG_TERMINAL_KEY_FIX = true

    module_function

    def terminal_present?
        return defined?(TERMINAL_KEYBIND) && defined?(TERMINAL_ENABLED) &&
               defined?(pbFreeTextNoWindow) && defined?(Window_TextEntry_Keyboard_Terminal)
    end

    def ensure_terminal_key
        return unless DEBUG_TERMINAL_KEY_FIX && terminal_present?
        current = Input.method(:update)
        return if @wrapped && current == @wrapped
        original = current
        Input.define_singleton_method(:update) do
            before = Graphics.frame_count
            original.call
            CompatibilityFixes.check_terminal_key if Graphics.frame_count == before
        end
        @wrapped = Input.method(:update)
    end

    def check_terminal_key
        return unless $DEBUG && TERMINAL_ENABLED && !$InCommandLine
        return unless Input.triggerex?(TERMINAL_KEYBIND)
        $InCommandLine = true
        begin
            script = pbFreeTextNoWindow("", false, 256, Graphics.width)
            unless nil_or_empty?(script)
                $game_temp.debug_commands_history.unshift(script)
                $game_temp.debug_commands_index = -1
                begin
                    pbMapInterpreter.execute_script(script)
                rescue Exception
                end
            end
        ensure
            $InCommandLine = false
        end
    end
end

module Graphics
    class << Graphics
        alias compatibility_fixes_update update unless method_defined?(:compatibility_fixes_update)
    end

    def self.update
        compatibility_fixes_update
        CompatibilityFixes.ensure_terminal_key
    end
end
