class AddSubKindOfToMovements < ActiveRecord::Migration[7.0]
  def change
    add_column :movements, :sub_kind_of, :integer
  end
end
