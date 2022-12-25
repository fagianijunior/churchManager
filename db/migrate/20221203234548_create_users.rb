class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
      t.integer :gender
      t.string :contact_number
      t.string :address
      t.date :baptism_date
      t.date :member_since
      t.integer :marital_status
      t.string :cpf
      t.string :rg
      t.date :birth_date
      t.references :church, null: false, foreign_key: true
      t.text :description

      t.timestamps
    end
  end
end
