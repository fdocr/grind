# frozen_string_literal: true

class RoundsController < ApplicationController
  before_action :set_course, only: %i[new create]
  before_action :set_round, only: :show

  def new
    @holes = @course.holes.order(:number)
  end

  def create
    @round = @course.rounds.build(round_params)
    @round.finished_at = Time.current
    @round.started_at = parse_started_at

    if @round.save
      redirect_to round_path(@round.token)
    else
      @holes = @course.holes.order(:number)
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @holes = @round.course.holes.order(:number)
  end

  private

  def set_course
    @course = Course.find(params[:course_id] || params[:id])
  end

  def set_round
    @round = Round.find_by!(token: params[:token])
  end

  def round_params
    params.require(:round).permit(
      :oop_tee_shots,
      :three_putts,
      :botched_up_downs,
      :inside_pw_9i,
      :started_at,
      hole_scores: {}
    )
  end

  def parse_started_at
    Time.zone.parse(params.dig(:round, :started_at).to_s) || Time.current
  rescue ArgumentError
    Time.current
  end
end
