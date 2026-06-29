# frozen_string_literal: true

class Contribution < ApplicationRecord
  belongs_to :user
  belongs_to :course, optional: true
  has_one_attached :image

  enum :kind, { correction: 0, new_course: 1 }, default: :correction
  enum :status, { pending: 0, finalized: 1 }, default: :pending

  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp image/heic image/heif].freeze
  MAX_IMAGE_BYTES = 10.megabytes

  before_validation :normalize_for_kind

  validates :comments, length: { maximum: 1000 }
  validate :image_present
  validate :image_type_and_size
  validates :course, presence: true, if: :correction?
  validates :proposed_name, :proposed_country, presence: true, if: :new_course?

  scope :recent, -> { order(created_at: :desc) }
  scope :search, ->(query) {
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip)}%"
    left_joins(:course, :user).where(
      "courses.name LIKE :term OR courses.city LIKE :term OR users.email LIKE :term " \
      "OR contributions.proposed_name LIKE :term OR contributions.proposed_country LIKE :term",
      term: term
    )
  }

  def course_label
    course&.name || proposed_name
  end

  def location_label
    course&.location_label || [ proposed_city, proposed_state_province, proposed_country ].compact_blank.join(", ")
  end

  def finalize!(reply)
    update!(status: :finalized, finalized_at: Time.current, admin_reply: reply.presence)
  end

  private

    def normalize_for_kind
      if new_course?
        self.course = nil
      else
        self.proposed_name = self.proposed_city = self.proposed_state_province = self.proposed_country = nil
      end
    end

    def image_present
      errors.add(:image, "is required") unless image.attached?
    end

    def image_type_and_size
      return unless image.attached?

      unless ALLOWED_IMAGE_TYPES.include?(image.content_type)
        errors.add(:image, "must be PNG, JPEG, WEBP, or HEIC")
      end
      errors.add(:image, "must be under 10 MB") if image.byte_size > MAX_IMAGE_BYTES
    end
end
