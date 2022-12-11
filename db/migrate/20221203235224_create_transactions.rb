class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.integer :kind_of
      t.decimal :amount, precision: 8, scale: 2
      t.date :payment_date
      t.text :description
      t.references :wallet, null: false, foreign_key: true

      t.timestamps
    end
  end
end