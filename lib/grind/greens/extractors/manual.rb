# frozen_string_literal: true

module Grind
  module Greens
    module Extractors
      class Manual
        MAX_RING_POINTS = 120

        def call(input)
          ring = Geometry.normalize_ring(input.polygon)
          raise Extractor::Error, "Need at least 3 points to define a green" if ring.size < 3
          raise Extractor::Error, "Too many vertices (#{ring.size})" if ring.size > MAX_RING_POINTS

          centroid = Geometry.centroid(ring)
          raise Extractor::Error, "Could not compute centroid" unless centroid

          { "centroid" => centroid, "polygon" => ring }
        end
      end
    end
  end
end
