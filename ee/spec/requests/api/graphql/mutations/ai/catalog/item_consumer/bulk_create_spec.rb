# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::BulkCreate, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project_1) { create(:project, group: group, maintainers: user) }
  let_it_be(:project_2) { create(:project, group: group, maintainers: user) }
  let_it_be(:item) { create(:ai_catalog_agent, :with_released_version, :public) }

  let(:current_user) { user }
  let(:params) do
    {
      item_id: item.to_global_id.to_s,
      project_ids: [project_1.to_global_id.to_s, project_2.to_global_id.to_s]
    }
  end

  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_bulk_create, params, 'errors') }

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(ai_catalog_bulk_item_consumer_create: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  it 'enqueues the worker and returns success' do
    expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
      user.id,
      item.id,
      contain_exactly(project_1.id, project_2.id),
      {}
    )

    execute

    expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to be_empty
    expect(graphql_errors).to be_nil
  end

  context 'when pinned_version is provided' do
    let(:params) { super().merge(pinned_version: '1.2.3') }

    before do
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '1.2.3')
    end

    it 'enqueues the worker with pinned_version and returns success', :aggregate_failures do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
        user.id,
        item.id,
        contain_exactly(project_1.id, project_2.id),
        { 'pinned_version' => '1.2.3' }
      )

      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to be_empty
      expect(graphql_errors).to be_nil
    end

    context 'and it does not resolve to a released version' do
      let(:params) { super().merge(pinned_version: '9.9.9') }

      # Swallow the dev exception Item#resolve_version raises for unknown versions.
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'returns an error and does not enqueue the worker', :aggregate_failures do
        expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).not_to receive(:perform_async)

        execute

        expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to include(
          'Pinned version must resolve to a released version of the agent or flow.'
        )
      end
    end
  end

  describe 'flow triggers' do
    let(:trigger_types) { %w[pipeline_hooks] }

    # Deprecated argument format
    let(:trigger_filter) do
      {
        'pipeline_hooks' => {
          'rules' => [
            { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
          ]
        }
      }
    end

    # New argument format
    let(:trigger_conditions) do
      {
        'pipeline_hooks' => {
          'rules' => [
            { 'field' => 'object_attributes.status', 'operator' => 'IN', 'value' => %w[success failed] }
          ]
        }
      }
    end

    let_it_be(:flow_item) { create(:ai_catalog_flow, :with_released_version, :public) }

    context 'when trigger_types and trigger_conditions are provided' do
      let(:item) { flow_item }

      let(:params) do
        super().merge(trigger_types:, trigger_conditions:)
      end

      it 'enqueues the worker with the trigger filter', :aggregate_failures do
        expected_filter = trigger_filter.dup
        expected_filter['pipeline_hooks']['type'] = 'group'

        expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
          user.id,
          item.id,
          contain_exactly(project_1.id, project_2.id),
          { 'trigger_types' => %w[pipeline_hooks], 'trigger_filter' => expected_filter }
        )

        execute

        expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to be_empty
        expect(graphql_errors).to be_nil
      end
    end

    context 'when trigger_filter is provided' do
      let_it_be(:item) { flow_item }

      # We can't reuse the shared `mutation`/`params` helpers here. The `graphql_mutation` helper camelizes keys inside
      # the JSON-typed `triggerFilter` (e.g. `pipeline_hooks` becomes `pipelineHooks`).
      let(:query) do
        <<~MUTATION
        mutation($input: AiCatalogItemConsumerBulkCreateInput!) {
          aiCatalogItemConsumerBulkCreate(input: $input) {
            errors
          }
        }
        MUTATION
      end

      let(:input) do
        {
          itemId: item.to_global_id.to_s,
          projectIds: [project_1.to_global_id.to_s, project_2.to_global_id.to_s],
          triggerTypes: %w[pipeline_hooks],
          triggerFilter: trigger_filter
        }
      end

      subject(:execute) { post_graphql(query, current_user: current_user, variables: { input: input }.to_json) }

      it 'enqueues the worker with the trigger filter', :aggregate_failures do
        expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
          user.id,
          item.id,
          contain_exactly(project_1.id, project_2.id),
          {
            'trigger_types' => %w[pipeline_hooks],
            'trigger_filter' => {
              'pipeline_hooks' => {
                'rules' => [
                  { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
                ]
              }
            }
          }
        )

        execute

        expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to be_empty
        expect(graphql_errors).to be_nil
      end
    end

    context 'when both trigger_filter and trigger_conditions are provided' do
      let(:item) { flow_item }

      let(:params) do
        super().merge(trigger_conditions:, trigger_filter:, trigger_types:)
      end

      it 'returns a mutually exclusive error and does not enqueue the worker' do
        expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).not_to receive(:perform_async)

        execute

        expect(graphql_errors).to include(
          a_hash_including(
            'message' => 'Only one of [triggerFilter, triggerConditions] arguments is allowed at the same time.'
          )
        )
      end
    end
  end

  context 'when too many project_ids are passed' do
    let(:params) do
      {
        item_id: item.to_global_id.to_s,
        project_ids: Array.new(described_class::MAX_PROJECTS + 1) { "gid://gitlab/Project/1" }
      }
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: ["projectIds is too long (maximum is 100)"]
  end

  context 'when user cannot read the item' do
    let_it_be(:private_item) { create(:ai_catalog_agent) }

    let(:current_user) { create(:user) }
    let(:params) do
      {
        item_id: private_item.to_global_id.to_s,
        project_ids: [project_1.to_global_id.to_s]
      }
    end

    it_behaves_like 'a mutation that returns a top-level access error', errors: [
      "The resource that you are attempting to access does not exist or " \
        "you don't have permission to perform this action"
    ]
  end

  context 'when the enqueue service returns an error' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:unauthorized_project) { create(:project, group: other_group) }

    let(:params) do
      {
        item_id: item.to_global_id.to_s,
        project_ids: [project_1.to_global_id.to_s, unauthorized_project.to_global_id.to_s]
      }
    end

    it 'returns an error and does not enqueue the worker' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).not_to receive(:perform_async)

      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_bulk_create, :errors)).to include(
        'One or more projects not found, or you do not have permission to enable this item in the project.'
      )
    end
  end
end
