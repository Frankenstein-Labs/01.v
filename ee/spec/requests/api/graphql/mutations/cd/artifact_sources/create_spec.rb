# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment artifact source', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      service_id: service.to_global_id.to_s,
      name: 'api',
      source_ref: 'registry.example.com/web'
    }
  end

  let(:mutation) { graphql_mutation(:cd_artifact_source_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_artifact_source_create) }

  context 'when the user is an organization owner' do
    it 'creates the artifact source on the service' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::ArtifactSource.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['artifactSource']).to include('name' => 'api', 'sourceRef' => 'registry.example.com/web')
      expect(::Cd::ArtifactSource.last).to have_attributes(
        service: service,
        name: 'api',
        source_ref: 'registry.example.com/web'
      )
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_artifact_source do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_artifact_source_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when source_ref is too long' do
      let(:input) { super().merge(source_ref: 'a' * 256) }

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ArtifactSource.count }

        expect(mutation_response['artifactSource']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Source ref is too long/))
      end
    end

    context 'when source_ref is not provided' do
      let(:input) { super().tap { |i| i.delete(:source_ref) } }

      it 'returns a top-level argument error and does not create the artifact source' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ArtifactSource.count }

        expect_graphql_errors_to_include(/was provided invalid value for sourceRef/)
      end
    end

    context 'when name is blank' do
      let(:input) { super().merge(name: '') }

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ArtifactSource.count }

        expect(mutation_response['artifactSource']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Name can't be blank/))
      end
    end

    context 'when source_ref is blank' do
      let(:input) { super().merge(source_ref: '') }

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ArtifactSource.count }

        expect(mutation_response['artifactSource']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Source ref can't be blank/))
      end
    end

    context 'when source_config is provided' do
      let(:input) { super().merge(source_config: { name: 'api', type: 'oci_image' }) }

      it 'creates the artifact source with the given source_config' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { ::Cd::ArtifactSource.count }.by(1)

        expect(mutation_response['errors']).to be_empty
        expect(::Cd::ArtifactSource.last.source_config).to eq('name' => 'api', 'type' => 'oci_image')
      end
    end

    context 'when source_config is not provided' do
      it 'defaults source_config to an empty hash' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(::Cd::ArtifactSource.last.source_config).to eq({})
      end
    end

    context 'when name is not provided' do
      let(:input) { super().tap { |i| i.delete(:name) } }

      it 'returns a top-level argument error and does not create the artifact source' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ArtifactSource.count }

        expect_graphql_errors_to_include(/was provided invalid value for name/)
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

    it 'does not create the artifact source' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::ArtifactSource.count }
    end
  end
end
