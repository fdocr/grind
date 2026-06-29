# frozen_string_literal: true

class ContributionsController < ApplicationController
  def new
    @kind = params[:kind].presence_in(Contribution.kinds.keys) || "correction"
    @selected_course = Course.find_by(id: params[:course_id])
    @kind = "correction" if @selected_course.present?

    @query = params[:q].to_s.strip
    if authenticated? && @kind == "correction" && @selected_course.nil? && @query.present?
      @courses = Course.search(@query).order(:name).limit(Course::RESULT_LIMIT)
    end

    @contribution = Contribution.new(kind: @kind, course: @selected_course)
    @contributions = current_user.contributions.includes(:course).recent if authenticated?
  end

  def create
    unless authenticated?
      redirect_to new_session_path
      return
    end

    return unless verify_turnstile!(contribute_path)

    @contribution = current_user.contributions.new(contribution_params)

    if @contribution.save
      ContributionMailer.submitted_confirmation(@contribution).deliver_later
      ContributionMailer.submitted_admin_notification(@contribution).deliver_later if User.admin.exists?

      redirect_to contribute_path, notice: "Thanks! Your contribution was submitted."
    else
      setup_new_after_failure
      render :new, status: :unprocessable_entity
    end
  end

  private

    def contribution_params
      params.require(:contribution).permit(
        :kind, :course_id, :comments, :image,
        :proposed_name, :proposed_city, :proposed_state_province, :proposed_country
      )
    end

    def setup_new_after_failure
      @kind = @contribution.kind
      @selected_course = @contribution.course || Course.find_by(id: params.dig(:contribution, :course_id))
      @query = params[:q].to_s.strip
      @contributions = current_user.contributions.includes(:course).recent
    end
end
