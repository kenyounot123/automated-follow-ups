class MakeCadenceOnePerAccount < ActiveRecord::Migration[8.1]
  def change
    remove_index :cadences, name: "index_cadences_one_active_per_account"
    remove_index :cadences, name: "index_cadences_on_account_id"
    remove_column :cadences, :active, :boolean
    add_index :cadences, :account_id, unique: true
  end
end
