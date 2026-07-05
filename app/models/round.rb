# frozen_string_literal: true

class Round < ApplicationRecord
  has_secure_token

  belongs_to :course
  belongs_to :user, optional: true
  has_many :deliveries, dependent: :destroy

  validates :oop_tee_shots, :botched_up_downs,
            numericality: { greater_than_or_equal_to: 0 }
  validates :inside_pw_9i, numericality: true
  validate :hole_scores_complete, if: :finished_at?

  scope :finished, -> { where.not(finished_at: nil) }

  def finished?
    finished_at.present?
  end

  def tee_label
    tee.to_s.titleize.presence
  end

  def tee_yardage(hole_number)
    return nil if tee.blank?

    course.tee_yardage(tee, hole_number)
  end

  def tee_total_yardage
    return nil if tee.blank?

    total = course.tee_total_yardage(tee)
    total.positive? ? total : nil
  end

  def total_score
    hole_scores.values.sum { |entry| entry["gross"].to_i }
  end

  def total_putts
    hole_scores.values.sum { |entry| entry["putts"].to_i }
  end

  # Holes where the player needed three or more putts, derived from hole_scores.
  def three_putts
    hole_scores.values.count { |entry| entry["putts"].to_i >= 3 }
  end

  def score_to_par
    hole_scores.sum do |number, entry|
      par = course.holes.find_by!(number: number.to_i).par
      entry["gross"].to_i - par
    end
  end

  private

  def hole_scores_complete
    course.holes.order(:number).each do |hole|
      entry = hole_scores[hole.number.to_s] || hole_scores[hole.number]
      if entry.blank? || entry["gross"].blank?
        errors.add(:hole_scores, "must include a gross score for hole #{hole.number}")
      end
    end
  end
end
