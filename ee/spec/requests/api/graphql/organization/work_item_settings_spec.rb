# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization.workItemSettings', :with_current_organization, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:organization_user, :owner, organization: current_organization).user }

  let(:query_param) { { 'id' => current_organization.to_gid } }
  let(:query) do
    graphql_query_for('organization', query_param,
      'workItemSettings { customizableTypeVisibility }')
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  it 'returns the settings with default values when no record exists' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    settings_data = graphql_data_at(:organization, :work_item_settings)
    expect(settings_data).to include('customizableTypeVisibility' => false)
  end

  context 'when a settings record exists' do
    before do
      create(:work_item_settings, namespace: nil, organization: current_organization,
        customizable_type_visibility: true)
    end

    it 'returns the persisted settings' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      settings_data = graphql_data_at(:organization, :work_item_settings)
      expect(settings_data).to include('customizableTypeVisibility' => true)
    end
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it 'returns null for work item settings' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      settings_data = graphql_data_at(:organization, :work_item_settings)
      expect(settings_data).to be_nil
    end
  end

  context 'when organization id is not set' do
    let(:query_param) { {} }

    it 'returns work item settings for the current organization' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      settings_data = graphql_data_at(:organization, :work_item_settings)
      expect(settings_data).to include('customizableTypeVisibility' => false)
    end
  end
end
