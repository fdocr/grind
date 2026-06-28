# frozen_string_literal: true

require "test_helper"

class Grind::Greens::GeometryTest < ActiveSupport::TestCase
  test "normalize_ring removes consecutive duplicates and closing vertex" do
    ring = Grind::Greens::Geometry.normalize_ring([
      [ 1.0, 2.0 ], [ 1.0, 2.0 ], [ 1.1, 2.1 ], [ 1.2, 2.2 ], [ 1.0, 2.0 ]
    ])

    assert_equal 3, ring.size
    assert_equal [ 1.0, 2.0 ], ring.first
  end

  test "centroid returns lat lng for a square" do
    ring = [
      [ 0.0, 0.0 ], [ 0.0, 1.0 ], [ 1.0, 1.0 ], [ 1.0, 0.0 ]
    ]
    centroid = Grind::Greens::Geometry.centroid(ring)

    assert_in_delta 0.5, centroid[0], 0.01
    assert_in_delta 0.5, centroid[1], 0.01
  end
end
