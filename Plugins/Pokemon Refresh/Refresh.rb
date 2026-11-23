#===============================================================================
# Pokémon Refresh - saved state, friendship, fullness and the rules
# (no graphics here; the screen is in RefreshScene.rb)
#===============================================================================

class PokemonGlobalMetadata
    attr_writer :pokemon_refresh

    def pokemon_refresh
        @pokemon_refresh ||= {}
        return @pokemon_refresh
    end
end

module PokemonRefresh
    module_function

    def config(character)
        data = CHARACTERS[character]
        raise ArgumentError, _INTL("Pokémon Refresh: no character {1} in the settings.", character.inspect) unless data
        return data
    end

    def state(character)
        all = $PokemonGlobal.pokemon_refresh
        all[character] ||= { :full => 0, :steps => 0, :dirt => [] }
        return all[character]
    end

    #---------------------------------------------------------------------------
    # Friendship
    #---------------------------------------------------------------------------
    def friendship(character)
        return $game_variables[config(character)[:friendship_variable]].to_i
    end

    def add_friendship(character, amount)
        id = config(character)[:friendship_variable]
        old = $game_variables[id].to_i
        new = [[old + amount, 0].max, MAX_FRIENDSHIP].min
        $game_variables[id] = new
        $game_map.need_refresh = true if $game_map
        return new - old
    end

    #---------------------------------------------------------------------------
    # Fullness (one berry is digested every STEPS_PER_BERRY steps)
    #---------------------------------------------------------------------------
    def full?(character)
        return state(character)[:full] >= BERRIES_UNTIL_FULL
    end

    def ate_berry(character)
        s = state(character)
        s[:steps] = 0 if s[:full] == 0
        s[:full] += 1
    end

    def step_taken
        return unless $PokemonGlobal
        $PokemonGlobal.pokemon_refresh.each_value do |s|
            next if s[:full] <= 0
            s[:steps] += 1
            next if s[:steps] < STEPS_PER_BERRY
            s[:full] -= 1
            s[:steps] = 0
        end
    end

    def berries_in_bag
        return [] unless $PokemonBag
        found = []
        GameData::Item.each { |item| found.push(item.id) if item.is_berry? && $PokemonBag.pbQuantity(item.id) > 0 }
        return found
    end

    #---------------------------------------------------------------------------
    # Spots
    #---------------------------------------------------------------------------
    def in_rect?(rect, x, y)
        return x >= rect[0] && y >= rect[1] && x < rect[0] + rect[2] && y < rect[1] + rect[3]
    end

    def spot_at(character, x, y, on_character)
        return nil unless on_character.call(x, y)
        data = config(character)
        data[:spots].each { |kind, rect| return kind if in_rect?(rect, x, y) }
        return data[:elsewhere] || :neutral
    end

    def mouth?(character, x, y)
        return in_rect?(config(character)[:mouth], x, y)
    end

    def make_dirt(character, on_character, rng = Random)
        return [] unless config(character)[:can_get_dirty]
        return [] unless rng.rand(100) < DIRT_CHANCE
        count = DIRT_MIN + rng.rand(DIRT_MAX - DIRT_MIN + 1)
        dirt = []
        400.times do
            break if dirt.length >= count
            x = 20 + rng.rand(472)
            y = 20 + rng.rand(DIRT_LOWEST_Y - 20)
            next unless on_character.call(x, y)
            next if dirt.any? { |dx, dy, _| (dx - x).abs < 34 && (dy - y).abs < 34 }
            dirt.push([x, y, 255])
        end
        return dirt
    end

    #---------------------------------------------------------------------------
    # Rubbing: counts how many times the cursor turns back while held down
    #---------------------------------------------------------------------------
    class Rubbing
        attr_reader :rubs

        def initialize
            reset
        end

        def reset
            @last_x = nil
            @dir = 0
            @travel = 0
            @rubs = 0
        end

        def update(x)
            if @last_x.nil?
                @last_x = x
                return false
            end
            dx = x - @last_x
            @last_x = x
            return false if dx == 0
            dir = dx > 0 ? 1 : -1
            if dir == @dir
                @travel += dx.abs
                return false
            end
            counted = @dir != 0 && @travel >= RUB_DISTANCE
            @rubs += 1 if counted
            @dir = dir
            @travel = dx.abs
            return counted
        end
    end
end

Events.onStepTaken += proc { |_sender, _e| PokemonRefresh.step_taken }

#-------------------------------------------------------------------------------
# For events
#-------------------------------------------------------------------------------
def pokemonRefresh(character)
    PokemonRefresh.config(character)
    pbFadeOutIn do
        scene = PokemonRefresh::Scene.new(character)
        scene.main
    end
    return true
end

def refreshFriendship(character)
    return PokemonRefresh.friendship(character)
end
