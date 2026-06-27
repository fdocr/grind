# frozen_string_literal: true

require "test_helper"

module Grind
  module Osm
    class OverpassTest < ActiveSupport::TestCase
      test "parses available slots from a status body" do
        body = <<~STATUS
          Connected as: 1807441248
          Current time: 2026-06-26T12:00:00Z
          Rate limit: 2
          2 slots available now.
        STATUS

        status = Overpass.parse_status(body)

        assert_equal 2, status.slots_available
        assert_equal 0, status.wait_seconds
        assert status.slot_available?
      end

      test "parses the minimum wait when no slots are available" do
        body = <<~STATUS
          Connected as: 1807441248
          Rate limit: 2
          0 slots available now.
          Slot available after: 2026-06-26T12:00:14Z, in 14 seconds.
          Slot available after: 2026-06-26T12:00:06Z, in 6 seconds.
        STATUS

        status = Overpass.parse_status(body)

        assert_equal 0, status.slots_available
        assert_equal 6, status.wait_seconds
        assert_not status.slot_available?
      end

      test "derives the status endpoint from the interpreter endpoint" do
        assert_equal "https://overpass-api.de/api/status", Overpass.status_endpoint
      end

      test "honors OVERPASS_API_URL for the status endpoint" do
        original = ENV["OVERPASS_API_URL"]
        ENV["OVERPASS_API_URL"] = "https://osm.example.com/api/interpreter"

        assert_equal "https://osm.example.com/api/status", Overpass.status_endpoint
      ensure
        ENV["OVERPASS_API_URL"] = original
      end

      test "builds a query that excludes pins" do
        query = Overpass.new(latitude: 1.0, longitude: 2.0).query

        assert_includes query, "\"golf\"=\"green\""
        assert_includes query, "\"golf\"=\"hole\""
        assert_not_includes query, "pin"
      end
    end
  end
end
