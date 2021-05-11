module ProposalsHelper
  def proposal_types
    ProposalType.active_forms.map { |pt| [pt.name, pt.id] }
  end

  def locations
    Location.all.map { |loc| [loc.name, loc.id] }
  end

  def common_proposal_fields(proposal_type)
    proposal_form = proposal_type.proposal_forms&.where(status: :active)&.last
    proposal_form&.proposal_fields&.where(location_id: nil)
  end
end
