# frozen_string_literal: true

class Course < ApplicationRecord
  RESULT_LIMIT = 6
  NEAR_RADIUS_KM = 80
  EARTH_RADIUS_M = 6_371_000

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

  scope :with_coordinates, -> { where.not(latitude: nil).where.not(longitude: nil) }

  # Courses nearest to lat/lng within a bounding box, ordered by great-circle distance.
  def self.near(lat, lng, limit: RESULT_LIMIT, radius_km: NEAR_RADIUS_KM)
    lat = lat.to_f
    lng = lng.to_f
    return none unless lat.between?(-90, 90) && lng.between?(-180, 180)

    delta_lat = radius_km / 111.0
    cos_lat = Math.cos(lat * Math::PI / 180).abs
    delta_lng = radius_km / (111.0 * [ cos_lat, 0.01 ].max)

    candidates = with_coordinates
      .where(latitude: (lat - delta_lat)..(lat + delta_lat))
      .where(longitude: (lng - delta_lng)..(lng + delta_lng))
      .to_a

    ids = candidates
      .sort_by { |course| haversine_meters(lat, lng, course.latitude.to_f, course.longitude.to_f) }
      .first(limit)
      .map(&:id)

    where(id: ids).in_order_of(:id, ids)
  end

  # Distinct courses from a user's finished rounds, most recently played first.
  def self.played_by(user, limit: RESULT_LIMIT)
    return none unless user

    ids = joins(:rounds)
      .merge(Round.finished)
      .where(rounds: { user_id: user.id })
      .group("courses.id")
      .order(Arel.sql("MAX(rounds.finished_at) DESC"))
      .limit(limit)
      .pluck("courses.id")

    where(id: ids).in_order_of(:id, ids)
  end

  def self.haversine_meters(lat1, lng1, lat2, lng2)
    d_lat = (lat2 - lat1) * Math::PI / 180
    d_lng = (lng2 - lng1) * Math::PI / 180
    a = Math.sin(d_lat / 2)**2 +
        Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(d_lng / 2)**2
    2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a))
  end
  private_class_method :haversine_meters

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

  def greens_mapped?
    holes.any?(&:green?)
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
