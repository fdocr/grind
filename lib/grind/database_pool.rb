# frozen_string_literal: true

module Grind
  module DatabasePool
    SOLID_QUEUE_OVERHEAD = 2

    module_function

    def size
      return ENV["DB_POOL"].to_i if ENV["DB_POOL"].present?

      [
        ENV.fetch("RAILS_MAX_THREADS", 3).to_i,
        ENV.fetch("SOLID_QUEUE_THREADS", 3).to_i + SOLID_QUEUE_OVERHEAD
      ].max
    end
  end
end
