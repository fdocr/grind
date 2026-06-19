# frozen_string_literal: true

class SendRoundStatsJob < ApplicationJob
  queue_as :default

  def perform(delivery_id)
    delivery = Delivery.find(delivery_id)
    RoundStatsMailer.stats(delivery).deliver_now
  end
end
