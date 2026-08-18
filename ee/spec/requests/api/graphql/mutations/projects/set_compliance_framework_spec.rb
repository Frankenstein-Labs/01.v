# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Set project compliance framework', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }

  let(:variables) { { project_id: GitlabSchema.id_from_object(project).to_s, compliance_framework_id: GitlabSchema.id_from_object(framework).to_s } }

  let(:mutation) do
    graphql_mutation(:project_set_compliance_framework, variables) do
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
    graphql_mutation_response(:project_set_compliance_framework)
  end

  describe '#resolve' do
    context 'when feature is not available' do
      before do
        stub_licensed_features(compliance_framework: false, custom_compliance_frameworks: false)
      end

      it_behaves_like 'a mutation that returns top-level errors',
        errors: ['The resource that you are attempting to access does not exist '\
                 'or you don\'t have permission to perform this action']
    end

    context 'when feature is available' do
      before do
        stub_licensed_features(compliance_framework: true, custom_compliance_frameworks: true)
      end

      context 'when less than 2 frameworks associated with project' do
        context 'when no framework is associated with the project' do
          it_behaves_like 'authorizing granular token permissions for GraphQL', :update_compliance_framework do
            let(:user) { current_user }
            let(:boundary_object) { project }
            let(:mutation) { graphql_mutation(:project_set_compliance_framework, variables, 'errors') }

            let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
          end

          it_behaves_like 'a working GraphQL mutation'

          it 'adds the framework' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change {
              project.reload.compliance_management_frameworks
            }.from([]).to([framework])
          end
        end

        context 'when 1 framework is associated with the project' do
          let_it_be(:framework1) { create(:compliance_framework, name: 'framework1', namespace: namespace) }

          before_all do
            create(:compliance_framework_project_setting,
              project: project, compliance_management_framework: framework1)
          end

          it_behaves_like 'a working GraphQL mutation'

          it 'updates the framework' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.to change {
              project.reload.compliance_management_frameworks
            }.from([framework1]).to([framework])
          end
        end
      end

      context 'when more than 1 framework is associated with project' do
        let_it_be(:framework1) { create(:compliance_framework, name: 'framework1', namespace: namespace) }
        let_it_be(:framework2) { create(:compliance_framework, name: 'framework2', namespace: namespace) }

        before_all do
          create(:compliance_framework_project_setting,
            project: project, compliance_management_framework: framework1)
          create(:compliance_framework_project_setting,
            project: project, compliance_management_framework: framework2)
        end

        it 'returns error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_response['errors']).to contain_exactly("You cannot assign or unassign frameworks to a "\
            "project that has more than one associated framework.")
        end
      end
    end
  end
end
