# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless Rails.env.production?

  begin
    Grind::Smtp.configure!
  rescue => e
    Rails.logger.warn "SMTP configuration skipped: #{e.message}"
  end
end
