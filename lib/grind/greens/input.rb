# frozen_string_literal: true

module Grind
  module Greens
    # Raw input for a single hole's green extraction. Only polygon is required for
    # manual tracing; bbox/zoom/provider/image/points support future backends.
    Input = Data.define(:hole_number, :polygon, :bbox, :zoom, :provider, :image, :points) do
      def initialize(hole_number:, polygon: nil, bbox: nil, zoom: nil, provider: nil, image: nil, points: nil)
        super
      end
    end
  end
end
