# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).pipelineExecutionSchedulePolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with project level pipeline execution schedule policies'

  subject(:query_result) { graphql_data_at(:project, :pipelineExecutionSchedulePolicies, :nodes) }

  let_it_be(:yaml) do
    YAML.dump({
      name: policy[:name],
      description: policy[:description],
      enabled: policy[:enabled],
      policy_scope: {},
      content: policy[:content],
      schedules: policy[:schedules],
      metadata: policy[:metadata]
    }.compact.deep_stringify_keys)
  end

  context 'when policy_configuration is assigned to the project' do
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_policy_response(policy, false, yaml)
          .merge(expected_project_source_response)
          .merge(expected_edit_path_response(project, 'pipeline_execution_schedule_policy'))
      ])
    end
  end

  context 'when policy_configuration is assigned to the group' do
    let_it_be(:project_variables) do
      {
        fullPath: project.full_path,
        relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['INHERITED'].graphql_name
      }
    end

    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: nil, namespace: group)
    end

    it 'returns the policy' do
      expect(query_result).to match_array([
        expected_policy_response(policy, true, yaml)
          .merge(expected_edit_path_response(group, 'pipeline_execution_schedule_policy'))
      ])
    end
  end

  describe 'upcomingSchedules' do
    let_it_be(:policy_configuration) do
      create(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_management_project,
        project: project)
    end

    let_it_be(:security_policy) do
      create(:security_policy, :pipeline_execution_schedule_policy,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:project_schedule) do
      create(:security_pipeline_execution_project_schedule,
        security_policy: security_policy,
        project: project)
    end

    let(:query) do
      <<~QUERY
        query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
          project(fullPath: $fullPath) {
            pipelineExecutionSchedulePolicies(relationship: $relationship) {
              nodes {
                name
                upcomingSchedules {
                  nodes {
                    id
                    nextRunAt
                    project {
                      fullPath
                    }
                  }
                }
              }
            }
          }
        }
      QUERY
    end

    let(:upcoming_schedules_result) do
      graphql_data_at(:project, :pipelineExecutionSchedulePolicies, :nodes, 0, :upcomingSchedules, :nodes)
    end

    context 'when user has push_code access to the policy management project' do
      before do
        policy_management_project.add_developer(user)
        post_graphql(query, current_user: user, variables: project_variables)
      end

      it 'returns the upcoming schedules' do
        expect(upcoming_schedules_result).to contain_exactly(
          a_hash_including(
            'id' => project_schedule.to_gid.to_s,
            'project' => { 'fullPath' => project.full_path }
          )
        )
      end
    end

    context 'when user has push_code access to policy project but no access to target project' do
      let_it_be(:external_user) { create(:user) }

      before do
        policy_management_project.add_developer(external_user)
        post_graphql(query, current_user: external_user, variables: project_variables)
      end

      it 'returns nil as the user cannot see the target project' do
        # User cannot access the target project, so the entire query returns nil
        expect(graphql_data_at(:project)).to be_nil
      end
    end

    context 'when user does not have push_code access to the policy management project' do
      let_it_be(:unauthorized_user) { create(:user) }

      before do
        project.add_developer(unauthorized_user)
        post_graphql(query, current_user: unauthorized_user, variables: project_variables)
      end

      it 'returns empty upcoming schedules' do
        expect(upcoming_schedules_result).to be_empty
      end
    end

    context 'with a granular token' do
      # Use the same project as both target and policy management project
      # to simplify boundary testing (single boundary object)
      let_it_be(:gpat_project) { create(:project, :repository, group: group) }

      let_it_be(:gpat_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: gpat_project,
          project: gpat_project)
      end

      let_it_be(:gpat_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          security_orchestration_policy_configuration: gpat_policy_configuration)
      end

      let_it_be(:gpat_project_schedule) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: gpat_security_policy,
          project: gpat_project)
      end

      let(:variables) do
        {
          fullPath: gpat_project.full_path,
          relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum
                          .values['DIRECT'].graphql_name
        }
      end

      before_all do
        gpat_project.add_maintainer(user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:read_project, :read_pipeline_execution_project_schedule] do
        let(:boundary_object) { gpat_project }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }, variables: variables) }
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL with a skipped child type',
        :read_project do
        let(:boundary_object) { gpat_project }
        let(:query) do
          graphql_query_for(:project, { full_path: gpat_project.full_path },
            query_nodes(:pipeline_execution_schedule_policies, :name))
        end

        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
        let(:skipped_data_path) { [:project, :pipelineExecutionSchedulePolicies, :nodes, 0, :name] }
      end
    end

    context 'with inherited policies from multiple policy projects' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_project) { create(:project, group: subgroup) }

      let_it_be(:other_policy_management_project) { create(:project, :repository) }

      let_it_be(:group_policy_configuration) do
        create(:security_orchestration_policy_configuration,
          security_policy_management_project: other_policy_management_project,
          project: nil,
          namespace: group)
      end

      let_it_be(:group_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          security_orchestration_policy_configuration: group_policy_configuration)
      end

      let_it_be(:group_schedule) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: group_security_policy,
          project: project)
      end

      let(:inherited_query) do
        <<~QUERY
          query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
            project(fullPath: $fullPath) {
              pipelineExecutionSchedulePolicies(relationship: $relationship) {
                nodes {
                  name
                  upcomingSchedules {
                    nodes {
                      id
                      project {
                        fullPath
                      }
                    }
                  }
                }
              }
            }
          }
        QUERY
      end

      let(:inherited_variables) do
        {
          fullPath: project.full_path,
          relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['INHERITED'].graphql_name
        }
      end

      context 'when user has push_code on one policy project but not the other' do
        let_it_be(:partial_access_user) { create(:user) }

        before do
          # User has access to the target project
          project.add_developer(partial_access_user)
          # User can push to the project-level policy project but not the group-level one
          policy_management_project.add_developer(partial_access_user)
          post_graphql(inherited_query, current_user: partial_access_user, variables: inherited_variables)
        end

        it 'returns only schedules from the authorized policy project' do
          all_schedule_ids = graphql_data_at(:project, :pipelineExecutionSchedulePolicies, :nodes)
            .flat_map { |node| node.dig('upcomingSchedules', 'nodes') }
            .map { |s| s['id'] }

          expect(all_schedule_ids).to include(project_schedule.to_gid.to_s)
          expect(all_schedule_ids).not_to include(group_schedule.to_gid.to_s)
        end
      end
    end
  end
end
