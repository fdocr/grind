class AddGreenProvenanceToHoles < ActiveRecord::Migration[8.1]
  def change
    add_column :holes, :green_source, :string
    add_column :holes, :green_input, :json
  end
end
