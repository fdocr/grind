class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("SMTP_FROM_EMAIL", "noreply@grind.fdo.cr") }
  layout "mailer"
  helper ScoreHelper
end
