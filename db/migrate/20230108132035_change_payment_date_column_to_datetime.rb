class ChangePaymentDateColumnToDatetime < ActiveRecord::Migration[7.0]
  def change
    change_column :movements, :payment_date, :datetime
  end
end
