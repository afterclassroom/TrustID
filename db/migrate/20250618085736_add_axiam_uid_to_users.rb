class AddAxiamUidToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :axiam_uid, :string
  end
end
