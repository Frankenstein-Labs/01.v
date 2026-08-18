# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a wiki page', feature_category: :wiki do
  include GraphqlHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, :private, developers: user) }

  let(:slug) { wiki_page_meta.slugs.first.slug }
  let(:global_id) { wiki_page_meta.to_gid.to_s }
  let(:current_user) { user }

  let(:query) do
    graphql_query_for(:wiki_page, { 'slug' => slug, 'namespace_id' => global_id_of(group) }, wiki_page_fields)
  end

  let(:wiki_page_fields) { all_graphql_fields_for('WikiPage', max_depth: 2) }
  let(:wiki_page_data) { graphql_data_at('wikiPage') }

  before do
    stub_licensed_features(group_wikis: true)
    post_graphql(query, current_user: current_user)
  end

  context 'for group wikis' do
    let_it_be_with_reload(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }

    it_behaves_like 'a working graphql query that returns data'

    it 'returns all fields' do
      expect(wiki_page_data).to include(
        'id' => global_id,
        'title' => wiki_page_meta.title,
        'subscribed' => false,
        'userPermissions' => {
          'readWikiPage' => true,
          'createNote' => true,
          'markNoteAsInternal' => true,
          'awardEmoji' => true
        }
      )
    end

    context 'when page does not exist' do
      let(:slug) { 'foobar' }

      it_behaves_like 'a working graphql query that returns no data'
    end

    context 'when user is not a member' do
      let_it_be(:other_user) { create(:user) }

      let(:current_user) { other_user }

      it_behaves_like 'a working graphql query that returns no data'
    end

    describe 'subscribed' do
      let_it_be_with_reload(:note) do
        create(:note, noteable: wiki_page_meta, author: user, namespace: group, project: nil)
      end

      it 'returns subscription without being subscribed when is a note author' do
        expect(wiki_page_data).to include(
          'subscribed' => true
        )
      end
    end

    describe 'notes' do
      let_it_be_with_reload(:note) do
        create(:note, noteable: wiki_page_meta, author: user, namespace: group, project: nil)
      end

      let(:notes_response) do
        graphql_data_at(:wiki_page, :notes, :nodes)
      end

      let(:wiki_page_fields) do
        <<~GRAPHQL
          notes {
            nodes {
              #{all_graphql_fields_for('Note', max_depth: 2)}
            }
          }
        GRAPHQL
      end

      it 'returns notes' do
        expect(notes_response).to contain_exactly(
          a_graphql_entity_for(note)
        )
      end
    end

    describe 'discussions' do
      let_it_be_with_reload(:discussion) do
        create(:discussion_note_on_wiki_page, noteable: wiki_page_meta, author: user, namespace: group).to_discussion
      end

      let(:discussions_response) do
        graphql_data_at(:wiki_page, :discussions, :nodes)
      end

      let(:wiki_page_fields) do
        <<~GRAPHQL
          discussions {
            nodes {
              #{all_graphql_fields_for('Discussion', max_depth: 2)}
            }
          }
        GRAPHQL
      end

      it 'returns discussions' do
        expect(discussions_response).to contain_exactly(
          a_graphql_entity_for(discussion)
        )
      end

      describe 'performance' do
        let_it_be_with_reload(:group) { create(:group) }
        let_it_be_with_reload(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }
        let_it_be(:other_user) { create(:user) }

        it 'avoids N+1 queries' do
          discussion = create(
            :discussion_note_on_wiki_page,
            noteable: wiki_page_meta,
            author: user
          ).to_discussion

          create(
            :discussion_note_on_wiki_page,
            noteable: wiki_page_meta,
            author: other_user,
            discussion: discussion
          )

          control = ActiveRecord::QueryRecorder.new do
            post_graphql(query, current_user: current_user)
          end

          5.times do
            discussion = create(
              :discussion_note_on_wiki_page,
              noteable: wiki_page_meta,
              author: user
            ).to_discussion

            create(
              :discussion_note_on_wiki_page,
              noteable: wiki_page_meta,
              author: other_user,
              discussion: discussion
            )
          end

          expect { post_graphql(query, current_user: current_user) }
            .not_to exceed_query_limit(control)
        end
      end
    end
  end
end
