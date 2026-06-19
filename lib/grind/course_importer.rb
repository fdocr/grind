# frozen_string_literal: true

module Grind
  class CourseImporter
    def self.import!(path)
      new(path).import!
    end

    def initialize(path)
      @path = path
    end

    def import!
      data = YAML.unsafe_load_file(@path)
      count = 0

      data.each do |entry|
        import_course!(entry)
        count += 1
      end

      count
    end

    private

    def import_course!(entry)
      course = Course.find_or_initialize_by(
        name: entry[:name],
        city: entry[:city].to_s,
        state_province: entry[:stateprovince].to_s
      )

      course.assign_attributes(
        country: entry[:country].to_s,
        address: entry[:address].to_s,
        zip: entry[:zip].to_s,
        phone: entry[:phone].to_s,
        website: entry[:website].to_s,
        metric: entry[:metric] == true,
        latitude: entry[:latitude].presence,
        longitude: entry[:longitude].presence,
        tees: build_tees(entry)
      )
      course.save!

      import_holes!(course, entry[:scorecard])
      course
    end

    def import_holes!(course, scorecard)
      scorecard.each_with_index do |hole_data, index|
        number = index + 1
        tee_entry = hole_data.values.first
        hole = course.holes.find_or_initialize_by(number: number)
        hole.assign_attributes(
          par: tee_entry[:par].to_i,
          handicap: tee_entry[:handicap].to_i
        )
        hole.save!
      end
    end

    def build_tees(entry)
      scorecard = entry[:scorecard] || []
      tee_names = scorecard.flat_map(&:keys).uniq
      ratings = entry[:ratings] || {}
      slopes = entry[:slopes] || {}

      tee_names.index_with do |tee_name|
        yardages = scorecard.map do |hole|
          hole.dig(tee_name, :yardage).to_i
        end

        {
          "rating" => ratings[tee_name].to_s,
          "slope" => slopes[tee_name].to_s,
          "yardages" => yardages
        }
      end
    end
  end
end
