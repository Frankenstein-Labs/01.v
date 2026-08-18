# frozen_string_literal: true

RSpec.shared_examples 'returns resource not available' do
  it 'returns a resource not available error' do
    result = defined?(resolved_metrics) ? resolved_metrics : resolved_risk_score
    expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
  end
end
