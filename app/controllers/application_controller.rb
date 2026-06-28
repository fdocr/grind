class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def prevent_indexing
    @seo_robots = "noindex, nofollow"
  end

  def verify_turnstile!(redirect_path)
    return true if TurnstileVerifier.verify(params["cf-turnstile-response"], request.remote_ip)

    redirect_to redirect_path, alert: "Captcha verification failed. Please try again."
    false
  end
end
