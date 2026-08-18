# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Mergeability::CheckRequestedChangesService, feature_category: :code_review_workflow do
  subject(:service) { described_class.new(merge_request: merge_request, params: params) }

  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { build(:project) }
  let_it_be(:merge_request, freeze: false) { build(:merge_request, source_project: project, reviewers: [build(:user)]) }
  let(:params) { { skip_requested_changes_check: skip_check } }
  let(:skip_check) { false }

  let(:result) { service.execute }

  describe "#skip?" do
    context 'when skip check param is true' do
      let(:skip_check) { true }

      it 'returns true' do
        expect(service.skip?).to be true
      end
    end

    context 'when skip check param is false' do
      let(:skip_check) { false }

      it 'returns false' do
        expect(service.skip?).to be false
      end
    end
  end

  describe '#cacheable?' do
    it 'returns false' do
      expect(service.cacheable?).to be false
    end
  end

  context 'when license is invalid' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: false)
    end

    it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS }
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    describe 'when no reviewer has requested changes' do
      it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS }
    end

    describe 'when a reviewer has requested changes' do
      before_all do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: create(:user))
      end

      it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS }
    end

    describe 'when override_requested_changes is set' do
      let_it_be(:merge_request, freeze: false) do
        build(:merge_request, source_project: project, override_requested_changes: true)
      end

      it { expect(result.status).to eq Gitlab::MergeRequests::Mergeability::CheckResult::WARNING_STATUS }
    end
  end
end
