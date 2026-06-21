# frozen_string_literal: true

class CoursesController < ApplicationController
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
    @course = Course.find(params[:id])
    @holes = @course.holes.order(:number)
    @tee_names = @course.tee_names
    @active_tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
  end
end
