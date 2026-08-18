# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::UpdateApprovalRulesForRelatedMrsWorker, feature_category: :code_review_workflow do
  describe '#perform' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
    let_it_be(:base_pipeline) do
      create(:ee_ci_pipeline, :success, project: project,
        ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
    end

    let_it_be_with_reload(:head_pipeline) do
      create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch)
    end

    let_it_be(:base_pipeline_id) { base_pipeline.id }

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [base_pipeline_id] }
    end

    context "when the pipeline is a base pipeline of some merge requests" do
      before do
        merge_request.update!(head_pipeline_id: head_pipeline.id)
      end

      it 'calls SyncReportsToApprovalRulesService for the head pipelines' do
        expect(::Ci::SyncReportsToApprovalRulesService).to receive(:new).with(head_pipeline).and_call_original

        described_class.new.perform(base_pipeline_id)
      end

      context 'when base pipeline is missing' do
        let(:base_pipeline_id) { non_existing_record_id }

        it 'does not call SyncReportsToApprovalRulesService' do
          expect(::Ci::SyncReportsToApprovalRulesService).not_to receive(:new)

          described_class.new.perform(base_pipeline_id)
        end
      end

      context 'when head_pipeline is not completed' do
        before do
          head_pipeline.update!(status: 'running')
        end

        it 'does not call SyncReportsToApprovalRulesService for the head pipeline' do
          expect(::Ci::SyncReportsToApprovalRulesService).not_to receive(:new).with(head_pipeline)

          described_class.new.perform(base_pipeline_id)
        end
      end

      context 'when there are too many merge requests' do
        it 'limits the number of merge requests to update' do
          stub_const("#{described_class}::MAX_BATCHES_COUNT", 1)
          stub_const("#{described_class}::EACH_BATCH_COUNT", 2)

          3.times { create_merge_request_with_completed_pipeline }

          expect(::Ci::SyncReportsToApprovalRulesService).to receive(:new).twice.and_call_original
          described_class.new.perform(base_pipeline_id)
        end
      end

      context 'when there is no approval rule' do
        before do
          ApprovalMergeRequestRule.id_in(approval_rule.id).delete_all
        end

        it 'does not call SyncReportsToApprovalRulesService' do
          expect(::Ci::SyncReportsToApprovalRulesService).not_to receive(:new).with(head_pipeline)

          described_class.new.perform(base_pipeline_id)
        end
      end
    end
  end

  def create_merge_request_with_completed_pipeline
    merge_request = create(:merge_request, source_project: project, source_branch: generate(:branch))
    head_pipeline = create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch)
    merge_request.update!(head_pipeline_id: head_pipeline.id)
    merge_request.merge_request_diff.update!(base_commit_sha: base_pipeline.sha)
  end
end
