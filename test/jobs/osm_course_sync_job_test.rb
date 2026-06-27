# frozen_string_literal: true

require "test_helper"

class OsmCourseSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @course = courses(:one)
  end

  test "stores green geometry and marks the course ok" do
    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, overpass_with_green) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    @course.reload
    assert_equal "ok", @course.osm_status
    assert @course.osm_synced_at.present?

    hole = holes(:cariari_01).reload
    assert hole.green?
    assert_equal 4, hole.green_polygon.size
  end

  test "clears stale geometry and marks no_data when nothing is found" do
    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, { "elements" => [] }) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    @course.reload
    assert_equal "no_data", @course.osm_status
    assert_nil holes(:cariari_01).reload.green_geometry
  end

  test "marks the course as errored without stamping synced_at when Overpass fails" do
    failing = ->(**) { raise Grind::Osm::Overpass::Error, "boom" }

    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, failing) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    @course.reload
    assert_equal "error", @course.osm_status
    assert_nil @course.osm_synced_at
  end

  test "reschedules itself without querying when no Overpass slot is free" do
    busy = Grind::Osm::Overpass::Status.new(slots_available: 0, wait_seconds: 12)

    assert_enqueued_with(job: OsmCourseSyncJob, args: [ @course.id ]) do
      stub_method(Grind::Osm::Overpass, :status, busy) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    assert_nil @course.reload.osm_status
  end

  test "does nothing when the course has no coordinates" do
    course = Course.create!(name: "No Coords Club", country: "US")
    build_eighteen_holes!(course)

    called = false
    stub_method(Grind::Osm::Overpass, :fetch, ->(**) { called = true }) do
      OsmCourseSyncJob.perform_now(course.id)
    end

    assert_not called
    assert_nil course.reload.osm_status
  end

  test "discards the job when the course no longer exists" do
    assert_nothing_raised do
      OsmCourseSyncJob.perform_now(-1)
    end
  end

  private

  def with_slot(&block)
    free = Grind::Osm::Overpass::Status.new(slots_available: 2, wait_seconds: 0)
    stub_method(Grind::Osm::Overpass, :status, free, &block)
  end

  def overpass_with_green
    { "elements" => [
      way("boundary", { "leisure" => "golf_course" }, [
        [ 9.980, -84.158 ], [ 9.983, -84.158 ], [ 9.983, -84.155 ], [ 9.980, -84.155 ]
      ]),
      way("green1", { "golf" => "green", "ref" => "1" }, [
        [ 9.98155, -84.15655 ], [ 9.98155, -84.15645 ], [ 9.98145, -84.15645 ], [ 9.98145, -84.15655 ]
      ])
    ] }
  end

  def way(id, tags, coords)
    {
      "type" => "way",
      "id" => id,
      "tags" => tags,
      "geometry" => coords.map { |lat, lng| { "lat" => lat, "lon" => lng } }
    }
  end
end
