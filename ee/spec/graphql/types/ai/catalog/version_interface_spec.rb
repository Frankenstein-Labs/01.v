# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::VersionInterface, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogItemVersion')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      created_at
      created_by
      deprecated
      human_version_name
      id
      item
      released_at
      released
      updated_at
      version_name
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe ".resolve_type" do
    let_it_be(:user) { create(:user) }
    let_it_be(:version) { create(:ai_catalog_item_version) }

    let(:context) { {} }

    subject(:resolve_type) { described_class.resolve_type(version, context) }

    it { is_expected.to eq(Types::Ai::Catalog::AgentVersionType) }

    context 'when item_type of item is unknown' do
      before do
        allow(version.item).to receive(:item_type).and_return('unknown_type')
      end

      it 'raises an error' do
        expect { resolve_type }.to raise_exception(StandardError, 'Unknown catalog item type: unknown_type')
      end
    end
  end
end
