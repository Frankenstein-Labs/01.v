# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequests::Mergeability::CheckExternalStatusChecksPassedService,
  feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  subject(:check_external_status_checks_passed_service) do
    described_class.new(merge_request: merge_request, params: params)
  end

  let(:merge_request) { build(:merge_request) }
  let(:params) { { skip_external_status_check: skip_check } }
  let(:skip_check) { false }

  it_behaves_like 'mergeability check service', :status_checks_must_pass,
    'Checks whether the external status checks pass'

  describe "#execute" do
    let(:result) { check_external_status_checks_passed_service.execute }

    where(
      :only_allow_merge_if_all_status_checks_passed_enabled?,
      :any_external_status_checks_not_passed?,
      :expected_status
    ) do
      true  | false | Gitlab::MergeRequests::Mergeability::CheckResult::SUCCESS_STATUS
      false | true  | Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      false | false | Gitlab::MergeRequests::Mergeability::CheckResult::INACTIVE_STATUS
      true  | true  | Gitlab::MergeRequests::Mergeability::CheckResult::FAILED_STATUS
    end

    with_them do
      before do
        allow(subject).to receive(:only_allow_merge_if_all_status_checks_passed_enabled?)
                            .and_return(only_allow_merge_if_all_status_checks_passed_enabled?)
        allow(merge_request.project).to receive(:any_external_status_checks_not_passed?)
                            .and_return(any_external_status_checks_not_passed?)
      end

      it "returns correct status" do
        expect(result.status).to eq(expected_status)
        expect(result.payload[:identifier]).to eq(:status_checks_must_pass)
      end
    end
  end

  describe '#only_allow_merge_if_all_status_checks_passed_enabled?' do
    let(:result) { subject.send(:only_allow_merge_if_all_status_checks_passed_enabled?, merge_request.project) }

    where(:license, :column_value, :return_value) do
      false | false | false
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(external_status_checks: license)
        allow(merge_request.project).to receive(:only_allow_merge_if_all_status_checks_passed).and_return(column_value)
      end

      it 'returns correct value' do
        expect(result).to eq(return_value)
      end
    end
  end

  describe "#skip?" do
    context 'when skip check param is true' do
      let(:skip_check) { true }

      it 'returns true' do
        expect(check_external_status_checks_passed_service.skip?).to be true
      end
    end

    context 'when skip check param is false' do
      let(:skip_check) { false }

      it 'returns false' do
        expect(check_external_status_checks_passed_service.skip?).to be false
      end
    end
  end

  describe "#cacheable?" do
    it "returns false" do
      expect(check_external_status_checks_passed_service.cacheable?).to be false
    end
  end
end
