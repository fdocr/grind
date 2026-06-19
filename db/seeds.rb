# frozen_string_literal: true

if Rails.env.development?
  sample = Rails.root.join("tmp/sample_courses.yml")
  unless Course.exists?
    if sample.exist?
      Grind::CourseImporter.import!(sample)
      puts "Imported sample courses from #{sample}"
    else
      puts "No courses in database. Import with: bin/rails grind:courses:import FILE=path/to/file.yml"
    end
  end
end
