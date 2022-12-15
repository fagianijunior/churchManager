module DashboardHelper

  def amount_percent(amount, date_range)
    number_to_percentage(amount.to_f / Movement.entrada.where(payment_date: date_range).sum(:amount).to_f * 100.0, precision: 0)
  end

end
