# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.mergeRequest.policiesOverridingApprovalSettings', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:policies_overriding_approval_settings_fields) do
    <<~QUERY
      policiesOverridingApprovalSettings {
        name
        editPath
        settings
      }
    QUERY
  end

  let(:merge_request_fields) do
    query_graphql_field(
      :merge_request,
      { iid: merge_request.iid.to_s },
      policies_overriding_approval_settings_fields)
  end

  let(:query) { graphql_query_for(:project, { full_path: project.full_path }, merge_request_fields) }

  subject(:result) { graphql_data_at(:project, :merge_request, :policies_overriding_approval_settings) }

  context 'when the user is not authorized to read the field' do
    before do
      post_graphql(query, current_user: user)
    end

    it { is_expected.to be_nil }
  end

  context 'when the user is authorized to read the field' do
    before_all do
      project.add_developer(user)
    end

    context 'when feature is available' do
      before do
        stub_licensed_features(security_orchestration_policies: true, security_dashboard: true)
      end

      it 'returns empty data' do
        post_graphql(query, current_user: user)
        expect(result).to eq([])
      end

      context 'with data' do
        let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
        let_it_be(:scan_result_policy_read) do
          create(:scan_result_policy_read, :prevent_approval_by_author, project: project,
            security_orchestration_policy_configuration: policy_configuration)
        end

        context 'when approval_policy_rule is not populated for the violations' do
          before do
            create(:scan_result_policy_violation, merge_request: merge_request, project: project,
              scan_result_policy_read: scan_result_policy_read)
          end

          it 'returns expected response' do
            post_graphql(query, current_user: user)
            expect(result).to eq([
              {
                name: nil,
                editPath: nil,
                settings: { prevent_approval_by_author: true }
              }.deep_stringify_keys
            ])
          end
        end

        context 'when approval_policy_rule is populated for the violations' do
          let(:policy) do
            create(:security_policy, :with_approval_settings,
              security_orchestration_policy_configuration: policy_configuration, name: 'Policy 1')
          end

          let(:policy_rule) do
            create(:approval_policy_rule, :any_merge_request, security_policy: policy)
          end

          before do
            create(:scan_result_policy_violation, merge_request: merge_request, project: project,
              scan_result_policy_read: scan_result_policy_read, approval_policy_rule: policy_rule)
          end

          it 'returns expected response' do
            post_graphql(query, current_user: user)
            expect(result).to eq([
              {
                name: policy.name,
                editPath: Gitlab::Routing.url_helpers.edit_project_security_policy_url(
                  project, id: CGI.escape(policy.name), type: 'approval_policy'
                ),
                settings: { prevent_approval_by_author: true }
              }.deep_stringify_keys
            ])
          end
        end
      end
    end
  end
end
