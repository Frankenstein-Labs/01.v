# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project.aiCatalogItem', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, project: project) }

  let(:args) { { id: global_id_of(item) } }

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(:ai_catalog_item,
        attributes_to_graphql(args).to_s,
        all_graphql_fields_for('AiCatalogItem', max_depth: 1)
      )
    )
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'returns null' do
    let(:item_data) { graphql_data.dig('project', 'aiCatalogItem') }

    specify do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_data).to be_nil
    end
  end

  shared_examples 'returns the item that matches the given ID' do
    let(:item_data) { graphql_data.dig('project', 'aiCatalogItem', 'id') }

    specify do
      post_graphql(query, current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(item_data).to eq(global_id_of(item).to_s)
    end
  end

  context 'when the user can read items on the project' do
    before_all do
      project.add_developer(user)
    end

    it_behaves_like 'returns the item that matches the given ID'

    context 'when item is soft-deleted' do
      before do
        item.update!(deleted_at: Time.current)
      end

      it_behaves_like 'returns null'

      context 'when showSoftDeleted is true' do
        let(:args) { super().merge(show_soft_deleted: true) }

        it_behaves_like 'returns the item that matches the given ID'
      end
    end

    context 'when item ID belongs to another project' do
      let_it_be_with_reload(:item) { create(:ai_catalog_item, project: create(:project)) }

      it_behaves_like 'returns null'
    end
  end

  context 'when the user cannot read items on the project' do
    it_behaves_like 'returns null'
  end

  describe 'descriptionHtml field' do
    before_all do
      project.add_developer(user)
    end

    let(:description_html_query) do
      graphql_query_for(
        :project,
        { full_path: project.full_path },
        query_graphql_field(:ai_catalog_item, attributes_to_graphql(args).to_s, 'descriptionHtml')
      )
    end

    subject(:description_html) do
      post_graphql(description_html_query, current_user: user)
      graphql_data.dig('project', 'aiCatalogItem', 'descriptionHtml')
    end

    context 'with a custom (non-foundational) item' do
      it { is_expected.to be_nil }
    end

    context 'with a foundational item' do
      before do
        allow_next_found_instance_of(::Ai::Catalog::Item) do |i|
          allow(i).to receive(:foundational?).and_return(true)
        end
      end

      it 'returns the rendered Markdown HTML' do
        expect(description_html).to be_a(String).and(include('<p'))
      end
    end
  end
end
