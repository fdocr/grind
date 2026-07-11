module RoundUnlockTestHelper
  # Grants a short-lived session unlock so GET /courses/:id/round can render greens.
  def unlock_course_round!(course, tee: nil)
    post unlock_round_course_path(course), params: { tee: tee || course.default_tee }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include RoundUnlockTestHelper
end
