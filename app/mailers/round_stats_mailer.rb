# frozen_string_literal: true

class RoundStatsMailer < ApplicationMailer
  def stats(delivery)
    @delivery = delivery
    @round = delivery.round
    @course = delivery.course
    @holes = @course.holes.order(:number)
    @show_register_cta = delivery.user_id.nil?

    mail(
      to: delivery.email,
      subject: "Your round at #{@course.name}"
    )
  end
end
