# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query single custom system dashboard', feature_category: :custom_dashboards_foundation do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:slug) { 'duo_and_sdlc_trends' }
  let(:config) { { 'title' => 'Duo and SDLC trends', 'version' => '2', 'panels' => [] } }
  let(:dashboard) do
    Analytics::CustomDashboards::SystemDashboard.new(slug: slug, config: config)
  end

  let(:fields) do
    <<~GRAPHQL
      id
      name
      description
      slug
      system
      config
    GRAPHQL
  end

  let(:query) do
    graphql_query_for(:custom_system_dashboard, { slug: slug }, fields)
  end

  subject(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  before do
    allow(Analytics::CustomDashboards::SystemDashboardsLoader)
      .to receive(:find_by_slug).with(slug).and_return(dashboard)
  end

  context 'when the user is authenticated' do
    it 'returns the dashboard for the given slug' do
      execute_query

      expect(graphql_data_at(:custom_system_dashboard)).to include(
        'name' => 'Duo and SDLC trends',
        'slug' => slug,
        'system' => true,
        'config' => config
      )
    end
  end

  context 'when the user is anonymous' do
    let(:current_user) { nil }

    it 'returns nil' do
      execute_query

      expect(graphql_data_at(:custom_system_dashboard)).to be_nil
    end
  end

  context 'when no dashboard matches the slug' do
    let(:dashboard) { nil }

    it 'returns nil' do
      execute_query

      expect(graphql_data_at(:custom_system_dashboard)).to be_nil
    end
  end
end
