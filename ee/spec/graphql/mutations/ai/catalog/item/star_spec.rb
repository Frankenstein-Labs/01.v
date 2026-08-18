# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Item::Star, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogItemStar') }
  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item) }
  it { is_expected.to have_graphql_fields(:star_count, :errors, :client_mutation_id) }
  it { is_expected.to have_graphql_arguments(:id, :starred, :client_mutation_id) }
end
