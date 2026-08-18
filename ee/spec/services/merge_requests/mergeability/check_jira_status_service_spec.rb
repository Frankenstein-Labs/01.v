# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Mergeability::CheckJiraStatusService, feature_category: :code_review_workflow do
  subject(:check_jira_status) { described_class.new(merge_request: merge_request, params: params) }

  let_it_be(:jira_integration, freeze: false) { create(:jira_integration) }
  let_it_be(:project) { build(:project) }
  let_it_be(:merge_request, freeze: false) { build(:merge_request, source_project: project) }
  let(:params) { { skip_jira_check: skip_check } }
  let(:skip_check) { false }

  it_behaves_like 'mergeability check service', :jira_association_missing,
    'Checks whether the title or description references a Jira issue.'

  describe '#execute' do
    let(:result) { check_jira_status.execute }

    before do
      allow(project).to receive(:jira_integration).and_return(jira_integration)
      allow(project).to receive(:prevent_merge_without_jira_issue?).and_return(prevent_merge)
    end

    context 'when prevent merge is true' do
      let(:prevent_merge) { true }

      context 'when the merge request has a key' do
        before do
          merge_request.title = 'PROJECT-1'
        end

        it 'returns a check result with status success' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context 'when the merge request does not have a key' do
        before do
          merge_request.title = 'Hello'
        end

        it 'returns a check result with status failed' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
          expect(result.payload[:reason]).to eq :jira_association_missing
        end
      end
    end

    context 'when prevent merge is false' do
      let(:prevent_merge) { false }

      context 'when the merge request has a key' do
        before do
          merge_request.title = 'PROJECT-1'
        end

        it 'returns a check result with inactive status' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end

      context 'when the merge request does not have a key' do
        before do
          merge_request.title = 'Hello'
        end

        it 'returns a check result with inactive status' do
          expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
        end
      end
    end
  end

  describe '#skip?' do
    context 'when skip check param is true' do
      let(:skip_check) { true }

      it 'returns true' do
        expect(check_jira_status.skip?).to be true
      end
    end

    context 'when skip check param is false' do
      let(:skip_check) { false }

      it 'returns false' do
        expect(check_jira_status.skip?).to be false
      end
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(check_jira_status.cacheable?).to be false
    end
  end
end
