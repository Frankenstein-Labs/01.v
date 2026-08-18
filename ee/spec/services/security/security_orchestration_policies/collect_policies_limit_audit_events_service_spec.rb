# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CollectPoliciesLimitAuditEventsService, feature_category: :security_policy_management do
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_management_project)
  end

  let(:approval_policy_limit) { 5 }
  let(:scan_execution_policy_limit) { 5 }
  let(:latest_commit) { build(:commit) }

  subject(:service) { described_class.new(policy_configuration) }

  def mock_other_policy_type_limits(policy_types)
    other_policy_types = Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES - policy_types
    other_policy_types.each do |type|
      allow(policy_configuration).to receive(:policy_limit_by_type).with(type).and_return(0)
    end
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    before do
      policy_configuration.clear_memoization(:policy_blob)

      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive_messages(blob_data_at: policy_yaml)
      end

      allow(policy_configuration).to receive(:latest_commit_before_configured_at).and_return(latest_commit)
    end

    context 'when policy limits are not exceeded' do
      before do
        allow(policy_configuration).to receive(:policy_limit_by_type)
          .with(:approval_policy).and_return(approval_policy_limit)

        allow(policy_configuration).to receive(:policy_limit_by_type)
          .with(:scan_execution_policy).and_return(scan_execution_policy_limit)

        mock_other_policy_type_limits([:approval_policy, :scan_execution_policy])
      end

      let(:approval_policies) { build_list(:approval_policy, approval_policy_limit) }
      let(:scan_execution_policies) { build_list(:scan_execution_policy, scan_execution_policy_limit) }

      let(:policy_yaml) do
        build(:orchestration_policy_yaml, approval_policy: approval_policies,
          scan_execution_policy: scan_execution_policies)
      end

      it 'does not create any audit events' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute_service
      end
    end

    context 'when policy limits are exceeded' do
      let(:audit_context) do
        {
          name: 'security_policy_limit_exceeded',
          message: "Policies limit exceeded for '#{type_name}' type. " \
            "Only the first #{mock_policy_limit} enabled policies will be applied",
          scope: policy_management_project,
          target: policy_management_project,
          author: latest_commit.author,
          additional_details: {
            policy_type: policy_type,
            policy_type_limit: mock_policy_limit,
            policies_count: policies.count,
            active_skipped_policies_count: policies.count - mock_policy_limit,
            active_policies_names: policies.first(mock_policy_limit).pluck(:name),
            active_skipped_policies_names: policies.drop(mock_policy_limit).pluck(:name),
            security_policy_project_commit_sha: latest_commit.sha,
            security_orchestration_policy_configuration_id: policy_configuration.id,
            security_policy_configured_at: policy_configuration.configured_at
          }
        }
      end

      shared_examples 'creating an audit event for the exceeded policy type' do
        it 'creates an audit event for the exceeded policy type' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(audit_context)

          execute_service
        end
      end

      where(:policy_type) do
        Security::OrchestrationPolicyConfiguration::AVAILABLE_POLICY_TYPES
      end

      with_them do
        let(:mock_policy_limit) { rand(2..6) }
        let(:type_name) { policy_configuration.policy_type_name_by_type(policy_type) }
        let(:policies) { build_list(policy_type, mock_policy_limit + 1) }
        let(:policy_yaml) do
          build(:orchestration_policy_yaml, policy_type => policies)
        end

        before do
          allow(policy_configuration).to receive(:policy_limit_by_type)
            .with(policy_type).and_return(mock_policy_limit)

          mock_other_policy_type_limits([policy_type])
        end

        it_behaves_like 'creating an audit event for the exceeded policy type'
      end

      context 'for multiple policy types' do
        let(:mock_policy_limit) { 2 }
        let(:scan_execution_policies) { build_list(:scan_execution_policy, mock_policy_limit + 1) }
        let(:approval_policies) { build_list(:approval_policy, mock_policy_limit + 1) }
        let(:policies) { build_list(policy_type, mock_policy_limit + 1) }

        let(:policy_yaml) do
          build(:orchestration_policy_yaml, scan_execution_policy: scan_execution_policies,
            approval_policy: approval_policies)
        end

        before do
          allow(policy_configuration).to receive(:policy_limit_by_type)
            .with(:scan_execution_policy).and_return(mock_policy_limit)
          allow(policy_configuration).to receive(:policy_limit_by_type)
            .with(:approval_policy).and_return(mock_policy_limit)

          mock_other_policy_type_limits([:scan_execution_policy, :approval_policy])
        end

        it 'creates an audit event for each exceeded policy type' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).twice

          execute_service
        end
      end

      context 'with disabled policies' do
        let(:mock_policy_limit) { 2 }
        let(:enabled_approval_policies) { build_list(:approval_policy, mock_policy_limit) }
        let(:disabled_approval_policies) { build_list(:approval_policy, 2, enabled: false) }
        let(:approval_policies) { enabled_approval_policies + disabled_approval_policies }
        let(:policy_yaml) do
          build(:orchestration_policy_yaml, approval_policy: approval_policies)
        end

        before do
          allow(policy_configuration).to receive(:policy_limit_by_type)
            .with(:approval_policy).and_return(mock_policy_limit)

          mock_other_policy_type_limits([:approval_policy])
        end

        it 'does not create an audit event if enabled policies are within the limit' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute_service
        end

        context 'when enabled policies exceed the limit' do
          let(:enabled_approval_policies) { build_list(:approval_policy, mock_policy_limit + 1) }

          it 'creates an audit event' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).once

            execute_service
          end
        end
      end
    end

    context 'when commit author is not available' do
      let(:mock_policy_limit) { 2 }
      let(:policy_type) { :approval_policy }
      let(:policies) { build_list(:approval_policy, mock_policy_limit + 1) }

      let(:policy_yaml) do
        build(:orchestration_policy_yaml, approval_policy: policies)
      end

      before do
        allow(policy_configuration).to receive(:policy_limit_by_type)
          .with(:approval_policy).and_return(mock_policy_limit)
        mock_other_policy_type_limits([:approval_policy])

        allow(policy_configuration).to receive(:latest_commit_before_configured_at).and_return(nil)
      end

      it 'audits with a deleted author' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          a_hash_including(
            author: an_instance_of(Gitlab::Audit::DeletedAuthor),
            additional_details: a_hash_including(security_policy_project_commit_sha: nil)
          )
        )

        execute_service
      end
    end
  end
end
