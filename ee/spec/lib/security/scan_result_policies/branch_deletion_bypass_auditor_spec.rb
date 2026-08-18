# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BranchDeletionBypassAuditor, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }

  before do
    allow(Gitlab::Audit::Auditor).to receive(:audit)
  end

  shared_examples 'bypass auditor' do |container_type|
    let(:container) { send(container_type) }
    let(:auditor) do
      described_class.new(
        security_policy: security_policy,
        container: container,
        user: user
      )
    end

    describe '#log_service_account_bypass' do
      let(:service_account_id) { 789 }

      it 'logs the bypass event with correct details' do
        auditor.log_service_account_bypass(service_account_id)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'security_policy_service_account_branch_deletion_bypass',
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: "Protected branch deletion for #{container_type} '#{container.full_path}' " \
            "has been bypassed by a service_account with ID: #{service_account_id}",
          additional_details: {
            container_id: container.id,
            container_type: container.class.name,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            bypass_type: :service_account,
            service_account_id: service_account_id,
            action: :branch_deletion
          }
        )
      end

      context 'with different service account ID' do
        let(:service_account_id) { 999 }

        it 'logs the bypass event with different service account ID' do
          auditor.log_service_account_bypass(service_account_id)

          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              message: "Protected branch deletion for #{container_type} '#{container.full_path}' " \
                "has been bypassed by a service_account with ID: #{service_account_id}",
              additional_details: hash_including(
                service_account_id: service_account_id
              )
            )
          )
        end
      end
    end

    describe '#log_access_token_bypass' do
      let(:token_ids) { [123, 456] }

      it 'logs the bypass event with correct details' do
        auditor.log_access_token_bypass(token_ids)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'security_policy_access_token_branch_deletion_bypass',
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: "Protected branch deletion for #{container_type} '#{container.full_path}' " \
            "has been bypassed by a access_token with ID: #{token_ids}",
          additional_details: {
            container_id: container.id,
            container_type: container.class.name,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            bypass_type: :access_token,
            access_token_ids: token_ids,
            action: :branch_deletion
          }
        )
      end

      context 'with single token ID' do
        let(:token_ids) { 789 }

        it 'logs the bypass event with single token ID' do
          auditor.log_access_token_bypass(token_ids)

          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              message: "Protected branch deletion for #{container_type} '#{container.full_path}' " \
                "has been bypassed by a access_token with ID: #{token_ids}",
              additional_details: hash_including(
                access_token_ids: [token_ids]
              )
            )
          )
        end
      end

      context 'with empty token IDs' do
        let(:token_ids) { [] }

        it 'logs the bypass event with empty token IDs' do
          auditor.log_access_token_bypass(token_ids)

          expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
            hash_including(
              additional_details: hash_including(
                access_token_ids: []
              )
            )
          )
        end
      end
    end
  end

  context 'with a project' do
    it_behaves_like 'bypass auditor', 'project'
  end

  context 'with a group' do
    it_behaves_like 'bypass auditor', 'group'
  end
end
