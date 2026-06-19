# frozen_string_literal: true

class Hole < ApplicationRecord
  belongs_to :course, inverse_of: :holes

  validates :number, inclusion: { in: 1..18 }, uniqueness: { scope: :course_id }
  validates :par, :handicap, presence: true
end
