class RegistrationsController < ApplicationController
  before_action :redirect_if_authenticated, only: %i[new create]
  require_authentication only: :destroy

  def new
    @user = User.new
  end

  def create
    return unless verify_turnstile!(new_registration_path)

    @user = User.new(registration_params)

    if @user.save
      WelcomeMailer.welcome(@user).deliver_later
      start_new_session_for(@user)
      redirect_to root_path, notice: "Welcome to Grind! Your account is ready."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    user = current_user
    rounds = user.rounds.finished.includes(:course).order(finished_at: :desc)

    UserDeletedMailer.deleted_user_notification(user: user, rounds: rounds).deliver_now
    terminate_session

    if user.destroy
      redirect_to root_path, notice: "Your account has been permanently deleted."
    else
      redirect_to dashboard_path, alert: "Could not delete account."
    end
  end

  private

    def registration_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end

    def redirect_if_authenticated
      redirect_to root_path, notice: "You are already signed in." if authenticated?
    end
end
