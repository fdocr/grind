# frozen_string_literal: true

require "test_helper"

class ContributionMailerTest < ActionMailer::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @contribution = create_contribution!(
      user: users(:player),
      comments: "Fix yardages"
    )
  end

  test "submitted confirmation" do
    email = ContributionMailer.submitted_confirmation(@contribution)

    assert_equal [ @contribution.user.email ], email.to
    assert_equal "Thanks for your contribution", email.subject
    assert_includes email.body.encoded, "Thank you for your contribution"
    assert_equal "grind@fdo.cr", email.from.first
  end

  test "submitted admin notification for correction" do
    email = ContributionMailer.submitted_admin_notification(@contribution)

    assert_equal User.admin.pluck(:email), email.to
    assert_equal "New scorecard contribution: #{@contribution.course.name}", email.subject
    assert_includes email.body.encoded, "/admin/contributions/#{@contribution.id}"
  end

  test "submitted admin notification for new course" do
    @contribution.update!(kind: :new_course, course: nil, proposed_name: "Hidden Links", proposed_country: "US")
    email = ContributionMailer.submitted_admin_notification(@contribution)

    assert_equal "New course request: Hidden Links", email.subject
  end

  test "finalized includes optional reply" do
    @contribution.update!(admin_reply: "All updated.")
    email = ContributionMailer.finalized(@contribution)

    assert_equal [ @contribution.user.email ], email.to
    assert_equal "Your contribution was processed", email.subject
    assert_includes email.body.encoded, "All updated."
  end
end
