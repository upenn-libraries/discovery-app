class AddIndexes < ActiveRecord::Migration
  def change
    add_index :searches, :created_at
    add_index :users, :updated_at
    add_index :users, :guest
  end
end
