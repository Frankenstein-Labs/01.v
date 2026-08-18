# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::ProjectItemConsumerForItemResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }
  let_it_be(:owning_project) { create(:project) }
  let_it_be(:item) { create(:ai_catalog_item, :public, project: owning_project) }

  let(:args) { { id: global_id_of(item) } }

  subject(:result) { sync(resolve(described_class, obj: project, args: args, ctx: { current_user: user })) }

  it 'has expected arguments' do
    expect(described_class).to have_graphql_arguments(:id)
  end

  context 'when a consumer exists for the project and item' do
    let_it_be(:consumer) do
      create(:ai_catalog_item_consumer, project: project, item: item, enabled: true)
    end

    it { is_expected.to eq(consumer) }
  end

  context 'when no consumer exists for the project and item' do
    it { is_expected.to be_nil }
  end

  context 'when a consumer exists in a different project' do
    let_it_be(:other_project) { create(:project) }

    before do
      create(:ai_catalog_item_consumer, project: other_project, item: item, enabled: true)
    end

    it { is_expected.to be_nil }
  end
end
