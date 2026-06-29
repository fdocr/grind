# frozen_string_literal: true

class WelcomeMailerPreview < ActionMailer::Preview
  def welcome
    WelcomeMailer.welcome(User.first || User.new(email: "player@example.com"))
  end
end
