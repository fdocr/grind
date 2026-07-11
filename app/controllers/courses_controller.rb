# frozen_string_literal: true

class CoursesController < ApplicationController
  rate_limit to: 15, within: 60.seconds, only: :index,
    if: -> { locating_or_searching? && !hotwire_native_app? },
    with: -> {
      redirect_to root_path, alert: "Rate limit reached: Try again in a minute and slow down a bit"
    }

  def index
    @query = params[:q].to_s.strip
    @lat = parse_coordinate(params[:lat])
    @lng = parse_coordinate(params[:lng])
    @more_results = false

    if @query.present?
      matches = Course.search(@query)
      @more_results = matches.count > Course::RESULT_LIMIT
      @courses = matches.includes(:holes).order(:name).limit(Course::RESULT_LIMIT)
      @mode = :search
    elsif params[:lat].present? || params[:lng].present?
      @mode = :near
      @courses = if @lat && @lng
        Course.near(@lat, @lng).includes(:holes)
      else
        Course.none
      end
    elsif authenticated?
      @courses = Course.played_by(current_user).includes(:holes)
      @mode = :yours
    else
      @courses = Course.none
      @mode = :empty
    end
  end

  def show
    prevent_indexing
    @course = Course.find(params[:id])
    @holes = @course.holes.order(:number)
    @tee_names = @course.tee_names
    @active_tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
  end

  private

    def locating_or_searching?
      params[:q].present? || params[:lat].present? || params[:lng].present?
    end

    def parse_coordinate(value)
      return nil if value.blank?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end
end
