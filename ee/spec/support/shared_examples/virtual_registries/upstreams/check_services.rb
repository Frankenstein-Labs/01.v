# frozen_string_literal: true

RSpec.shared_examples 'a check upstream service handling no path set' do
  let(:path) { nil }
  let(:upstreams) { [] }

  it { is_expected.to eq(described_class::ERRORS[:path_not_present]) }
end

RSpec.shared_examples 'a check upstream service handling empty upstreams' do
  let(:path) { 'test' }
  let(:upstreams) { [] }

  it { is_expected.to eq(described_class::ERRORS[:file_not_found_on_upstreams]) }
end

RSpec.shared_examples 'returning a service success response with upstream' do
  it { is_expected.to be_success.and have_attributes(payload: { upstream: expected_upstream }) }
end
