# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Framework', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(
      :create_compliance_framework,
      namespace_path: namespace.full_path,
      params: {
        name: 'GDPR',
        description: 'Example Description',
        color: '#ABC123',
        pipeline_configuration_full_path: '.compliance-gitlab-ci.yml@compliance/hipaa'
      }
    )
  end

  let(:pipeline_configuration_full_path) do
    '.compliance-gitlab-ci.yml@compliance/hipaa'
  end

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_framework)
  end

  shared_examples 'a mutation that creates a compliance framework' do
    it 'creates a new compliance framework' do
      expect { subject }.to change { namespace.compliance_management_frameworks.count }.by 1
    end

    it 'returns the newly created framework', :aggregate_failures do
      subject

      expect(mutation_response['framework']['color']).to eq '#ABC123'
      expect(mutation_response['framework']['name']).to eq 'GDPR'
      expect(mutation_response['framework']['description']).to eq 'Example Description'
      expect(mutation_response['framework']['pipelineConfigurationFullPath']).to eq pipeline_configuration_full_path
    end
  end

  context 'framework feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'a mutation that returns errors in the response', errors: ['Not permitted to create framework']
  end

  context 'pipeline configuration feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: false)
      namespace.add_owner(current_user)
    end

    context 'when pipeline_configuration_full_path is set' do
      before do
        post_graphql_mutation(mutation, current_user: current_user)
      end

      it_behaves_like 'a mutation that returns errors in the response', errors: ['Pipeline configuration full path feature is not available']
    end

    context 'when pipeline_configuration_full_path is not set' do
      let(:mutation) do
        graphql_mutation(
          :create_compliance_framework,
          namespace_path: namespace.full_path,
          params: {
            name: 'GDPR',
            description: 'Example Description',
            color: '#ABC123',
            pipeline_configuration_full_path: ''
          }
        )
      end

      let(:pipeline_configuration_full_path) do
        nil
      end

      it_behaves_like 'a mutation that creates a compliance framework'
    end
  end

  context 'feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'namespace is a personal namespace' do
      let_it_be(:namespace) { create(:user_namespace) }

      context 'current_user is namespace owner' do
        let(:current_user) { namespace.owner }

        it_behaves_like 'a mutation that returns errors in the response', errors: ['Failed to create framework',
          'Namespace must be a group, user namespaces are not supported.']

        it 'does not create a new compliance framework' do
          expect { subject }.not_to change { namespace.compliance_management_frameworks.count }
        end
      end
    end

    context 'namespace is a group' do
      context 'current_user is group owner' do
        before do
          namespace.add_owner(current_user)
        end

        it_behaves_like 'authorizing granular token permissions for GraphQL', :create_compliance_framework do
          let(:user) { current_user }
          let(:boundary_object) { namespace }
          let(:mutation) do
            graphql_mutation(
              :create_compliance_framework,
              {
                namespace_path: namespace.full_path,
                params: {
                  name: 'GDPR',
                  description: 'Example Description',
                  color: '#ABC123',
                  pipeline_configuration_full_path: '.compliance-gitlab-ci.yml@compliance/hipaa'
                }
              },
              'errors'
            )
          end

          let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
        end

        context 'when a granular token is scoped to a subgroup but the framework is created on the root' do
          let_it_be(:subgroup) { create(:group, parent: namespace) }

          let(:mutation) do
            graphql_mutation(
              :create_compliance_framework,
              {
                namespace_path: subgroup.full_path,
                params: {
                  name: 'GDPR',
                  description: 'Example Description',
                  color: '#ABC123',
                  pipeline_configuration_full_path: '.compliance-gitlab-ci.yml@compliance/hipaa'
                }
              },
              'errors'
            )
          end

          let(:pat) do
            create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(subgroup),
              permissions: [
                ::Authz::PermissionGroups::Assignable.for_permission(:create_compliance_framework).first.name
              ])
          end

          it 'denies access because the boundary resolves to the root ancestor' do
            expect do
              post_graphql_mutation(mutation, token: { personal_access_token: pat })
            end.not_to change { ComplianceManagement::Framework.count }

            expect(graphql_errors).to be_present
          end
        end

        it_behaves_like 'a mutation that creates a compliance framework'
      end

      context 'current_user is not a group owner' do
        context 'current_user is group owner' do
          before do
            namespace.add_maintainer(current_user)
          end

          it 'does not create a new compliance framework' do
            expect { subject }.not_to change { namespace.compliance_management_frameworks.count }
          end

          it_behaves_like 'a mutation that returns errors in the response', errors: ['Not permitted to create framework']
        end
      end
    end
  end
end
