# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ReviewerAssignment::StrategyFactory, feature_category: :code_review_workflow do
  describe '.build' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }

    context 'when strategy is code_owners' do
      before do
        allow(project.project_setting).to receive(:reviewer_assignment_strategy).and_return('code_owners')
      end

      it 'returns a CodeOwnersStrategy instance' do
        strategy = described_class.build(merge_request)

        expect(strategy).to be_a(MergeRequests::ReviewerAssignment::CodeOwnersStrategy)
      end
    end

    context 'when strategy is disabled' do
      before do
        allow(project.project_setting).to receive(:reviewer_assignment_strategy).and_return('disabled')
      end

      it 'returns nil' do
        expect(described_class.build(merge_request)).to be_nil
      end
    end

    context 'when strategy is unknown' do
      before do
        allow(project.project_setting).to receive(:reviewer_assignment_strategy).and_return('unknown')
      end

      it 'returns nil' do
        expect(described_class.build(merge_request)).to be_nil
      end
    end
  end
end
