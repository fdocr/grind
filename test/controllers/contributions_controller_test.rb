# frozen_string_literal: true

require "test_helper"

class ContributionsControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile
  include ActiveJob::TestHelper

  setup do
    @course = courses(:one)
    @player = users(:player)
  end

  test "new is public and shows intro for guests" do
    get contribute_path
    assert_response :success
    assert_match "Registered users can submit", response.body
    assert_match "Sign up", response.body
  end

  test "new includes seo meta tags" do
    get contribute_path
    assert_select "meta[property='og:title'][content='Contribute · Grind']"
  end

  test "authenticated user sees submission form for new course" do
    sign_in_as(@player)
    get contribute_path(kind: "new_course")

    assert_response :success
    assert_select "input[name='contribution[proposed_name]']"
    assert_select "input[name='contribution[image]'][required=required]"
  end

  test "authenticated user sees course picker for correction" do
    sign_in_as(@player)
    get contribute_path

    assert_response :success
    assert_select "turbo-frame#contribution_course"
  end

  test "create requires authentication" do
    post contribute_path, params: { contribution: { kind: "correction", course_id: @course.id } }
    assert_redirected_to new_session_path
  end

  test "create correction enqueues emails" do
    sign_in_as(@player)

    assert_difference "Contribution.count", 1 do
      assert_enqueued_jobs 2, only: ActionMailer::MailDeliveryJob do
        post contribute_path, params: {
          contribution: {
            kind: "correction",
            course_id: @course.id,
            comments: "Fix yardages",
            image: fixture_file_upload("scorecard.png", "image/png")
          }
        }
      end
    end

    assert_redirected_to contribute_path
    assert_equal "Thanks! Your contribution was submitted.", flash[:notice]
  end

  test "create new_course succeeds" do
    sign_in_as(@player)

    assert_difference "Contribution.count", 1 do
      post contribute_path, params: {
        contribution: {
          kind: "new_course",
          proposed_name: "New Meadow",
          proposed_country: "US",
          proposed_city: "Austin",
          image: fixture_file_upload("scorecard.png", "image/png")
        }
      }
    end

    contribution = Contribution.order(:id).last
    assert contribution.new_course?
    assert_nil contribution.course_id
  end

  test "create fails without image" do
    sign_in_as(@player)

    assert_no_difference "Contribution.count" do
      post contribute_path, params: {
        contribution: {
          kind: "correction",
          course_id: @course.id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Image is required", response.body
  end

  test "course preselect via course_id shows form" do
    sign_in_as(@player)
    get contribute_path(course_id: @course.id)

    assert_response :success
    assert_select "input[name='contribution[course_id]'][value=?]", @course.id.to_s
    assert_select "input[name='contribution[image]']"
  end
end
