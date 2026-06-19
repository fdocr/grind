# frozen_string_literal: true

class TurnstileVerifier
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def self.verify(token, remote_ip)
    new(token, remote_ip).verify
  end

  def initialize(token, remote_ip)
    @token = token
    @remote_ip = remote_ip
  end

  def verify
    return true if Rails.env.test?
    return true if secret_key.blank?

    response = Net::HTTP.post_form(
      URI(VERIFY_URL),
      secret: secret_key,
      response: @token,
      remoteip: @remote_ip
    )
    JSON.parse(response.body)["success"] == true
  rescue StandardError
    false
  end

  private

  def secret_key
    ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
  end
end
