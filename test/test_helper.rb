ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/system_test_retry"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    def build_eighteen_holes!(course)
      (1..18).each do |number|
        course.holes.find_or_create_by!(number: number) do |hole|
          hole.par = number.even? ? 4 : (number % 3 == 0 ? 3 : 5)
          hole.handicap = number
        end
      end
    end

    def build_nine_holes!(course)
      course.holes.where(number: 10..18).delete_all
      (1..9).each do |number|
        course.holes.find_or_create_by!(number: number) do |hole|
          hole.par = number.even? ? 4 : (number % 3 == 0 ? 3 : 5)
          hole.handicap = number
        end
      end
    end

    # Temporarily replaces a class or instance method. When result responds to
    # call it is invoked with the original arguments, otherwise it is returned.
    def stub_method(object, name, result)
      original = object.method(name)
      object.define_singleton_method(name) do |*args, **kwargs|
        result.respond_to?(:call) ? result.call(*args, **kwargs) : result
      end
      yield
    ensure
      object.define_singleton_method(name, original)
    end
  end
end

class ActionDispatch::IntegrationTest
  setup { host! "example.com" }
end
