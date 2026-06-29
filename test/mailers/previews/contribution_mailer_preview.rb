# frozen_string_literal: true

class ContributionMailerPreview < ActionMailer::Preview
  def submitted_confirmation
    ContributionMailer.submitted_confirmation(sample_contribution)
  end

  def submitted_admin_notification
    ContributionMailer.submitted_admin_notification(sample_contribution)
  end

  def finalized
    contribution = sample_contribution
    contribution.update!(admin_reply: "We just updated your golf course. Let us know if it looks good now!")
    ContributionMailer.finalized(contribution)
  end

  private

    def sample_contribution
      existing = Contribution.includes(:user, :course).last
      return existing if existing

      user = User.first || User.create!(email: "preview@example.com", password: "password123")
      course = Course.first || Course.create!(name: "Preview Course", country: "US", city: "Austin")
      contribution = Contribution.new(
        user: user,
        course: course,
        kind: :correction,
        comments: "Tee distances on the back nine look wrong."
      )
      contribution.image.attach(
        io: File.open(Rails.root.join("test/fixtures/files/scorecard.png")),
        filename: "scorecard.png",
        content_type: "image/png"
      )
      contribution.save!
      contribution
    end
end
