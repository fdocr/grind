# frozen_string_literal: true

# Syncs one course's green geometry from OpenStreetMap via the Overpass API.
# Runs one at a time (limits_concurrency) and checks the Overpass rate limit
# before querying, to stay within fair use:
# https://dev.overpass-api.de/overpass-doc/en/preface/commons.html
class OsmCourseSyncJob < ApplicationJob
  queue_as :overpass
  limits_concurrency key: "overpass", to: 1
  discard_on ActiveRecord::RecordNotFound
  retry_on Grind::Osm::Overpass::Error, wait: :polynomially_longer, attempts: 5
  retry_on Grind::Osm::Overpass::RateLimitedError, wait: 1.minute, attempts: 10 do |job, _error|
    OsmCourseSyncJob.mark_overpass_error(job.arguments.first)
  end

  # Extra seconds added when rescheduling past a busy Overpass slot.
  SLOT_BUFFER = 2

  def self.mark_overpass_error(course_id)
    Course.find_by(id: course_id)&.update_column(:osm_status, "error")
  end

  def perform(course_id)
    course = Course.find(course_id)
    return unless course.coordinates?
    return if reschedule_until_slot_free(course_id)

    overpass = Grind::Osm::Overpass.fetch(latitude: course.latitude, longitude: course.longitude)
    geometry = Grind::Osm::CourseGeometry.new(overpass, course).build
    apply(course, geometry)
  rescue Grind::Osm::Overpass::RateLimitedError
    raise
  rescue Grind::Osm::Overpass::Error
    self.class.mark_overpass_error(course_id)
    raise
  end

  private

  # Returns true when the job rescheduled itself because no Overpass slot was
  # free, so the caller stops without querying. Non blocking: the worker is
  # released immediately instead of sleeping.
  def reschedule_until_slot_free(course_id)
    status = Grind::Osm::Overpass.status
    return false if status.nil? || status.slot_available?

    wait = status.wait_seconds + SLOT_BUFFER
    self.class.set(wait: wait.seconds).perform_later(course_id)
    true
  end

  def apply(course, geometry)
    Course.transaction do
      course.holes.find_each do |hole|
        next if hole.green_source == "manual"

        data = geometry[hole.number]
        hole.update_columns(
          green_geometry: data,
          green_source: data ? "osm" : nil
        )
      end
      course.update_columns(
        osm_status: course.holes.any?(&:green?) ? "ok" : "no_data",
        osm_synced_at: Time.current
      )
    end
  end
end
