# frozen_string_literal: true

class Course < ApplicationRecord
  has_many :holes, -> { order(:number) }, dependent: :destroy, inverse_of: :course
  has_many :rounds, dependent: :destroy

  validates :name, :country, presence: true
  validates :name, uniqueness: { scope: [ :city, :state_province ] }

  scope :search, ->(query) {
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip)}%"
    where("name LIKE :term OR city LIKE :term OR country LIKE :term OR state_province LIKE :term", term: term)
  }

  def out_par
    holes.where(number: 1..9).sum(:par)
  end

  def in_par
    holes.where(number: 10..18).sum(:par)
  end

  def total_par
    holes.sum(:par)
  end

  def location_label
    [ city, state_province, country ].compact_blank.join(", ")
  end
end
