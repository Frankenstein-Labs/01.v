# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::ConfiguredItemsResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:resolver) { described_class }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :group_id,
      :include_inherited,
      :include_foundational_consumers,
      :item_id,
      :project_id,
      :configurable_for_project_id,
      :item_type,
      :item_types,
      :foundational_flow_reference
    )
  end

  describe 'validation' do
    let(:item_consumer_finder_result) { class_double(::Ai::Catalog::ItemConsumer, exists?: true) }

    before do
      allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
        allow(finder).to receive(:execute).and_return(item_consumer_finder_result)
      end
    end

    context 'when neither group_id nor project_id is provided' do
      it 'returns a GraphQL error' do
        result = resolve(resolver, args: {}, ctx: { current_user: user })

        expect(result).to be_a(GraphQL::ExecutionError)
        expect(result.message).to eq('At least one of [groupId, projectId] arguments is required.')
      end
    end
  end

  describe 'argument preparation' do
    before do
      allow_next_instance_of(Ai::Catalog::ItemConsumersFinder) do |finder|
        allow(finder).to receive(:execute).and_return(::Ai::Catalog::ItemConsumer.none)
      end
    end

    context 'when configurable_for_project_id, project_id are nil' do
      it 'prepares the argument as nil' do
        result = resolve(resolver, args: {
          group_id: group.to_global_id, configurable_for_project_id: nil, project_id: nil
        }, ctx: { current_user: user })

        expect(result).to be_a(Gitlab::Graphql::Pagination::Keyset::Connection)
      end
    end
  end
end
