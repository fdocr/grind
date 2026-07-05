# frozen_string_literal: true

class RemoveThreePuttsFromRounds < ActiveRecord::Migration[8.1]
  def change
    remove_column :rounds, :three_putts, :integer, default: 0, null: false
  end
end
