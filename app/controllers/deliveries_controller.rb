# frozen_string_literal: true

class DeliveriesController < ApplicationController
  before_action :set_round

  def create
    unless @round.finished?
      redirect_to round_path(@round.token), alert: "Finish your round before requesting stats by email."
      return
    end

    unless TurnstileVerifier.verify(params["cf-turnstile-response"], request.remote_ip)
      redirect_to round_path(@round.token), alert: "Captcha verification failed. Please try again."
      return
    end

    delivery = @round.deliveries.build(
      course: @round.course,
      email: delivery_params[:email],
      score_to_par: @round.score_to_par
    )

    if delivery.save
      SendRoundStatsJob.perform_later(delivery.id)
      redirect_to round_path(@round.token), notice: "Your round stats are on the way."
    else
      redirect_to round_path(@round.token), alert: delivery.errors.full_messages.to_sentence
    end
  end

  private

  def set_round
    @round = Round.find_by!(token: params[:round_token])
  end

  def delivery_params
    params.require(:delivery).permit(:email)
  end
end
