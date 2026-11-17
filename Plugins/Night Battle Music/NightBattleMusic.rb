#===============================================================================
# Night Battle Music
#-
# Wild battles at night play "[name]_n" if that file exists in
# Audio/BGM/, the same rule the overworld already uses for map music.
#
#   Battle wild.ogg      plays during the day
#   Battle wild_n.ogg    plays at night (20:00 - 04:59), if the file exists
#
# Works for the default wild track and for each map's own WildBattleBGM.
#===============================================================================
module NightBattleMusic
    NIGHT_SUFFIX = "_n"
    AUDIO_EXTENSIONS = [".ogg", ".mid", ".midi", ".mp3", ".wav", ".wma"].freeze

    module_function

    def night_version(audio)
        return nil unless audio && audio.name && !audio.name.empty?
        name = audio.name
        extension = File.extname(name)
        extension = "" unless AUDIO_EXTENSIONS.include?(extension.downcase)
        base = name[0, name.length - extension.length]
        return nil if base.end_with?(NIGHT_SUFFIX) # Already a night track
        night_name = base + NIGHT_SUFFIX + extension
        return nil unless FileTest.audio_exist?("Audio/BGM/" + night_name)
        return RPG::AudioFile.new(night_name, audio.volume, audio.pitch)
    end

    module Hook
        private

        def pbGetWildBattleBGM(*args)
            chosen_by_event = !$PokemonGlobal.nil? && !$PokemonGlobal.nextBattleBGM.nil?
            ret = super
            return ret if chosen_by_event || !PBDayNight.isNight?
            return NightBattleMusic.night_version(ret) || ret
        end
    end
end

Object.prepend(NightBattleMusic::Hook)
