# frozen_string_literal: true

class CreateContributions < ActiveRecord::Migration[8.1]
  def change
    create_table :contributions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: true, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.text :comments
      t.integer :status, null: false, default: 0
      t.text :admin_reply
      t.datetime :finalized_at
      t.string :proposed_name
      t.string :proposed_city
      t.string :proposed_state_province
      t.string :proposed_country

      t.timestamps
    end

    add_index :contributions, :status
    add_index :contributions, :kind
  end
end
