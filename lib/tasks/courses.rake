# frozen_string_literal: true

namespace :grind do
  namespace :courses do
    desc "Import golf courses from a YAML file"
    task :import, [ :file ] => :environment do |_task, args|
      path = args[:file].presence || ENV["FILE"]
      abort "Usage: bin/rails grind:courses:import FILE=path/to/file.yml" if path.blank?
      abort "File not found: #{path}" unless File.exist?(path)

      count = Grind::CourseImporter.import!(path)
      puts "Imported #{count} courses from #{path}"
    end
  end
end
