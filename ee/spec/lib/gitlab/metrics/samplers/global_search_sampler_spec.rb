# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::Samplers::GlobalSearchSampler, feature_category: :global_search do
  subject(:sampler) { described_class.new }

  before do
    allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
      .and_return(ActiveContextHelpers.code_collection_name)
  end

  it_behaves_like 'metrics sampler', 'GLOBAL_SEARCH_SAMPLER'

  describe '#sample' do
    it 'invokes the Elastic::MetricsUpdateService' do
      expect_next_instance_of(::Elastic::MetricsUpdateService) do |service|
        expect(service).to receive(:execute)
      end

      sampler.sample
    end

    it 'invokes the ::Ai::ActiveContext::MetricsUpdateService' do
      expect_next_instance_of(::Ai::ActiveContext::MetricsUpdateService) do |service|
        expect(service).to receive(:execute)
      end

      sampler.sample
    end
  end
end
