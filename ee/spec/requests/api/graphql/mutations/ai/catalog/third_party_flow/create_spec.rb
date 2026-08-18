# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_third_party_flow_create, params) do
      <<~FIELDS
        errors
        item {
          name
          description
          project {
            id
          }
          visibility
          latestVersion {
            released
            ... on AiCatalogThirdPartyFlowVersion {
              definition
            }
          }
        }
      FIELDS
    end
  end

  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:tools) { Ai::Catalog::BuiltInTool.where(id: [1, 9]) }
  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      visibility: 'RESTRICTED',
      release: true,
      definition: <<-YAML
      injectGatewayToken: true
      image: example/image:latest
      commands:
        - /bin/bash
      variables:
        - VAL1
        - VAL2
      YAML
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item or version' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when just the ai_catalog StageCheck passes' do
    let(:third_party_flows_available) { false }

    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
    end

    it_behaves_like 'an authorization failure'

    context 'and the ai_catalog_third_party_flows StageCheck also passes' do
      let(:third_party_flows_available) { true }

      it 'is successful' do
        execute

        expect(graphql_data_at(:ai_catalog_third_party_flow_create, :item)).to be_present
        expect(graphql_errors).to be_nil
      end
    end
  end

  context 'when graphql params are invalid' do
    let(:name) { nil }
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include(
        'provided invalid value for',
        'name (Expected value to not be null)',
        'description (Expected value to not be null)'
      )
    end
  end

  context 'when model params are invalid' do
    let(:name) { '' }
    let(:description) { '' }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_third_party_flow_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank",
        "Name is too short (minimum is 3 characters)"
      )
      expect(graphql_data_at(:ai_catalog_third_party_flow_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data', :freeze_time do
    execute

    item = Ai::Catalog::Item.last

    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      visibility: 'restricted',
      item_type: Ai::Catalog::Item::THIRD_PARTY_FLOW_TYPE.to_s
    )
    expect(item.latest_version).to have_attributes(
      schema_version: 1,
      release_date: Time.zone.now,
      version: '1.0.0',
      definition: {
        injectGatewayToken: true,
        image: 'example/image:latest',
        commands: ['/bin/bash'],
        variables: %w[VAL1 VAL2],
        yaml_definition: params[:definition]
      }.stringify_keys
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_third_party_flow_create, :item)).to match a_hash_including(
      'name' => name,
      'description' => description,
      'project' => a_graphql_entity_for(project),
      'visibility' => 'RESTRICTED',
      'latestVersion' => {
        'released' => true,
        'definition' => params[:definition]
      }
    )
  end

  context 'when using the legacy public argument' do
    let(:params) { super().except(:visibility).merge(public: true) }

    it 'creates a third-party flow with public visibility' do
      execute

      expect(Ai::Catalog::Item.last).to have_attributes(visibility: 'public')
      expect(graphql_data_at(:ai_catalog_third_party_flow_create, :item, :visibility)).to eq('PUBLIC')
    end
  end

  it_behaves_like 'an AI catalog create mutation with a visibility argument' do
    let(:mutation_name) { :ai_catalog_third_party_flow_create }
  end
end
