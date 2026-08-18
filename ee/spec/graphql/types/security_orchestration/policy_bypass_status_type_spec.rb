# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::SecurityOrchestration::PolicyBypassStatusType, feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:policy) do
    create(:security_policy, :approval_policy,
      linked_projects: [project],
      content: { bypass_settings: {} }
    )
  end

  before do
    approval_policy_rule = create(:approval_policy_rule, security_policy: policy)
    create(:approval_merge_request_rule, merge_request: merge_request, approval_policy_rule: approval_policy_rule)
  end

  describe 'fields' do
    it 'exposes the expected fields' do
      expect(described_class).to have_graphql_fields(:id, :name, :allow_bypass, :bypassed)
    end
  end

  describe '#allow_bypass' do
    subject(:allow_bypass) do
      resolve_field(:allow_bypass, policy, extras: { parent: merge_request }, current_user: user)
    end

    context 'when user is not allwed to bypass' do
      it 'returns false' do
        expect(allow_bypass).to be false
      end
    end

    context 'when user is allowed to bypass' do
      before do
        policy.update!(content: { bypass_settings: { users: [{ id: user.id }] } })
      end

      it 'returns the allow_bypass value from the object' do
        expect(allow_bypass).to be true
      end
    end
  end

  describe '#bypassed' do
    subject(:bypassed) { resolve_field(:bypassed, policy, extras: { parent: merge_request }, current_user: user) }

    it 'returns the bypassed value from the object' do
      expect(bypassed).to be false
    end

    context 'when bypassed is true' do
      before do
        create(:approval_policy_merge_request_bypass_event, merge_request: merge_request, security_policy: policy)
      end

      it 'returns true' do
        expect(bypassed).to be true
      end
    end
  end

  describe 'N+1 queries' do
    let(:query) do
      <<~GQL
        query($projectPath: ID!, $iid: String!) {
          project(fullPath: $projectPath) {
            mergeRequest(iid: $iid) {
              securityPolicyBypassStatuses {
                nodes {
                  id
                  name
                  allowBypass
                  bypassed
                }
              }
            }
          }
        }
      GQL
    end

    let(:variables) do
      {
        projectPath: project.full_path,
        iid: merge_request.iid.to_s
      }
    end

    let_it_be_with_reload(:additional_policies) do
      create_list(:security_policy, 3, :approval_policy, linked_projects: [project])
    end

    before_all do
      project.add_developer(user)
    end

    before do
      additional_policies.each do |policy|
        approval_policy_rule = create(:approval_policy_rule, security_policy: policy)
        create(:approval_merge_request_rule,
          merge_request: merge_request,
          approval_policy_rule: approval_policy_rule
        )
      end
    end

    it 'avoids N+1 queries for bypassed and allow_bypass field' do
      GitlabSchema.execute(query, context: { current_user: user }, variables: variables)

      control = ActiveRecord::QueryRecorder.new do
        run_with_clean_state(query, context: { current_user: user }, variables: variables)
      end

      additional_policies.each do |policy|
        policy.update!(content: { bypass_settings: { users: [{ id: user.id }] } })
        create(:approval_policy_merge_request_bypass_event, merge_request: merge_request, security_policy: policy)
      end

      expect do
        run_with_clean_state(query, context: { current_user: user }, variables: variables)
      end.not_to exceed_query_limit(control.count).with_threshold(2)
    end
  end
end
