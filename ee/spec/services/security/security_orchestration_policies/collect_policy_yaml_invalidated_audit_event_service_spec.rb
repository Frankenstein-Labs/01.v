# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CollectPolicyYamlInvalidatedAuditEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: project)
  end

  subject(:service) { described_class.new(policy_configuration) }

  describe '#execute' do
    before do
      allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
    end

    context 'when policy configuration is valid' do
      before do
        allow(policy_configuration).to receive(:policy_configuration_valid?).and_return(true)
      end

      it 'does not create an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        service.execute
      end
    end

    context 'when policy configuration is invalid' do
      before do
        allow(policy_configuration).to receive_messages(
          policy_configuration_valid?: false,
          latest_commit_before_configured_at: commit
        )
      end

      context 'when commit is present' do
        let(:commit) { build(:commit, project: project, author: user) }

        let(:audit_context) do
          {
            name: 'security_policy_yaml_invalidated',
            author: user,
            scope: project,
            target: project,
            message: 'The policy YAML has been invalidated in the security policy project. ' \
              'Security policies will no longer be enforced.',
            additional_details: {
              security_policy_project_commit_sha: commit&.sha,
              security_orchestration_policy_configuration_id: policy_configuration.id
            }
          }
        end

        it 'creates an audit event with the correct attributes' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

          service.execute
        end
      end

      context 'when commit is not present' do
        let(:commit) { nil }

        it 'creates an audit event with an unknown author' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'security_policy_yaml_invalidated',
              author: a_kind_of(::Gitlab::Audit::DeletedAuthor),
              additional_details: hash_including(security_policy_project_commit_sha: be_nil)
            )
          )

          service.execute
        end
      end
    end
  end
end
