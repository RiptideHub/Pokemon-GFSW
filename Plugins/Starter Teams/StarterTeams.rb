#===============================================================================
# Starter Teams - logic. Settings and usage are in Settings.rb.
#===============================================================================
module StarterTeams
    module_function


    def slot
        return 0 unless $game_variables
        value = $game_variables[VARIABLE]
        return 0 unless value.is_a?(Integer) && value.between?(1, STARTERS.length)
        return value
    end

    def species
        return nil if slot == 0
        return STARTERS[slot - 1]
    end


    def record(starter)
        if starter.is_a?(Integer)
            position = starter
        else
            index = STARTERS.index(starter.to_s.upcase.to_sym)
            position = index ? index + 1 : 0
        end
        unless position.between?(1, STARTERS.length)
            raise ArgumentError.new(_INTL("setStarter: {1} is not one of the starters in StarterTeams::STARTERS ({2}).",
                starter.inspect, STARTERS.join(", ")))
        end
        $game_variables[VARIABLE] = position
        $game_map.need_refresh = true if $game_map
    end

    def validate_fight(fight)
        return if fight.is_a?(Integer) && fight >= 1
        raise ArgumentError.new(_INTL("Starter Teams: the fight number must be 1 or higher, not {1}.", fight.inspect))
    end

    def version_for(tr_type, tr_name, fight)
        validate_fight(fight)
        shared = fight * 10
        return shared if slot == 0
        own = shared + slot
        return own if GameData::Trainer.exists?(tr_type, tr_name, own)
        return shared if GameData::Trainer.exists?(tr_type, tr_name, shared)
        return own
    end

    def given_species(pkmn)
        return pkmn.species if pkmn.respond_to?(:species)
        return pkmn.to_s.upcase.to_sym if pkmn.is_a?(Symbol) || pkmn.is_a?(String)
        return nil
    end

    def auto_record(pkmn)
        return unless AUTO_RECORD && slot == 0 && $game_variables
        species = given_species(pkmn)
        record(species) if species && STARTERS.include?(species)
    end
end

if StarterTeams::STARTERS.length > 9
    raise "Starter Teams: STARTERS can hold at most 9 starters, because each one takes a single digit of the team version."
end

#===============================================================================
# Script commands for events
#===============================================================================
def setStarter(starter)
    StarterTeams.record(starter)
end

def starterSpecies
    return StarterTeams.species
end

def starterSlot
    return StarterTeams.slot
end

def starterIs?(species)
    return StarterTeams.species == species.to_s.upcase.to_sym
end

def starterTeamVersion(fight, tr_type = nil, tr_name = nil)
    if tr_type && tr_name
        return StarterTeams.version_for(tr_type, tr_name, fight)
    end
    StarterTeams.validate_fight(fight)
    return fight * 10 + StarterTeams.slot
end

def starterBattle(tr_type, tr_name, fight = 1, endSpeech: nil, doubleBattle: false,
                  canLose: false, outcomeVar: 1)
    version = StarterTeams.version_for(tr_type, tr_name, fight)
    return pbTrainerBattle(tr_type, tr_name, endSpeech, doubleBattle, version, canLose, outcomeVar)
end

#===============================================================================
# Automatic recording.
#===============================================================================
unless defined?(starter_teams_pbAddPokemon)
    alias starter_teams_pbAddPokemon pbAddPokemon
    alias starter_teams_pbAddPokemonSilent pbAddPokemonSilent

    def pbAddPokemon(pkmn, level = 1)
        added = starter_teams_pbAddPokemon(pkmn, level)
        StarterTeams.auto_record(pkmn) if added
        return added
    end

    def pbAddPokemonSilent(pkmn, level = 1)
        added = starter_teams_pbAddPokemonSilent(pkmn, level)
        StarterTeams.auto_record(pkmn) if added
        return added
    end
end
