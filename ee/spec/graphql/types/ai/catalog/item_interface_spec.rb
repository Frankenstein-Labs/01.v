# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::ItemInterface, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogItem')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      created_at
      configuration_for_group
      configuration_for_project
      description
      description_html
      foundational
      id
      item_type
      name
      latest_version
      effective_version
      project
      public
      visibility
      soft_deleted
      soft_deleted_at
      updated_at
      user_permissions
      versions
      foundational_flow_reference
      verification_level
      last_30_day_usage_count
      is_enabled_in_managed_by_project
      star_count
      starred
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe ".resolve_type" do
    let_it_be(:user) { create(:user) }
    let_it_be(:item) { create(:ai_catalog_item, item_type: 'agent') }

    let(:context) { {} }

    subject(:resolve_type) { described_class.resolve_type(item, context) }

    it { is_expected.to eq(Types::Ai::Catalog::AgentType) }

    context 'when item_type is unknown' do
      before do
        allow(item).to receive(:item_type).and_return('unknown_type')
      end

      it 'raises an error' do
        expect { resolve_type }.to raise_exception(StandardError, 'Unknown catalog item type: unknown_type')
      end
    end
  end

  describe 'is_enabled_in_managed_by_project field' do
    subject(:field) { described_class.fields['isEnabledInManagedByProject'] }

    it 'limits field call count' do
      extension = field.extensions.find { |e| e.is_a?(::Gitlab::Graphql::Limit::FieldCallCount) }

      expect(extension).to be_present
      expect(extension.options).to eq(limit: 1)
    end
  end
end
