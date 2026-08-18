# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Create, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project_maintainer) { create(:user) }
  let_it_be(:project_maintainer_not_in_group) { create(:user) }

  let_it_be(:consumer_group) { create(:group, owners: user, guests: project_maintainer) }
  let_it_be(:consumer_project) do
    create(:project, group: consumer_group, maintainers: [project_maintainer, project_maintainer_not_in_group])
  end

  let_it_be(:service_account) { create(:user, :service_account) }
  let_it_be(:service_account_user_detail) do
    create(:user_detail, user: service_account, provisioned_by_group: consumer_group)
  end

  let_it_be(:item_project) { create(:project, guests: user) }
  let_it_be(:item, freeze: false) { create(:ai_catalog_flow, :public, project: item_project) }

  let_it_be(:item_old_released_version, freeze: false) do
    create(:ai_catalog_flow_version, :released, item: item, version: '1.2.3')
  end

  let_it_be(:item_latest_released_version) do
    create(:ai_catalog_flow_version, :released, item: item, version: '3.2.1')
  end

  let_it_be(:consumer_group_item_consumer) do
    create(:ai_catalog_item_consumer, pinned_version_prefix: '1.2.3', group: consumer_group, item: item,
      service_account: service_account)
  end

  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_group_item_consumer) { create(:ai_catalog_item_consumer, group: other_group, item: item) }

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_create, params) }
  let(:target) { { project_id: consumer_project.to_global_id } }
  let(:params) do
    {
      target: target,
      item_id: item.to_global_id,
      parent_item_consumer_id: consumer_group_item_consumer.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a catalog item consumer' do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }
    end
  end

  shared_examples 'a successful request' do |pinned_version_prefix:|
    it 'creates a catalog item consumer with expected data' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
        'pinnedVersionPrefix' => pinned_version_prefix
      )
    end
  end

  context 'when user is not authorized to create a consumer item in the consumer project' do
    let(:current_user) do
      create(:user).tap do |user|
        consumer_project.add_guest(user)
        item_project.add_guest(user)
      end
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the user is a project maintainer and group guest' do
    let(:current_user) { project_maintainer }

    it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'
  end

  context 'when the user is a project maintainer and does not belong to the group' do
    let(:current_user) { project_maintainer_not_in_group }

    it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'
  end

  context 'when the parent_item_consumer ID does not exist' do
    let(:params) { super().merge(parent_item_consumer_id: "gid://gitlab/Ai::Catalog::ItemConsumer/non-existent-id") }
    let(:current_user) { project_maintainer_not_in_group }

    it 'returns a not found error' do
      execute

      expect(graphql_errors.first['message']).to eq(
        "The resource that you are attempting to access does not exist or " \
          "you don't have permission to perform this action"
      )
    end
  end

  context 'when the parent_item_consumer ID belongs to a different group' do
    let(:params) { super().merge(parent_item_consumer_id: other_group_item_consumer.to_global_id) }

    context 'when the user does not have access to the group' do
      it 'returns a not found error' do
        execute

        expect(graphql_errors.first['message']).to eq(
          "The resource that you are attempting to access does not exist or " \
            "you don't have permission to perform this action"
        )
      end
    end

    # TODO: Add this test after the issue below. There will still be an error, but it will be a different error message.
    context 'when the user has access to the group', skip: 'Depends on https://gitlab.com/gitlab-org/gitlab/-/issues/580696'
  end

  context 'when user is not authorized to read the catalog item' do
    let_it_be(:item, freeze: false) { create(:ai_catalog_flow, project: item_project) }

    let(:current_user) do
      create(:user).tap do |user|
        consumer_project.add_maintainer(user)
        # User is not a member of item_project
      end
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when target argument is provided neither group_id or project_id' do
    let(:target) { {} }

    it_behaves_like 'an invalid argument to the mutation', argument_name: :target
  end

  context 'when target is provided both group_id or project_id are provided' do
    let(:target) { super().merge({ group_id: consumer_group.to_global_id }) }

    it_behaves_like 'an invalid argument to the mutation', argument_name: :target
  end

  context 'when user has a custom role with admin_ai_catalog_item_consumer' do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) do
      create(:member_role, :guest, :admin_ai_catalog_item_consumer, namespace: consumer_group)
    end

    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: consumer_project)
    end

    let(:current_user) { custom_role_user }
    let(:params) do
      {
        target: { project_id: consumer_project.to_global_id },
        item_id: item.to_global_id
      }
    end

    it 'creates a catalog item consumer' do
      stub_licensed_features(custom_roles: true)
      item_project.add_guest(custom_role_user)

      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
    end
  end

  context 'when the item is an agent' do
    let_it_be(:item, freeze: false) { create(:ai_catalog_agent, :public, project: item_project) }
    let_it_be(:consumer_group_item_consumer) do
      create(:ai_catalog_item_consumer, item: item, group: consumer_group, pinned_version_prefix: '3.2.1')
    end

    let_it_be(:item_latest_released_version) do
      create(:ai_catalog_agent_version, :released, item: item, version: '3.2.1')
    end

    it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'
  end

  it_behaves_like 'a successful request', pinned_version_prefix: '3.2.1'

  context 'when a pinned_version is provided' do
    context 'and it is a released version' do
      let(:params) { super().merge(pinned_version: '1.2.3') }

      it_behaves_like 'a successful request', pinned_version_prefix: '1.2.3'
    end

    context 'and it does not resolve to a released version' do
      # Item#resolve_version raises a dev exception on an unknown version; here that
      # version is ordinary user input we validate, so swallow the raise in test env.
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      let(:params) { super().merge(pinned_version: '9.9.9') }

      it 'returns an error and does not create a consumer' do
        expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }

        expect(graphql_data_at(:ai_catalog_item_consumer_create, :errors)).to include(
          'Pinned version must resolve to a released version of the agent or flow'
        )
      end
    end
  end

  context 'with a group_id' do
    let_it_be(:group) { create(:group, owners: user) }

    let(:params) do
      {
        item_id: item.to_global_id,
        target: { group_id: group.to_global_id }
      }
    end

    let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

    before do
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive(:seats).and_return(User.service_account.count + 2)
    end

    it 'creates a service account and attaches it to the item consumer' do
      expect { execute }.to change { User.count }.by(1)
      service_account = User.last
      expect(service_account).to be_service_account
      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'serviceAccount' => a_hash_including('id' => service_account.to_global_id.to_s),
        'pinnedVersionPrefix' => '3.2.1'
      )
    end
  end

  context 'when item is a foundational chat agent' do
    let_it_be(:foundational_item) { create(:ai_catalog_agent, :public, project: item_project, id: 348) }

    let(:params) do
      {
        target: target,
        item_id: foundational_item.to_global_id,
        parent_item_consumer_id: consumer_group_item_consumer.to_global_id
      }
    end

    it 'returns an error and does not create an item consumer' do
      stub_saas_features(gitlab_duo_saas_only: true)

      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to be_nil
      expect(graphql_data_at(:ai_catalog_item_consumer_create,
        :errors)).to eq(["Foundational agents must be configured in admin settings."])
    end
  end

  context 'when parent_item_consumer_id is not provided', :aggregate_failures do
    let(:params) do
      {
        target: { project_id: consumer_project.to_global_id },
        item_id: item.to_global_id
      }
    end

    let(:current_user) { project_maintainer }

    it 'reuses the existing group item consumer as the parent and creates only the project item consumer' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => item.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s),
        'pinnedVersionPrefix' => item.latest_released_version.version
      )
    end
  end

  context 'when trigger_filter is provided' do
    # Build the query by hand and pass the variables as a raw JSON string so that
    # `prepare_variables` does not camelize keys inside the JSON-typed `triggerFilter`
    # argument (a test-helper artifact that does not reflect real client behavior).
    let(:trigger_filter) do
      {
        'pipeline_hooks' => {
          'rules' => [
            { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
          ]
        }
      }
    end

    let(:query) do
      <<~MUTATION
        mutation($input: AiCatalogItemConsumerCreateInput!) {
          aiCatalogItemConsumerCreate(input: $input) {
            errors
          }
        }
      MUTATION
    end

    let(:input) do
      {
        target: { projectId: consumer_project.to_global_id.to_s },
        itemId: item.to_global_id.to_s,
        triggerTypes: %w[pipeline_hooks],
        triggerFilter: trigger_filter
      }
    end

    subject(:execute) { post_graphql(query, current_user: current_user, variables: { input: input }.to_json) }

    it 'persists the filter on the auto-created flow trigger' do
      expect { execute }.to change { Ai::FlowTrigger.count }.by(1)

      expect(Ai::FlowTrigger.last).to have_attributes(
        project_id: consumer_project.id,
        event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]],
        filter: trigger_filter
      )
    end

    context 'when trigger_filter references an event type not in trigger_types' do
      let(:input) { super().merge(triggerTypes: %w[mention]) }

      it 'returns a validation error and does not create a flow trigger' do
        expect { execute }.not_to change { Ai::FlowTrigger.count }

        expect(graphql_data_at(:ai_catalog_item_consumer_create, :errors)).to eq(
          ['Flow trigger filter contains filters for event types not in event_types: pipeline_hooks']
        )
      end
    end

    context 'when trigger_filter is not a JSON object' do
      where(:trigger_filter) { [123, 'a string', [1, 2, 3], true] }

      with_them do
        it 'returns a validation error and does not create an item consumer or flow trigger' do
          expect { execute }.to not_change { Ai::Catalog::ItemConsumer.count }
            .and not_change { Ai::FlowTrigger.count }

          expect(graphql_data_at(:ai_catalog_item_consumer_create, :errors)).to include(
            'Flow trigger filter must be a valid json schema'
          )
        end
      end
    end
  end

  context 'when trigger_conditions is provided' do
    let(:status_rule) { { field: 'object_attributes.status', operator: 'IN', value: %w[success failed] } }
    let(:converted_status_rule) do
      { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
    end

    let(:ref_rule) { { field: 'object_attributes.ref', operator: 'EQ', value: 'main' } }
    let(:converted_ref_rule) { { 'field' => 'object_attributes.ref', 'operator' => 'eq', 'value' => 'main' } }

    let(:filter_group) { { match: 'ALL', rules: [status_rule] } }
    let(:converted_filter_group) { { 'type' => 'group', 'match' => 'all', 'rules' => [converted_status_rule] } }

    let(:params) do
      {
        target: { project_id: consumer_project.to_global_id.to_s },
        item_id: item.to_global_id.to_s,
        trigger_types: %w[pipeline_hooks],
        trigger_conditions: { pipeline_hooks: filter_group }
      }
    end

    let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_create, params, 'errors') }

    subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

    shared_examples 'a request that persists the converted filter' do
      it 'persists the converted filter on the auto-created flow trigger' do
        expect { execute }.to change { Ai::FlowTrigger.count }.by(1)

        expect(Ai::FlowTrigger.last).to have_attributes(
          project_id: consumer_project.id,
          event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]],
          filter: { 'pipeline_hooks' => converted_filter_group }
        )
      end
    end

    shared_examples 'a rule item validation failure' do |*messages|
      it 'returns a validation error and does not create a flow trigger', :aggregate_failures do
        expect { execute }.not_to change { Ai::FlowTrigger.count }

        messages.each do |message|
          expect(graphql_errors).to include(a_hash_including('message' => a_string_including(message)))
        end
      end
    end

    shared_examples 'a rule item that must provide exactly one variant' do
      it_behaves_like 'a rule item validation failure',
        'AiCatalogTriggerConditionsRuleItemInput must include exactly one of the following ' \
          'arguments: (field and operator and value), (rules).'
    end

    it_behaves_like 'a request that persists the converted filter'

    context 'when a rule contains a nested group' do
      let(:filter_group) do
        super().merge(rules: [status_rule, { match: 'ANY', rules: [ref_rule] }])
      end

      let(:converted_filter_group) do
        super().merge(
          'rules' => [
            converted_status_rule,
            { 'type' => 'group', 'match' => 'any', 'rules' => [converted_ref_rule] }
          ]
        )
      end

      it_behaves_like 'a request that persists the converted filter'
    end

    context 'when match is omitted' do
      let(:filter_group) { { rules: [status_rule, { rules: [ref_rule] }] } }

      let(:converted_filter_group) do
        {
          'type' => 'group',
          'rules' => [converted_status_rule, { 'type' => 'group', 'rules' => [converted_ref_rule] }]
        }
      end

      it_behaves_like 'a request that persists the converted filter'
    end

    context 'when a rule item provides both rule and group fields' do
      let(:filter_group) { { rules: [status_rule.merge(rules: [ref_rule])] } }

      it_behaves_like 'a rule item that must provide exactly one variant'
    end

    context 'when a rule item provides neither rule nor group fields' do
      let(:filter_group) { { rules: [{}] } }

      it_behaves_like 'a rule item that must provide exactly one variant'
    end

    context 'when a rule item provides only some of the rule fields' do
      let(:filter_group) { { rules: [{ field: 'object_attributes.status', operator: 'IN' }] } }

      it_behaves_like 'a rule item that must provide exactly one variant'
    end

    context 'when a rule item provides only match' do
      let(:filter_group) { { rules: [{ match: 'ANY' }] } }

      it_behaves_like 'a rule item that must provide exactly one variant'
    end

    context 'when a rule item provides match alongside a rule field' do
      where(:rule_field, :message) do
        [
          [{ field: 'object_attributes.status' }, 'Only one of [match, field] arguments is allowed at the same time.'],
          [{ operator: 'IN' }, 'Only one of [match, operator] arguments is allowed at the same time.'],
          [{ value: %w[success] }, 'Only one of [match, value] arguments is allowed at the same time.']
        ]
      end

      with_them do
        let(:filter_group) { { rules: [{ match: 'ANY', rules: [ref_rule] }.merge(rule_field)] } }

        it 'returns a validation error and does not create a flow trigger' do
          expect { execute }.not_to change { Ai::FlowTrigger.count }

          expect(graphql_errors).to include(a_hash_including('message' => a_string_including(message)))
        end
      end
    end

    context 'when a rule item provides all rule fields alongside match' do
      let(:filter_group) { { rules: [status_rule.merge(match: 'ANY')] } }

      it_behaves_like 'a rule item validation failure',
        'Only one of [match, field] arguments is allowed at the same time.',
        'Only one of [match, operator] arguments is allowed at the same time.',
        'Only one of [match, value] arguments is allowed at the same time.'
    end

    context 'when both trigger_filter and trigger_conditions are provided' do
      let(:params) do
        super().merge(
          trigger_filter: { 'pipeline_hooks' => { 'rules' => [] } }
        )
      end

      it 'returns a mutually exclusive error and does not create a flow trigger' do
        expect { execute }.not_to change { Ai::FlowTrigger.count }

        expect(graphql_errors).to include(
          a_hash_including(
            'message' => 'Only one of [triggerFilter, triggerConditions] arguments is allowed at the same time.'
          )
        )
      end
    end
  end

  context 'when item is a foundational flow' do
    let_it_be(:foundational_flow, freeze: false) do
      create(:ai_catalog_flow, :with_foundational_flow_reference, :public, project: item_project)
    end

    let_it_be(:foundational_flow_latest_released_version, freeze: false) do
      create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')
    end

    let_it_be(:foundational_flow_service_account) { create(:user, :service_account) }
    let_it_be(:foundational_flow_service_account_detail) do
      create(:user_detail, user: foundational_flow_service_account, provisioned_by_group: consumer_group)
    end

    let_it_be(:foundational_flow_item_consumer) do
      create(:ai_catalog_item_consumer, item: foundational_flow, group: consumer_group, pinned_version_prefix: '1.0.0',
        service_account: foundational_flow_service_account)
    end

    let(:params) do
      {
        target: target,
        item_id: foundational_flow.to_global_id,
        parent_item_consumer_id: foundational_flow_item_consumer.to_global_id
      }
    end

    let_it_be(:foundational_flow_group_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace,
        namespace: consumer_group,
        catalog_item: foundational_flow)
    end

    let_it_be(:foundational_flow_project_enabled) do
      create(:ai_catalog_enabled_foundational_flow, :for_project,
        project: consumer_project,
        catalog_item: foundational_flow)
    end

    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(anything, :foundational_flows).and_return(true)
    end

    it 'successfully creates an item consumer for foundational flows' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)

      expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to match a_hash_including(
        'item' => a_hash_including('id' => foundational_flow.to_global_id.to_s),
        'project' => a_hash_including('id' => consumer_project.to_global_id.to_s)
      )
      expect(graphql_data_at(:ai_catalog_item_consumer_create, :errors)).to be_empty
    end

    context 'when trigger_types are provided' do
      let(:params) do
        super().merge(trigger_types: %w[mention assign])
      end

      it 'returns a validation error' do
        execute

        expect(graphql_data_at(:ai_catalog_item_consumer_create, :item_consumer)).to be_nil
        expect(graphql_data_at(:ai_catalog_item_consumer_create, :errors)).to eq(
          ["You can't create triggers for foundational flows"]
        )
      end
    end
  end
end
