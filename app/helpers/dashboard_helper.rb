module DashboardHelper

  def tithe_amount_percent(amount, date_range)
    number_to_percentage(amount.to_f / Movement.entrada.dízimo.where(payment_date: date_range).sum(:amount).to_f * 100.0, precision: 0)
  end

  def offer_amount_percent(amount, date_range)
    number_to_percentage(amount.to_f / Movement.entrada.oferta.where(payment_date: date_range).sum(:amount).to_f * 100.0, precision: 0)
  end

  def list_2022_to_next_year()
    2022..(Date.today.year.next)
  end
end
