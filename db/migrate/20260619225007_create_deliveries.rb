class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries do |t|
      t.references :round, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.string :email, null: false
      t.integer :score_to_par, null: false

      t.timestamps
    end
  end
end
