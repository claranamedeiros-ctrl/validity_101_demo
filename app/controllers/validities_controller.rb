class ValiditiesController < ApplicationController
  def new; end

  def create
    svc = AI::ValidityAnalysis::Service.new
    @result = svc.call(
      patent_number: params[:patent_number],
      claim_number: params[:claim_number],
      claim_text: params[:claim_text],
      abstract: params[:abstract]
    )
    if @result[:status] == :success
      redirect_to validity_path(id: SecureRandom.uuid, **@result) # pass via query just for demo
    else
      flash.now[:alert] = @result[:status_message]
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @result = params.permit!.to_h.symbolize_keys
  end
end