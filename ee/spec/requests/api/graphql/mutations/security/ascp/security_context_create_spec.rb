# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AscpSecurityContextCreate', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:component) { create(:security_ascp_component, project: project, scan: scan) }

  let(:current_user) { maintainer }

  let(:input) do
    {
      projectPath: project.full_path,
      componentId: component.to_global_id.to_s,
      scanId: scan.to_global_id.to_s,
      summary: 'Threat model summary',
      authenticationModel: 'JWT tokens',
      authorizationModel: 'RBAC',
      dataSensitivity: 'high',
      guidelines: [
        {
          name: 'SQL Injection Prevention',
          operation: 'Database queries',
          legitimateUse: 'Parameterized queries only',
          securityBoundary: 'User input in SQL',
          businessContext: 'Data integrity risk',
          severityIfViolated: 'HIGH'
        }
      ]
    }
  end

  let(:mutation) { graphql_mutation(:ascp_security_context_create, input, security_context_fields) }

  def security_context_fields
    <<~FIELDS
      securityContext {
        id
        summary
        authenticationModel
        authorizationModel
        dataSensitivity
        scan {
          id
        }
        securityGuidelines {
          nodes {
            name
            operation
            legitimateUse
            securityBoundary
            businessContext
            severityIfViolated
          }
        }
      }
      errors
    FIELDS
  end

  def mutation_result
    graphql_mutation_response(:ascp_security_context_create)
  end

  before_all do
    project.add_maintainer(maintainer)
    project.add_guest(guest)
  end

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'GraphQL mutation' do
    context 'when user has permissions' do
      it 'creates a security context with guidelines' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { Security::Ascp::SecurityContext.count }.by(1)
          .and change { Security::Ascp::SecurityGuideline.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_result['errors']).to be_empty
        expect(mutation_result['securityContext']).to include(
          'summary' => 'Threat model summary',
          'authenticationModel' => 'JWT tokens',
          'authorizationModel' => 'RBAC',
          'dataSensitivity' => 'high'
        )
        expect(mutation_result['securityContext']['scan']).to include(
          'id' => scan.to_global_id.to_s
        )

        guidelines = mutation_result.dig('securityContext', 'securityGuidelines', 'nodes')
        expect(guidelines).to contain_exactly(
          a_hash_including(
            'name' => 'SQL Injection Prevention',
            'operation' => 'Database queries',
            'severityIfViolated' => 'HIGH'
          )
        )
      end

      context 'when component does not belong to the project' do
        let_it_be(:other_component) { create(:security_ascp_component) }

        let(:input) do
          {
            projectPath: project.full_path,
            componentId: other_component.to_global_id.to_s,
            scanId: scan.to_global_id.to_s,
            guidelines: [{ name: 'Test', operation: 'test' }]
          }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['securityContext']).to be_nil
          expect(mutation_result['errors']).to include('Component not found in this project')
        end
      end

      context 'when scan does not belong to the project' do
        let_it_be(:other_scan) { create(:security_ascp_scan) }

        let(:input) do
          {
            projectPath: project.full_path,
            componentId: component.to_global_id.to_s,
            scanId: other_scan.to_global_id.to_s,
            guidelines: [{ name: 'Test', operation: 'test' }]
          }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['securityContext']).to be_nil
          expect(mutation_result['errors']).to include('Scan not found in this project')
        end
      end

      context 'when guidelines array is empty' do
        let(:input) do
          {
            projectPath: project.full_path,
            componentId: component.to_global_id.to_s,
            scanId: scan.to_global_id.to_s,
            guidelines: []
          }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['securityContext']).to be_nil
          expect(mutation_result['errors']).to include('Guidelines must not be empty')
        end
      end

      context 'when guidelines exceed maximum limit' do
        let(:input) do
          guidelines = (1..101).map { |i| { name: "Guideline #{i}", operation: "Operation #{i}" } }
          {
            projectPath: project.full_path,
            componentId: component.to_global_id.to_s,
            scanId: scan.to_global_id.to_s,
            guidelines: guidelines
          }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['securityContext']).to be_nil
          expect(mutation_result['errors']).to include('Maximum 100 guidelines allowed')
        end
      end

      context 'when guideline validation fails' do
        let(:input) do
          {
            projectPath: project.full_path,
            componentId: component.to_global_id.to_s,
            scanId: scan.to_global_id.to_s,
            guidelines: [{ name: '', operation: 'test' }]
          }
        end

        it 'returns errors and rolls back transaction' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::Ascp::SecurityContext.count }

          expect(mutation_result['securityContext']).to be_nil
          expect(mutation_result['errors']).not_to be_empty
        end
      end
    end

    context 'when user does not have permissions' do
      let(:current_user) { guest }

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when security_dashboard feature is not available' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end
  end
end
