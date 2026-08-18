# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::ItemConsumerType, feature_category: :workflow_catalog do
  include GraphqlHelpers

  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogItemConsumer')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      group
      id
      enabled
      flow_trigger
      item
      organization
      parent_item_consumer
      pinned_item_version
      pinned_version_prefix
      service_account
      project
      user_permissions
      web_path
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item_consumer) }

  describe 'pinned_item_version field' do
    subject(:field) { described_class.fields['pinnedItemVersion'] }

    it 'limits field call count' do
      extension = field.extensions.find { |e| e.is_a?(::Gitlab::Graphql::Limit::FieldCallCount) }

      expect(extension).to be_present
      expect(extension.options).to eq(limit: 20)
    end
  end

  describe '#web_path' do
    using RSpec::Parameterized::TableSyntax

    subject(:web_path) { Gitlab::Graphql::Lazy.force(resolve_field(:web_path, consumer)) }

    before do
      allow(described_class).to receive(:authorized?).and_return(true)
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:item).and_return(consumer.item)
      end
    end

    let(:group) { build_stubbed(:group, path: 'test-group') }
    let(:project) { build_stubbed(:project, path: 'test-project', group: group) }

    where(:container, :item_type, :expected_path) do
      ref(:group)   | :for_agent            | "/groups/test-group/-/automate/agents/"
      ref(:group)   | :for_third_party_flow | "/groups/test-group/-/automate/agents/"
      ref(:group)   | :for_flow             | "/groups/test-group/-/automate/flows/"
      ref(:project) | :for_agent            | "/test-group/test-project/-/automate/agents/"
      ref(:project) | :for_third_party_flow | "/test-group/test-project/-/automate/agents/"
      ref(:project) | :for_flow             | "/test-group/test-project/-/automate/flows/"
    end

    with_them do
      let(:consumer) do
        if container.is_a?(Project)
          build_stubbed(:ai_catalog_item_consumer, item_type, project: container)
        else
          build_stubbed(:ai_catalog_item_consumer, item_type, group: container)
        end
      end

      it { is_expected.to eq(expected_path + consumer.ai_catalog_item_id.to_s) }
    end

    context 'when the consumer is not scoped' do
      let(:consumer) { build_stubbed(:ai_catalog_item_consumer, project: nil, group: nil) }

      it { is_expected.to be_nil }
    end

    context 'when item is nil' do
      let(:consumer) { build_stubbed(:ai_catalog_item_consumer, :for_agent, project: project) }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:item).and_return(nil)
        end
      end

      it { is_expected.to be_nil }
    end

    context 'when item type has no path helper' do
      let(:consumer) { build_stubbed(:ai_catalog_item_consumer, :for_agent, project: project) }
      let(:unknown_item) { instance_double(Ai::Catalog::Item, item_type: 'unknown') }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:item).and_return(unknown_item)
        end
      end

      it { is_expected.to be_nil }
    end
  end
end
