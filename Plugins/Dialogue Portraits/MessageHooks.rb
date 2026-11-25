#===============================================================================
# Dialogue Portraits - text codes and message box hooks
# \pl[Name] and \pr[Name] in a message change the left / right portrait at the
# moment. \pl[] and \pr[] slide that side out.
#
#===============================================================================
module DialoguePortraits
    TEXT_CODE  = /(?<!\\)\\p([lr])\[([^\]]*)\]/i
    MARK_START = "\x0E"
    MARK_END   = "\x0F"
    MARKER     = /\x0E(\d+)\x0F/

    @messages = []

    module_function

    def encode_text_codes(message, context)
        return message unless message.is_a?(String) && message[TEXT_CODE]
        return message.gsub(TEXT_CODE) do
            side = (Regexp.last_match(1).downcase == "l") ? :left : :right
            context[:codes].push([side, Regexp.last_match(2).strip])
            next MARK_START + (context[:codes].length - 1).to_s + MARK_END
        end
    end

    def strip_markers(text)
        return text unless text.include?(MARK_START)
        return text.gsub(MARKER, "")
    end

    def begin_message(msgwindow)
        context = { window: msgwindow, codes: [], pending: [] }
        @messages.push(context)
        return context
    end

    def end_message(context)
        fire_pending(context, true)
        @messages.delete(context)
    end

    def current_message
        return @messages.last
    end

    def capture_markers(window, text)
        context = @messages.reverse.find { |c| c[:window].equal?(window) }
        return strip_markers(text) unless context
        pending = []
        clean = ""
        rest = text
        while (match = MARKER.match(rest))
            clean << match.pre_match
            position = unformattedTextLength(clean)
            code = context[:codes][match[1].to_i]
            pending.push([position, code]) if code
            rest = match.post_match
        end
        clean << rest
        context[:pending] = pending
        fire_pending(context) # Codes at the very start fire before the box is drawn
        return clean
    end

    def fire_pending(context, all = false)
        pending = context[:pending]
        return if pending.empty?
        window = context[:window]
        reached = (window.nil? || window.disposed?) ? nil : window.position
        while (entry = pending.first)
            break unless all || (reached && entry[0] <= reached)
            pending.shift
            side, name = entry[1]
            show(side, name)
        end
    end

    def frame_update
        context = current_message
        if context
            window = context[:window]
            if window && !window.disposed?
                fire_pending(context)
                update
                place_name_tag(window)
                return
            end
        end
        update
    end
end

#===============================================================================
# Hooks
#===============================================================================
module DialoguePortraits
    module MessageDisplayHook
        private

        def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, &block)
            return super unless msgwindow
            context = DialoguePortraits.begin_message(msgwindow)
            begin
                message = DialoguePortraits.encode_text_codes(message, context)
                return super(msgwindow, message, letterbyletter, commandProc, &block)
            ensure
                DialoguePortraits.end_message(context)
            end
        end

        def toUnformattedText(text)
            return super(DialoguePortraits.strip_markers(text))
        end
    end

    module MessageWindowHook
        def setText(value)
            value = DialoguePortraits.capture_markers(self, value) if value.is_a?(String) && value.include?(DialoguePortraits::MARK_START)
            super(value)
        end
    end

    # Choice, number and text-entry boxes sit on top of the message box, in the
    # same strip as the speaker name tag. If one would overlap the tag, stack it
    # above the tag instead. If there isn't room above, draw it in front of the tag.
    module ChoiceBoxHook
        private

        def pbPositionNearMsgWindow(cmdwindow, msgwindow, side)
            super
            DialoguePortraits.stack_above_name_tag(cmdwindow, msgwindow)
        end
    end

    # Runs once per Graphics.update. Errors are logged once instead of crashing.
    def self.safe_frame_update
        frame_update
    rescue StandardError => e
        unless @frameErrorShown
            @frameErrorShown = true
            echoln("Dialogue Portraits error: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        end
    end
end

Object.prepend(DialoguePortraits::MessageDisplayHook)
Object.prepend(DialoguePortraits::ChoiceBoxHook)
Window_AdvancedTextPokemon.prepend(DialoguePortraits::MessageWindowHook)

# Graphics.update is now hooked with alias, not prepend. otherwise it will loop and crash becouse Chasm Speedup uses alias instead of prepend 
# Also fucking f12 fix
class << Graphics
    alias dialogue_portraits_update update unless method_defined?(:dialogue_portraits_update)

    def update
        DialoguePortraits.safe_frame_update
        dialogue_portraits_update
    end
end
