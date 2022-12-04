class CreateChurches < ActiveRecord::Migration[7.0]
  def change
    create_table :churches do |t|
      t.string :name
      t.date :fundation_date

      t.timestamps
    end
  end
end
