# frozen_string_literal: true

RSpec.shared_examples 'does not create state transition for same state' do
  it 'does not create a state transition entry' do
    expect { action }.not_to change { Vulnerabilities::StateTransition.count }
  end
end
