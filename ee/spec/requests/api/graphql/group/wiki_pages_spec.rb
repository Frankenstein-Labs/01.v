# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting group wiki pages', feature_category: :wiki do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }

  let(:licensed) { true }
  let(:group_path) { group.full_path }

  let(:query) do
    <<~QUERY
      query($path: ID!) {
        group(fullPath: $path) {
          wikiPages {
            nodes { id title slug }
          }
        }
      }
    QUERY
  end

  let(:wiki_pages) { graphql_data_at(:group, :wiki_pages, :nodes) }

  before do
    stub_licensed_features(group_wikis: licensed)
    post_graphql(query, current_user: current_user, variables: { path: group_path })
  end

  context 'when group wikis are licensed' do
    it 'returns the group wiki pages' do
      expect(wiki_pages).to contain_exactly(
        a_hash_including('title' => wiki_page_meta.title, 'slug' => wiki_page_meta.canonical_slug)
      )
    end

    context 'when the wiki has no pages' do
      let_it_be(:empty_group) { create(:group, developers: current_user) }
      let(:group_path) { empty_group.full_path }

      it 'returns an empty collection' do
        expect(wiki_pages).to eq([])
      end
    end

    context 'with pagination' do
      let_it_be(:paginated_group, freeze: false) { create(:group, developers: current_user) }
      let_it_be(:paginated_wiki, freeze: false) { create(:wiki, container: paginated_group, user: current_user) }
      let_it_be(:paginated_pages, freeze: false) do
        %w[apple banana cherry].map { |title| create(:wiki_page, wiki: paginated_wiki, title: title) }
      end

      let(:group_path) { paginated_group.full_path }

      def paginated_query(args)
        <<~QUERY
          query($path: ID!) {
            group(fullPath: $path) {
              wikiPages(#{args}) {
                nodes { title }
                pageInfo { hasNextPage endCursor }
              }
            }
          }
        QUERY
      end

      def post_page(args)
        post_graphql(paginated_query(args), current_user: current_user, variables: { path: group_path })
      end

      it 'paginates the group wiki pages through the connection' do
        post_page('first: 2')

        expect(graphql_data_at(:group, :wiki_pages, :nodes).size).to eq(2)
        page_info = graphql_data_at(:group, :wiki_pages, :page_info)
        expect(page_info['hasNextPage']).to be(true)

        first_titles = graphql_data_at(:group, :wiki_pages, :nodes).pluck('title')

        post_page(%(first: 2, after: "#{page_info['endCursor']}"))

        expect(graphql_data_at(:group, :wiki_pages, :nodes).size).to eq(1)
        expect(graphql_data_at(:group, :wiki_pages, :page_info)['hasNextPage']).to be(false)

        second_titles = graphql_data_at(:group, :wiki_pages, :nodes).pluck('title')

        expect(first_titles + second_titles).to contain_exactly('apple', 'banana', 'cherry')
      end
    end
  end

  context 'when group wikis are not licensed' do
    let(:licensed) { false }

    it 'does not return the group wiki pages' do
      expect(graphql_data_at(:group, :wiki_pages)).to be_nil
    end
  end
end
