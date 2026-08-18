# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::FlowTriggers::Update, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :in_group, maintainers: [service_account]) }
  let_it_be(:group_owner) { create(:user, owner_of: project.group) }
  let_it_be(:service_account) { create(:service_account, provisioned_by_group: project.root_ancestor) }

  let_it_be_with_reload(:trigger) { create(:ai_flow_trigger, project: project) }
  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }
  let_it_be(:original) { trigger.attributes.dup }

  let(:current_user) { group_owner }
  let(:mutation) { graphql_mutation(:ai_flow_trigger_update, params) }
  let(:description) { 'New' }
  let(:event_types) { [Ai::FlowTrigger::EVENT_TYPES[:mention]] }
  let(:params) do
    {
      id: trigger.to_global_id,
      user_id: service_account.to_global_id,
      description: description,
      event_types: event_types,
      config_path: '.gitlab/duo_agents.yml'
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

    it 'does not modify the trigger' do
      expect { execute }.not_to change { trigger.attributes }
    end
  end

  context 'when user does not have permission' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when graphql params are invalid' do
    let(:params) { super().merge(user_id: 'gid://gitlab/Project/1') }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include('does not represent an instance of User')
    end
  end

  context 'when model params are invalid' do
    let(:description) { 'a' * 256 }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_flow_trigger_update, :errors).first).to include(
        'Description is too long (maximum is 255 characters)'
      )
      expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to be_nil
    end
  end

  it 'creates a flow trigger with expected data' do
    expect { execute }.to change { trigger.reload.attributes }.from(
      a_hash_including(
        'description' => original['description'],
        'user_id' => original['user_id'],
        'config_path' => original['config_path']
      )
    ).to(
      a_hash_including(
        'description' => 'New',
        'user_id' => service_account.id,
        'config_path' => '.gitlab/duo_agents.yml'
      )
    )
  end

  it 'returns the new trigger' do
    execute

    expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to match a_hash_including(
      'description' => description,
      'eventTypes' => event_types,
      'configPath' => '.gitlab/duo_agents.yml',
      'configUrl' => "/#{project.full_path}/-/blob/#{project.default_branch}/.gitlab/duo_agents.yml",
      'project' => a_hash_including('id' => project.to_global_id.to_s),
      'user' => a_hash_including('id' => service_account.to_global_id.to_s)
    )
  end

  context 'when updating catalog item configuration' do
    let_it_be(:parent_item_consumer) do
      create(
        :ai_catalog_item_consumer, :parent_item_consumer, group: project.root_ancestor, service_account: service_account
      )
    end

    let_it_be(:item_consumer1) do
      create(
        :ai_catalog_item_consumer,
        :child_item_consumer,
        project: project,
        parent_item_consumer: parent_item_consumer,
        item: parent_item_consumer.item
      )
    end

    let_it_be(:item_consumer2) { create(:ai_catalog_item_consumer, :child_item_consumer, project: project) }

    before do
      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
    end

    context 'when switching from config_path to catalog item' do
      let_it_be_with_reload(:config_trigger) do
        create(:ai_flow_trigger, project: project, user: service_account, config_path: 'original/config.yml')
      end

      let(:params) do
        {
          id: config_trigger.to_global_id,
          user_id: service_account.to_global_id,
          description: description,
          event_types: event_types,
          config_path: nil,
          ai_catalog_item_consumer_id: item_consumer1.to_global_id
        }
      end

      it 'updates to use catalog item' do
        execute

        config_trigger.reload
        expect(config_trigger).to have_attributes(
          description: description,
          user_id: nil,
          event_types: event_types,
          config_path: nil,
          ai_catalog_item_consumer_id: item_consumer1.id
        )
      end

      it 'returns the updated trigger with catalog item data' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to match a_hash_including(
          'description' => description,
          'eventTypes' => event_types,
          'configPath' => nil,
          'configUrl' => nil,
          'aiCatalogItemConsumer' => a_hash_including('id' => item_consumer1.to_global_id.to_s),
          'project' => a_hash_including('id' => project.to_global_id.to_s),
          'user' => a_hash_including('id' => service_account.to_global_id.to_s)
        )
      end
    end

    context 'when switching from catalog item to config_path' do
      let_it_be_with_reload(:catalog_trigger) do
        create(:ai_flow_trigger,
          :for_catalog_consumer,
          project: project,
          ai_catalog_item_consumer: item_consumer1
        )
      end

      let(:params) do
        {
          id: catalog_trigger.to_global_id,
          user_id: service_account.to_global_id,
          description: description,
          event_types: event_types,
          config_path: 'new/config/path.yml',
          ai_catalog_item_consumer_id: nil
        }
      end

      it 'updates to use config_path' do
        execute

        catalog_trigger.reload
        expect(catalog_trigger).to have_attributes(
          description: description,
          user_id: service_account.id,
          event_types: event_types,
          config_path: 'new/config/path.yml',
          ai_catalog_item_consumer_id: nil
        )
      end

      it 'returns the updated trigger with config path data' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to match a_hash_including(
          'description' => description,
          'eventTypes' => event_types,
          'configPath' => 'new/config/path.yml',
          'configUrl' => "/#{project.full_path}/-/blob/#{project.default_branch}/new/config/path.yml",
          'aiCatalogItemConsumer' => nil,
          'project' => a_hash_including('id' => project.to_global_id.to_s),
          'user' => a_hash_including('id' => service_account.to_global_id.to_s)
        )
      end
    end

    context 'when updating catalog item' do
      let_it_be_with_reload(:catalog_trigger) do
        create(:ai_flow_trigger,
          :for_catalog_consumer,
          project: project,
          ai_catalog_item_consumer: item_consumer1)
      end

      let(:params) do
        {
          id: catalog_trigger.to_global_id,
          description: description,
          event_types: event_types,
          ai_catalog_item_consumer_id: item_consumer2.to_global_id
        }
      end

      it 'updates to different catalog item' do
        execute

        catalog_trigger.reload
        expect(catalog_trigger).to have_attributes(
          description: description,
          user_id: nil,
          event_types: event_types,
          ai_catalog_item_consumer_id: item_consumer2.id
        )
      end

      context 'when the user_id param is explicitly set to nil' do
        let(:params) { super().merge(user_id: nil) }

        it 'updates the new trigger without causing any exception' do
          execute

          expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to match a_hash_including(
            'description' => description,
            'user' => a_hash_including('id' => item_consumer2.parent_item_consumer.service_account.to_global_id.to_s)
          )
        end
      end

      it 'returns the updated trigger with new catalog item data' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_update, :ai_flow_trigger)).to match a_hash_including(
          'description' => description,
          'eventTypes' => event_types,
          'aiCatalogItemConsumer' => a_hash_including('id' => item_consumer2.to_global_id.to_s)
        )
      end
    end

    context 'with invalid catalog item parameters' do
      let(:params) do
        {
          id: trigger.to_global_id,
          user_id: service_account.to_global_id,
          description: description,
          event_types: event_types,
          config_path: nil,
          ai_catalog_item_consumer_id: nil
        }
      end

      it 'returns an error' do
        execute

        expect(graphql_data_at(:ai_flow_trigger_update, :errors).first).to include(
          'Exactly one of config_path, ai_catalog_item_consumer must be present'
        )
      end
    end
  end
end
