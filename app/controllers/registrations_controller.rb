class RegistrationsController < ApplicationController
  before_action :redirect_if_authenticated, only: %i[new create]

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

  private

    def registration_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end

    def redirect_if_authenticated
      redirect_to root_path, notice: "You are already signed in." if authenticated?
    end
end
