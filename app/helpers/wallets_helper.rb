module WalletsHelper
  def kind_of_icon(kind_of)
    case kind_of
    when 'corrente'
      'fa-building-columns'
    when 'poupanca'
      'fa-arrow-trend-down'
    when 'caixa'
      'fa-piggy-bank'
    when 'investimento'
      'fa-arrow-trend-up'
    when 'dizimo'
      'fa-hand-holding-dollar'
    else
      'fa-sack-dollar'
    end
end
end