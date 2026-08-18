# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Policies::FailedPipelinesAuditWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:pipeline) { create(:ci_pipeline) }

    subject(:run_worker) { described_class.new.perform(pipeline_id) }

    shared_examples_for 'does not call PipelineFailedAuditor' do
      specify do
        expect(Security::SecurityOrchestrationPolicies::PipelineFailedAuditor).not_to receive(:new)

        run_worker
      end
    end

    context 'when pipeline is not found' do
      let(:pipeline_id) { non_existing_record_id }

      it_behaves_like 'does not call PipelineFailedAuditor'
    end

    context 'when pipeline exist' do
      let(:pipeline_id) { pipeline.id }

      context 'when security_orchestration_policies feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'calls PipelineFailedAuditor' do
          expect_next_instance_of(Security::SecurityOrchestrationPolicies::PipelineFailedAuditor,
            pipeline: pipeline) do |auditor|
            expect(auditor).to receive(:audit)
          end

          run_worker
        end

        it_behaves_like 'an idempotent worker' do
          let(:job_args) { pipeline.id }
        end
      end

      context 'when security_orchestration_policies feature is not available' do
        let(:pipeline_id) { pipeline.id }

        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'does not call PipelineFailedAuditor'
      end
    end
  end
end
