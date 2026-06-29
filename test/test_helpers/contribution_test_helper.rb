# frozen_string_literal: true

module ContributionTestHelper
  def create_contribution!(attrs = {})
    defaults = {
      user: users(:player),
      course: courses(:one),
      kind: :correction
    }
    contribution = Contribution.new(defaults.merge(attrs))
    contribution.image.attach(
      io: File.open(file_fixture("scorecard.png")),
      filename: "scorecard.png",
      content_type: "image/png"
    )
    contribution.save!
    contribution
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include ContributionTestHelper
  include ActionDispatch::TestProcess::FixtureFile
end
