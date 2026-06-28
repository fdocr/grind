# frozen_string_literal: true

module MapHelper
  def satellite_tile_url
    Grind::MapTiles.satellite_url
  end

  def satellite_tile_attribution
    Grind::MapTiles.satellite_attribution
  end
end
