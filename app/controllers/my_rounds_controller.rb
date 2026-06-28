class MyRoundsController < ApplicationController
  require_authentication

  def index
    @rounds = current_user.rounds.finished.order(finished_at: :desc)
  end
end
