# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.duoDefaultNamespaceCandidates', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group1) { create(:group, name: 'Duo Group 1') }
  let_it_be_with_reload(:group2) { create(:group, name: 'Duo Group 2') }
  let_it_be_with_reload(:group3) { create(:group, name: 'No Duo Group') }

  let(:current_user) { user }

  let(:query) do
    <<~QUERY
      query {
        duoDefaultNamespaceCandidates {
          nodes {
            id
            name
            fullPath
          }
        }
      }
    QUERY
  end

  subject(:request) { post_graphql(query, current_user: current_user) }

  context 'when user is not authenticated' do
    let(:current_user) { nil }

    it 'returns empty result' do
      request

      expect(graphql_data['duoDefaultNamespaceCandidates']['nodes']).to be_empty
    end
  end

  context 'when user has no Duo add-on assignments' do
    before do
      allow_next_instance_of(UserPreference) do |preference|
        allow(preference).to receive(:duo_default_namespace_candidates).and_return(Namespace.none)
      end
    end

    it 'returns empty result' do
      request

      expect(graphql_data['duoDefaultNamespaceCandidates']['nodes']).to be_empty
    end
  end

  context 'when user has Duo add-on assignments' do
    before do
      allow_next_instance_of(UserPreference) do |preference|
        allow(preference).to receive(:duo_default_namespace_candidates)
          .and_return(Namespace.where(id: [group1.id, group2.id]))
      end
    end

    it 'returns Duo namespaces candidates' do
      request

      expect(graphql_data['duoDefaultNamespaceCandidates']['nodes']).to contain_exactly(
        hash_including(
          'id' => global_id_of(group1).to_s,
          'name' => group1.name,
          'fullPath' => group1.full_path
        ),
        hash_including(
          'id' => global_id_of(group2).to_s,
          'name' => group2.name,
          'fullPath' => group2.full_path
        )
      )
    end

    context 'when user cannot read some namespaces' do
      before do
        # Make group1 private and don't add user as member
        group1.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
      end

      it 'filters out unauthorized namespaces through GraphQL authorization' do
        request

        expect(graphql_data['duoDefaultNamespaceCandidates']['nodes']).to contain_exactly(
          hash_including(
            'id' => global_id_of(group2).to_s,
            'name' => group2.name,
            'fullPath' => group2.full_path
          )
        )
      end
    end
  end
end
