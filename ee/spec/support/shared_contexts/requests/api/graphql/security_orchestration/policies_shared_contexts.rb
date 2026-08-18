# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_context 'with base security policies graphql context' do
  let_it_be(:committed_date, freeze: false) { Time.zone.now }
  let_it_be(:commit, freeze: false) { create(:commit, committed_date: committed_date) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:invited_group, freeze: false) { create(:group, :public) }
  let_it_be(:policy_management_project, freeze: false) { create(:project, :repository) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:project_variables, freeze: false) do
    {
      fullPath: project.full_path,
      relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['DIRECT'].graphql_name
    }
  end

  let_it_be(:group_variables, freeze: false) do
    {
      fullPath: group.full_path,
      relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['DIRECT'].graphql_name
    }
  end

  let_it_be(:action, freeze: false) do
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers_ids: [user.id],
      group_approvers_ids: [group.id],
      role_approvers: %w[maintainer developer]
    }
  end

  def expected_project_source_response
    {
      "source" => {
        '__typename' => 'ProjectSecurityPolicySource',
        'project' => { 'id' => project.to_gid.to_s }
      }
    }
  end

  def expected_group_source_response(inherited = false)
    {
      "source" => {
        '__typename' => 'GroupSecurityPolicySource',
        'inherited' => inherited,
        'namespace' => { 'id' => group.to_gid.to_s }
      }
    }
  end

  def expected_edit_path_response(project_or_group, policy_type = 'scan_execution_policy')
    edid_path = if project_or_group.is_a?(Project)
                  edit_project_policy_path(project_or_group, policy_type, policy)
                else
                  edit_group_policy_path(project_or_group, policy_type, policy)
                end

    { "editPath" => edid_path }
  end

  def expected_policy_response(policy, inherited = false, yaml = nil)
    {
      "description" => policy[:description],
      "enabled" => policy[:enabled],
      "name" => policy[:name],
      "yaml" => yaml.presence || YAML.dump(policy.deep_stringify_keys),
      "updatedAt" => committed_date.iso8601,
      "editPath" => edit_group_policy_path(group, policy_type, policy),
      "policyScope" => {
        "complianceFrameworks" => { "nodes" => [] },
        "includingProjects" => { "nodes" => [] },
        "excludingProjects" => { "nodes" => [] }
      }
    }.merge(expected_group_source_response(inherited))
  end

  def expected_approval_policy_response(policy, inherited = false, yaml = nil)
    expected_policy_response(policy, inherited, yaml).merge({
      "userApprovers" => [
        {
          "id" => "gid://gitlab/User/#{user.id}",
          "webUrl" => "http://localhost/#{user.full_path}"
        }
      ],
      "allGroupApprovers" => [
        {
          "id" => "gid://gitlab/Group/#{group.id}",
          "webUrl" => "http://localhost/groups/#{group.full_path}"
        }
      ],
      "roleApprovers" => %w[
        MAINTAINER
        DEVELOPER
      ]
    })
  end

  def edit_project_policy_path(target_project, policy_type, policy)
    Gitlab::Routing.url_helpers.edit_project_security_policy_url(
      target_project, id: CGI.escape(policy[:name]), type: policy_type
    )
  end

  def edit_group_policy_path(target_group, policy_type, policy)
    Gitlab::Routing.url_helpers.edit_group_security_policy_url(
      target_group, id: CGI.escape(policy[:name]), type: policy_type
    )
  end
end

RSpec.shared_context 'with project level approval policies' do
  include_context 'with base security policies graphql context'

  let(:policy_type) { 'merge_request_approval_policy' }

  let_it_be(:policy) { build(:approval_policy, actions: [action]) }
  let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, approval_policy: [policy]) }

  let_it_be(:query, freeze: false) do
    <<~QUERY
      query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
        project(fullPath: $fullPath) {
          scanResultPolicies(relationship: $relationship) {
            nodes{
              name
              description
              enabled
              editPath
              updatedAt
              yaml
              source {
                __typename
                ... on ProjectSecurityPolicySource {
                  project {
                    id
                  }
                }
                ... on GroupSecurityPolicySource {
                  inherited
                  namespace {
                    id
                  }
                }
              }
              policyScope {
                complianceFrameworks {
                  nodes {
                    id
                  }
                }
                includingProjects {
                  nodes {
                    id
                  }
                }
                excludingProjects {
                  nodes {
                    id
                  }
                }
              }
              userApprovers{
                id
                webUrl
              }
              allGroupApprovers{
                id
                webUrl
              }
              roleApprovers
            }
          }
        }
      }
    QUERY
  end

  before_all do
    project.add_maintainer(user)
    project.invited_groups = [invited_group]
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    post_graphql(query, current_user: user, variables: project_variables)
  end
end

RSpec.shared_context 'with group level approval policies' do
  include_context 'with base security policies graphql context'

  let_it_be(:policy) { build(:approval_policy, actions: [action]) }
  let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, approval_policy: [policy]) }

  let_it_be(:group_variables, freeze: false) do
    {
      fullPath: group.full_path,
      relationship: Types::SecurityOrchestration::SecurityPolicyRelationTypeEnum.values['INHERITED'].graphql_name
    }
  end

  let_it_be(:query, freeze: false) do
    <<~QUERY
      query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
        group(fullPath: $fullPath) {
          approvalPolicies(relationship: $relationship) {
            nodes{
              name
              description
              enabled
              editPath
              updatedAt
              yaml
              source {
                __typename
                ... on ProjectSecurityPolicySource {
                  project {
                    id
                  }
                }
                ... on GroupSecurityPolicySource {
                  inherited
                  namespace {
                    id
                  }
                }
              }
              policyScope {
                complianceFrameworks {
                  nodes {
                    id
                  }
                }
                includingProjects {
                  nodes {
                    id
                  }
                }
                excludingProjects {
                  nodes {
                    id
                  }
                }
              }
              userApprovers{
                id
                webUrl
              }
              allGroupApprovers{
                id
                webUrl
              }
              roleApprovers
            }
          }
        }
      }
    QUERY
  end

  before_all do
    group.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    post_graphql(query, current_user: user, variables: group_variables)
  end
