class AddUserToRoundsAndDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_reference :rounds, :user, null: true, foreign_key: true
    add_reference :deliveries, :user, null: true, foreign_key: true
  end
end
