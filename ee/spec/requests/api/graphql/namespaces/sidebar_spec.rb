# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Namespace.sidebar', feature_category: :navigation do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }

  let_it_be(:reporter) { create(:user, reporter_of: group) }

  let(:query) do
    <<~QUERY
    query {
      namespace(fullPath: "#{namespace.full_path}") {
        sidebar {
          openEpicsCount
        }
      }
    }
    QUERY
  end

  before_all do
    create_list(:epic, 2, group: group)
  end

  before do
    stub_licensed_features(epics: true)
  end

  context 'with a Group' do
    let(:namespace) { group }

    it 'returns the epic counts' do
      post_graphql(query, current_user: reporter)

      expect(response).to have_gitlab_http_status(:ok)

      expect(graphql_data_at(:namespace, :sidebar)).to eq({
        'openEpicsCount' => 2
      })
    end
  end

  context 'with a ProjectNamespace' do
    let(:namespace) { project.project_namespace }

    it 'returns nil epic count' do
      post_graphql(query, current_user: reporter)

      expect(response).to have_gitlab_http_status(:ok)

      expect(graphql_data_at(:namespace, :sidebar)).to eq({
        'openEpicsCount' => nil
      })
    end
  end
end
