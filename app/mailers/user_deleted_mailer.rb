# frozen_string_literal: true

class UserDeletedMailer < ApplicationMailer
  def deleted_user_notification(user:, rounds:)
    @user = user
    @rounds = rounds

    mail(
      to: ENV.fetch("SMTP_FROM_EMAIL", "grind@fdo.cr"),
      subject: "Deleted Grind user: #{user.email}"
    )
  end
end
