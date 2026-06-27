# frozen_string_literal: true

# Syncs one course's green geometry from OpenStreetMap via the Overpass API.
# Runs one at a time (limits_concurrency) to stay within Overpass fair use.
class OsmCourseSyncJob < ApplicationJob
  queue_as :overpass
  limits_concurrency key: "overpass", to: 1
  retry_on Grind::Osm::Overpass::Error, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(course_id)
    course = Course.find(course_id)
    return unless course.coordinates?

    overpass = Grind::Osm::Overpass.fetch(latitude: course.latitude, longitude: course.longitude)
    geometry = Grind::Osm::CourseGeometry.new(overpass, course).build
    apply(course, geometry)
  rescue Grind::Osm::Overpass::Error
    course.update_columns(osm_status: "error", osm_synced_at: Time.current)
    raise
  end

  private

  def apply(course, geometry)
    Course.transaction do
      course.holes.find_each do |hole|
        hole.update_column(:green_geometry, geometry[hole.number])
      end
      course.update_columns(
        osm_status: geometry.any? ? "ok" : "no_data",
        osm_synced_at: Time.current
      )
    end
  end
end
