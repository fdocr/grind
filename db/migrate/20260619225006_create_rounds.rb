class CreateRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :rounds do |t|
      t.references :course, null: false, foreign_key: true
      t.string :token, null: false
      t.json :hole_scores, null: false, default: {}
      t.integer :oop_tee_shots, null: false, default: 0
      t.integer :three_putts, null: false, default: 0
      t.integer :botched_up_downs, null: false, default: 0
      t.integer :inside_pw_9i, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :rounds, :token, unique: true
  end
end
