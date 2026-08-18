# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Bypassing security policy for a merge request', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:group) { create(:group) }

  let(:bypass_settings) do
    {
      users: [{ id: current_user.id }],
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

  let(:input) do
    {
      security_policy_ids: [security_policy.id],
      reason: 'Emergency fix required'
    }
  end

  def mutation(vars = input, mr = merge_request)
    variables = vars.merge(project_path: mr.project.full_path, iid: mr.iid.to_s)

    graphql_mutation(:merge_request_bypass_security_policy, variables, <<-QL.strip_heredoc)
      clientMutationId
      errors
      mergeRequest {
        id
        iid
      }
    QL
  end

  def mutation_response
    graphql_mutation_response(:merge_request_bypass_security_policy)
  end

  before_all do
    group.add_maintainer(current_user)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_merge_request do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :merge_request_bypass_security_policy,
        { project_path: project.full_path, iid: merge_request.iid.to_s }.merge(input),
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  describe 'successful bypass' do
    it 'bypasses the security policy successfully' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['mergeRequest']['id']).to eq(merge_request.to_global_id.to_s)
    end

    it 'creates bypass event with correct attributes' do
      post_graphql_mutation(mutation, current_user: current_user)

      bypass_event = Security::ApprovalPolicyMergeRequestBypassEvent.last
      expect(bypass_event.security_policy).to eq(security_policy)
      expect(bypass_event.project).to eq(merge_request.project)
      expect(bypass_event.user).to eq(current_user)
      expect(bypass_event.reason).to eq('Emergency fix required')
      expect(bypass_event.merge_request).to eq(merge_request)
    end

    it 'logs the bypass event through auditor' do
      expect(Gitlab::Audit::Auditor).to receive(:audit).with(
        name: 'security_policy_merge_request_bypass',
        author: current_user,
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

      post_graphql_mutation(mutation, current_user: current_user)
    end
  end

  describe 'multiple security policies' do
    let(:input) do
      {
        security_policy_ids: [security_policy.id, other_security_policy.id],
        reason: 'Emergency fix required'
      }
    end

    it 'bypasses multiple security policies successfully' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(2)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      bypass_events = Security::ApprovalPolicyMergeRequestBypassEvent.last(2)
      expect(bypass_events.map(&:security_policy)).to contain_exactly(security_policy, other_security_policy)
    end
  end

  describe 'error scenarios' do
    context 'when security policies are not found' do
      let(:input) do
        {
          security_policy_ids: ['gid://gitlab/Security::OrchestrationPolicyConfiguration/999999'],
          reason: 'Emergency fix required'
        }
      end

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('Security policies not found')
        expect(mutation_response['mergeRequest']).to be_nil
      end
    end

    context 'when reason is blank' do
      let(:input) do
        {
          security_policy_ids: [security_policy.id],
          reason: ''
        }
      end

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('Reason is required')
        expect(mutation_response['mergeRequest']).to be_nil
      end
    end

    context 'when security policy is already bypassed' do
      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: security_policy,
          project: project,
          user: current_user,
          merge_request: merge_request,
          reason: 'Previous bypass'
        )
      end

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You have already bypassed this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end

      it 'does not create additional bypass event' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end
    end

    context 'when user is not allowed to bypass security policy' do
      let_it_be(:unauthorized_user) { create(:user, developer_of: project) }

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: unauthorized_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You are not allowed to bypass this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end

      it 'does not create bypass event' do
        expect do
          post_graphql_mutation(mutation, current_user: unauthorized_user)
        end.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end
    end

    context 'with multiple security policies where one is already bypassed' do
      let(:input) do
        {
          security_policy_ids: [security_policy.id, other_security_policy.id],
          reason: 'Emergency fix required'
        }
      end

      before do
        create(:approval_policy_merge_request_bypass_event,
          security_policy: other_security_policy,
          project: project,
          user: current_user,
          merge_request: merge_request,
          reason: 'Previous bypass'
        )
      end

      it 'returns error response for the first already bypassed policy' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You have already bypassed this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end

      it 'does not process remaining policies' do
        expect do
          post_graphql_mutation(mutation, current_user: current_user)
        end.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end
    end

    context 'with multiple security policies where user is not allowed to bypass one' do
      let_it_be(:unauthorized_user) { create(:user, developer_of: project) }
      let(:input) do
        {
          security_policy_ids: [security_policy.id, other_security_policy.id],
          reason: 'Emergency fix required'
        }
      end

      it 'returns error response for the first policy user cannot bypass' do
        post_graphql_mutation(mutation, current_user: unauthorized_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You are not allowed to bypass this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end

      it 'does not process remaining policies' do
        expect do
          post_graphql_mutation(mutation, current_user: unauthorized_user)
        end.not_to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }
      end
    end
  end

  describe 'bypass with access token (project bot)' do
    let_it_be(:bot_user) { create(:user, :project_bot, developer_of: project) }
    let_it_be(:token) { create(:personal_access_token, user: bot_user) }

    let(:bypass_settings) do
      { access_tokens: [{ id: token.id }] }
    end

    it 'bypasses the security policy successfully' do
      expect do
        post_graphql_mutation(mutation, current_user: bot_user)
      end.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['mergeRequest']['id']).to eq(merge_request.to_global_id.to_s)
    end

    it 'creates bypass event with correct attributes' do
      post_graphql_mutation(mutation, current_user: bot_user)

      bypass_event = Security::ApprovalPolicyMergeRequestBypassEvent.last
      expect(bypass_event.security_policy).to eq(security_policy)
      expect(bypass_event.user).to eq(bot_user)
      expect(bypass_event.reason).to eq('Emergency fix required')
    end

    context 'when access token is not configured in bypass_settings' do
      let(:bypass_settings) do
        { access_tokens: [{ id: -1 }] }
      end

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: bot_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You are not allowed to bypass this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end
    end
  end

  describe 'bypass with service account' do
    let_it_be(:service_account_user) { create(:user, :service_account, developer_of: project) }

    let(:bypass_settings) do
      { service_accounts: [{ id: service_account_user.id }] }
    end

    it 'bypasses the security policy successfully' do
      expect do
        post_graphql_mutation(mutation, current_user: service_account_user)
      end.to change { Security::ApprovalPolicyMergeRequestBypassEvent.count }.by(1)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['mergeRequest']['id']).to eq(merge_request.to_global_id.to_s)
    end

    context 'when service account is not configured in bypass_settings' do
      let(:bypass_settings) do
        { service_accounts: [{ id: -1 }] }
      end

      it 'returns error response' do
        post_graphql_mutation(mutation, current_user: service_account_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly('You are not allowed to bypass this security policy.')
        expect(mutation_response['mergeRequest']).to be_nil
      end
    end
  end

  describe 'authorization' do
    context 'when user does not have permission to update merge request' do
      let_it_be(:guest_user) { create(:user) }

      it 'returns authorization error' do
        post_graphql_mutation(mutation, current_user: guest_user)

        expect_graphql_errors_to_include(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end
  end
end
