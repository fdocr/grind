class AddTeeToRounds < ActiveRecord::Migration[8.1]
  def change
    add_column :rounds, :tee, :string
  end
end
