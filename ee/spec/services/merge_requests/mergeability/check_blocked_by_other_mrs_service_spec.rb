# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckBlockedByOtherMrsService, feature_category: :code_review_workflow do
  subject(:check_blocked_by_other_mrs) { described_class.new(merge_request: merge_request, params: params) }

  let(:params) { { skip_blocked_check: skip_check } }
  let(:skip_check) { false }
  let(:merge_request) { build(:merge_request) }

  let_it_be(:blocking_merge_request) { build(:merge_request) }

  it_behaves_like 'mergeability check service', :merge_request_blocked, 'Checks whether the merge request is blocked'

  describe "#execute" do
    let(:result) { check_blocked_by_other_mrs.execute }

    before do
      allow(merge_request)
        .to receive(:blocking_merge_requests_feature_available?)
        .and_return(blocking_merge_requests_feature_available?)
    end

    context "when blocking_merge_requests feature is unavailable" do
      let(:blocking_merge_requests_feature_available?) { false }

      it "returns a check result with status inactive" do
        expect(result.status)
          .to eq Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      end
    end

    context "when blocking_merge_requests feature is available" do
      let(:blocking_merge_requests_feature_available?) { true }

      context "when there are no blocking MRs" do
        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
        end
      end

      context "when there are blocking MRs" do
        before do
          expect(merge_request).to receive(:blocking_merge_requests).and_return([blocking_merge_request])
        end

        it "returns a check result with status success" do
          expect(result.status)
            .to eq Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
          expect(result.payload[:identifier]).to eq(:merge_request_blocked)
        end
      end
    end
  end

  describe "#skip?" do
    context 'when skip check param is true' do
      let(:skip_check) { true }

      it 'returns true' do
        expect(check_blocked_by_other_mrs.skip?).to be true
      end
    end

    context 'when skip check param is false' do
      let(:skip_check) { false }

      it 'returns false' do
        expect(check_blocked_by_other_mrs.skip?).to be false
      end
    end
  end

  describe "#cacheable?" do
    it "returns false" do
      expect(check_blocked_by_other_mrs.cacheable?).to be false
    end
  end
end
