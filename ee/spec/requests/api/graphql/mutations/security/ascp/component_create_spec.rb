# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AscpComponentCreate', feature_category: :static_application_security_testing do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }

  let(:current_user) { maintainer }

  let(:input) do
    {
      projectPath: project.full_path,
      title: 'Authentication Module',
      subDirectory: 'app/auth',
      description: 'Handles user authentication',
      expectedUserBehavior: 'Users log in with email and password',
      scanId: scan.to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:ascp_component_create, input, component_fields) }

  def component_fields
    <<~FIELDS
      component {
        id
        title
        subDirectory
        description
        expectedUserBehavior
        scan {
          id
        }
      }
      errors
    FIELDS
  end

  def mutation_result
    graphql_mutation_response(:ascp_component_create)
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
      it 'creates a component' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { Security::Ascp::Component.count }.by(1)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_result['errors']).to be_empty
        expect(mutation_result['component']).to include(
          'title' => 'Authentication Module',
          'subDirectory' => 'app/auth',
          'description' => 'Handles user authentication',
          'expectedUserBehavior' => 'Users log in with email and password'
        )
        expect(mutation_result['component']['scan']).to include(
          'id' => scan.to_global_id.to_s
        )
      end

      context 'when validation fails' do
        let(:input) do
          {
            projectPath: project.full_path,
            title: '',
            subDirectory: 'app/auth',
            scanId: scan.to_global_id.to_s
          }
        end

        it 'returns errors and nil component' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['component']).to be_nil
          expect(mutation_result['errors']).to include("Title can't be blank")
        end
      end

      context 'when sub_directory is a duplicate for the same project and scan' do
        before do
          create(:security_ascp_component, project: project, scan: scan,
            title: 'Existing', sub_directory: 'app/auth')
        end

        let(:input) do
          {
            projectPath: project.full_path,
            title: 'New Component',
            subDirectory: 'app/auth',
            scanId: scan.to_global_id.to_s
          }
        end

        it 'returns a uniqueness error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['component']).to be_nil
          expect(mutation_result['errors']).to include('Sub directory has already been taken')
        end
      end

      context 'when title exceeds maximum length' do
        let(:input) do
          {
            projectPath: project.full_path,
            title: 'A' * 256,
            subDirectory: 'app/test',
            scanId: scan.to_global_id.to_s
          }
        end

        it 'returns a validation error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['component']).to be_nil
          expect(mutation_result['errors']).to include('Title is too long (maximum is 255 characters)')
        end
      end

      context 'when scan does not belong to the project' do
        let_it_be(:other_scan) { create(:security_ascp_scan) }

        let(:input) do
          {
            projectPath: project.full_path,
            title: 'Test Component',
            subDirectory: 'app/test',
            scanId: other_scan.to_global_id.to_s
          }
        end

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(mutation_result['component']).to be_nil
          expect(mutation_result['errors']).to include('Scan not found in this project')
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
