# frozen_string_literal: true

module Admin::CoursesHelper
  def osm_status_tone(course)
    case course.osm_status
    when "ok" then :success
    when "no_data" then :warning
    when "error" then :danger
    else :neutral
    end
  end
end
