# frozen_string_literal: true

class Hole < ApplicationRecord
  GREEN_SOURCES = %w[osm manual cv sam llm].freeze

  belongs_to :course, inverse_of: :holes

  validates :number, inclusion: { in: 1..18 }, uniqueness: { scope: :course_id }
  validates :par, :handicap, presence: true
  validates :green_source, inclusion: { in: GREEN_SOURCES }, allow_nil: true

  scope :with_green, -> { where.not(green_geometry: nil) }

  # [[lat, lng], ...] outer ring of the green when OpenStreetMap data is present.
  def green_polygon
    Array(green_geometry&.dig("polygon"))
  end

  # [lat, lng] centroid of the green when OpenStreetMap data is present.
  def green_centroid
    green_geometry&.dig("centroid")
  end

  def green?
    green_polygon.size >= 3 && green_centroid.present?
  end

  def green_manual?
    green_source == "manual"
  end
end
