class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :rounds, dependent: :nullify
  has_many :contributions, dependent: :destroy

  enum :role, { user: 0, admin: 1, banned: 2 }, default: :user

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_create :assign_admin_from_allowlist

  def ban!
    update!(role: :banned)
    sessions.destroy_all
  end

  def unban!(to: :user)
    update!(role: to)
  end

  def self.admin_emails
    ENV.fetch("GRIND_ADMIN_EMAILS", "").split(",").map { it.strip.downcase }.reject(&:blank?)
  end

  def self.admin_allowlisted?(addr)
    addr.present? && admin_emails.include?(addr.strip.downcase)
  end

  private

    def assign_admin_from_allowlist
      self.role = :admin if self.class.admin_allowlisted?(email)
    end
end
