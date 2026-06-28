# frozen_string_literal: true

module Grind
  module MapTiles
    module_function

    def satellite_url
      ENV.fetch(
        "SATELLITE_TILE_URL",
        "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      )
    end

    def satellite_attribution
      ENV.fetch("SATELLITE_TILE_ATTRIBUTION", "Tiles © Esri")
    end
  end
end
