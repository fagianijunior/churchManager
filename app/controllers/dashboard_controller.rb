class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    month = params[:month] ? params[:month].to_i : nil
    year = params[:year] ? params[:year].to_i : nil

    @month = (1..12).include?(month) ? month : Date.today.month
    @year  = (2022..Date.today.year).include?(year) ? year : Date.today.year

    date  = Date.strptime("#{@month},#{@year}","%m,%Y")
    @date_range = date.beginning_of_month..date.end_of_month

    @monthMovementsIn      = Movement.where.not(kind_of: ['saida', 'entre_contas']).where(payment_date: @date_range).sum(:amount)
    @monthMovementsOut     = Movement.saida.where(payment_date: @date_range).sum(:amount)

    @monthMovementsBalance = Movement.where("payment_date <= ?", date.end_of_month).sum(:amount)
    @monthMovementsChart   = Movement.where.not(kind_of: 'entre_contas').group(:kind_of).group_by_day(:payment_date).where(payment_date: @date_range).sum(:amount)

    @monthlyStatement      = Movement.where.not(kind_of: 'entre_contas').where(payment_date: @date_range)

    @monthMovementsBalanceChart = Movement.group_by_month(:payment_date).where('payment_date <= ?', date.end_of_month).sum(:amount)
    accumulator = 0
    @monthMovementsBalanceChart.transform_values! do |val|
      val += accumulator
      accumulator = val
    end
    
    @monthTithe = Movement.dizimo.where(payment_date: @date_range).order("amount DESC")

    # Show latest five users
    @lastMembers = User.where.not(member_since: nil).order("member_since DESC").take(5)

    @monthBirthdays = User.where("EXTRACT(MONTH FROM birth_date) = ?", @month).order("birth_date DESC")

    daysBefore = Date.today.yday() - 15 <= 1   ? 1   : 15.days.before.yday()
    daysAfter  = Date.today.yday() + 15 >= 366 ? 366 : 15.days.after.yday()
    
    @upcomingBirthdays = User.where('EXTRACT(DOY FROM birth_date) BETWEEN ? AND ?', daysBefore, daysAfter)
                             .order(:birth_date)

    @monthEvents = Event.where(start_date: @date_range).order("start_date DESC")
    @upcomigEvents = Event.where("start_date >= ?", DateTime.now-1.day).order(:start_date).limit(5)

    @administration = Administration.where('(EXTRACT(YEAR FROM start_date) <= ?) AND (EXTRACT(YEAR FROM end_date) >= ? OR end_date IS NULL)', @year, @year)

  end
end