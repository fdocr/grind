# frozen_string_literal: true

class CoursesController < ApplicationController
  rate_limit to: 15, within: 60.seconds, only: :index, if: -> { params[:q].present? }, with: -> {
    redirect_to root_path, alert: "Rate limit reached: Try again in a minute and slow down a bit"
  }

  def index
    @query = params[:q].to_s.strip

    if @query.present?
      matches = Course.search(@query)
      @more_results = matches.count > Course::RESULT_LIMIT
      @courses = matches.order(:name).limit(Course::RESULT_LIMIT)
      @featured = false
    else
      @courses = Course.featured
      @more_results = false
      @featured = true
    end
  end

  def show
    prevent_indexing
    @course = Course.find(params[:id])
    @holes = @course.holes.order(:number)
    @tee_names = @course.tee_names
    @active_tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
  end
end
