# frozen_string_literal: true

require "test_helper"

class OsmFullSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueues a sync job for every unsynced course with coordinates" do
    Course.create!(name: "No Coords Club", country: "US")
    expected = Course.where.not(latitude: nil).where.not(longitude: nil).count
    assert_operator expected, :>, 0

    assert_enqueued_jobs expected, only: OsmCourseSyncJob do
      OsmFullSyncJob.perform_now
    end
  end

  test "skips courses synced within the resync window" do
    courses(:one).update_columns(osm_synced_at: 1.day.ago)
    courses(:two).update_columns(osm_synced_at: 90.days.ago)

    assert_enqueued_with(job: OsmCourseSyncJob, args: [ courses(:two).id ]) do
      assert_enqueued_jobs 1, only: OsmCourseSyncJob do
        OsmFullSyncJob.perform_now
      end
    end
  end

  test "enqueues every course when resync_after is nil" do
    courses(:one).update_columns(osm_synced_at: 1.minute.ago)
    expected = Course.where.not(latitude: nil).where.not(longitude: nil).count

    assert_enqueued_jobs expected, only: OsmCourseSyncJob do
      OsmFullSyncJob.perform_now(resync_after: nil)
    end
  end
end
