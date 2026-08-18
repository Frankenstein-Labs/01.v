# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::BypassMergeRequestService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:bypass_settings) do
    {
      users: [{ id: user.id }],
      groups: [{ id: group.id }],
      roles: ['maintainer']
    }
  end

  let(:security_policy) do
    create(:security_policy, :approval_policy, linked_projects: [project], content: {
      actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }],
      bypass_settings: bypass_settings
    })
  end

  let(:other_security_policy) do
    create(:security_policy, :approval_policy, linked_projects: [project], content: {
      actions: [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[owner] }],
      bypass_settings: bypass_settings
    })
  end

  let(:params) do
    {
      security_policy_ids: [security_policy.id],
      reason: 'Emergency fix required'
    }
  end

  let(:service) { described_class.new(merge_request: merge_request, current_user: user, params: params) }

  before_all do
    project.add_developer(user)
    group.add_developer(other_user)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when security policies are found' do
      it 'returns success response' do
        expect(execute).to be_success
        expect(execute.payload[:merge_request]).to eq(merge_request)
      end

      it 'creates bypass event for each security policy' do
        expect { execute }.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

        bypass_event = Security::ApprovalPolicyMergeRequestBypassEvent.last
        expect(bypass_event.security_policy).to eq(security_policy)
        expect(bypass_event.project).to eq(merge_request.project)
        expect(bypass_event.user).to eq(user)
        expect(bypass_event.reason).to eq('Emergency fix required')
        expect(bypass_event.merge_request).to eq(merge_request)
      end

      it 'logs the bypass event through auditor' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'security_policy_merge_request_bypass',
          author: user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: match(/Security policy #{security_policy.name} in merge request/),
          additional_details: hash_including(
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: merge_request.target_branch,
            bypass_type: :merge_request,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            reason: 'Emergency fix required'
          )
        )

        execute
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end

      context 'with multiple security policies' do
        let(:params) do
          {
            security_policy_ids: [security_policy.id, other_security_policy.id],
            reason: 'Emergency fix required'
          }
        end

        it 'processes all security policies' do
          expect { execute }.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(2)

          bypass_events = Security::ApprovalPolicyMergeRequestBypassEvent.last(2)
          expect(bypass_events.map(&:security_policy)).to contain_exactly(security_policy, other_security_policy)
        end

        it 'returns success response' do
          expect(execute).to be_success
        end

        it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
          let(:action) { execute }
        end

        it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
          let(:action) { execute }
        end
      end
    end

    context 'when no security policies are found' do
      let(:params) do
        {
          security_policy_ids: [999999],
          reason: 'Emergency fix required'
        }
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Security policies not found')
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when reason is blank' do
      let(:params) do
        {
          security_policy_ids: [security_policy.id],
          reason: ''
        }
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Reason is required')
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when reason is nil' do
      let(:params) do
        {
          security_policy_ids: [security_policy.id],
          reason: nil
        }
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Reason is required')
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when security policy is already bypassed' do
      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: security_policy,
          project: project,
          user: user,
          merge_request: merge_request,
          reason: 'Previous bypass'
        )
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('You have already bypassed this security policy.')
      end

      it 'does not create additional bypass event' do
        expect { execute }.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when user is not allowed to bypass security policy' do
      let_it_be(:unauthorized_user) { create(:user) }
      let(:service) do
        described_class.new(merge_request: merge_request, current_user: unauthorized_user, params: params)
      end

      before_all do
        project.add_developer(unauthorized_user)
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('You are not allowed to bypass this security policy.')
      end

      it 'does not create bypass event' do
        expect { execute }.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'with multiple security policies where one is already bypassed' do
      let(:params) do
        {
          security_policy_ids: [security_policy.id, other_security_policy.id],
          reason: 'Emergency fix required'
        }
      end

      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: other_security_policy,
          project: project,
          user: user,
          merge_request: merge_request,
          reason: 'Previous bypass'
        )
      end

      it 'returns error response for the first already bypassed policy' do
        expect(execute).to be_error
        expect(execute.message).to eq('You have already bypassed this security policy.')
      end

      it 'does not process remaining policies' do
        expect { execute }.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'with multiple security policies where user is not allowed to bypass one' do
      let_it_be(:unauthorized_user) { create(:user) }
      let(:service) do
        described_class.new(merge_request: merge_request, current_user: unauthorized_user, params: params)
      end

      let(:params) do
        {
          security_policy_ids: [security_policy.id, other_security_policy.id],
          reason: 'Emergency fix required'
        }
      end

      before_all do
        project.add_developer(unauthorized_user)
      end

      it 'returns error response for the first policy user cannot bypass' do
        expect(execute).to be_error
        expect(execute.message).to eq('You are not allowed to bypass this security policy.')
      end

      it 'does not process remaining policies' do
        expect { execute }.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'does not trigger GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when current user is a project bot with access token bypass' do
      let_it_be(:bot_user) { create(:user, :project_bot) }
      let_it_be(:token) { create(:personal_access_token, user: bot_user) }

      let(:bypass_settings) do
        { access_tokens: [{ id: token.id }] }
      end

      let(:service) do
        described_class.new(merge_request: merge_request, current_user: bot_user, params: params)
      end

      before_all do
        project.add_developer(bot_user)
      end

      it 'returns success response' do
        expect(execute).to be_success
        expect(execute.payload[:merge_request]).to eq(merge_request)
      end

      it 'creates bypass event' do
        expect { execute }.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

        bypass_event = Security::ApprovalPolicyMergeRequestBypassEvent.last
        expect(bypass_event.security_policy).to eq(security_policy)
        expect(bypass_event.user).to eq(bot_user)
        expect(bypass_event.reason).to eq('Emergency fix required')
      end

      it 'logs the bypass event with access token details through auditor' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'security_policy_merge_request_bypass',
          author: bot_user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: match(/bypassed by access token #{bot_user.name}/),
          additional_details: hash_including(
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            bypass_type: :access_token,
            access_token_ids: [token.id],
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            reason: 'Emergency fix required'
          )
        )

        execute
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when current user is a service account with service account bypass' do
      let_it_be(:service_account_user) { create(:user, :service_account) }

      let(:bypass_settings) do
        { service_accounts: [{ id: service_account_user.id }] }
      end

      let(:service) do
        described_class.new(merge_request: merge_request, current_user: service_account_user, params: params)
      end

      before_all do
        project.add_developer(service_account_user)
      end

      it 'returns success response' do
        expect(execute).to be_success
        expect(execute.payload[:merge_request]).to eq(merge_request)
      end

      it 'creates bypass event' do
        expect { execute }.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

        bypass_event = Security::ApprovalPolicyMergeRequestBypassEvent.last
        expect(bypass_event.security_policy).to eq(security_policy)
        expect(bypass_event.user).to eq(service_account_user)
        expect(bypass_event.reason).to eq('Emergency fix required')
      end

      it 'logs the bypass event with service account details through auditor' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'security_policy_merge_request_bypass',
          author: service_account_user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: match(/bypassed by service account #{service_account_user.name}/),
          additional_details: hash_including(
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            bypass_type: :service_account,
            service_account_id: service_account_user.id,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            reason: 'Emergency fix required'
          )
        )

        execute
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestApprovalStateUpdated' do
        let(:action) { execute }
      end

      it_behaves_like 'triggers GraphQL subscription mergeRequestMergeStatusUpdated' do
        let(:action) { execute }
      end
    end

    context 'when current user is a bot authorized via role bypass settings' do
      let_it_be(:bot_user) { create(:user, :project_bot) }

      let(:bypass_settings) do
        { roles: ['maintainer'] }
      end

      let(:service) do
        described_class.new(merge_request: merge_request, current_user: bot_user, params: params)
      end

      before_all do
        project.add_maintainer(bot_user)
      end

      it 'returns success response' do
        expect(execute).to be_success
        expect(execute.payload[:merge_request]).to eq(merge_request)
      end

      it 'creates bypass event' do
        expect { execute }.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)
      end

      it 'logs the bypass event as a merge request bypass through auditor' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'security_policy_merge_request_bypass',
          author: bot_user,
          scope: security_policy.security_policy_management_project,
          target: security_policy,
          message: match(/Security policy #{security_policy.name} in merge request/),
          additional_details: hash_including(
            project_id: project.id,
            security_policy_name: security_policy.name,
            security_policy_id: security_policy.id,
            branch_name: merge_request.target_branch,
            bypass_type: :merge_request,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            reason: 'Emergency fix required'
          )
        )

        execute
      end
    end

    context 'when bot user is not configured in bypass_settings' do
      let_it_be(:bot_user) { create(:user, :project_bot) }

      let(:service) do
        described_class.new(merge_request: merge_request, current_user: bot_user, params: params)
      end

      before_all do
        project.add_developer(bot_user)
      end

      it 'returns error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('You are not allowed to bypass this security policy.')
      end

      it 'does not create bypass event' do
        expect { execute }.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end
    end
  end
end
