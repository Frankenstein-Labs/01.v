# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update project compliance framework', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:framework1) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:framework2) { create(:compliance_framework, :sox, namespace: namespace) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:variables) do
    {
      project_id: GitlabSchema.id_from_object(project).to_s,
      compliance_framework_ids: [
        GitlabSchema.id_from_object(framework1).to_s,
        GitlabSchema.id_from_object(framework2).to_s,
        GitlabSchema.id_from_object(framework1).to_s # Adding same framework twice for checking it only gets added once
      ]
    }
  end

  let(:mutation) do
    graphql_mutation(:project_update_compliance_frameworks, variables) do
      <<~QL
        errors
        project {
          complianceFrameworks {
            nodes {
              name
            }
          }
        }
      QL
    end
  end

  def mutation_response
    graphql_mutation_response(:project_update_compliance_frameworks)
  end

  describe '#resolve' do
    context 'when feature is not available' do
      before do
        stub_licensed_features(compliance_framework: false, custom_compliance_frameworks: false)
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: ['The resource that you are attempting to access does not exist ' \
          'or you don\'t have permission to perform this action']
    end

    context 'when feature is available' do
      before do
        stub_licensed_features(compliance_framework: true, custom_compliance_frameworks: true)
      end

      context 'when there is no framework associated with the project' do
        it_behaves_like 'authorizing granular token permissions for GraphQL', :update_compliance_framework do
          let(:user) { current_user }
          let(:boundary_object) { project }
          let(:mutation) { graphql_mutation(:project_update_compliance_frameworks, variables, 'errors') }

          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end

        it_behaves_like 'a working GraphQL mutation'

        it 'adds the frameworks' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.to change {
            project.reload.compliance_management_frameworks
          }.from([]).to([framework1, framework2])
        end
      end

      context 'when there is a framework associated with the project' do
        let_it_be(:existing_framework) { create(:compliance_framework, namespace: namespace, name: 'framework3') }

        before do
          create(:compliance_framework_project_setting, project: project,
            compliance_management_framework: existing_framework)
        end

        it 'adds the new frameworks' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.to change {
            project.reload.compliance_management_frameworks
          }.from([existing_framework]).to([framework1, framework2])
        end
      end

      context 'when there are more than 20 frameworks' do
        let(:framework_ids) { (1..21).map { |num| "gid://gitlab/ComplianceManagement::Framework/#{num}" } }

        let(:variables) do
          {
            project_id: GitlabSchema.id_from_object(project).to_s,
            compliance_framework_ids: framework_ids
          }
        end

        it 'return error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include('No more than 10 compliance frameworks can be updated at the same time.')
        end
      end
    end
  end
end
