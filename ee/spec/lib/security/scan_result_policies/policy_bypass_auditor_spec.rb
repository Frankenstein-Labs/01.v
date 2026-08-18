# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyBypassAuditor, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:branch_name) { 'main' }
  let_it_be(:security_policy) { create(:security_policy, linked_projects: [project]) }

  let(:bypass_context) { Security::ScanResultPolicies::BypassContexts::PushPolicyContext.new }
  let(:auditor) do
    described_class.new(
      security_policy: security_policy,
      project: project,
      user: user,
      branch_name: branch_name,
      bypass_context: bypass_context
    )
  end

  before do
    allow(Gitlab::Audit::Auditor).to receive(:audit)
  end

  describe '#log_access_token_bypass' do
    let(:token_ids) { [123, 456] }

    it 'logs the bypass event with correct details' do
      auditor.log_access_token_bypass(token_ids)

      expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
        name: 'security_policy_access_token_push_bypass',
        author: user,
        scope: security_policy.security_policy_management_project,
        target: security_policy,
        message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
          "has been bypassed by access_token with ID: #{token_ids}",
        additional_details: {
          project_id: project.id,
          security_policy_name: security_policy.name,
          security_policy_id: security_policy.id,
          branch_name: branch_name,
          bypass_type: :access_token,
          access_token_ids: token_ids
        }
      )
    end

    context 'with single token ID' do
      let(:token_ids) { [789] }

      it 'logs the bypass event with single token ID' do
        auditor.log_access_token_bypass(token_ids)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by access_token with ID: #{token_ids}",
            additional_details: hash_including(
              access_token_ids: token_ids
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

  describe '#log_service_account_bypass' do
    let(:service_account_id) { 789 }

    it 'logs the bypass event with correct details' do
      auditor.log_service_account_bypass(service_account_id)

      expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
        name: 'security_policy_service_account_push_bypass',
        author: user,
        scope: security_policy.security_policy_management_project,
        target: security_policy,
        message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
          "has been bypassed by service_account with ID: #{service_account_id}",
        additional_details: {
          project_id: project.id,
          security_policy_name: security_policy.name,
          security_policy_id: security_policy.id,
          branch_name: branch_name,
          bypass_type: :service_account,
          service_account_id: service_account_id
        }
      )
    end

    context 'with different service account ID' do
      let(:service_account_id) { 999 }

      it 'logs the bypass event with different service account ID' do
        auditor.log_service_account_bypass(service_account_id)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by service_account with ID: #{service_account_id}",
            additional_details: hash_including(
              service_account_id: service_account_id
            )
          )
        )
      end
    end
  end

  describe '#log_user_bypass' do
    let(:reason) { 'Emergency security fix' }

    context 'with group bypass scope' do
      let(:user_bypass_scope) { :group }
      let(:group_ids) { [1, 2, 3] }

      before do
        allow(security_policy.bypass_settings).to receive(:group_ids).and_return(group_ids)
      end

      it 'logs the bypass event with group details' do
        auditor.log_user_bypass(user_bypass_scope, reason)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'security_policy_user_push_bypass',
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
            "has been bypassed by user with ID: #{user.id} with reason: #{reason}",
          additional_details: {
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: branch_name,
            user_id: user.id,
            reason: reason,
            bypass_type: :group,
            group_ids: group_ids
          }
        )
      end
    end

    context 'with role bypass scope' do
      let(:user_bypass_scope) { :role }
      let(:default_roles) { %w[MAINTAINER DEVELOPER] }
      let(:custom_role_ids) { [4, 5, 6] }

      before do
        allow(security_policy.bypass_settings).to receive_messages(default_roles: default_roles,
          custom_role_ids: custom_role_ids)
      end

      it 'logs the bypass event with role details' do
        auditor.log_user_bypass(user_bypass_scope, reason)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          name: 'security_policy_user_push_bypass',
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
            "has been bypassed by user with ID: #{user.id} with reason: #{reason}",
          additional_details: {
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: branch_name,
            user_id: user.id,
            reason: reason,
            bypass_type: :role,
            default_roles: default_roles,
            custom_role_ids: custom_role_ids
          }
        )
      end
    end

    context 'when bypass context includes bypass reason in details' do
      let(:user_bypass_scope) { :group }

      before do
        allow(security_policy.bypass_settings).to receive(:group_ids).and_return([1])
        allow(bypass_context).to receive(:include_bypass_reason_in_details?).and_return(true)
      end

      it 'includes bypass_reason in additional_details' do
        auditor.log_user_bypass(user_bypass_scope, reason)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            additional_details: hash_including(
              bypass_reason: reason
            )
          )
        )
      end
    end

    context 'without reason' do
      let(:user_bypass_scope) { :group }
      let(:reason) { nil }

      before do
        allow(security_policy.bypass_settings).to receive(:group_ids).and_return([1])
      end

      it 'logs the bypass event without reason in message' do
        auditor.log_user_bypass(user_bypass_scope, reason)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by user with ID: #{user.id}",
            additional_details: hash_including(
              reason: nil
            )
          )
        )
      end
    end

    context 'with empty reason' do
      let(:user_bypass_scope) { :group }
      let(:reason) { '' }

      before do
        allow(security_policy.bypass_settings).to receive(:group_ids).and_return([1])
      end

      it 'logs the bypass event without reason in message' do
        auditor.log_user_bypass(user_bypass_scope, reason)

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Branch push restriction on '#{branch_name}' for project '#{project.full_path}' " \
              "has been bypassed by user with ID: #{user.id}",
            additional_details: hash_including(
              reason: ''
            )
          )
        )
      end
    end
  end

  describe '#log_merge_request_bypass' do
    let_it_be(:merge_request) { create(:merge_request) }
    let(:reason) { 'Emergency security fix' }
    let(:bypass_context) do
      Security::ScanResultPolicies::BypassContexts::MergeRequestContext.new(
        merge_request: merge_request, reason: reason
      )
    end

    it 'logs the bypass event with correct details' do
      auditor.log_merge_request_bypass

      expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
        name: 'security_policy_merge_request_bypass',
        author: user,
        scope: security_policy.security_policy_management_project,
        target: security_policy,
        message: "Security policy #{security_policy.name} in merge request " \
          "(#{project.full_path}!#{merge_request.iid}) has been bypassed by #{user.name} " \
          "with reason: #{reason}",
        additional_details: {
          project_id: project.id,
          security_policy_name: security_policy.name,
          security_policy_id: security_policy.id,
          branch_name: branch_name,
          bypass_type: :merge_request,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          reason: reason
        }
      )
    end

    context 'without reason' do
      let(:reason) { nil }

      it 'logs the bypass event without reason in message' do
        auditor.log_merge_request_bypass

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Security policy #{security_policy.name} in merge request " \
              "(#{project.full_path}!#{merge_request.iid}) has been bypassed by #{user.name}",
            additional_details: hash_including(
              reason: nil
            )
          )
        )
      end
    end

    context 'with empty reason' do
      let(:reason) { '' }

      it 'logs the bypass event without reason in message' do
        auditor.log_merge_request_bypass

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Security policy #{security_policy.name} in merge request " \
              "(#{project.full_path}!#{merge_request.iid}) has been bypassed by #{user.name}",
            additional_details: hash_including(
              reason: ''
            )
          )
        )
      end
    end

    context 'with different merge request' do
      let_it_be(:another_merge_request) { create(:merge_request) }
      let(:bypass_context) do
        Security::ScanResultPolicies::BypassContexts::MergeRequestContext.new(
          merge_request: another_merge_request, reason: reason
        )
      end

      it 'logs the bypass event with different merge request details' do
        auditor.log_merge_request_bypass

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            message: "Security policy #{security_policy.name} in merge request " \
              "(#{project.full_path}!#{another_merge_request.iid}) has been bypassed by #{user.name} " \
              "with reason: #{reason}",
            additional_details: hash_including(
              merge_request_id: another_merge_request.id,
              merge_request_iid: another_merge_request.iid
            )
          )
        )
      end
    end
  end
end
