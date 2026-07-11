# frozen_string_literal: true

class AddPublicIdToCourses < ActiveRecord::Migration[8.1]
  def up
    add_column :courses, :public_id, :string
    add_index :courses, :public_id, unique: true

    say_with_time "backfill course public_id" do
      Course.reset_column_information
      Course.find_each do |course|
        course.update_columns(public_id: SecureRandom.base58(24))
      end
    end

    change_column_null :courses, :public_id, false
  end

  def down
    remove_index :courses, :public_id
    remove_column :courses, :public_id
  end
end
