module Admin
  class UsersController < BaseController
    def index
      @query = params[:q].to_s.strip
      scope = User.order(created_at: :desc)
      if @query.present?
        term = "%#{User.sanitize_sql_like(@query.downcase)}%"
        scope = scope.where("email LIKE ?", term)
      end
      @pagy, @users = pagy(scope)
    end

    def show
      @user = User.find(params[:id])
      @rounds = @user.rounds.finished.order(finished_at: :desc)
    end

    def update
      @user = User.find(params[:id])

      if @user == current_user
        redirect_to admin_user_path(@user), alert: "You can't change your own role."
        return
      end

      role = params.require(:user).permit(:role)[:role]
      @user.update!(role: role)
      @user.sessions.destroy_all if @user.banned?

      redirect_to admin_user_path(@user), notice: "#{@user.email} is now #{@user.role}."
    rescue ArgumentError, ActiveRecord::RecordInvalid
      redirect_to admin_user_path(@user), alert: "Could not update role."
    end
  end
end
