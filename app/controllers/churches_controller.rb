class ChurchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_church, only: %i[ show edit update destroy ]

  # GET /churches or /churches.json
  def index
    @churches = Church.all
  end

  # GET /churches/1 or /churches/1.json
  def show
  end

  # GET /churches/new
  def new
    @church = Church.new
  end

  # GET /churches/1/edit
  def edit
  end

  # POST /churches or /churches.json
  def create
    @church = Church.new(church_params)

    respond_to do |format|
      if @church.save
        format.html { redirect_to church_url(@church), notice: "Church was successfully created." }
        format.json { render :show, status: :created, location: @church }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @church.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /churches/1 or /churches/1.json
  def update
    respond_to do |format|
      if @church.update(church_params)
        format.html { redirect_to church_url(@church), notice: "Church was successfully updated." }
        format.json { render :show, status: :ok, location: @church }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @church.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /churches/1 or /churches/1.json
  def destroy
    @church.destroy

    respond_to do |format|
      format.html { redirect_to churches_url, notice: "Church was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_church
      @church = Church.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def church_params
      params.require(:church).permit(:name, :fundation_date)
    end
end
