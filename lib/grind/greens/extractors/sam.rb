# frozen_string_literal: true

module Grind
  module Greens
    module Extractors
      # Future: Segment Anything via a hosted API.
      class Sam
        def call(_input)
          raise NotImplementedError, "SAM green extractor is not implemented yet"
        end
      end
    end
  end
end
