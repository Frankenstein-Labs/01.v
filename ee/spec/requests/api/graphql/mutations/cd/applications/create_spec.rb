# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment application', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      organization_id: organization.to_global_id.to_s,
      name: 'app-1',
      description: 'My app'
    }
  end

  let(:mutation) { graphql_mutation(:cd_application_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_application_create) }

  context 'when the user is an organization owner' do
    it 'creates the application on the organization' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::Application.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['application']).to include(
        'name' => 'app-1',
        'description' => 'My app'
      )
      expect(::Cd::Application.last).to have_attributes(organization: organization, name: 'app-1')
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_application do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_application_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when services are provided' do
      let(:input) { super().merge(services: [{ name: 'web', description: 'Web service' }, { name: 'worker' }]) }

      it 'creates the application together with its services' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { ::Cd::Application.count }.by(1)
          .and change { ::Cd::Service.count }.by(2)

        expect(mutation_response['errors']).to be_empty
        expect(::Cd::Application.last.services.pluck(:name)).to contain_exactly('web', 'worker')
      end

      context 'when a service is invalid' do
        let(:input) { super().merge(services: [{ name: '' }]) }

        it 'creates neither the application nor the services' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { ::Cd::Application.count }
            .and not_change { ::Cd::Service.count }

          expect(mutation_response['application']).to be_nil
          expect(mutation_response['errors']).to include(a_string_matching(/Name can't be blank/))
        end
      end
    end

    context 'when services with artifact_sources are provided' do
      let(:input) do
        super().merge(services: [
          {
            name: 'web',
            artifact_sources: [
              { name: 'api', source_ref: 'registry.example.com/acme/api',
                source_config: { name: 'api', type: 'oci_image' } },
              { name: 'worker', source_ref: 'registry.example.com/acme/worker' }
            ]
          },
          { name: 'worker' }
        ])
      end

      it 'creates the application, services, and nested artifact sources' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { ::Cd::Application.count }.by(1)
          .and change { ::Cd::Service.count }.by(2)
          .and change { ::Cd::ArtifactSource.count }.by(2)

        expect(mutation_response['errors']).to be_empty

        web_service = ::Cd::Application.last.services.find_by(name: 'web')
        expect(web_service.artifact_sources.pluck(:name, :source_ref)).to contain_exactly(
          ['api', 'registry.example.com/acme/api'],
          ['worker', 'registry.example.com/acme/worker']
        )
        expect(web_service.artifact_sources.find_by(name: 'api').source_config).to eq(
          'name' => 'api', 'type' => 'oci_image'
        )
        expect(web_service.artifact_sources.find_by(name: 'worker').source_config).to eq({})
      end

      context 'when a nested artifact source is invalid' do
        let(:input) do
          super().merge(services: [{ name: 'web',
                                     artifact_sources: [{ name: '', source_ref: 'registry.example.com/acme/api' }] }])
        end

        it 'creates neither the application, the services, nor the artifact sources' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { ::Cd::Application.count }
            .and not_change { ::Cd::Service.count }
            .and not_change { ::Cd::ArtifactSource.count }

          expect(mutation_response['application']).to be_nil
          expect(mutation_response['errors']).to include(a_string_matching(/Name can't be blank/))
        end
      end
    end

    context 'when the name is already taken' do
      before do
        create(:cd_application, organization: organization, name: 'app-1')
      end

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::Application.count }

        expect(mutation_response['application']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Name has already been taken/))
      end
    end
  end

  context 'when the user is an organization member' do
    let(:current_user) { organization_member }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create the application' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::Application.count }
    end
  end
end
