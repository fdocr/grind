# frozen_string_literal: true

class Course < ApplicationRecord
  RESULT_LIMIT = 10

  has_many :holes, -> { order(:number) }, dependent: :destroy, inverse_of: :course
  has_many :rounds, dependent: :destroy
  has_many :contributions, dependent: :destroy

  accepts_nested_attributes_for :holes

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

  def coordinates?
    latitude.present? && longitude.present?
  end

  def osm_synced?
    osm_synced_at.present?
  end

  def green_holes_count
    holes.count(&:green?)
  end

  def osm_status_label
    case osm_status
    when "ok" then "Synced"
    when "no_data" then "No green data"
    when "error" then "Sync error"
    else "Not synced"
    end
  end

  # Tee names in import order (longest course first when yardage is known).
  def tee_names
    tees.keys.sort_by { |name| -tee_total_yardage(name) }
  end

  def default_tee
    tee_names.first
  end

  def tee?(name)
    name.present? && tees.key?(name.to_s)
  end

  def tee_data(name)
    tees[name.to_s] || {}
  end

  def tee_yardages(name)
    Array(tee_data(name)["yardages"]).map(&:to_i)
  end

  # Yardage for a specific hole number (1-indexed); nil when unknown.
  def tee_yardage(name, hole_number)
    yards = tee_yardages(name)[hole_number.to_i - 1].to_i
    yards.positive? ? yards : nil
  end

  def tee_total_yardage(name)
    tee_yardages(name).sum
  end

  def tee_rating(name)
    tee_data(name)["rating"].to_s.presence
  end

  def tee_slope(name)
    tee_data(name)["slope"].to_s.presence
  end
end
