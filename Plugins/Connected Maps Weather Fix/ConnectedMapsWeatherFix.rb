#===============================================================================
# Connected Maps Weather Fix
# only the spriteset of the map the player is on runs the weather.
# Neighbouring spritesets draw their tiles and events as usual but leave the
# weather and fog alone. When the player walks into a connected map, the weather layer
# is handed over to that map's spriteset, so rain, snow, etc. carry on without
# restarting, the cloud shadows keep their exact place on screen, and if the
# new map's weather wants thicker or thinner clouds they ease into it instead
# of switching in one frame.
#
#===============================================================================
module ConnectedMapsWeatherFix
  # The spriteset that currently owns the visible weather layer.
  @owner = nil
  # True while a neighbouring map's spriteset is updating.
  @neighbour_update = false

  class << self
    attr_accessor :owner, :neighbour_update
  end

  # Give the weather layer (with its particles, strength and fade state) to the
  # spriteset of the map the player has just walked into.
  def self.hand_over_weather(new_owner)
    old = @owner
    @owner = new_owner
    return if old.nil? || old.equal?(new_owner)
    old_weather = old.instance_variable_get(:@weather)
    new_weather = new_owner.instance_variable_get(:@weather)
    return if old_weather.nil? || new_weather.nil?   # old spriteset already disposed
    old.instance_variable_set(:@weather, new_weather)
    new_owner.instance_variable_set(:@weather, old_weather)
    # Map display coordinates restart on the new map: don't scroll the weather
    # tiles by the jump between the two coordinate systems.
    old_weather.instance_variable_set(:@lastDisplayX, 0)
    old_weather.instance_variable_set(:@lastDisplayY, 0)
    carry_fog_over(old.map, new_owner.map)
  end


  EASE_FRAMES = 120
  # Max change of the cloud opacity per frame while easing (0-255 scale).
  EASE_STEP = 1
  @ease_frames = 0
  class << self
    attr_accessor :ease_frames
  end


  def self.display_offset(map_a, map_b)
    conns = MapFactoryHelper.getMapConnections[map_b.map_id] rescue nil
    (conns || []).each do |c|
      if c[0] == map_b.map_id && c[3] == map_a.map_id
        dx = (c[4] - c[1]) * Game_Map::REAL_RES_X; dy = (c[5] - c[2]) * Game_Map::REAL_RES_Y
      elsif c[3] == map_b.map_id && c[0] == map_a.map_id
        dx = (c[1] - c[4]) * Game_Map::REAL_RES_X; dy = (c[2] - c[5]) * Game_Map::REAL_RES_Y
      else
        next
      end
      return [dx / Game_Map::X_SUBPIXELS, dy / Game_Map::Y_SUBPIXELS]
    end
    return nil
  end


  def self.carry_fog_over(old_map, new_map)
    return if old_map.nil? || new_map.nil? || old_map.equal?(new_map)
    off = display_offset(old_map, new_map)
    return unless off   # not a connection (a normal transfer): nothing to carry over
    new_map.fog_name       = old_map.fog_name
    new_map.fog_hue        = old_map.fog_hue
    new_map.fog_opacity    = old_map.fog_opacity
    new_map.fog_blend_type = old_map.fog_blend_type
    new_map.fog_zoom       = old_map.fog_zoom
    new_map.fog_sx         = old_map.fog_sx
    new_map.fog_sy         = old_map.fog_sy
    new_map.instance_variable_set(:@fog_ox, old_map.fog_ox + off[0])
    new_map.instance_variable_set(:@fog_oy, old_map.fog_oy + off[1])
    @ease_frames = EASE_FRAMES
  rescue Exception => e
    echoln("[Connected Maps Weather Fix] fog carry-over failed: #{e.class} #{e.message}") rescue nil
  end

  module SpritesetPatch
    def update
      neighbour = begin
        !self.map.equal?($game_map) && self.map.map_id != $game_map.map_id
      rescue
        false
      end
      unless neighbour
        ConnectedMapsWeatherFix.hand_over_weather(self)
        ConnectedMapsWeatherFix.ease_frames -= 1 if ConnectedMapsWeatherFix.ease_frames > 0
      end
      ConnectedMapsWeatherFix.neighbour_update = neighbour
      super

      fog = @fog
      fog.visible = !neighbour if fog && fog.respond_to?(:visible=)
    ensure
      ConnectedMapsWeatherFix.neighbour_update = false
    end

    def dispose
      ConnectedMapsWeatherFix.owner = nil if ConnectedMapsWeatherFix.owner.equal?(self)
      super
    end

    def echoln(*args)
      return if ConnectedMapsWeatherFix.neighbour_update && args[0].to_s.start_with?("Resetting weather from the spriteset")
      super
    end
  end

  module ScreenPatch
    # A neighbouring map must not clear the current map's weather...
    def resetWeather
      return if ConnectedMapsWeatherFix.neighbour_update
      super
    end

    def updateWeather(weather)
      return if ConnectedMapsWeatherFix.neighbour_update
      super
    end
  end

  module FogEase
    private

    def applyFog(name, hue = 0, opacity = 100, velX = 0, velY = 0, blend_type = 0, zoom = 100)
      if ConnectedMapsWeatherFix.ease_frames > 0 && $game_map && name == $game_map.fog_name
        cur = $game_map.fog_opacity
        step = ConnectedMapsWeatherFix::EASE_STEP
        opacity = cur + [[opacity - cur, step].min, -step].max
        # Opacity still far off when the window ends: keep easing.
        ConnectedMapsWeatherFix.ease_frames = 2 if ConnectedMapsWeatherFix.ease_frames == 1 && (opacity - cur).abs >= step
      end
      super(name, hue, opacity, velX, velY, blend_type, zoom)
    end
  end

  PATCHES = [[:Spriteset_Map, SpritesetPatch], [:Game_Screen, ScreenPatch]]

  def self.install
    PATCHES.each do |cname, mod|
      next unless Object.const_defined?(cname)
      klass = Object.const_get(cname)
      klass.prepend(mod) unless klass.ancestors.include?(mod)
    end

    has_fog = Object.private_method_defined?(:applyFog) || Object.method_defined?(:applyFog)
    Object.prepend(FogEase) if has_fog && !Object.ancestors.include?(FogEase)
  rescue Exception => e
    echoln("[Connected Maps Weather Fix] patch failed: #{e.class} #{e.message}") rescue nil
  end
end

ConnectedMapsWeatherFix.install
if defined?(Events)
  Events.onMapChanging += proc { |_sender, _e| ConnectedMapsWeatherFix.install }
  Events.onMapChange   += proc { |_sender, _e| ConnectedMapsWeatherFix.install }
end
