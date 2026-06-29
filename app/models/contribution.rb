# frozen_string_literal: true

class Contribution < ApplicationRecord
  belongs_to :user
  belongs_to :course, optional: true
  has_one_attached :image

  enum :kind, { correction: 0, new_course: 1 }, default: :correction
  enum :status, { pending: 0, finalized: 1 }, default: :pending

  MAX_IMAGE_BYTES = Grind::ContributionImage::MAX_BYTES

  before_validation :normalize_for_kind
  after_commit :normalize_attached_image, on: %i[create update]

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

  def displayable_image
    return image unless image.attached?

    @displayable_image ||= begin
      Grind::ContributionImage.ensure_displayable!(image)
      image
    end
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

      blob = image.blob

      if blob.byte_size > MAX_IMAGE_BYTES
        errors.add(:image, "must be under 10 MB")
        return
      end

      unless Grind::ContributionImage.extension_allowed?(blob.filename.to_s)
        errors.add(:image, "must be a photo (JPEG, PNG, WEBP, or HEIC)")
        return
      end

      unless Grind::ContributionImage.allowed_content_type?(blob)
        errors.add(:image, "must be a photo (JPEG, PNG, WEBP, or HEIC)")
      end
    end

    def normalize_attached_image
      return unless image.attached?
      return unless Grind::ContributionImage.needs_normalization?(image)

      Grind::ContributionImage.normalize!(image)
    end
end
