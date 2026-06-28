# frozen_string_literal: true

module Grind
  module Greens
    module Extractor
      class Error < StandardError; end

      module_function

      def for(method = ENV.fetch("GREEN_EXTRACTOR", "manual"))
        case method.to_s
        when "manual" then Extractors::Manual.new
        when "cv" then Extractors::Cv.new
        when "sam" then Extractors::Sam.new
        when "llm" then Extractors::Llm.new
        else
          raise Error, "Unknown green extractor: #{method}"
        end
      end
    end
  end
end
