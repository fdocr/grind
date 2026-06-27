# frozen_string_literal: true

class AddOsmFieldsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :osm_id, :string
    add_column :courses, :osm_synced_at, :datetime
    add_column :courses, :osm_status, :string
  end
end
