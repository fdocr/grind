# frozen_string_literal: true

class Course < ApplicationRecord
  RESULT_LIMIT = 10

  has_many :holes, -> { order(:number) }, dependent: :destroy, inverse_of: :course
  has_many :rounds, dependent: :destroy

  validates :name, :country, presence: true
  validates :name, uniqueness: { scope: [ :city, :state_province ] }

  scope :search, ->(query) {
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip)}%"
    where("name LIKE :term OR city LIKE :term OR country LIKE :term OR state_province LIKE :term", term: term)
  }

  def self.featured(limit = RESULT_LIMIT)
    recent_ids = joins(:rounds)
      .merge(Round.finished)
      .group("courses.id")
      .order(Arel.sql("MAX(rounds.finished_at) DESC"))
      .limit(limit)
      .pluck("courses.id")

    if recent_ids.any?
      where(id: recent_ids).in_order_of(:id, recent_ids)
    else
      order(Arel.sql("RANDOM()")).limit(limit)
    end
  end

  def out_par
    holes.where(number: 1..9).sum(:par)
  end

  def in_par
    holes.where(number: 10..18).sum(:par)
  end

  def total_par
    holes.sum(:par)
  end

  def last_hole_number
    holes.maximum(:number) || 0
  end

  def location_label
    [ city, state_province, country ].compact_blank.join(", ")
  end
end
