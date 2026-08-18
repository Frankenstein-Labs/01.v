# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting runners of the current user', feature_category: :fleet_visibility do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:query) do
    graphql_query_for(:current_user, {}, user_fields)
  end

  let(:args) { nil }
  let(:user_fields) { query_nodes(:runners, %w[id description], args: args) }
  let(:path) { %i[current_user runners nodes] }

  subject(:user_runners) do
    post_graphql(query, current_user: current_user)
    graphql_data_at(*path)
  end

  include_context 'runners resolver setup'

  context 'when user is banned', :saas do
    before do
      stub_licensed_features(unique_project_download_limit: true)

      create(:group_member, :banned, :maintainer, source: group, user: current_user)
    end

    it 'does not return runners of projects where the user is banned' do
      is_expected.to be_empty
    end
  end
end
