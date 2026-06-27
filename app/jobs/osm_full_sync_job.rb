# frozen_string_literal: true

# Enqueues a per course OpenStreetMap sync for courses that have coordinates and
# have not been synced recently. Jobs are staggered so the Overpass API is
# queried politely (one request roughly every STAGGER). Because already synced
# courses are skipped, a full run is resumable: re run it and it picks up where
# it left off (including any that previously errored, which are left unstamped).
class OsmFullSyncJob < ApplicationJob
  queue_as :overpass

  STAGGER = 20.seconds
  RESYNC_AFTER = 30.days

  def perform(resync_after: RESYNC_AFTER)
    stale_courses(resync_after).find_each.with_index do |course, index|
      OsmCourseSyncJob.set(wait: index * STAGGER).perform_later(course.id)
    end
  end

  private

  def stale_courses(resync_after)
    scope = Course.where.not(latitude: nil).where.not(longitude: nil)
    return scope if resync_after.nil?

    scope.where("osm_synced_at IS NULL OR osm_synced_at < ?", resync_after.ago)
  end
end
