# frozen_string_literal: true

module Grind
  module Smtp
    module_function

    def configure!
      address = ENV["SMTP_ADDRESS"].presence
      return if address.blank?

      ActionMailer::Base.delivery_method = :smtp
      ActionMailer::Base.smtp_settings = {
        address: address,
        port: ENV.fetch("SMTP_PORT", 587).to_i,
        user_name: ENV["SMTP_USERNAME"].presence,
        password: ENV["SMTP_PASSWORD"].presence,
        authentication: :plain,
        enable_starttls_auto: true
      }

      from = ENV["SMTP_FROM_EMAIL"].presence
      ActionMailer::Base.default_options = { from: from } if from.present?

      host = ENV["APP_HOST"].presence
      ActionMailer::Base.default_url_options = { host: host, protocol: "https" } if host.present?
    end
  end
end
