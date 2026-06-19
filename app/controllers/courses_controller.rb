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
end
