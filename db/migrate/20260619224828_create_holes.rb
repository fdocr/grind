class CreateHoles < ActiveRecord::Migration[8.1]
  def change
    create_table :holes do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :par, null: false
      t.integer :handicap, null: false

      t.timestamps
    end

    add_index :holes, [ :course_id, :number ], unique: true
  end
end
