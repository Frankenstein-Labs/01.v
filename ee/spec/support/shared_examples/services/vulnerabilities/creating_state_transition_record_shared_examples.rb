# frozen_string_literal: true

RSpec.shared_examples 'creating state transition record' do |state|
  let(:extra_attributes) { {} }
  let(:expected_state_transition_relation) do
    Vulnerabilities::StateTransition.where(
      vulnerability: vulnerability,
      vulnerability_occurrence_id: vulnerability.finding_id,
      from_state: vulnerability.state,
      to_state: state,
      author: user,
      comment: comment,
      **extra_attributes
    )
  end

  it 'creates state transition record with correct attributes' do
    expect { subject }.to change { expected_state_transition_relation.count }.by(1)
  end
end
