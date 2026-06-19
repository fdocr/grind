# frozen_string_literal: true

class CoursesController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @courses = Course.search(@query).order(:name).limit(50)
  end
end
