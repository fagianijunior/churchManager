class ApplicationController < ActionController::Base

  private

  def set_header
    month = params[:month] ? params[:month].to_i : nil
    year = params[:year] ? params[:year].to_i : nil

    @month = (1..12).include?(month) ? month : Date.today.month
    @year  = (2022..(Date.today.year + 1)).include?(year) ? year : Date.today.year

    @date  = Date.strptime("#{@month},#{@year}","%m,%Y")
  end

  def set_header_panel
    set_header
    @header_panel=true
    @date_range = @date.beginning_of_month.beginning_of_day..@date.end_of_month.end_of_day

    @monthMovementsIn   = Movement.entrada.not_entre_contas.where(payment_date: @date_range).sum(:amount)
    @monthMovementsOut  = Movement.saida.not_entre_contas.where(payment_date: @date_range).sum(:amount)

    @previousMonthBalance  = Movement.not_entre_contas.where("payment_date <= ?", @date.prev_month.end_of_month.end_of_day).sum(:amount)
    
    @monthMovementsBalance = Movement.not_entre_contas.where("payment_date <= ?", @date.end_of_month.end_of_day).sum(:amount)
    @walletsBalances = Wallet.all
  end
end
