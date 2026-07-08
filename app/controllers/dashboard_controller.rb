# frozen_string_literal: true

class DashboardController < ApplicationController
  include Pagy::Method

  ROUNDS_PER_PAGE = 12

  require_authentication

  def show
  end

  def rounds
    scope = current_user.rounds.finished.includes(:course).order(finished_at: :desc)
    @pagy, @rounds = pagy(scope, limit: ROUNDS_PER_PAGE)
  end
end
