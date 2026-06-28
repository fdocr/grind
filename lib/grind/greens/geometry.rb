# frozen_string_literal: true

module Grind
  module Greens
    # Shared polygon math for green geometry. Used by manual extraction, OSM
    # parsing, and future CV/SAM/LLM backends.
    module Geometry
      module_function

      # Remove consecutive duplicate vertices and drop a closing duplicate.
      def normalize_ring(points)
        ring = Array(points).filter_map do |point|
          next unless point.is_a?(Array) && point.size >= 2

          [ point[0].to_f, point[1].to_f ]
        end
        ring = ring.each_with_object([]) do |vertex, cleaned|
          cleaned << vertex unless cleaned.last == vertex
        end
        ring.pop if ring.size > 1 && ring.first == ring.last
        ring
      end

      # Area weighted polygon centroid in a local frame. point and ring are [lat, lng].
      def centroid(ring)
        points = normalize_ring(ring).map { |lat, lng| [ lng.to_f, lat.to_f ] }
        return nil if points.size < 3

        origin_x, origin_y = points.first
        local = points.map { |x, y| [ x - origin_x, y - origin_y ] }

        area = 0.0
        cx = 0.0
        cy = 0.0
        local.each_with_index do |(x0, y0), index|
          x1, y1 = local[(index + 1) % local.size]
          cross = (x0 * y1) - (x1 * y0)
          area += cross
          cx += (x0 + x1) * cross
          cy += (y0 + y1) * cross
        end
        area /= 2.0

        if area.abs < 1e-15
          avg_x = local.sum { |x, _y| x } / local.size
          avg_y = local.sum { |_x, y| y } / local.size
          return [ origin_y + avg_y, origin_x + avg_x ]
        end

        [ origin_y + (cy / (6.0 * area)), origin_x + (cx / (6.0 * area)) ]
      end

      def valid_ring?(ring)
        normalize_ring(ring).size >= 3
      end
    end
  end
end
