# frozen_string_literal: true

require "test_helper"

class Grind::Greens::Extractors::ManualTest < ActiveSupport::TestCase
  setup do
    @extractor = Grind::Greens::Extractors::Manual.new
  end

  test "returns geometry with centroid and polygon" do
    polygon = [
      [ 9.98155, -84.15655 ], [ 9.98155, -84.15645 ], [ 9.98145, -84.15645 ], [ 9.98145, -84.15655 ]
    ]
    input = Grind::Greens::Input.new(hole_number: 1, polygon: polygon)
    result = @extractor.call(input)

    assert_equal 4, result["polygon"].size
    assert result["centroid"].is_a?(Array)
    assert_equal 2, result["centroid"].size
  end

  test "raises when polygon has fewer than three points" do
    input = Grind::Greens::Input.new(hole_number: 1, polygon: [ [ 1, 2 ], [ 3, 4 ] ])

    assert_raises(Grind::Greens::Extractor::Error) do
      @extractor.call(input)
    end
  end
end
