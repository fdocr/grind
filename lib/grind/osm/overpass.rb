# frozen_string_literal: true

require "net/http"

module Grind
  module Osm
    # Thin HTTP seam around the Overpass API. Builds an Overpass QL query from a
    # course location and returns the parsed JSON Hash. Parsing of the response
    # into geometry lives in Grind::Osm::CourseGeometry so it can be tested
    # without the network.
    #
    # Overpass is a shared, fair use service. See its usage policy:
    # https://dev.overpass-api.de/overpass-doc/en/preface/commons.html
    class Overpass
      class Error < StandardError; end

      # Raised on 429 (rate limit) and 504 (resources). Retryable with a longer
      # backoff than a generic error.
      class RateLimitedError < Error; end

      DEFAULT_ENDPOINT = "https://overpass-api.de/api/interpreter"
      DEFAULT_RADIUS = 2500
      USER_AGENT = "Grind golf tracker (https://github.com/fdocr/grind)"

      # Reported by the /api/status endpoint: how many slots are free for us and,
      # when none are, how many seconds until the next one frees up.
      Status = Struct.new(:slots_available, :wait_seconds, keyword_init: true) do
        def slot_available?
          slots_available.to_i.positive? || wait_seconds.to_i.zero?
        end
      end

      def self.fetch(latitude:, longitude:, radius: DEFAULT_RADIUS)
        new(latitude: latitude, longitude: longitude, radius: radius).fetch
      end

      # Current rate limit status for our IP. Returns nil when it cannot be
      # determined (fail open) so callers proceed rather than stall.
      def self.status
        uri = URI(status_endpoint)
        response = http_for(uri).request(get_request(uri))
        return nil unless response.is_a?(Net::HTTPSuccess)

        parse_status(response.body)
      rescue Timeout::Error, IOError, SystemCallError, Net::HTTPBadResponse, Net::ProtocolError, OpenSSL::SSL::SSLError
        nil
      end

      def self.parse_status(body)
        slots = body[/(\d+)\s+slots?\s+available\s+now/i, 1].to_i
        waits = body.scan(/in\s+(-?\d+)\s+seconds?/i).flatten.map { |n| [ n.to_i, 0 ].max }
        Status.new(slots_available: slots, wait_seconds: slots.positive? ? 0 : (waits.min || 0))
      end

      def self.endpoint
        ENV["OVERPASS_API_URL"].presence || DEFAULT_ENDPOINT
      end

      def self.status_endpoint
        endpoint.sub(%r{/interpreter/?\z}, "/status")
      end

      def self.http_for(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 15
        http.read_timeout = 120
        http
      end

      def self.get_request(uri)
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        request
      end

      def initialize(latitude:, longitude:, radius: DEFAULT_RADIUS)
        @latitude = latitude
        @longitude = longitude
        @radius = radius
      end

      def fetch
        response = post(query)
        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPTooManyRequests, Net::HTTPGatewayTimeOut
          raise RateLimitedError, "Overpass rate limited with #{response.code}"
        else
          raise Error, "Overpass request failed with #{response.code}"
        end
      rescue JSON::ParserError => e
        raise Error, "Overpass returned invalid JSON: #{e.message}"
      rescue Timeout::Error, IOError, SystemCallError, Net::HTTPBadResponse, Net::ProtocolError, OpenSSL::SSL::SSLError => e
        raise Error, "Overpass request error: #{e.message}"
      end

      # We deliberately do not request golf=pin: pins are rarely mapped and move
      # daily, so they are useless here and would only add noise.
      def query
        <<~QL
          [out:json][timeout:90];
          (
            way(around:#{@radius},#{@latitude},#{@longitude})["golf"="green"];
            relation(around:#{@radius},#{@latitude},#{@longitude})["golf"="green"];
            way(around:#{@radius},#{@latitude},#{@longitude})["golf"="hole"];
            way(around:#{@radius},#{@latitude},#{@longitude})["leisure"="golf_course"];
            relation(around:#{@radius},#{@latitude},#{@longitude})["leisure"="golf_course"];
          );
          out geom;
        QL
      end

      private

      def post(body)
        uri = URI(self.class.endpoint)
        http = self.class.http_for(uri)

        request = Net::HTTP::Post.new(uri)
        request["User-Agent"] = USER_AGENT
        request.set_form_data(data: body)
        http.request(request)
      end
    end
  end
end
