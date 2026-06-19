# frozen_string_literal: true

class Delivery < ApplicationRecord
  belongs_to :round
  belongs_to :course

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :score_to_par, presence: true
end
