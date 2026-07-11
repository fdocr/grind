# frozen_string_literal: true

module Admin
  class CoursesController < BaseController
    before_action :set_course, only: %i[show edit update destroy sync_osm]

    def index
      @query = params[:q].to_s.strip
      scope = if @query.present?
        Course.search(@query).order(:name)
      else
        Course.order(:name)
      end
      @pagy, @courses = pagy(scope)
    end

    def show
      @holes = @course.holes.order(:number)
      @tee_names = @course.tee_names
      @active_tee = @course.default_tee
    end

    def new
      @course = Course.new(
        metric: false,
        tees: default_tees,
        name: params[:name],
        country: params[:country],
        city: params[:city],
        state_province: params[:state_province]
      )
      build_holes
    end

    def create
      @course = Course.new(course_attributes)
      if @course.save
        enqueue_osm_sync if @course.coordinates?
        redirect_to admin_course_path(@course), notice: "Course created."
      else
        build_holes
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      build_holes
      @course.tees = default_tees if @course.tees.blank?
    end

    def update
      if @course.update(course_attributes)
        enqueue_osm_sync if coordinates_changed?
        redirect_to admin_course_path(@course), notice: "Course updated."
      else
        build_holes
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      name = @course.name
      @course.destroy!
      redirect_to admin_courses_path, notice: "#{name} was deleted."
    end

    def sync_osm
      unless @course.coordinates?
        redirect_to admin_course_path(@course), alert: "Add latitude and longitude before syncing."
        return
      end

      OsmCourseSyncJob.perform_later(@course.id)
      redirect_to admin_course_path(@course), notice: "OpenStreetMap sync queued."
    end

    private

      def set_course
        @course = Course.find(params[:id])
      end

      def course_attributes
        attrs = params.require(:course).permit(
          :name, :country, :city, :state_province, :address, :zip, :phone, :website,
          :metric, :latitude, :longitude,
          holes_attributes: %i[id number par handicap]
        )
        attrs[:tees] = normalize_tees(params.dig(:course, :tees)) if params.dig(:course, :tees)
        attrs
      end

      def normalize_tees(raw)
        return default_tees if raw.blank?

        normalized = raw.to_unsafe_h.each_with_object({}) do |(key, tee), hash|
          tee = tee.to_h.with_indifferent_access
          name = tee[:name].to_s.strip.downcase.presence
          name ||= key.to_s.strip.downcase unless key.to_s.match?(/\A\d+\z/)
          next if name.blank?

          yardages = Array(tee[:yardages]).map { |yards| yards.to_i }.first(18)
          yardages.fill(0, yardages.length...18)

          hash[name] = {
            "rating" => tee[:rating].to_s,
            "slope" => tee[:slope].to_s,
            "yardages" => yardages
          }
        end

        normalized.presence || default_tees
      end

      def default_tees
        { "white" => { "rating" => "", "slope" => "", "yardages" => Array.new(18, 0) } }
      end

      def build_holes
        existing = @course.holes.index_by(&:number)
        (1..18).each do |number|
          next if existing[number]

          @course.holes.build(number: number, par: 4, handicap: number)
        end
      end

      def coordinates_changed?
        @course.saved_change_to_latitude? || @course.saved_change_to_longitude?
      end

      def enqueue_osm_sync
        OsmCourseSyncJob.perform_later(@course.id)
      end
  end
end
