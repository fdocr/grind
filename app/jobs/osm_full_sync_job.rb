# frozen_string_literal: true

# Enqueues a per course OpenStreetMap sync for every course that has
# coordinates. Jobs are staggered so the Overpass API is queried politely.
class OsmFullSyncJob < ApplicationJob
  queue_as :overpass

  STAGGER = 3.seconds

  def perform
    Course.where.not(latitude: nil).where.not(longitude: nil).find_each.with_index do |course, index|
      OsmCourseSyncJob.set(wait: index * STAGGER).perform_later(course.id)
    end
  end
end
