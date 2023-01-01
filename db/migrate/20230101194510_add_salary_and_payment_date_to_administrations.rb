class AddSalaryAndPaymentDateToAdministrations < ActiveRecord::Migration[7.0]
  def change
    add_column :administrations, :salary, :float
    add_column :administrations, :payment_day, :integer
  end
end
