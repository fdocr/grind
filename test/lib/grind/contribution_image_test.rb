# frozen_string_literal: true

require "test_helper"

class GrindContributionImageTest < ActiveSupport::TestCase
  test "allows common photo types before optimization" do
    attachment = attach_file("scorecard.png", content_type: "image/png")

    assert Grind::ContributionImage.allowed_content_type?(attachment.blob)
    assert Grind::ContributionImage.extension_allowed?("scorecard.png")
    assert Grind::ContributionImage.needs_optimization?(attachment)
  end

  test "heic uploads are optimized after save" do
    contribution = Contribution.new(user: users(:player), course: courses(:one), kind: :correction)
    contribution.image.attach(
      io: File.open(file_fixture("scorecard.png")),
      filename: "scorecard.heic",
      content_type: "image/heic"
    )
    contribution.save!

    assert_equal "image/jpeg", contribution.image.blob.content_type
    assert_equal "scorecard.jpg", contribution.image.blob.filename.to_s
    assert contribution.image.blob.byte_size <= Grind::ContributionImage::MAX_BYTES
    assert_equal true, contribution.image.blob.metadata["optimized"]
  end

  test "jpeg uploads are optimized to save storage" do
    contribution = create_contribution!

    assert_equal "image/jpeg", contribution.image.blob.content_type
    assert contribution.image.blob.byte_size <= Grind::ContributionImage::MAX_BYTES
    assert_equal true, contribution.image.blob.metadata["optimized"]
  end

  test "rejects non-photo extensions" do
    assert_not Grind::ContributionImage.extension_allowed?("scorecard.pdf")
    assert_not Grind::ContributionImage.extension_allowed?("notes.txt")
  end

  private

    def attach_file(fixture_name, filename: fixture_name, content_type: "image/png")
      contribution = Contribution.new(user: users(:player), course: courses(:one))
      contribution.image.attach(
        io: File.open(file_fixture(fixture_name)),
        filename: filename,
        content_type: content_type
      )
      contribution.image
    end
end
