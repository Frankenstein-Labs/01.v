# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PolicyViolationsResolvedAuditEventWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, name: 'SP Test') }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:merge_request) do
    create(:merge_request, title: "Test MR", source_project: project, target_project: project)
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    include_examples 'an idempotent worker' do
      let(:job_args) { merge_request.id }
    end

    context 'when a merge request is not found' do
      it 'logs and does not call PolicyViolationsResolvedAuditEventService' do
        expect(Sidekiq.logger).to receive(:info).with(
          hash_including('message' => 'Merge request not found.', 'merge_request_id' => non_existing_record_id)
        )
        expect(MergeRequests::PolicyViolationsResolvedAuditEventService).not_to receive(:new).with(anything)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when a merge request is found' do
      it 'calls PolicyViolationsResolvedAuditEventService' do
        expect_next_instance_of(MergeRequests::PolicyViolationsResolvedAuditEventService, merge_request) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(merge_request.id)
      end
    end
  end
end
