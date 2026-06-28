class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
    redirect_to root_path, notice: "You are already signed in." if authenticated?
  end

  def create
    return unless verify_turnstile!(new_session_path)

    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.banned?
      redirect_to new_session_path, alert: "Your account has been suspended."
      return
    end

    if user&.authenticate(params[:password])
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "Signed in."
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Signed out."
  end
end
