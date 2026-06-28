# frozen_string_literal: true

module Grind
  module Osm
    # Pure transformation of an Overpass response into per hole green geometry.
    # No network and no database writes, so it can be unit tested with fixtures.
    #
    # Input:  the parsed Overpass JSON Hash (elements with `out geom`) and a Course.
    # Output: { hole_number => { "centroid" => [lat, lng], "polygon" => [[lat, lng], ...] } }
    class CourseGeometry
      EARTH_RADIUS_M = 6_371_000.0
      # Max distance from a hole line endpoint to a green centroid to still
      # consider them the same hole when the endpoint is not inside the green.
      NEAREST_GREEN_LIMIT_M = 60.0

      def initialize(overpass, course)
        @elements = Array(overpass.is_a?(Hash) ? overpass["elements"] : overpass)
        @course = course
      end

      def build
        greens = parse_greens
        boundary = course_boundary
        greens = greens.select { |green| point_in_ring?(green[:centroid], boundary) } if boundary
        return {} if greens.empty?

        holes = parse_hole_ways
        holes = holes.select { |hole| hole[:points].any? { |point| point_in_ring?(point, boundary) } } if boundary

        associate(greens, holes)
      end

      private

      def associate(greens, holes)
        result = {}
        used = []

        greens.each do |green|
          number = green[:ref]
          next unless in_range?(number)
          next if result.key?(number)

          result[number] = geometry_for(green)
          used << green
        end

        holes.each do |hole|
          number = hole[:ref]
          next unless in_range?(number)
          next if result.key?(number)

          green = best_green_for(hole, greens - used)
          next unless green

          result[number] = geometry_for(green)
          used << green
        end

        result
      end

      def geometry_for(green)
        { "centroid" => green[:centroid], "polygon" => green[:ring] }
      end

      # Prefer a green that contains one of the hole line endpoints; otherwise the
      # nearest green centroid within NEAREST_GREEN_LIMIT_M.
      def best_green_for(hole, candidates)
        return nil if candidates.empty?

        endpoints = [ hole[:points].first, hole[:points].last ].compact
        contained = candidates.find do |green|
          endpoints.any? { |point| point_in_ring?(point, green[:ring]) }
        end
        return contained if contained

        nearest = candidates.min_by do |green|
          endpoints.map { |point| distance_m(point, green[:centroid]) }.min
        end
        return nil unless nearest

        closest = endpoints.map { |point| distance_m(point, nearest[:centroid]) }.min
        closest <= NEAREST_GREEN_LIMIT_M ? nearest : nil
      end

      def parse_greens
        @elements.filter_map do |element|
          next unless element.dig("tags", "golf") == "green"

          ring = ring_for(element)
          next if ring.size < 3

          { ring: ring, centroid: centroid(ring), ref: ref_for(element) }
        end
      end

      def parse_hole_ways
        @elements.filter_map do |element|
          next unless element["type"] == "way"
          next unless element.dig("tags", "golf") == "hole"

          points = ring_from_geometry(element["geometry"])
          next if points.size < 2

          { ref: ref_for(element), points: points }
        end
      end

      def course_boundary
        boundaries = @elements.filter_map do |element|
          next unless element.dig("tags", "leisure") == "golf_course"

          ring = ring_for(element)
          ring.size >= 3 ? ring : nil
        end
        return nil if boundaries.empty?

        point = [ @course.latitude.to_f, @course.longitude.to_f ]
        boundaries.find { |ring| point_in_ring?(point, ring) } ||
          boundaries.max_by { |ring| ring.size }
      end

      def ring_for(element)
        if element["type"] == "relation"
          outer = Array(element["members"]).select { |member| member["type"] == "way" }
          outer = outer.select { |member| member["role"] == "outer" }.presence || outer
          rings = outer.map { |member| ring_from_geometry(member["geometry"]) }
          rings.max_by(&:size) || []
        else
          ring_from_geometry(element["geometry"])
        end
      end

      def ring_from_geometry(geometry)
        Array(geometry).filter_map do |point|
          lat = point["lat"]
          lng = point["lon"]
          [ lat, lng ] if lat && lng
        end
      end

      def ref_for(element)
        tags = element["tags"] || {}
        raw = tags["ref"] || tags["golf:hole"] || tags["hole"]
        Integer(raw.to_s, exception: false)
      end

      def in_range?(number)
        number.is_a?(Integer) && number >= 1 && number <= max_hole_number
      end

      def max_hole_number
        max = @course.respond_to?(:last_hole_number) ? @course.last_hole_number.to_i : 0
        max.positive? ? max : 18
      end

      def centroid(ring)
        Grind::Greens::Geometry.centroid(ring)
      end

      # Ray casting point in polygon. point and ring are [lat, lng].
      def point_in_ring?(point, ring)
        return false if ring.nil? || ring.size < 3

        y = point[0].to_f
        x = point[1].to_f
        inside = false
        size = ring.size
        j = size - 1
        (0...size).each do |i|
          yi = ring[i][0].to_f
          xi = ring[i][1].to_f
          yj = ring[j][0].to_f
          xj = ring[j][1].to_f
          if (yi > y) != (yj > y)
            intersect_x = ((xj - xi) * (y - yi) / (yj - yi)) + xi
            inside = !inside if x < intersect_x
          end
          j = i
        end
        inside
      end

      def distance_m(a, b)
        return Float::INFINITY if a.nil? || b.nil?

        lat1 = a[0].to_f * Math::PI / 180
        lat2 = b[0].to_f * Math::PI / 180
        d_lat = lat2 - lat1
        d_lng = (b[1].to_f - a[1].to_f) * Math::PI / 180
        h = (Math.sin(d_lat / 2)**2) + (Math.cos(lat1) * Math.cos(lat2) * (Math.sin(d_lng / 2)**2))
        2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h))
      end
    end
  end
end
