class MovementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_movement, only: %i[ show edit update destroy ]
  before_action :set_header_panel

  # GET /movements or /movements.json
  def index
    @movements = Movement.where(payment_date: @date_range).order(:payment_date)
  end

  # GET /movements/1 or /movements/1.json
  def show
  end

  # GET /movements/new
  def new
    @movement = Movement.new
  end

  # GET /movements/1/edit
  def edit
  end

  # GET /movements/search_users - API endpoint for user search
  def search_users
    search_term = params[:q]
    
    begin
      if search_term.present?
        # Search users by name
        users = User.search_by_name(search_term).limit(10)
      else
        # Return recently used members when no search term
        users = User.recently_used_in_movements
      end
      
      # Format results for JSON response
      results = users.map(&:as_search_result)
      
      render json: {
        success: true,
        users: results,
        count: results.length
      }
    rescue => e
      render json: {
        success: false,
        error: 'Erro ao buscar usuários',
        message: e.message
      }, status: :internal_server_error
    end
  end

  # POST /movements or /movements.json
  def create
    # Process amount based on movement type before creating
    processed_params = movement_params.dup
    if processed_params[:amount].present? && processed_params[:kind_of].present?
      processed_params[:amount] = Movement.process_amount_by_type(
        processed_params[:amount], 
        processed_params[:kind_of]
      )
    end
    
    @movement = Movement.new(processed_params)

    respond_to do |format|
      if @movement.save
        success_message = "Movimentação criada com sucesso: #{@movement.income? ? 'Entrada' : 'Saída'} de R$ #{@movement.amount_for_display}"
        format.html { redirect_to movement_url(@movement), notice: success_message }
        format.json { render :show, status: :created, location: @movement }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @movement.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /movements/1 or /movements/1.json
  def update
    # Process amount based on movement type before updating
    processed_params = movement_params.dup
    if processed_params[:amount].present? && processed_params[:kind_of].present?
      processed_params[:amount] = Movement.process_amount_by_type(
        processed_params[:amount], 
        processed_params[:kind_of]
      )
    end
    
    respond_to do |format|
      if @movement.update(processed_params)
        success_message = "Movimentação atualizada com sucesso: #{@movement.income? ? 'Entrada' : 'Saída'} de R$ #{@movement.amount_for_display}"
        format.html { redirect_to movement_url(@movement), notice: success_message }
        format.json { render :show, status: :ok, location: @movement }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @movement.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /movements/1 or /movements/1.json
  def destroy
    @movement.destroy

    respond_to do |format|
      format.html { redirect_to movements_url, notice: "Movement was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_movement
      @movement = Movement.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def movement_params
      params.require(:movement).permit(:kind_of, :sub_kind_of, :wallet_id, :user_id, :amount, :payment_date, :description, :receipt)
    end
end
