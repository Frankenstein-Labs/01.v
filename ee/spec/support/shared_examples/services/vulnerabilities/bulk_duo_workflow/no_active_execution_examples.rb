# frozen_string_literal: true

RSpec.shared_examples 'returns not_found when there is no active execution' do |**params|
  it 'returns an error', :aggregate_failures do
    execution.complete!

    response = described_class.new(
      project: project,
      workflow: workflow,
      current_user: current_user,
      **params
    ).execute

    expect(response).to be_error
    expect(response.message).to eq('No active execution')
    expect(response.reason).to eq(:not_found)
  end
end
