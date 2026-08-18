# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::PendingStatusCheckWorker, feature_category: :security_policy_management do
  describe "#perform" do
    let_it_be(:worker) { described_class.new }
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, :with_merge_request_pipeline, source_project: project) }
    let_it_be(:status_check) { create(:external_status_check, project: project) }
    let_it_be(:another_status_check) { create(:external_status_check, project: project) }

    let(:diff_head_sha) { 'example-branch' }
    let(:job_args) { [merge_request.id, project.id, diff_head_sha] }
    let(:expected_result) do
      [
        [status_check.id, merge_request.id, 'pending'],
        [another_status_check.id, merge_request.id, 'pending']
      ]
    end

    before do
      stub_licensed_features(external_status_checks: true)
    end

    it 'creates status checks on MR' do
      expect(merge_request.status_check_responses.count).to be(0)

      worker.perform(*job_args)

      expect(merge_request.status_check_responses.count).to be(2)
      expect(merge_request.status_check_responses.pluck(:external_status_check_id, :merge_request_id, :status))
        .to match_array(expected_result)
    end

    it_behaves_like 'an idempotent worker'

    context 'when an exception is raised' do
      before do
        allow(::MergeRequests::StatusCheckResponse).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it 'rescues the exception' do
        expect { worker.perform(*job_args) }.not_to raise_exception
      end
    end

    context 'when merge_request and project are missing' do
      let(:job_args) { [non_existing_record_id, non_existing_record_id, diff_head_sha] }

      it 'does not raise exception' do
        expect { worker.perform(*job_args) }.not_to raise_exception
      end
    end
  end
end
