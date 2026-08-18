# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CollectPoliciesAuditEvents, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:fixed_time) { Time.current.round }
  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_project,
      configured_at: fixed_time
    )
  end

  let(:commit_sha) { 'a1b2c3d4e5f6' }
  let(:commit) do
    create(
      :commit,
      project: policy_project,
      sha: commit_sha,
      author: user
    )
  end

  let_it_be(:scan_execution_policy) do
    create(:security_policy, type: :scan_execution_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:approval_policy) do
    create(:security_policy, type: :approval_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:vulnerability_policy) do
    create(:security_policy, type: :vulnerability_management_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:created_policies) { [] }
  let(:updated_policies) { [] }
  let(:deleted_policies) { [] }

  let(:service) do
    described_class.new(
      policy_configuration: policy_configuration,
      created_policies: created_policies,
      updated_policies: updated_policies,
      deleted_policies: deleted_policies
    )
  end

  subject(:execute_service) { service.execute }

  before do
    allow(policy_configuration).to receive(:latest_commit_before_configured_at).and_return(commit)

    allow(Time).to receive(:current).and_return(fixed_time)
    allow(Gitlab::Audit::Auditor).to receive(:audit)
  end

  describe '#execute' do
    context 'when created policies are present' do
      let(:created_policies) { [scan_execution_policy, approval_policy] }

      it 'audits created policies with correct context' do
        execute_service

        created_policies.each do |policy|
          expected_message = "Created security policy with the name: \"#{policy.name}\""
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_create',
              author: user,
              scope: policy_project,
              target: policy,
              target_details: policy.name,
              message: expected_message,
              created_at: fixed_time,
              additional_details: {
                policy_id: policy.id,
                policy_name: policy.name,
                policy_type: policy.type,
                security_policy_project_commit_sha: commit_sha,
                security_policy_configured_at: policy_configuration.configured_at
              }
            )
          )
        end
      end
    end

    context 'when updated policies are present' do
      let(:updated_policies) { [approval_policy] }

      it 'audits updated policies with correct context' do
        execute_service

        updated_policies.each do |policy|
          expected_message = "Updated security policy with the name: \"#{policy.name}\""
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_update',
              author: user,
              scope: policy_project,
              target: policy,
              target_details: policy.name,
              message: expected_message,
              created_at: fixed_time,
              additional_details: {
                policy_id: policy.id,
                policy_name: policy.name,
                policy_type: policy.type,
                security_policy_project_commit_sha: commit_sha,
                security_policy_configured_at: policy_configuration.configured_at
              }
            )
          )
        end
      end
    end

    context 'when deleted policies are present' do
      let(:deleted_policies) { [vulnerability_policy] }

      it 'audits deleted policies with correct context' do
        execute_service

        deleted_policies.each do |policy|
          expected_message = "Deleted security policy with the name: \"#{policy.name}\""
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_delete',
              author: user,
              scope: policy_project,
              target: policy,
              target_details: policy.name,
              message: expected_message,
              created_at: fixed_time,
              additional_details: {
                policy_id: policy.id,
                policy_name: policy.name,
                policy_type: policy.type,
                security_policy_project_commit_sha: commit_sha,
                security_policy_configured_at: policy_configuration.configured_at
              }
            )
          )
        end
      end
    end

    context 'when policy lists are empty' do
      it 'does not call the auditor' do
        execute_service
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit)
      end
    end

    context 'when commit cannot be in the repository' do
      let(:created_policies) { [scan_execution_policy] }
      let(:default_user) { Gitlab::Audit::DeletedAuthor.new(id: -3, name: 'Unknown User') }

      before do
        allow(policy_configuration).to receive(:latest_commit_before_configured_at).and_return(nil)
        allow(Gitlab::Audit::DeletedAuthor).to receive(:new).and_return(default_user)
      end

      it 'uses default user as the author and commit sha as nil for audit context' do
        execute_service

        created_policies.each do |policy|
          expected_message = "Created security policy with the name: \"#{policy.name}\""
          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              name: 'security_policy_create',
              author: default_user,
              scope: policy_project,
              target: policy,
              target_details: policy.name,
              message: expected_message,
              created_at: fixed_time,
              additional_details: {
                policy_id: policy.id,
                policy_name: policy.name,
                policy_type: policy.type,
                security_policy_project_commit_sha: nil,
                security_policy_configured_at: policy_configuration.configured_at
              }
            )
          )
        end
      end
    end
  end
end
