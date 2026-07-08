# frozen_string_literal: true

class AccountController < ApplicationController
  require_authentication

  def edit_password
  end

  def update_password
    if current_user.authenticate(params[:current_password])
      if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        redirect_to dashboard_path, notice: "Password updated successfully."
      else
        redirect_to edit_account_password_path, alert: "Failed to update password: #{current_user.errors.full_messages.join(', ')}"
      end
    else
      redirect_to edit_account_password_path, alert: "Current password is incorrect."
    end
  end
end
