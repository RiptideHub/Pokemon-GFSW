#===============================================================================
# Tribes Switch - logic. The setting is in Settings.rb.
#
#===============================================================================
module TribesSwitch
    SUMMARY_ICON  = [8, 158, 36, 48]      
    SUMMARY_TEXT  = [48, 128, 176, 112]
    SUMMARY_PROBE = [120, 200]
    DEX_ICON      = [222, 168, 36, 48]    
    DEX_TEXT      = [260, 160, 240, 68]
    DEX_PROBE     = [400, 200]
    SHOWCASE_BAR_WIDTH  = 204   
    SHOWCASE_BAR_HEIGHT = 26

    CLEAR = Color.new(0, 0, 0, 0)

    module_function

    def enabled?
        return ENABLED
    end

    def hide_tribe_box(overlay, background, icon, text, probe)
        return unless overlay && !overlay.disposed?
        overlay.fill_rect(*text, CLEAR)
        bitmap = background && background.bitmap
        return unless bitmap && !bitmap.disposed?
        overlay.fill_rect(*icon, bitmap.get_pixel(*probe))
    end

    def tribe_reward_page
        original = Settings.method(:collection_reward_page_names).super_method
        names = original ? original.call : Settings.collection_reward_page_names
        return names.index(_INTL("Tribe")) || 3
    rescue StandardError
        return 3
    end

    #---------------------------------------------------------------------------
    # Gameplay: no tribe ever gives a bonus
    #---------------------------------------------------------------------------
    module TribalBonusHook
        def updateTribeCount
            return super if TribesSwitch.enabled?
            resetTribeCounts
        end

        def hasTribeBonus?(tribeID)
            return false unless TribesSwitch.enabled?
            return super
        end

        def getTribeBonusStats(battler)
            return TribalBonus.initStatBonusHash unless TribesSwitch.enabled?
            return super
        end

        def getActiveBonusesList(*args)
            return [] unless TribesSwitch.enabled?
            return super
        end

        def hasAnyTribalBonus?
            return false unless TribesSwitch.enabled?
            return super
        end

        def hasAnyTribeOverlap?
            return false unless TribesSwitch.enabled?
            return super
        end
    end

    #---------------------------------------------------------------------------
    # Menus
    #---------------------------------------------------------------------------
    module PauseMenuHook
        def initializeMenuButtons
            super
            @cardButtons.delete(:TRIBAL_BONUS) unless TribesSwitch.enabled?
        end
    end

    module DocumentationMenuHook
        def pbShowCommands(commands)
            index = commands.index(_INTL("Tribes"))
            return super if TribesSwitch.enabled? || index.nil?
            ret = super(commands.reject.with_index { |_, i| i == index })
            ret += 1 if ret >= index
            return ret
        end
    end

    module SummaryHook
        def drawPageThree
            super
            return if TribesSwitch.enabled?
            TribesSwitch.hide_tribe_box(@sprites["overlay"].bitmap, @sprites["background"],
                                        SUMMARY_ICON, SUMMARY_TEXT, SUMMARY_PROBE)
        end
    end

    module DexInfoHook
        def drawPageInfo
            super
            return if TribesSwitch.enabled?
            TribesSwitch.hide_tribe_box(@sprites["overlay"].bitmap, @sprites["background"],
                                        DEX_ICON, DEX_TEXT, DEX_PROBE)
        end
    end

    module DexSearchHook
        def pbDrawTextPositions(bitmap, textpos)
            unless TribesSwitch.enabled?
                label = _INTL("Tribe")
                textpos = textpos.reject { |entry| entry[0] == label }
            end
            return super(bitmap, textpos)
        end

        def searchByTribe
            return super if TribesSwitch.enabled?
            pbPlayBuzzerSE
            return nil
        end
    end

    module StorageHook
        def pbChooseSearch(msg)
            return super if TribesSwitch.enabled?
            searchMethods = [_INTL("Cancel"), _INTL("Name"), _INTL("Species"), _INTL("Type")]
            return pbShowCommands(msg, searchMethods)
        end
    end

    module ShowcaseHook
        def drawPartyShowcase
            super
            return if TribesSwitch.enabled?
            return unless @overlay && !@overlay.disposed?
            @overlay.fill_rect(0, Graphics.height - SHOWCASE_BAR_HEIGHT, SHOWCASE_BAR_WIDTH, SHOWCASE_BAR_HEIGHT, CLEAR)
        end
    end

    #---------------------------------------------------------------------------
    # Collection Rewards: no "Tribe" page, later pages move down by one
    #---------------------------------------------------------------------------
    module RewardPageNamesHook
        def collection_reward_page_names
            names = super
            return names if TribesSwitch.enabled?
            return names.reject { |name| name == _INTL("Tribe") }
        end
    end

    module AwardsHook
        def getAwardsCompletionState
            list = super
            return list if TribesSwitch.enabled?
            tribePage = TribesSwitch.tribe_reward_page
            return list.map { |info| info[:page] > tribePage ? info.merge(:page => info[:page] - 1) : info }
        end
    end
end

TribalBonus.prepend(TribesSwitch::TribalBonusHook)
TilingCardsPauseMenu_Scene.prepend(TribesSwitch::PauseMenuHook)
PokemonDocumentationMenu_Scene.prepend(TribesSwitch::DocumentationMenuHook)
PokemonSummary_Scene.prepend(TribesSwitch::SummaryHook)
PokemonPokedexInfo_Scene.prepend(TribesSwitch::DexInfoHook)
PokemonPokedex_Scene.prepend(TribesSwitch::DexSearchHook)
PokemonStorageScene.prepend(TribesSwitch::StorageHook)
PokemonPartyShowcase_Scene.prepend(TribesSwitch::ShowcaseHook)
PokEstate.prepend(TribesSwitch::AwardsHook)
Settings.singleton_class.prepend(TribesSwitch::RewardPageNamesHook)

unless defined?(tribes_switch_battleGuideMainDirectory)
    alias tribes_switch_battleGuideMainDirectory battleGuideMainDirectory

    def battleGuideMainDirectory
        directory = tribes_switch_battleGuideMainDirectory
        directory.delete(_INTL("Tribes")) unless TribesSwitch.enabled?
        return directory
    end
end

unless defined?(tribes_switch_tribeReward)
    alias tribes_switch_tribeReward tribeReward

    def tribeReward(*args)
        return nil unless TribesSwitch.enabled?
        return tribes_switch_tribeReward(*args)
    end
end
