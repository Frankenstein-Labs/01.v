# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_security_policy_link custom role', feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be_with_reload(:role) { create(:member_role, :guest, manage_security_policy_link: true, namespace: group) }
  let_it_be(:member) { create(:group_member, :guest, user: user, source: group, member_role: role) }

  let_it_be(:policy_management_project) { create(:project, :repository, namespace: group) }
  let_it_be(:project_policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project, project: project)
  end

  let_it_be(:group_policy_configuration) do
    create(:security_orchestration_policy_configuration, :namespace,
      security_policy_management_project: policy_management_project, namespace: group)
  end

  before do
    stub_licensed_features(custom_roles: true, security_orchestration_policies: true)

    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
    end

    sign_in(user)
  end

  describe 'Controllers endpoints' do
    let_it_be(:policy) { build(:scan_execution_policy) }
    let_it_be(:type) { 'scan_execution_policy' }
    let_it_be(:policy_id) { policy[:name] }

    describe Projects::Security::PoliciesController do
      describe "#index" do
        it 'user has access via a custom role' do
          get project_security_policies_path(project)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    describe Groups::Security::PoliciesController do
      describe "#index" do
        it 'user has access via a custom role' do
          get group_security_policies_path(group)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end

  describe 'GraphQL mutations' do
    include GraphqlHelpers

    let_it_be_with_refind(:policy_project) { create(:project, group: group) }
    let(:full_path) { project.full_path }
    let(:base_params) do
      {
        full_path: full_path

      }
    end

    let(:addtional_params) { {} }
    let(:input) { base_params.merge(addtional_params) }
    let(:fields) do
      <<~FIELDS
        errors
      FIELDS
    end

    let(:mutation) { graphql_mutation(mutation_name, input, fields) }
    let_it_be_with_refind(:policy_project_id) { GitlabSchema.id_from_object(policy_project).to_s }
    let(:mutation_name) { nil }

    subject(:execute_mutation) { post_graphql_mutation(mutation, current_user: user) }

    describe Mutations::SecurityPolicy::AssignSecurityPolicyProject do
      let(:mutation_name) { :security_policy_project_assign }
      let(:addtional_params) { { security_policy_project_id: policy_project_id } }

      context 'for project' do
        it 'has access via a custom role' do
          execute_mutation

          expect(response).to have_gitlab_http_status(:success)
          mutation_response = graphql_mutation_response(:security_policy_project_assign)
          expect(mutation_response).to be_present

          expect(mutation_response['errors']).to be_empty
        end
      end

      context 'for group' do
        let(:full_path) { group.full_path }

        it 'has access via a custom role' do
          execute_mutation

          expect(response).to have_gitlab_http_status(:success)
          mutation_response = graphql_mutation_response(:security_policy_project_assign)
          expect(mutation_response).to be_present

          expect(mutation_response['errors']).to be_empty
        end
      end
    end

    describe Mutations::SecurityPolicy::UnassignSecurityPolicyProject do
      let(:mutation_name) { :security_policy_project_unassign }

      context 'for project' do
        it 'has access via a custom role' do
          execute_mutation

          expect(response).to have_gitlab_http_status(:success)
          mutation_response = graphql_mutation_response(:security_policy_project_unassign)
          expect(mutation_response).to be_present

          expect(mutation_response['errors']).to be_empty
        end
      end

      context 'for group' do
        let(:full_path) { group.full_path }

        it 'has access via a custom role' do
          execute_mutation

          expect(response).to have_gitlab_http_status(:success)
          mutation_response = graphql_mutation_response(:security_policy_project_unassign)
          expect(mutation_response).to be_present

          expect(mutation_response['errors']).to be_empty
        end
      end
    end
  end
end
