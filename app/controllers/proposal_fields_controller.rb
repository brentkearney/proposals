class ProposalFieldsController < ApplicationController
  before_action :set_proposal_form, only: %i[new create edit update]
  before_action :set_proposal_field, only: %i[edit update]

  def new
    type = "ProposalFields::#{params[:field_type]}".safe_constantize.new
    @proposal_field = @proposal_form.proposal_fields.new(fieldable: type)
    render partial: 'proposal_fields/fields_form',
           locals: { proposal_field: @proposal_field, proposal_form: @proposal_form }
  end

  def create
    @fieldable = "ProposalFields::#{params[:type]}".safe_constantize.new
    options if params[:type].in?(%w[SingleChoice MultiChoice Radio])
    @proposal_field = @proposal_form.proposal_fields.new(proposal_field_params)
    @proposal_field.fieldable = @fieldable
    if @proposal_field.save
      @proposal_form.update(updated_by: current_user)
      redirect_to edit_proposal_form_path(@proposal_form), notice: "Field was successfully created."
    else
      redirect_to edit_proposal_form_path(@proposal_form), alert: @proposal_form.errors
    end
  end

  def latex_text
    session[:latex_text] = params[:text]
  end

  def edit
    render partial: 'proposal_fields/fields_form',
           locals: { proposal_field: @proposal_field, proposal_form: @proposal_form }
  end

  def update
    if @proposal_field.update(proposal_field_params)
      @proposal_form.update(updated_by: current_user)
      redirect_to edit_proposal_form_path(@proposal_form), notice: "Field was successfully updated."
    else
      redirect_to edit_proposal_form_path(@proposal_form), alert: @proposal_form.errors
    end
  end

  private

  def proposal_field_params
    params.require(:proposal_field).permit(:index, :description, :location_id, :statement)
  end

  def set_proposal_form
    @proposal_form = ProposalForm.find(params[:proposal_form_id])
  end

  def set_proposal_field
    @proposal_field = ProposalField.find_by(id: params[:id])
  end

  def options
    @fieldable.options = params[:proposal_field][:options]
  end
end
