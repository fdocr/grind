# frozen_string_literal: true

module Dev
  class StyleguideController < ApplicationController
    layout "application"

    before_action :ensure_development!

    def show
    end

    private

    def ensure_development!
      head :not_found unless Rails.env.development?
    end
  end
end
