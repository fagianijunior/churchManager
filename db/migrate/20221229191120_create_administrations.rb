class CreateAdministrations < ActiveRecord::Migration[7.0]
  def change
    create_table :administrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :occupation, null: false, foreign_key: true
      t.boolean :titular, default: false
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
