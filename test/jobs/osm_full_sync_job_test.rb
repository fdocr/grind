# frozen_string_literal: true

require "test_helper"

class OsmFullSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueues a sync job for every course with coordinates" do
    Course.create!(name: "No Coords Club", country: "US")
    expected = Course.where.not(latitude: nil).where.not(longitude: nil).count
    assert_operator expected, :>, 0

    assert_enqueued_jobs expected, only: OsmCourseSyncJob do
      OsmFullSyncJob.perform_now
    end
  end
end
