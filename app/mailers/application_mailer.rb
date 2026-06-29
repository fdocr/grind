class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("SMTP_FROM_EMAIL", "grind@fdo.cr") }
  layout "mailer"
  helper ScoreHelper
end
