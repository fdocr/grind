# frozen_string_literal: true

module Admin::CoursesHelper
  def osm_embed_url(course, zoom_delta: 0.012)
    return unless course.coordinates?

    lat = course.latitude.to_f
    lng = course.longitude.to_f
    bbox = [ lng - zoom_delta, lat - zoom_delta, lng + zoom_delta, lat + zoom_delta ].join(",")
    marker = ERB::Util.url_encode("#{lat},#{lng}")
    "https://www.openstreetmap.org/export/embed.html?bbox=#{bbox}&layer=mapnik&marker=#{marker}"
  end

  def osm_status_tone(course)
    case course.osm_status
    when "ok" then :success
    when "no_data" then :warning
    when "error" then :danger
    else :neutral
    end
  end
end
