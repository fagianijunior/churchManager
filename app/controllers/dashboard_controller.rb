class DashboardController < ApplicationController
  def index
    month = params[:month] ? params[:month].to_i : nil
    year = params[:year] ? params[:year].to_i : nil

    @month = (1..12).include?(month) ? month : Date.today.month
    @year  = (2022..Date.today.year).include?(year) ? year : Date.today.year

    date  = Date.strptime("#{@month},#{@year}","%m,%Y")
    @date_range = date.beginning_of_month..date.end_of_month

    @monthMovementsIn      = Movement.entrada.where(payment_date: @date_range).sum(:amount)
    @monthMovementsOut     = Movement.saida.where(payment_date: @date_range).sum(:amount)

    @monthMovementsBalance = Movement.where("payment_date <= ?", date.end_of_month).sum(:amount)
    @monthMovementsChart   = Movement.group(:kind_of).group_by_day(:payment_date).where(payment_date: @date_range).sum(:amount)
    # Needs to be a cumulative calculation
    @monthMovementsBalanceChart = Movement.group_by_month(:payment_date).where('payment_date <= ?', date.end_of_month).sum(:amount)
    accumulator = 0
    @monthMovementsBalanceChart.transform_values! do |val|
      val += accumulator
      accumulator = val
    end
    
    @monthTithe = Wallet.dizimo.first.movements.entrada.where(payment_date: @date_range).order("amount DESC")


    # Show latest ten users
    @latestUsers = User.order("member_since DESC").take(10)

    @monthBirthdays = User.where("EXTRACT(MONTH FROM birth_date) = ?", @month).order(:birth_date)

    @upcomingBirthdays = User.where('EXTRACT(DOY FROM birth_date) >= ? AND EXTRACT(DOY FROM birth_date) <= ?',
      15.days.before.yday(), 15.days.after.yday()).order(:birth_date)

  end
end
