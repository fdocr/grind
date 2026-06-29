# frozen_string_literal: true

class ContributionMailer < ApplicationMailer
  def submitted_confirmation(contribution)
    @contribution = contribution

    mail(
      to: contribution.user.email,
      subject: "Thanks for your contribution"
    )
  end

  def submitted_admin_notification(contribution)
    @contribution = contribution

    subject = if contribution.new_course?
      "New course request: #{contribution.proposed_name}"
    else
      "New scorecard contribution: #{contribution.course_label}"
    end

    mail(
      to: User.admin.pluck(:email),
      subject: subject
    )
  end

  def finalized(contribution)
    @contribution = contribution

    mail(
      to: contribution.user.email,
      subject: "Your contribution was processed"
    )
  end
end
