# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemVersion::Restore, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogItemVersionRestore') }

  it { expect(described_class).to require_graphql_authorizations(:restore_ai_catalog_item) }

  it { is_expected.to have_graphql_fields(:item_version, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(:id, :deprecate_current, :client_mutation_id)
  end
end
