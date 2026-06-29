# frozen_string_literal: true

module Admin
  class ContributionsController < BaseController
    before_action :set_contribution, only: %i[show update]

    def index
      @query = params[:q].to_s.strip
      @status = params[:status].presence_in(Contribution.statuses.keys)
      @kind = params[:kind].presence_in(Contribution.kinds.keys)

      scope = Contribution.search(@query)
      scope = scope.where(status: @status) if @status
      scope = scope.where(kind: @kind) if @kind

      @pagy, @contributions = pagy(scope.includes(:user, :course).recent)
    end

    def show
      @course = @contribution.course
    end

    def update
      @contribution.finalize!(update_params[:admin_reply])
      ContributionMailer.finalized(@contribution).deliver_later

      redirect_to admin_contribution_path(@contribution), notice: "Contribution finalized."
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_contribution_path(@contribution), alert: "Could not finalize contribution."
    end

    private

      def set_contribution
        @contribution = Contribution.find(params[:id])
      end

      def update_params
        params.require(:contribution).permit(:admin_reply)
      end
  end
end
