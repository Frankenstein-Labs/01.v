# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Update, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_flow, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_flow_version, :released, version: '1.0.0', item: flow)
  end

  let_it_be_with_reload(:latest_version) do
    create(:ai_catalog_flow_version, version: '1.1.0', item: flow)
  end

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_flow_update, params) do
      <<~MUTATION
      errors
      item {
        id
        name
        description
        visibility
      }
      MUTATION
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_flow_update) }
  let(:definition) do
    <<~YAML
      version: v1
      environment: ambient
      components:
        - name: updated_agent
          type: AgentComponent
          prompt_id: updated_prompt
      routers: []
      flow:
        entry_point: updated_agent
    YAML
  end

  let(:params) do
    {
      id: flow.to_global_id,
      name: 'New name',
      visibility: 'RESTRICTED',
      release: true,
      description: 'New description',
      definition: definition,
      version_bump: 'PATCH'
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the flow' do
      expect { execute }.not_to change { flow.reload.attributes }
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

  context 'when update succeeds' do
    it 'updates the flow and returns a success response', :freeze_time do
      execute

      expect(flow.reload).to have_attributes(
        name: 'New name',
        description: 'New description',
        visibility: 'restricted'
      )
      expect(latest_version.reload).to have_attributes(
        schema_version: ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION,
        version: '1.0.1',
        release_date: Time.zone.now,
        definition: YAML.safe_load(definition).merge('yaml_definition' => definition)
      )

      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
    end

    context 'when passing only required arguments (test that mutation handles absence of optional args)' do
      let(:params) { { id: flow.to_global_id } }

      it 'works without errors' do
        execute

        expect(graphql_dig_at(mutation_response, :errors)).to be_empty
      end
    end
  end

  context 'when using the legacy public argument' do
    let(:params) { super().except(:visibility).merge(public: true) }

    it 'updates the flow with public visibility' do
      execute

      expect(flow.reload).to have_attributes(visibility: 'public')
      expect(graphql_dig_at(mutation_response, :item, :visibility)).to eq('PUBLIC')
    end
  end

  it_behaves_like 'an AI catalog update mutation with a visibility argument' do
    let(:mutation_name) { :ai_catalog_flow_update }
    let(:visibility_item) { flow }
  end
end
