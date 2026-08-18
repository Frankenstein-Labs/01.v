# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying duoWorkflowStatusCheck', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :with_duo_features_enabled) }
  let_it_be(:current_user) { create(:user, developer_of: project) }

  describe 'duoWorkflowStatusCheck' do
    it 'is available to query' do
      result = GitlabSchema.execute(%(
        query {
          project(fullPath: "#{project.full_path}") {
            duoWorkflowStatusCheck {
              enabled
              createDuoWorkflowForCiAllowed
              checks {
                name
                value
                message
              }
            }
          }
        }
      ), context: { current_user: current_user }).as_json
      status = result.dig('data', 'project', 'duoWorkflowStatusCheck')

      expect(status['enabled']).to be_truthy
      expect(status['createDuoWorkflowForCiAllowed']).to be_falsey
      expect(status['checks']).to match_array([
        hash_including('name' => 'feature_flag', 'value' => true),
        hash_including('name' => 'duo_features_enabled', 'value' => true),
        hash_including('name' => 'developer_access', 'value' => false),
        hash_including('name' => 'feature_available', 'value' => false)
      ])
    end

    context 'with an ai_workflows-scoped OAuth token' do
      let_it_be(:ai_workflows_oauth_token) do
        create(:oauth_access_token, user: current_user, scopes: [:ai_workflows])
      end

      let(:status_data) { graphql_data.dig('project', 'duoWorkflowStatusCheck') }

      it 'exposes the foundational flow fields' do
        query = graphql_query_for(
          :project, { full_path: project.full_path },
          query_graphql_field(:duo_workflow_status_check, {}, <<~FIELDS)
            foundationalFlowsEnabled
            enabledFoundationalFlows
          FIELDS
        )

        post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })

        expect(graphql_errors).to be_nil
        expect(status_data).to include(
          'foundationalFlowsEnabled' => project.duo_foundational_flows_enabled,
          'enabledFoundationalFlows' => project.enabled_foundational_flow_references
        )
      end

      it 'redacts nullable unscoped fields (checks, remoteFlowsEnabled) for an ai_workflows token' do
        query = graphql_query_for(
          :project, { full_path: project.full_path },
          query_graphql_field(:duo_workflow_status_check, {}, <<~FIELDS)
            foundationalFlowsEnabled
            checks { name }
            remoteFlowsEnabled
          FIELDS
        )

        post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })

        expect(graphql_errors).to be_nil
        # object still resolves and the allowed field returns its real value...
        expect(status_data['foundationalFlowsEnabled']).to eq(project.duo_foundational_flows_enabled)
        # ...while the unscoped nullable fields come back null (redacted, not just empty)
        expect(status_data['checks']).to be_nil
        expect(status_data['remoteFlowsEnabled']).to be_nil
      end

      %w[enabled createDuoWorkflowForCiAllowed].each do |restricted_field|
        it "denies access to the non-nullable field #{restricted_field}" do
          query = graphql_query_for(
            :project, { full_path: project.full_path },
            query_graphql_field(:duo_workflow_status_check, {}, restricted_field)
          )

          post_graphql(query, token: { oauth_access_token: ai_workflows_oauth_token })

          expect(status_data).to be_nil
          expect(graphql_errors.pluck('message'))
            .to include(a_string_including("Cannot return null for non-nullable field"))
        end
      end
    end
  end
end
