class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :name, null: false
      t.string :country, null: false
      t.string :address
      t.string :city
      t.string :state_province
      t.string :zip
      t.string :phone
      t.string :website
      t.boolean :metric, null: false, default: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.json :tees, null: false, default: {}

      t.timestamps
    end

    add_index :courses, :name
    add_index :courses, :city
    add_index :courses, :country
    add_index :courses, [ :name, :city, :state_province ], unique: true, name: "index_courses_on_identity"
  end
end
