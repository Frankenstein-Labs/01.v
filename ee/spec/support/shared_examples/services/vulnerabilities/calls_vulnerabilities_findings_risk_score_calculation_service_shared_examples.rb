# frozen_string_literal: true

RSpec.shared_examples 'calls Vulnerabilities::Findings::RiskScoreCalculationService' do
  before do
    allow(Vulnerabilities::Findings::RiskScoreCalculationService).to receive(:calculate_for)
  end

  it 'calls the service class' do
    subject

    expect(Vulnerabilities::Findings::RiskScoreCalculationService).to have_received(:calculate_for)
  end
end
