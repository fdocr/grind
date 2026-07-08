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


  test "does not overwrite manual green geometry" do
    manual_polygon = [ [ 9.99, -84.15 ], [ 9.99, -84.14 ], [ 9.98, -84.14 ] ]
    holes(:cariari_01).update!(
      green_geometry: { "centroid" => [ 9.985, -84.145 ], "polygon" => manual_polygon },
      green_source: "manual"
    )

    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, overpass_with_green) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    hole = holes(:cariari_01).reload
    assert hole.green_manual?
    assert_equal manual_polygon, hole.green_polygon
  end

  test "stamps osm as green source when syncing" do
    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, overpass_with_green) do
        OsmCourseSyncJob.perform_now(@course.id)
      end
    end

    assert_equal "osm", holes(:cariari_01).reload.green_source
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

  test "does not mark the course as errored when Overpass is rate limited" do
    rate_limited = ->(**) { raise Grind::Osm::Overpass::RateLimitedError, "429" }

    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, rate_limited) do
        assert_enqueued_with(job: OsmCourseSyncJob, args: [ @course.id ]) do
          OsmCourseSyncJob.perform_now(@course.id)
        end
      end
    end

    assert_nil @course.reload.osm_status
    assert_nil @course.osm_synced_at
  end

  test "marks the course as errored when rate limit retries are exhausted" do
    rate_limited = ->(**) { raise Grind::Osm::Overpass::RateLimitedError, "429" }
    job = OsmCourseSyncJob.new(@course.id)
    job.exception_executions = { "[Grind::Osm::Overpass::RateLimitedError]" => 9 }

    with_slot do
      stub_method(Grind::Osm::Overpass, :fetch, rate_limited) do
        job.perform_now
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
