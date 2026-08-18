# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncMergeRequestsWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:policy) { create(:security_policy, :approval_policy, enabled: true, linked_projects: [project]) }

  let(:project_id) { project.id }
  let(:policy_id) { policy.id }

  subject(:perform) { described_class.new.perform(project_id, policy_id) }

  shared_examples_for 'it does not updates merge request approvals' do
    specify do
      expect(Security::SecurityOrchestrationPolicies::SyncMergeRequestsService).not_to receive(:new)

      perform
    end
  end

  context 'with non-existent project ID' do
    let(:project_id) { non_existing_record_id }

    it_behaves_like 'it does not updates merge request approvals'
  end

  context 'with non-existent policy ID' do
    let(:policy_id) { non_existing_record_id }

    it_behaves_like 'it does not updates merge request approvals'
  end

  context 'with project and policy' do
    it 'invokes SyncMergeRequestsService with the correct arguments' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::SyncMergeRequestsService,
        project: project,
        security_policy: policy) do |service|
        expect(service).to receive(:execute)
      end

      perform
    end
  end
end
