# frozen_string_literal: true

require "test_helper"

class Admin::ContributionsControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin)
    @player = users(:player)
    @course = courses(:one)
    @contribution = create_contribution!(
      user: @player,
      comments: "Fix par on hole 7"
    )
  end

  test "requires authentication" do
    get admin_contributions_path
    assert_redirected_to new_session_path
  end

  test "requires admin role" do
    sign_in_as(@player)
    get admin_contributions_path
    assert_redirected_to root_path
  end

  test "admin can list and filter contributions" do
    sign_in_as(@admin)
    get admin_contributions_path, params: { status: "pending", kind: "correction" }

    assert_response :success
    assert_match @course.name, response.body
    assert_match @player.email, response.body
  end

  test "admin can view contribution" do
    sign_in_as(@admin)
    get admin_contribution_path(@contribution)

    assert_response :success
    assert_match @course.name, response.body
    assert_match "Scorecard photo", response.body
    assert_match "Edit course", response.body
    assert_match 'data-turbo-frame="course_modal"', response.body
  end

  test "admin can finalize contribution and email user" do
    sign_in_as(@admin)

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      patch admin_contribution_path(@contribution), params: {
        contribution: { admin_reply: "Updated now." }
      }
    end

    assert_redirected_to admin_contribution_path(@contribution)
    @contribution.reload
    assert @contribution.finalized?
    assert_equal "Updated now.", @contribution.admin_reply
  end

  test "new course contribution shows create course link" do
    new_course = create_contribution!(
      user: @player,
      kind: :new_course,
      course: nil,
      proposed_name: "Hidden Valley",
      proposed_country: "US"
    )

    sign_in_as(@admin)
    get admin_contribution_path(new_course)

    assert_response :success
    assert_match "Create course", response.body
    assert_match "Hidden Valley", response.body
    assert_no_match "Edit course", response.body
  end
end
