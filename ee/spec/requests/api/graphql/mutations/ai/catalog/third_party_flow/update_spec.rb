# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Update, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_item, :third_party_flow, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, :released, version: '1.0.0', item: flow)
  end

  let_it_be_with_reload(:latest_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, version: '1.1.0', item: flow)
  end

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_third_party_flow_update, params) do
      <<~FIELDS
        errors
        item {
          id
          name
          description
          project {
            id
          }
          visibility
          latestVersion {
            id
            released
            ... on AiCatalogThirdPartyFlowVersion {
              definition
            }
          }
        }
      FIELDS
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_third_party_flow_update) }
  let(:params) do
    {
      id: flow.to_global_id,
      name: "New name",
      description: "New description",
      visibility: 'RESTRICTED',
      release: true,
      version_bump: 'PATCH',
      definition: <<-YAML
      injectGatewayToken: false
      image: example/new_image:latest
      commands:
        - /bin/newcmd
      variables:
        - NEWVAR1
      YAML
    }
  end

  before do
    enable_ai_catalog
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the flow' do
      expect { execute }.not_to change { flow.reload.attributes }
    end

    it 'does not update the latest version' do
      expect { execute }.not_to change { latest_version.reload.attributes }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when the flow does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when flow cannot be updated' do
    let(:params) { super().merge(name: nil) }

    it 'returns the service error message and item with original attributes' do
      original_name = flow.name

      execute

      expect(graphql_dig_at(mutation_response, :item, :name)).to eq(original_name)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly("Name can't be blank")
    end
  end

  context 'when latest version cannot be updated' do
    before do
      stub_const('Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION', nil)
    end

    it 'returns the service error message' do
      execute

      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly(
        "Latest version schema version can't be blank", 'Latest version definition unable to validate definition'
      )
    end
  end

  context 'when update succeeds', :freeze_time do
    it 'updates the flow and its latest version, and returns a success response' do
      execute

      expect(flow.reload).to have_attributes(
        name: 'New name',
        description: 'New description',
        visibility: 'restricted'
      )

      expect(latest_version.reload).to have_attributes(
        schema_version: 1,
        version: '1.0.1',
        release_date: Time.zone.now,
        definition: {
          injectGatewayToken: false,
          image: 'example/new_image:latest',
          commands: ['/bin/newcmd'],
          variables: ['NEWVAR1'],
          yaml_definition: params[:definition]
        }.stringify_keys
      )

      expect(graphql_dig_at(mutation_response, :item)).to match(
        a_graphql_entity_for(flow,
          :name,
          :description,
          visibility: 'RESTRICTED',
          latest_version: a_graphql_entity_for(
            latest_version,
            released: true,
            definition: params[:definition]
          )
        )
      )

      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
    end
  end

  context 'when YAML is not valid' do
    let(:params) { super().merge(definition: "this: is\n - not\n yaml: true") }

    it 'handles invalid yaml' do
      execute

      expect(graphql_dig_at(mutation_response, :errors))
        .to contain_exactly("ThirdPartyFlow definition does not have a valid YAML syntax")
    end
  end

  context 'when update creates a new latest version' do
    it 'returns the correct version in latestVersion field' do
      latest_version.update!(release_date: Time.zone.now)

      execute

      flow.reload

      expect(graphql_dig_at(mutation_response, :item, :latest_version)).not_to match(
        a_graphql_entity_for(latest_version)
      )
      expect(graphql_dig_at(mutation_response, :item, :latest_version)).to match(
        a_graphql_entity_for(flow.latest_version)
      )
    end
  end

  context 'when using the legacy public argument' do
    let(:params) { super().except(:visibility).merge(public: true) }

    it 'updates the third-party flow with public visibility' do
      execute

      expect(flow.reload).to have_attributes(visibility: 'public')
      expect(graphql_dig_at(mutation_response, :item, :visibility)).to eq('PUBLIC')
    end
  end

  it_behaves_like 'an AI catalog update mutation with a visibility argument' do
    let(:mutation_name) { :ai_catalog_third_party_flow_update }
    let(:visibility_item) { flow }
  end
end
