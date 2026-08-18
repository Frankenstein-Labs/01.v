# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.resource(id).dashboards', feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }

  let(:query) do
    fields = all_graphql_fields_for('CustomizableDashboard')

    graphql_query_for(
      resource_parent_type,
      { full_path: resource_parent.full_path },
      query_nodes(:customizable_dashboards, fields)
    )
  end

  shared_examples 'list dashboards as guest' do
    before do
      resource_parent.add_guest(user)
    end

    it 'returns no dashboards' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes)).to be_nil
    end
  end

  shared_examples 'list dashboards without analytics dashboards license' do
    before do
      stub_licensed_features(
        product_analytics: true,
        project_level_analytics_dashboard: false,
        group_level_analytics_dashboard: false,
        project_merge_request_analytics: false
      )
    end

    it 'does not return the Value stream dashboard' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('slug'))
        .not_to match_array(%w[value_stream_dashboard merge_request_analytics])
    end
  end

  context 'when resource parent is a project' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:config_project) { create(:project, :with_product_analytics_dashboard, group: group) }
    let_it_be_with_reload(:resource_parent) { config_project }

    let(:resource_parent_type) { :project }

    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
      stub_licensed_features(product_analytics: true, project_level_analytics_dashboard: true,
        project_merge_request_analytics: true)
      resource_parent.project_setting.update!(product_analytics_instrumentation_key: "key")
      allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
          'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
        }))
      end

      resource_parent.reload
    end

    it_behaves_like 'list dashboards as guest'

    context 'when current user is a developer' do
      before do
        resource_parent.add_developer(user)
      end

      it 'returns all dashboards',
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24064' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
          .to match_array(["Behavior", "Audience", "Value Streams Dashboard", "Merge request analytics",
            "Dashboard Example 1"])
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          resource_parent.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'returns value stream and custom dashboards' do
          post_graphql(query, current_user: user)

          expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
            .to match_array(["Value Streams Dashboard", "Merge request analytics", "Dashboard Example 1"])
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(product_analytics_features: false)
        end

        it 'returns value stream and custom dashboards' do
          post_graphql(query, current_user: user)

          expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
            .to match_array(["Value Streams Dashboard", "Merge request analytics", "Dashboard Example 1"])
        end
      end

      it_behaves_like 'list dashboards without analytics dashboards license'
    end
  end

  context 'when resource parent is a group' do
    let_it_be_with_reload(:resource_parent) { create(:group) }
    let_it_be_with_reload(:config_project) do
      create(:project, :with_product_analytics_dashboard, group: resource_parent)
    end

    let(:resource_parent_type) { :group }

    before do
      resource_parent.update!(analytics_dashboards_configuration_project: config_project)
      stub_licensed_features(product_analytics: true, group_level_analytics_dashboard: true)
    end

    it_behaves_like 'list dashboards as guest'

    context 'when current user is a developer' do
      before do
        resource_parent.add_developer(user)
      end

      it 'returns builtin and custom dashboards' do
        post_graphql(query, current_user: user)

        expect(graphql_data_at(resource_parent_type, :customizable_dashboards, :nodes).pluck('title'))
          .to match_array(["Value Streams Dashboard", "Dashboard Example 1", "Contributions Dashboard"])
      end

      it_behaves_like 'list dashboards without analytics dashboards license'
    end
  end
end
