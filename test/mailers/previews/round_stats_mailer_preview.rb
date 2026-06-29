# frozen_string_literal: true

class RoundStatsMailerPreview < ActionMailer::Preview
  def stats
    delivery = Delivery.includes(round: { course: :holes }).last
    delivery ||= Delivery.new(
      email: "player@example.com",
      score_to_par: 3,
      round: Round.first,
      course: Course.first
    )
    RoundStatsMailer.stats(delivery)
  end
end
