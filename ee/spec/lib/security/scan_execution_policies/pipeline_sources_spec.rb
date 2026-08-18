# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::PipelineSources, feature_category: :security_policy_management do
  describe '#including' do
    context 'when including is present' do
      it 'returns the including array' do
        pipeline_sources_data = { including: %w[push web] }
        pipeline_sources = described_class.new(pipeline_sources_data)
        expect(pipeline_sources.including).to match_array(%w[push web])
      end

      it 'handles single pipeline source' do
        pipeline_sources_data = { including: ['push'] }
        pipeline_sources = described_class.new(pipeline_sources_data)
        expect(pipeline_sources.including).to match_array(['push'])
      end

      it 'handles all valid pipeline source values from schema' do
        sources = %w[unknown push web trigger schedule api external pipeline chat merge_request_event
          external_pull_request_event]
        pipeline_sources_data = { including: sources }
        pipeline_sources = described_class.new(pipeline_sources_data)
        expect(pipeline_sources.including).to match_array(sources)
      end
    end

    context 'when including is not present' do
      it 'returns an empty array' do
        pipeline_sources = described_class.new({})
        expect(pipeline_sources.including).to be_empty
      end
    end

    context 'when pipeline_sources is nil' do
      it 'returns an empty array' do
        pipeline_sources = described_class.new(nil)
        expect(pipeline_sources.including).to be_empty
      end
    end
  end

  describe 'complete pipeline_sources configuration' do
    it 'handles pipeline_sources with multiple sources' do
      pipeline_sources_data = {
        including: %w[push web api merge_request_event]
      }
      pipeline_sources = described_class.new(pipeline_sources_data)

      expect(pipeline_sources.including).to match_array(%w[push web api merge_request_event])
    end
  end
end
