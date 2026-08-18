# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::ItemConsumerResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:resolver) { described_class }

  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :public, developers: developer) }
  let_it_be(:catalog_item) { create(:ai_catalog_agent, project:) }
  let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, project: project, item: catalog_item) }

  let(:current_user) { developer }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(:id)
  end
end
