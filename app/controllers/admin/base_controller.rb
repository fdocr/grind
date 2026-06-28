module Admin
  class BaseController < ApplicationController
    require_authentication
    before_action :require_admin

    private

      def require_admin
        redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
      end
  end
end
