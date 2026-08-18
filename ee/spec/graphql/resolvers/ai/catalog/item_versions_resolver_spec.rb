# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::ItemVersionsResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:resolver) { described_class }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(:created_after, :exclude_deprecated)
  end
end
