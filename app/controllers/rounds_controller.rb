# frozen_string_literal: true

class RoundsController < ApplicationController
  before_action :set_course, only: %i[new create]
  before_action :set_round, only: :show

  def new
    prevent_indexing
    @holes = @course.holes.order(:number)
    @tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
  end

  def create
    @round = @course.rounds.build(round_params)
    @round.user = current_user
    @round.finished_at = Time.current
    @round.started_at = parse_started_at

    if @round.save
      deliver_recap_to_owner(@round)
      redirect_to round_path(@round.token)
    else
      @holes = @course.holes.order(:number)
      flash.now[:alert] = "We couldn't finish your round. Your scores are still saved on this device — please try again."
      render :new, status: :unprocessable_entity
    end
  rescue StandardError => e
    Honeybadger.notify(e) if defined?(Honeybadger)
    @holes = @course.holes.order(:number)
    flash.now[:alert] = "Something went wrong on our end. Your round is still saved on this device — please try finishing it again."
    render :new, status: :unprocessable_entity
  end

  def show
    prevent_indexing
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
      :tee,
      hole_scores: {}
    )
  end

  def parse_started_at
    Time.zone.parse(params.dig(:round, :started_at).to_s) || Time.current
  rescue ArgumentError
    Time.current
  end

  def deliver_recap_to_owner(round)
    return unless round.user

    delivery = round.deliveries.create!(
      course: round.course,
      user: round.user,
      email: round.user.email,
      score_to_par: round.score_to_par
    )
    SendRoundStatsJob.perform_later(delivery.id)
  end
end
