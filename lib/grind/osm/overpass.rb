# frozen_string_literal: true

require "net/http"

module Grind
  module Osm
    # Thin HTTP seam around the Overpass API. Builds an Overpass QL query from a
    # course location and returns the parsed JSON Hash. Parsing of the response
    # into geometry lives in Grind::Osm::CourseGeometry so it can be tested
    # without the network.
    class Overpass
      class Error < StandardError; end

      DEFAULT_ENDPOINT = "https://overpass-api.de/api/interpreter"
      DEFAULT_RADIUS = 2500
      USER_AGENT = "Grind golf tracker (https://github.com/fdocr/grind)"

      def self.fetch(latitude:, longitude:, radius: DEFAULT_RADIUS)
        new(latitude: latitude, longitude: longitude, radius: radius).fetch
      end

      def initialize(latitude:, longitude:, radius: DEFAULT_RADIUS)
        @latitude = latitude
        @longitude = longitude
        @radius = radius
      end

      def fetch
        response = post(query)
        unless response.is_a?(Net::HTTPSuccess)
          raise Error, "Overpass request failed with #{response.code}"
        end

        JSON.parse(response.body)
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
        uri = URI(endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 15
        http.read_timeout = 120

        request = Net::HTTP::Post.new(uri)
        request["User-Agent"] = USER_AGENT
        request.set_form_data(data: body)
        http.request(request)
      end

      def endpoint
        ENV["OVERPASS_API_URL"].presence || DEFAULT_ENDPOINT
      end
    end
  end
end