end

RSpec.shared_context 'with project level scan execution policies' do
  include_context 'with base security policies graphql context'

  let(:policy_type) { 'scan_execution_policy' }

  let_it_be(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline') }
  let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }

  let_it_be(:query, freeze: false) do
    <<~QUERY
      query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
        project(fullPath: $fullPath) {
          scanExecutionPolicies(relationship: $relationship) {
            nodes{
              name
              description
              enabled
              editPath
              updatedAt
              yaml
              source {
                __typename
                ... on ProjectSecurityPolicySource {
                  project {
                    id
                  }
                }
                ... on GroupSecurityPolicySource {
                  inherited
                  namespace {
                    id
                  }
                }
              }
              policyScope {
                complianceFrameworks {
                  nodes {
                    id
                  }
                }
                includingProjects {
                  nodes {
                    id
                  }
                }
                excludingProjects {
                  nodes {
                    id
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    post_graphql(query, current_user: user, variables: project_variables)
  end
end

RSpec.shared_context 'with group level scan execution policies' do
  include_context 'with base security policies graphql context'

  let_it_be(:policy) { build(:scan_execution_policy, name: 'Run DAST in every pipeline') }
  let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [policy]) }

  let_it_be(:query, freeze: false) do
    <<~QUERY
      query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
        group(fullPath: $fullPath) {
          scanExecutionPolicies(relationship: $relationship) {
            nodes{
              name
              description
              enabled
              editPath
              updatedAt
              yaml
              source {
                __typename
                ... on ProjectSecurityPolicySource {
                  project {
                    id
                  }
                }
                ... on GroupSecurityPolicySource {
                  inherited
                  namespace {
                    id
                  }
                }
              }
              policyScope {
                complianceFrameworks {
                  nodes {
                    id
                  }
                }
                includingProjects {
                  nodes {
                    id
                  }
                }
                excludingProjects {
                  nodes {
                    id
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  before_all do
    group.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    post_graphql(query, current_user: user, variables: group_variables)
  end
end

RSpec.shared_context 'with project level pipeline execution schedule policies' do
  include_context 'with base security policies graphql context'

  let(:policy_type) { 'pipeline_execution_schedule_policy' }

  let_it_be(:policy) { build(:pipeline_execution_schedule_policy) }
  let_it_be(:policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_schedule_policy: [policy])
  end

  let_it_be(:query, freeze: false) do
    <<~QUERY
      query($fullPath: ID!, $relationship: SecurityPolicyRelationType!) {
        project(fullPath: $fullPath) {
          pipelineExecutionSchedulePolicies(relationship: $relationship) {
            nodes{
              name
              description
              enabled
              editPath
              updatedAt
              yaml
              source {
                __typename
                ... on ProjectSecurityPolicySource {
                  project {
                    id
                  }
                }
                ... on GroupSecurityPolicySource {
                  inherited
                  namespace {
                    id
                  }
                }
              }
              policyScope {
                complianceFrameworks {
                  nodes {
                    id
                  }
                }
                includingProjects {
                  nodes {
                    id
                  }
                }
                excludingProjects {
                  nodes {
                    id
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      allow(repository).to receive(:last_commit_for_path).and_return(commit)
    end

    post_graphql(query, current_user: user, variables: project_variables)
  end
end

RSpec.shared_context 'with policy_scope' do
  let_it_be(:framework, freeze: false) { create(:compliance_framework, namespace: group, name: 'GDPR') }
  let_it_be(:including_project, freeze: false) { create(:project, group: group) }
  let_it_be(:excluding_project, freeze: false) { create(:project, group: group) }
  let_it_be(:expected_policy_scope_response, freeze: false) do
    {
      "policyScope" => {
        "complianceFrameworks" => {
          "nodes" => [
            {
              "id" => framework.to_gid.to_s
            }
          ]
        },
        "includingProjects" => {
          "nodes" => [
            {
              "id" => including_project.to_gid.to_s
            }
          ]
        },
        "excludingProjects" => {
          "nodes" => [
            {
              "id" => excluding_project.to_gid.to_s
            }
          ]
        }
      }
    }
  end

  before_all do
    including_project.add_developer(user)
    excluding_project.add_developer(user)
  end
end

RSpec.shared_context 'with approval policy and policy_scope' do
  include_context 'with policy_scope'

  let_it_be(:policy) do
    build(:approval_policy, actions: [action], policy_scope: {
      compliance_frameworks: [{ id: framework.id }],
      projects: {
        including: [{ id: including_project.id }],
        excluding: [{ id: excluding_project.id }]
      }
    })
  end

  let_it_be(:policy_yaml) do
    build(:orchestration_policy_yaml, approval_policy: [policy])
  end
end

RSpec.shared_context 'with scan execution policy and policy_scope' do
  include_context 'with policy_scope'

  let_it_be(:policy) do
    build(:scan_execution_policy, name: 'Run DAST in every pipeline', policy_scope: {
      compliance_frameworks: [{ id: framework.id }],
      projects: {
        including: [{ id: including_project.id }],
        excluding: [{ id: excluding_project.id }]
      }
    })
  end

  let_it_be(:policy_yaml) do
    build(:orchestration_policy_yaml, scan_execution_policy: [policy])
  end
end
