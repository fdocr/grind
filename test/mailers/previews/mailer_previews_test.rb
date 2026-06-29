# frozen_string_literal: true

require "test_helper"

class MailerPreviewsTest < ActiveSupport::TestCase
  Dir[Rails.root.join("test/mailers/previews/*_preview.rb")].each { |file| require file }

  ActionMailer::Preview.all.each do |preview_class|
    preview_class.public_instance_methods(false).each do |method_name|
      test "#{preview_class.name}##{method_name} renders" do
        preview = preview_class.new
        message = preview.public_send(method_name)

        assert message.respond_to?(:body)
        assert message.body.encoded.present?
      end
    end
  end
end
