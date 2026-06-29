# frozen_string_literal: true

require "test_helper"

class ContributionTest < ActiveSupport::TestCase
  setup do
    @user = users(:player)
    @course = courses(:one)
  end

  test "correction requires course and image" do
    contribution = Contribution.new(user: @user, kind: :correction)
    assert_not contribution.valid?
    assert_includes contribution.errors[:course], "can't be blank"
    assert_includes contribution.errors[:image], "is required"
  end

  test "new_course requires proposed name country and image" do
    contribution = Contribution.new(user: @user, kind: :new_course)
    assert_not contribution.valid?
    assert_includes contribution.errors[:proposed_name], "can't be blank"
    assert_includes contribution.errors[:proposed_country], "can't be blank"
    assert_includes contribution.errors[:image], "is required"
  end

  test "valid correction saves with image" do
    contribution = create_contribution!(comments: "Back nine yardages look off")
    assert contribution.correction?
    assert contribution.image.attached?
  end

  test "valid new_course saves with image" do
    contribution = create_contribution!(
      kind: :new_course,
      course: nil,
      proposed_name: "Hidden Links",
      proposed_country: "US",
      proposed_city: "Austin",
      proposed_state_province: "TX"
    )

    assert contribution.new_course?
    assert_nil contribution.course_id
    assert_equal "Hidden Links", contribution.course_label
  end

  test "normalize_for_kind clears opposite fields" do
    contribution = Contribution.new(
      user: @user,
      kind: :new_course,
      proposed_name: "Test",
      proposed_country: "US",
      course: @course
    )
    contribution.valid?

    assert_nil contribution.course_id
  end

  test "finalize sets status and reply" do
    contribution = create_contribution!
    contribution.finalize!("All set now.")

    assert contribution.finalized?
    assert_equal "All set now.", contribution.admin_reply
    assert contribution.finalized_at.present?
  end

  test "search matches course name and proposed name" do
    correction = create_contribution!(comments: "fix it")
    new_course = create_contribution!(
      kind: :new_course,
      course: nil,
      proposed_name: "Unique Meadow Club",
      proposed_country: "US"
    )

    assert_includes Contribution.search(@course.name), correction
    assert_includes Contribution.search("Unique Meadow"), new_course
  end

  test "rejects pdf uploads" do
    contribution = Contribution.new(user: @user, course: @course, kind: :correction)
    contribution.image.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "scorecard.pdf",
      content_type: "application/pdf"
    )

    assert_not contribution.valid?
    assert_includes contribution.errors[:image], "must be a photo (JPEG, PNG, WEBP, or HEIC)"
  end

  test "rejects text file uploads" do
    contribution = Contribution.new(user: @user, course: @course, kind: :correction)
    contribution.image.attach(
      io: StringIO.new("hole,par\n1,4"),
      filename: "scorecard.csv",
      content_type: "text/csv"
    )

    assert_not contribution.valid?
    assert_includes contribution.errors[:image], "must be a photo (JPEG, PNG, WEBP, or HEIC)"
  end
end
