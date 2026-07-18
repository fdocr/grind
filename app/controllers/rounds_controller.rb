# frozen_string_literal: true

class RoundsController < ApplicationController
  ROUND_UNLOCK_TTL = 2.hours
  RATE_LIMIT_ALERT = "Rate limit reached: Try again in a minute and slow down a bit"

  before_action :set_course, only: %i[new create unlock resume]
  before_action :set_round, only: :show

  rate_limit to: 60, within: 60.seconds, only: :new, name: "rounds.new",
    with: -> { redirect_to root_path, alert: RATE_LIMIT_ALERT }

  rate_limit to: 60, within: 60.seconds, only: :distances, name: "rounds.distances",
    with: -> { redirect_to root_path, alert: RATE_LIMIT_ALERT }

  rate_limit to: 30, within: 60.seconds, only: :unlock, name: "rounds.unlock",
    with: -> { redirect_to root_path, alert: RATE_LIMIT_ALERT }

  rate_limit to: 30, within: 60.seconds, only: :resume, name: "rounds.resume",
    with: -> { redirect_to root_path, alert: RATE_LIMIT_ALERT }

  def new
    prevent_indexing
    unless round_unlocked?(@course)
      redirect_to root_path, alert: "Please start your round from the course page."
      return
    end

    @holes = @course.holes.order(:number)
    @tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
  end

  def unlock
    return unless verify_turnstile!(root_path)

    unlock_round!(@course)
    redirect_to_round!
  end

  # Homepage "Continue" for an in-progress round. Re-grants unlock without Turnstile
  # so resume still works when the short-lived session unlock is gone (common in
  # Hotwire Native after the app is backgrounded or relaunched).
  def resume
    unlock_round!(@course)
    redirect_to_round!
  end

  # Generic distances shell for the Hotwire Native modal. Hole/green data is
  # supplied by the round page through localStorage so opening the sheet does
  # not require a course-specific network fetch (Plan A offline approach).
  # localStorage is required because native modals use a separate WKWebView.
  def distances
    prevent_indexing
    @native_modal = true
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
    @course = Course.find_by_param!(params[:course_id] || params[:id])
  end

  def set_round
    @round = Round.find_by!(token: params[:token])
  end

  def round_params
    params.require(:round).permit(
      :oop_tee_shots,
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

  def unlock_round!(course)
    session[:round_unlocks] ||= {}
    session[:round_unlocks][course.id.to_s] = Time.current.to_i
  end

  def round_unlocked?(course)
    unlocked_at = session.dig(:round_unlocks, course.id.to_s)
    return false if unlocked_at.blank?

    Time.current.to_i - unlocked_at.to_i < ROUND_UNLOCK_TTL.to_i
  end

  def redirect_to_round!
    tee = @course.tee?(params[:tee]) ? params[:tee].to_s : @course.default_tee
    redirect_to round_course_path(@course, tee: tee)
  end
end
