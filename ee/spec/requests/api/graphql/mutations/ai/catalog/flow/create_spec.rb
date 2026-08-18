# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_flow_create, params) }
  let(:name) { 'Name' }
  let(:description) { 'Description' }
  let(:definition) do
    <<~YAML
      version: v1
      environment: ambient
      components:
        - name: main_agent
          type: AgentComponent
          prompt_id: test_prompt
      routers: []
      flow:
        entry_point: main_agent
    YAML
  end

  let(:params) do
    {
      project_id: project.to_global_id,
      name: name,
      description: description,
      visibility: 'RESTRICTED',
      release: true,
      definition: definition
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

  context 'when user has a custom role with admin_ai_catalog_item' do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) { create(:member_role, :guest, :admin_ai_catalog_item, namespace: project.group) }
    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: project)
    end

    let(:current_user) { custom_role_user }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'creates a catalog flow' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(1)
    end
  end

  context 'when just the ai_catalog StageCheck passes' do
    let(:flows_available) { false }

    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(project, :ai_catalog_flows).and_return(flows_available)
    end

    it_behaves_like 'an authorization failure'

    context 'and the ai_catalog_flows StageCheck also passes' do
      let(:flows_available) { true }

      it 'is successful' do
        execute

        expect(graphql_data_at(:ai_catalog_flow_create, :item)).to be_present
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

      expect(graphql_data_at(:ai_catalog_flow_create, :errors)).to contain_exactly(
        "Description can't be blank",
        "Name can't be blank",
        "Name is too short (minimum is 3 characters)"
      )
      expect(graphql_data_at(:ai_catalog_flow_create, :item)).to be_nil
    end
  end

  it 'creates a catalog item and version with expected data', :freeze_time do
    execute

    item = Ai::Catalog::Item.last
    expect(item).to have_attributes(
      name: params[:name],
      description: params[:description],
      item_type: Ai::Catalog::Item::FLOW_TYPE.to_s,
      visibility: 'restricted'
    )
    expect(item.latest_version).to have_attributes(
      schema_version: ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION,
      version: '1.0.0',
      release_date: Time.zone.now,
      definition: YAML.safe_load(definition).merge('yaml_definition' => definition)
    )
  end

  it 'returns the new item' do
    execute

    expect(graphql_data_at(:ai_catalog_flow_create, :item)).to match a_hash_including(
      'name' => name,
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'description' => description,
      'latestVersion' => a_hash_including('released' => true)
    )
  end

  context 'with locally defined prompts' do
    let(:definition) do
      <<~YAML
        version: v1
        environment: ambient
        components:
          - name: main_agent
            type: AgentComponent
            prompt_id: test_prompt
        prompts:
          - prompt_id: test_prompt
            name: Test Prompt
            unit_primitives: []
            prompt_template:
              system: You are a helpful assistant
              user: "{{goal}}"
        routers: []
        flow:
          entry_point: main_agent
      YAML
    end

    it 'creates a flow with locally defined prompt' do
      execute

      item = Ai::Catalog::Item.flow.last
      expect(item.latest_version).to have_attributes(
        schema_version: ::Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION,
        version: '1.0.0',
        release_date: be_present,
        definition: YAML.safe_load(definition).merge('yaml_definition' => definition)
      )
    end
  end

  context 'when using the legacy public argument' do
    let(:params) { super().except(:visibility).merge(public: true) }

    it 'creates a flow with public visibility' do
      execute

      expect(Ai::Catalog::Item.last).to have_attributes(visibility: 'public')
      expect(graphql_data_at(:ai_catalog_flow_create, :item, :visibility)).to eq('PUBLIC')
    end
  end

  it_behaves_like 'an AI catalog create mutation with a visibility argument' do
    let(:mutation_name) { :ai_catalog_flow_create }
  end
end
