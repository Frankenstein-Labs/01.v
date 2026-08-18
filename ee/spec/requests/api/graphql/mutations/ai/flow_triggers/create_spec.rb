# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Create, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :in_group, maintainers: [service_account]) }
  let_it_be(:group_owner) { create(:user, owner_of: project.group) }
  let_it_be(:service_account) { create(:service_account, provisioned_by_group: project.root_ancestor) }
  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:current_user) { group_owner }
  let(:mutation) { graphql_mutation(:ai_flow_trigger_create, params) }
  let(:description) { 'Description' }
  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) do
    {
      project_path: project.full_path,
      user_id: service_account.to_global_id,
      description: description,
      event_types: event_types,
      config_path: '.gitlab/duo/agents.yml'
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    ::Ai::Setting.for_organization(current_organization).update!(duo_core_features_enabled: true)

    stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true,
      duo_features_enabled: true)
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a flow trigger' do
      expect { execute }.not_to change { Ai::FlowTrigger.count }
    end
  end

  context 'when user does not have permission' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when graphql params are invalid' do
    let(:description) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include('description (Expected value to not be null)')
    end
  end

  context 'when model params are invalid' do
    let(:description) { 'a' * 256 }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_create, :errors).first).to include(
        'Description is too long (maximum is 255 characters)'
      )
      expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to be_nil
    end
  end

  it 'creates a flow trigger with expected data' do
    execute

    trigger = Ai::FlowTrigger.last
    expect(trigger).to have_attributes(
      description: description,
      user_id: service_account.id,
      project_id: project.id,
      event_types: event_types,
      config_path: '.gitlab/duo/agents.yml'
    )
  end

  it 'returns the new trigger' do
    execute

    expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to match a_hash_including(
      'description' => description,
      'eventTypes' => event_types,
      'configPath' => '.gitlab/duo/agents.yml',
      'configUrl' => "/#{project.full_path}/-/blob/#{project.default_branch}/.gitlab/duo/agents.yml",
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'user' => a_hash_including('id' => service_account.to_global_id.to_s)
    )
  end

  context 'when filter is provided' do
    # Build the query by hand and pass the variables as a raw JSON string so that
    # `prepare_variables` does not camelize keys inside the JSON-typed `filter`
    # argument (a test-helper artifact that does not reflect real client behavior).
    let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]] }

    let(:filter) do
      {
        'pipeline_hooks' => {
          'match' => 'all',
          'rules' => [
            { 'field' => 'object_attributes.status', 'operator' => 'eq', 'value' => 'failed' }
          ]
        }
      }
    end

    let(:query) do
      <<~MUTATION
        mutation($input: AiFlowTriggerCreateInput!) {
          aiFlowTriggerCreate(input: $input) {
            aiFlowTrigger { id filter }
            errors
          }
        }
      MUTATION
    end

    let(:input) do
      {
        projectPath: project.full_path,
        userId: service_account.to_global_id.to_s,
        description: description,
        eventTypes: event_types,
        configPath: '.gitlab/duo/agents.yml',
        filter: filter
      }
    end

    subject(:execute) { post_graphql(query, current_user: current_user, variables: { input: input }.to_json) }

    it 'persists the filter on the trigger' do
      execute

      expect(Ai::FlowTrigger.last.filter).to eq(filter)
    end

    it 'returns the filter on the response' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger, :filter)).to eq(filter)
    end

    context 'when filter does not match the JSON schema' do
      let(:filter) { { 'pipeline_hooks' => { 'rules' => [{ 'field' => 'x' }] } } }

      it 'returns the validation error' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_create, :errors).first).to include('Filter')
        expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to be_nil
      end
    end
  end

  context 'when using catalog item configuration' do
    let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, :child_item_consumer, project: project) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
    end

    context 'with valid catalog item parameters' do
      let(:params) do
        {
          project_path: project.full_path,
          description: description,
          event_types: event_types,
          ai_catalog_item_consumer_id: item_consumer.to_global_id
        }
      end

      it 'creates a flow trigger with catalog item' do
        execute

        trigger = Ai::FlowTrigger.last
        expect(trigger).to have_attributes(
          description: description,
          project_id: project.id,
          event_types: event_types,
          ai_catalog_item_consumer_id: item_consumer.id,
          config_path: nil
        )
      end

      it 'returns the new trigger with catalog item data' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger)).to match a_hash_including(
          'description' => description,
          'eventTypes' => event_types,
          'configPath' => nil,
          'configUrl' => nil,
          'aiCatalogItemConsumer' => a_hash_including('id' => item_consumer.to_global_id.to_s),
          'project' => a_hash_including('id' => project.to_global_id.to_s),
          'user' => a_hash_including('id' => item_consumer.active_service_account.to_global_id.to_s)
        )
      end

      context 'when the user_id param is explicitly set to nil' do
        let(:params) { super().merge(user_id: nil) }

        it 'creates the new trigger with the correct user set' do
          expect { execute }.to change { Ai::FlowTrigger.count }

          expect(graphql_data_at(:ai_flow_trigger_create, :ai_flow_trigger, :user, :id))
            .to eq(item_consumer.active_service_account.to_global_id.to_s)
        end
      end

      context 'when the user_id param is also included' do
        let(:params) { super().merge(user_id: item_consumer.active_service_account.to_global_id) }

        it 'creates a flow trigger with catalog items, without setting the user_id' do
          execute

          trigger = Ai::FlowTrigger.last
          expect(trigger).to have_attributes(
            description: description,
            user_id: nil,
            project_id: project.id,
            event_types: event_types,
            ai_catalog_item_consumer_id: item_consumer.id,
            config_path: nil
          )
        end
      end
    end

    context 'with invalid catalog item parameters' do
      let(:params) do
        {
          project_path: project.full_path,
          description: description,
          event_types: event_types,
          config_path: '.gitlab/duo/agents.yml',
          ai_catalog_item_consumer_id: item_consumer.to_global_id
        }
      end

      it 'returns an error' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_create, :errors).first).to include(
          'Exactly one of config_path, ai_catalog_item_consumer must be present'
        )
      end
    end
  end
end
