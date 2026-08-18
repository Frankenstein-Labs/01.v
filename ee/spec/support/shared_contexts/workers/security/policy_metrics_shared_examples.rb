# frozen_string_literal: true

RSpec.shared_examples_for 'policy metrics with logging' do |histogram_name|
  include_examples 'policy metrics histogram', histogram_name

  let(:expected_logged_data) { { 'duration' => kind_of(Float) } }

  it 'logs duration' do
    expect(Gitlab::AppJsonLogger).to receive(:debug).with(hash_including(expected_logged_data)).and_call_original

    subject
  end
end

RSpec.shared_examples_for 'policy metrics histogram' do |histogram_name|
  let(:histogram) do
    Security::SecurityOrchestrationPolicies::ObserveHistogramsService.histogram(histogram_name)
  end

  it 'logs histogram metrics' do
    expect(histogram).to receive(:observe).with(kind_of(Hash), kind_of(Float)).at_least(:once).and_call_original

    subject
  end
end
