# frozen_string_literal: true

module Admin
  class GreensController < BaseController
    before_action :set_course

    def edit
      unless @course.coordinates?
        redirect_to admin_course_path(@course), alert: "Add latitude and longitude before calibrating greens."
        return
      end

      @holes = @course.holes.order(:number)
      @map_center = map_center_for(@course)
      @holes_json = @holes.map { |hole| hole_payload(hole) }
      @tile_url = satellite_tile_url
      @tile_attribution = satellite_tile_attribution
    end

    def update
      calibration = parse_calibration
      errors = []

      Course.transaction do
        calibration.each do |hole_number, data|
          hole = @course.holes.find_by(number: hole_number)
          next unless hole

          if data["clear"]
            hole.update!(green_geometry: nil, green_source: nil, green_input: nil)
            next
          end

          polygon = data["polygon"]
          next if polygon.blank?

          input = Grind::Greens::Input.new(
            hole_number: hole_number,
            polygon: polygon,
            bbox: data["bbox"],
            zoom: data["zoom"],
            provider: data["provider"]
          )

          geometry = Grind::Greens::Extractor.for.call(input)
          hole.update!(
            green_geometry: geometry,
            green_source: "manual",
            green_input: data.slice("polygon", "bbox", "zoom", "provider")
          )
        rescue Grind::Greens::Extractor::Error => e
          errors << "Hole #{hole_number}: #{e.message}"
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      if errors.any?
        @holes = @course.holes.order(:number)
        @map_center = map_center_for(@course)
        @holes_json = @holes.map { |hole| hole_payload(hole) }
        @tile_url = satellite_tile_url
        @tile_attribution = satellite_tile_attribution
        flash.now[:alert] = errors.join("; ")
        render :edit, status: :unprocessable_entity
      else
        @course.update_columns(osm_status: @course.holes.reload.any?(&:green?) ? "ok" : @course.osm_status)
        redirect_to admin_course_path(@course), notice: "Green calibration saved."
      end
    end

    private

      def set_course
        @course = Course.find(params[:course_id])
      end

      def parse_calibration
        raw = params[:calibration].presence || "{}"
        JSON.parse(raw)
      rescue JSON::ParserError
        {}
      end

      def hole_payload(hole)
        {
          number: hole.number,
          polygon: hole.green_polygon.presence,
          centroid: hole.green_centroid.presence,
          mapped: hole.green?
        }
      end

      def map_center_for(course)
        green = course.holes.order(:number).find(&:green?)
        if green&.green_centroid
          green.green_centroid
        else
          [ course.latitude.to_f, course.longitude.to_f ]
        end
      end

      def satellite_tile_url
        ENV.fetch(
          "SATELLITE_TILE_URL",
          "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        )
      end

      def satellite_tile_attribution
        ENV.fetch("SATELLITE_TILE_ATTRIBUTION", "Tiles © Esri")
      end
  end
end
