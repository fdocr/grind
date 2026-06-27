# frozen_string_literal: true

require "test_helper"

module Grind
  module Osm
    class CourseGeometryTest < ActiveSupport::TestCase
      setup do
        @course = courses(:one) # Cariari, lat 9.981234 lng -84.156789, 18 holes
      end

      test "associates greens to holes by ref and by hole line endpoint" do
        overpass = { "elements" => [
          boundary([
            [ 9.980, -84.158 ], [ 9.983, -84.158 ], [ 9.983, -84.155 ], [ 9.980, -84.155 ]
          ]),
          # Green for hole 1 has no ref; matched via the hole line endpoint inside it.
          green(nil, square(9.98150, -84.15650)),
          hole_way(1, [ [ 9.98050, -84.15700 ], [ 9.98150, -84.15650 ] ]),
          # Green for hole 2 carries its own ref.
          green(2, square(9.98180, -84.15600))
        ] }

        result = CourseGeometry.new(overpass, @course).build

        assert_equal [ 1, 2 ], result.keys.sort
        assert_equal 4, result[1]["polygon"].size
        assert_in_delta 9.98150, result[1]["centroid"][0], 0.0002
        assert_in_delta(-84.15650, result[1]["centroid"][1], 0.0002)
        assert_in_delta 9.98180, result[2]["centroid"][0], 0.0002
      end

      test "clips greens outside the course boundary" do
        overpass = { "elements" => [
          boundary([
            [ 9.980, -84.158 ], [ 9.983, -84.158 ], [ 9.983, -84.155 ], [ 9.980, -84.155 ]
          ]),
          green(1, square(9.98150, -84.15650)),
          # Far away green with a colliding ref must be ignored.
          green(2, square(9.99000, -84.15000))
        ] }

        result = CourseGeometry.new(overpass, @course).build

        assert_equal [ 1 ], result.keys
      end

      test "works without a boundary element" do
        overpass = { "elements" => [
          green(1, square(9.98150, -84.15650))
        ] }

        result = CourseGeometry.new(overpass, @course).build

        assert_equal [ 1 ], result.keys
        assert_equal 4, result[1]["polygon"].size
      end

      test "returns an empty hash when there are no greens" do
        overpass = { "elements" => [
          boundary([ [ 9.980, -84.158 ], [ 9.983, -84.158 ], [ 9.983, -84.155 ] ]),
          hole_way(1, [ [ 9.98050, -84.15700 ], [ 9.98150, -84.15650 ] ])
        ] }

        assert_empty CourseGeometry.new(overpass, @course).build
      end

      test "ignores ref values outside the hole range" do
        overpass = { "elements" => [
          green(0, square(9.98150, -84.15650)),
          green(99, square(9.98180, -84.15600))
        ] }

        assert_empty CourseGeometry.new(overpass, @course).build
      end

      private

      def boundary(coords)
        way("relation_boundary", { "leisure" => "golf_course" }, coords)
      end

      def green(ref, coords)
        tags = { "golf" => "green" }
        tags["ref"] = ref.to_s if ref
        way("green_#{ref || object_id}", tags, coords)
      end

      def hole_way(ref, coords)
        way("hole_#{ref}", { "golf" => "hole", "ref" => ref.to_s }, coords)
      end

      def way(id, tags, coords)
        {
          "type" => "way",
          "id" => id,
          "tags" => tags,
          "geometry" => coords.map { |lat, lng| { "lat" => lat, "lon" => lng } }
        }
      end

      # ~11m square ring centered on the point.
      def square(lat, lng)
        d = 0.00005
        [
          [ lat + d, lng + d ],
          [ lat + d, lng - d ],
          [ lat - d, lng - d ],
          [ lat - d, lng + d ]
        ]
      end
    end
  end
end
