module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    before_action :reject_banned_user
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def require_authentication(**options)
      before_action :require_authenticated_user, **options
    end
  end

  private
    def authenticated?
      Current.session.present?
    end

    def current_user
      Current.user
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def require_authenticated_user
      request_authentication unless authenticated?
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path, alert: "Please sign in to continue."
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_path
    end

    def reject_banned_user
      return unless current_user&.banned?

      terminate_session
      redirect_to new_session_path, alert: "Your account has been suspended."
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session_record|
        Current.session = session_record
        cookies.signed.permanent[:session_id] = { value: session_record.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(:session_id)
    end
end
