# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting work item notes from a work item', feature_category: :team_planning do
  include_context 'with work items list request'

  let_it_be_with_reload(:item1) do
    create(:work_item, project: project)
  end

  describe 'request with different scopes' do
    let(:fields) do
      <<~GRAPHQL
            nodes {
                widgets {
                    ... on WorkItemWidgetNotes {
                        notes {
                            nodes {
                                id
                                resolvable
                                resolved
                                resolvedBy {
                                    id
                                }
                                discussion {
                                  id
                                }
                                author {
                                    name
                                }
                            }
                        }
                    }
                }
            }
      GRAPHQL
    end

    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field('workItems', {}, fields)
      )
    end

    let(:token) { create(:oauth_access_token, user: current_user, scopes: scopes) }
    let(:scopes) { [:api] }

    let_it_be(:note1) do
      create(:discussion_note_on_work_item, :resolved, noteable: item1, project: item1.project)
    end

    let_it_be(:note2) do
      create(:note, noteable: item1, project: item1.project)
    end

    let_it_be(:note3) do
      create(:discussion_note_on_work_item, noteable: item1, project: item1.project,
        in_reply_to: note1)
    end

    let(:widgets) { graphql_data.dig('project', 'workItems', 'nodes').first['widgets'] }
    let(:notes) { widgets.find { |widget| widget.keys == ['notes'] }['notes']['nodes'] }

    let(:note1_response) { notes.find { |note| note['id'] == note1.to_global_id.to_s } }
    let(:note2_response) { notes.find { |note| note['id'] == note2.to_global_id.to_s } }
    let(:note3_response) { notes.find { |note| note['id'] == note3.to_global_id.to_s } }

    it 'returns all data' do
      post_graphql(query, token: { oauth_access_token: token })
      expect(note1_response.deep_symbolize_keys).to match(
        a_hash_including(
          resolved: true,
          resolvable: true,
          resolvedBy: a_hash_including(id: note1.resolved_by.to_global_id.to_s),
          discussion: a_hash_including(id: note1.discussion.to_global_id.to_s),
          author: a_hash_including(name: note1.author.name)
        )
      )
      expect(note2_response.deep_symbolize_keys).to match(
        a_hash_including(
          resolved: false,
          resolvable: false,
          resolvedBy: nil,
          discussion: a_hash_including(id: note2.discussion.to_global_id.to_s)
        )
      )
      expect(note3_response.deep_symbolize_keys).to match(
        a_hash_including(
          discussion: a_hash_including(id: note1.discussion.to_global_id.to_s) # same as 1
        )
      )
    end

    context 'when using ai_workflows scope' do
      let(:scopes) { [:ai_workflows] }

      it 'returns all data accessible by ai_workflows scope' do
        post_graphql(query, token: { oauth_access_token: token })
        expect(note1_response.deep_symbolize_keys).to match(
          a_hash_including(
            resolved: true,
            resolvable: true,
            resolvedBy: nil, # not accessible by ai_workflows scope
            discussion: a_hash_including(id: note1.discussion.to_global_id.to_s),
            author: a_hash_including(name: note1.author.name)
          )
        )
      end
    end
  end
end
