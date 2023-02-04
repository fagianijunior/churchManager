class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_header_panel, only: %i[ index ]
  def index
    @monthMovementsInChart  = Movement.entrada.not_entre_contas.group_by_day(:payment_date).where(payment_date: @date_range).sum(:amount)
    @monthMovementsOutChart = Movement.saida.not_entre_contas.group_by_day(:payment_date).where(payment_date: @date_range).sum('amount * -1')

    accumulator = 0
    @monthMovementsBalanceChart = Movement.group_by_day(:payment_date).where('payment_date <= ?', @date.end_of_month.end_of_day).sum(:amount)
    @monthMovementsBalanceChart.transform_values! do |val|
      val += accumulator
      accumulator = val
    end
    
    @monthlyInAmountByKind = Movement.entrada.not_entre_contas.where(payment_date: @date_range).group(:sub_kind_of).sum(:amount).sort
    @monthlyOutAmountByKind = Movement.saida.not_entre_contas.where(payment_date: @date_range).group(:sub_kind_of).sum(:amount).sort

    @monthMovements = Movement.not_entre_contas.where(payment_date: @date_range).order(:payment_date)

    @monthAmountTithe = Movement.entrada.dizimo.where(payment_date: @date_range).sum(:amount)
    @monthTithe = Movement.entrada.dizimo.joins(:user).group('users.id').where(payment_date: @date_range)
                    .order('sum(movements.amount) DESC').pluck('users.id, users.first_name, users.last_name, sum(movements.amount)')

    @monthOffer = Movement.entrada.oferta.where(payment_date: @date_range).order(:payment_date)


    @monthlyMovementsInByCategory = Movement.entrada.not_entre_contas.group(:sub_kind_of).where(payment_date: @date_range).sum(:amount)
    @monthlyMovementsOutByCategory = Movement.saida.not_entre_contas.group(:sub_kind_of).where(payment_date: @date_range).sum(:amount)

    # Show latest five users
    @lastMembers = User.where.not(member_since: nil).order("member_since DESC").take(5)

    @monthBirthdays = User.where("EXTRACT(MONTH FROM birth_date) = ?", @month).order(Arel.sql("date_part('day', birth_date)"))

    daysBefore = Date.today.yday() - 15 <= 1   ? 1   : 15.days.before.yday()
    daysAfter  = Date.today.yday() + 15 >= 366 ? 366 : 15.days.after.yday()
    
    @upcomingBirthdays = User.where('EXTRACT(DOY FROM birth_date) BETWEEN ? AND ?', daysBefore, daysAfter).order(Arel.sql("date_part('doy', birth_date)"))

    @monthEvents = Event.where(start_date: @date_range).order("start_date DESC")
    @upcomigEvents = Event.where("start_date >= ?", DateTime.now-1.day).order(:start_date).limit(5)

    @employees = Administration.where('(EXTRACT(YEAR FROM start_date) <= ?) AND (EXTRACT(YEAR FROM end_date) >= ? OR end_date IS NULL)', @year, @year).order(:id)
  end
end