# frozen_string_literal: true

class AddGreenGeometryToHoles < ActiveRecord::Migration[8.1]
  def change
    add_column :holes, :green_geometry, :json
  end
end
