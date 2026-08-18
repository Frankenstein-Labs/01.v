# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying work item settings on a group', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let(:current_user) { maintainer }

  let(:query) do
    graphql_query_for(
      'group',
      { 'fullPath' => group.full_path },
      query_graphql_field('workItemSettings', {}, 'customizableTypeVisibility')
    )
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  context 'when on SaaS' do
    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when user is a maintainer' do
      it 'returns the settings with default values when no record exists' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_be_empty

        settings_data = graphql_data_at(:group, :work_item_settings)
        expect(settings_data).to include('customizableTypeVisibility' => false)
      end

      context 'when a settings record exists' do
        before do
          create(:work_item_settings, namespace: group, customizable_type_visibility: true)
        end

        it 'returns the persisted settings' do
          post_graphql(query, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect_graphql_errors_to_be_empty

          settings_data = graphql_data_at(:group, :work_item_settings)
          expect(settings_data).to include('customizableTypeVisibility' => true)
        end
      end
    end
  end

  context 'when on self-managed' do
    let_it_be(:org_owner) { create(:user, maintainer_of: group, owner_of: group.organization) }
    let(:current_user) { org_owner }

    it 'returns the settings with default values when no record exists' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      settings_data = graphql_data_at(:group, :work_item_settings)
      expect(settings_data).to include('customizableTypeVisibility' => false)
    end
  end

  context 'when user is a developer' do
    let(:current_user) { developer }

    it 'returns null for work item settings' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect_graphql_errors_to_be_empty

      settings_data = graphql_data_at(:group, :work_item_settings)
      expect(settings_data).to be_nil
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

      settings_data = graphql_data_at(:group, :work_item_settings)
      expect(settings_data).to be_nil
    end
  end
end
