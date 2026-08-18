# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReviewerAssignment::BaseStrategy, feature_category: :code_review_workflow do
  describe '.strategy_name' do
    it 'raises NotImplementedError' do
      expect { described_class.strategy_name }.to raise_error(NotImplementedError)
    end
  end

  describe '#select_reviewers' do
    let(:project) { build_stubbed(:project) }
    let(:merge_request) { build_stubbed(:merge_request, source_project: project) }

    it 'raises NotImplementedError' do
      strategy = described_class.new(merge_request)

      expect { strategy.select_reviewers }.to raise_error(NotImplementedError)
    end
  end
end
