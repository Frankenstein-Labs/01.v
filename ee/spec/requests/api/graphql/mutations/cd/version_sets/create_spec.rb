# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment version set', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      application_id: application.to_global_id.to_s,
      name: 'release-1',
      version_ids: [version.to_global_id.to_s]
    }
  end

  let(:mutation) { graphql_mutation(:cd_version_set_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_version_set_create) }

  context 'when the user is an organization owner' do
    it 'creates the version set with an entry per version', :aggregate_failures do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::VersionSet.count }.by(1)
        .and change { ::Cd::VersionSetEntry.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['versionSet']).to include('name' => 'release-1')
      expect(::Cd::VersionSet.last).to have_attributes(application: application, name: 'release-1')

      entry = ::Cd::VersionSet.last.version_set_entries.first
      expect(entry).to have_attributes(version: version, service: service, artifact_source: artifact_source)
    end

    context 'when a description is provided' do
      let(:input) { super().merge(description: 'May production release') }

      it 'creates the version set with the description' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['versionSet']).to include('description' => 'May production release')
        expect(::Cd::VersionSet.find_by(name: 'release-1').description).to eq('May production release')
      end
    end

    context 'when a version does not belong to the application' do
      let_it_be(:other_version) { create(:cd_version) }

      let(:input) { super().merge(version_ids: [other_version.to_global_id.to_s]) }

      it 'does not create the version set and returns an error' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to not_change { ::Cd::VersionSet.count }
          .and not_change { ::Cd::VersionSetEntry.count }

        expect(mutation_response['versionSet']).to be_nil
        expect(mutation_response['errors'])
          .to include(a_string_matching(/were not found or do not belong to the application/))
      end
    end

    context 'when the versions list is empty' do
      let(:input) { super().merge(version_ids: []) }

      it 'does not create the version set and returns a validation error' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to not_change { ::Cd::VersionSet.count }

        expect(graphql_errors).to include(
          a_hash_including('message' => a_string_matching(/is too short/))
        )
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_version_set do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_version_set_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the name is already taken' do
      before do
        create(:cd_version_set, application: application, name: 'release-1')
      end

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::VersionSet.count }

        expect(mutation_response['versionSet']).to be_nil
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

    it 'does not create the version set' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::VersionSet.count }
    end
  end
end
