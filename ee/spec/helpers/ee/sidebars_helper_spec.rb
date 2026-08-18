# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::SidebarsHelper, feature_category: :navigation do
  include Devise::Test::ControllerHelpers

  describe '#super_sidebar_context' do
    let(:group) { build_stubbed(:group) }
    let(:user_namespace) { build_stubbed(:namespace) }
    let(:user) { build_stubbed(:user, namespace: user_namespace) }
    let(:panel) { {} }
    let(:panel_type) { 'project' }
    let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(user) }

    before do
      allow(helper).to receive(:current_user) { user }
      allow(user_namespace).to receive(:actual_plan_name).and_return(::Plan::ULTIMATE)
      allow(helper).to receive_messages(can?: true, show_buy_pipeline_with_subtext?: true,
        current_user_mode: current_user_mode)
      allow(panel).to receive_messages(super_sidebar_menu_items: nil, super_sidebar_context_header: nil)
      allow(user).to receive_messages(assigned_open_issues_count: 1, assigned_open_merge_requests_count: 4,
        review_requested_open_merge_requests_count: 0, todos_pending_count: 3, total_merge_requests_count: 4)
    end

    # Tests for logged-out sidebar context,
    # because EE/CE should have the same attributes for logged-out users
    it_behaves_like 'logged-out super-sidebar context'

    shared_examples 'compute minutes attributes' do
      it 'returns sidebar values from user', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context).to have_key(:pipeline_minutes)
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          show_buy_pipeline_minutes: true,
          show_notification_dot: false,
          show_with_subtext: true,
          tracking_attrs: {
            'track-action': 'click_buy_ci_minutes',
            'track-label': ::Plan::DEFAULT,
            'track-property': 'user_dropdown'
          },
          notification_dot_attrs: {
            'data-track-action': 'render',
            'data-track-label': 'show_buy_ci_minutes_notification',
            'data-track-property': ::Plan::ULTIMATE
          },
          callout_attrs: {
            feature_id: ::Ci::RunnersHelper::BUY_PIPELINE_MINUTES_NOTIFICATION_DOT,
            dismiss_endpoint: '/-/users/callouts'
          }
        })
      end
    end

    shared_examples 'trial status widget data' do
      describe 'trial status when subscriptions_trials feature is available', :saas do
        let(:root_group) { namespace }

        let(:gitlab_subscription) do
          build(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: root_group)
        end

        before do
          stub_saas_features(subscriptions_trials: true)
          allow(root_group).to receive(:gitlab_subscription).and_return(gitlab_subscription)
        end

        describe 'does not return trial status widget data' do
          it { is_expected.not_to include(:trial_widget_data_attrs) }
        end

        context 'when a namespace is qualified for trial status widget' do
          before do
            # need to stub a default for the other can? uses first
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_namespace, root_group).and_return(true)
          end

          it 'returns trial status widget data' do
            expect(super_sidebar_context).to include(:trial_widget_data_attrs)
          end
        end
      end
    end

    shared_examples 'duo pro trial status widget data' do
      describe 'duo pro trial status', :saas do
        let(:root_group) { namespace }
        let(:add_on_purchase) do
          build(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: root_group)
        end

        before do
          stub_saas_features(subscriptions_trials: true)
          allow(GitlabSubscriptions::Trials::DuoPro)
            .to receive(:any_add_on_purchase_for_namespace).with(root_group).and_return(add_on_purchase)
        end

        describe 'does not return trial status widget data' do
          it { is_expected.not_to include(:trial_widget_data_attrs) }
        end

        context 'when a namespace is qualified for duo pro trial status widget' do
          before do
            # need to stub a default for the other can? uses first
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_namespace, root_group).and_return(true)
          end

          context 'when only qualified for duo pro' do
            before do
              build(:gitlab_subscription, :ultimate, namespace: root_group)
            end

            it { is_expected.to include(:trial_widget_data_attrs) }
          end

          context 'when a namespace is also qualified for a trial status widget' do
            before do
              build(:gitlab_subscription, :active_trial, namespace: root_group)
            end

            it { is_expected.to include(:trial_widget_data_attrs) }
          end
        end
      end
    end

    shared_examples 'trial widget data' do
      describe 'trial widget when subscriptions_trials feature is available', :saas do
        let(:root_group) { namespace }
        let(:presenter) { GitlabSubscriptions::Trials::WidgetPresenter.new(root_group, user: user) }

        before do
          stub_saas_features(subscriptions_trials: true)
          allow(root_group).to receive(:actual_plan_name).and_return('_actual_plan_name_')
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_namespace, root_group).and_return(true)
          allow(GitlabSubscriptions::Trials::WidgetPresenter).to receive(:new).and_return(presenter)
        end

        context 'when eligible for Duo Enterprise trial widget' do
          before do
            build(:gitlab_subscription, :ultimate, namespace: root_group)
            build_stubbed(:gitlab_subscription_add_on_purchase, :duo_enterprise, :trial, namespace: root_group)
            allow(presenter).to receive(:attributes).and_return({ trial_widget_data_attrs: {} })
          end

          it 'returns Duo Enterprise trial widget data' do
            expect(super_sidebar_context).to include(:trial_widget_data_attrs)
          end
        end

        context 'when not eligible for any widget' do
          before do
            allow(presenter).to receive(:attributes).and_return({})
          end

          it 'does not return any trial widget data' do
            expect(super_sidebar_context).not_to include(:trial_widget_data_attrs)
          end
        end
      end
    end

    context 'with global concerns' do
      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: nil, project: nil, panel: panel, panel_type: nil)
      end

      it 'returns upgrade link' do
        stub_saas_features(gitlab_com_subscriptions: true)
        allow(::GitlabSubscriptions::Trials).to receive(:no_eligible_namespaces_for_user?).and_return(true)

        expect(super_sidebar_context).to include(:upgrade_link)
      end

      describe 'whats_new_placement experiment publish' do
        it 'publishes the experiment for the current user' do
          expect_next_instance_of(WhatsNewPlacementExperiment) do |experiment|
            expect(experiment).to receive(:publish)
          end

          super_sidebar_context
        end

        context 'when the user is not persisted' do
          let(:user) { build(:user) }

          it 'does not publish the experiment' do
            expect(WhatsNewPlacementExperiment).not_to receive(:new)

            super_sidebar_context
          end
        end
      end
    end

    context 'when in project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let(:project) { build(:project, namespace: build(:namespace, id: non_existing_record_id)) }
      let(:namespace) { project.namespace }
      let(:group) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'compute minutes attributes'
      include_examples 'trial status widget data'
      include_examples 'duo pro trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/-/profile/usage_quotas"
        })
      end
    end

    context 'when in group scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(true)
      end

      let(:group) { build(:group, id: non_existing_record_id) }
      let(:namespace) { group }
      let(:project) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      include_examples 'compute minutes attributes'
      include_examples 'trial status widget data'
      include_examples 'duo pro trial status widget data'

      it 'returns correct usage quotes path', :use_clean_rails_memory_store_caching do
        expect(super_sidebar_context[:pipeline_minutes]).to include({
          buy_pipeline_minutes_path: "/groups/#{group.path}/-/usage_quotas"
        })
      end
    end

    context 'when neither in a group nor in a project scope' do
      before do
        allow(helper).to receive(:show_buy_pipeline_minutes?).and_return(false)
      end

      let(:project) { nil }
      let(:group) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      it 'does not have compute minutes attributes' do
        expect(super_sidebar_context).not_to have_key('pipeline_minutes')
      end

      describe 'analytics dashboards path' do
        it 'is included' do
          expect(super_sidebar_context[:analytics_dashboards_path]).to eq('/explore/analytics_dashboards')
        end

        context 'when the explore_analytics_dashboards feature flag is disabled' do
          before do
            stub_feature_flags(explore_analytics_dashboards: false)
          end

          it 'is omitted' do
            expect(super_sidebar_context).not_to have_key(:analytics_dashboards_path)
          end
        end
      end

      it 'returns paths for user', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/461171' do
        expect(super_sidebar_context).to match(hash_including({
          sign_out_link: '/users/sign_out',
          issues_dashboard_path: "/dashboard/issues?assignee_username=#{user.username}",
          merge_request_dashboard_path: '/dashboard/merge_requests',
          todos_dashboard_path: '/dashboard/todos',
          projects_path: '/dashboard/projects',
          groups_path: '/dashboard/groups'
        }))
      end

      context 'when subscriptions_trials feature is not available and user is admin' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :admin_all_resources).and_return(true)
        end

        context 'when eligible for Ultimate trial widget' do
          before do
            allow(License).to receive(:current).and_return(build(:license, :ultimate_trial))
          end

          it 'returns trial widget data' do
            expect(super_sidebar_context).to include(:trial_widget_data_attrs)
          end
        end

        context 'when not eligible for any widget' do
          it 'does not return any trial widget data' do
            expect(super_sidebar_context).not_to include(:trial_widget_data_attrs)
          end
        end
      end
    end

    describe 'ai_search_available' do
      let(:project) { nil }

      subject(:super_sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: project, panel: panel, panel_type: panel_type)
      end

      context 'when eligible: FF enabled, resource present, namespace on an active trial' do
        before do
          stub_feature_flags(feature_discovery_gemini_search: user)
        end

        context 'with a group' do
          before do
            allow(group).to receive(:trial_active?).and_return(true)
          end

          it { expect(super_sidebar_context).to include(ai_search_available: true) }
        end

        context 'with a project instead of a group' do
          let(:group) { nil }
          let(:project) { build_stubbed(:project) }

          before do
            allow(project.root_ancestor).to receive(:trial_active?).and_return(true)
          end

          it { expect(super_sidebar_context).to include(ai_search_available: true) }
        end
      end

      context 'when the feature_discovery_gemini_search flag is disabled' do
        before do
          stub_feature_flags(feature_discovery_gemini_search: false)
          allow(group).to receive(:trial_active?).and_return(true)
        end

        it { expect(super_sidebar_context).to include(ai_search_available: false) }
      end

      context 'when the namespace is not on an active trial' do
        before do
          stub_feature_flags(feature_discovery_gemini_search: user)
          allow(group).to receive(:trial_active?).and_return(false)
        end

        it { expect(super_sidebar_context).to include(ai_search_available: false) }
      end

      context 'when neither in a group nor in a project scope' do
        let(:group) { nil }
        let(:project) { nil }

        before do
          stub_feature_flags(feature_discovery_gemini_search: user)
        end

        it { expect(super_sidebar_context).to include(ai_search_available: false) }
      end

      context 'with a group and no project', :aggregate_failures do
        it 'delegates to FeatureMatchService with panel "group"' do
          expect(Onboarding::FeatureLibrary::FeatureMatchService)
            .to receive(:new)
            .with(query: '', panel: 'group', user: user, resource: group)
            .and_call_original

          super_sidebar_context
        end
      end

      context 'with a project', :aggregate_failures do
        let(:group) { nil }
        let(:project) { build_stubbed(:project) }

        it 'delegates to FeatureMatchService with panel "project"' do
          expect(Onboarding::FeatureLibrary::FeatureMatchService)
            .to receive(:new)
            .with(query: '', panel: 'project', user: user, resource: project)
            .and_call_original

          super_sidebar_context
        end
      end
    end

    context 'when user pinned multiple work items types' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:panel_type) { 'group' }

      where(:pinned_items, :result) do
        nil | %w[group_overview members group_issue_list issue_boards group_merge_request_list epic_boards]
        %w[group_issue_list] | %w[group_issue_list]
        %w[group_epic_list] | %w[group_epic_list]
        %w[group_issue_list group_epic_list] | %w[group_issue_list]
      end

      with_them do
        it 'ensure to avoid duplicated work items on pinned menu' do
          user = build_stubbed(
            :user,
            namespace: user_namespace,
            pinned_nav_items: { panel_type => pinned_items }
          )

          sidebar = helper.super_sidebar_logged_in_context(
            user,
            group: group,
            project: nil,
            panel: panel,
            panel_type: panel_type
          )

          expect(sidebar[:pinned_items]).to eq(result)
        end
      end
    end

    describe 'wiki menu item internal events tracking in group context',
      :use_clean_rails_memory_store_caching do
      subject(:sidebar_context) do
        helper.super_sidebar_context(user, group: group, project: nil, panel: panel, panel_type: panel_type)
      end

      before do
        stub_licensed_features(group_wikis: true)
      end

      it 'includes data-event-tracking attributes with group label' do
        wiki_item = sidebar_context[:create_new_menu_groups].flat_map { |g| g[:items] }.find do |item|
          item[:extraAttrs][:'data-qa-create-menu-item'] == 'new_wiki_page'
        end

        expect(wiki_item).to be_present
        expect(wiki_item[:extraAttrs]).to include(
          'data-event-tracking': 'click_new_wiki_page_in_create_menu',
          'data-event-label': 'group'
        )
      end

      it 'does not include data-event-tracking on non-wiki menu items' do
        non_wiki_items = sidebar_context[:create_new_menu_groups].flat_map { |g| g[:items] }.reject do |item|
          item[:extraAttrs][:'data-qa-create-menu-item'] == 'new_wiki_page'
        end

        expect(non_wiki_items).not_to be_empty
        non_wiki_items.each do |item|
          expect(item[:extraAttrs]).not_to have_key(:'data-event-tracking')
          expect(item[:extraAttrs]).not_to have_key(:'data-event-label')
        end
      end
    end
  end

  describe '#compare_plans_url' do
    before do
      allow(helper).to receive(:group_billings_path) { |group| "/groups/#{group.full_path}/-/billings" }
    end

    context 'when user is nil' do
      it 'returns promo pricing URL' do
        result = helper.compare_plans_url(user: nil)

        expect(result).to eq(promo_pricing_url)
      end

      it 'returns promo pricing URL even when project and group are present' do
        group = build_stubbed(:group)
        project = build(:project, namespace: group)

        result = helper.compare_plans_url(user: nil, project: project, group: group)

        expect(result).to eq(promo_pricing_url)
      end
    end

    context 'when user is present' do
      let(:user) { build_stubbed(:user) }

      context 'when group is present and persisted' do
        let(:group) { build_stubbed(:group) }

        context 'when user can read billing for the group' do
          before do
            allow(helper).to receive(:can?).with(user, :read_billing, group).and_return(true)
          end

          it 'returns group billings path' do
            result = helper.compare_plans_url(user: user, group: group)

            expect(result).to eq("/groups/#{group.full_path}/-/billings")
          end

          it 'prioritizes group over project when both are present' do
            project = build_stubbed(:project)

            result = helper.compare_plans_url(user: user, project: project, group: group)

            expect(result).to eq("/groups/#{group.full_path}/-/billings")
          end
        end

        context 'when user cannot read billing for the group' do
          before do
            allow(helper).to receive(:can?).with(user, :read_billing, group).and_return(false)
          end

          it 'returns promo pricing URL' do
            result = helper.compare_plans_url(user: user, group: group)

            expect(result).to eq(promo_pricing_url)
          end
        end
      end

      context 'when group is not persisted' do
        let(:group) { build(:group) }

        it 'returns promo pricing URL' do
          result = helper.compare_plans_url(user: user, group: group)

          expect(result).to eq(promo_pricing_url)
        end
      end

      context 'when project is present and persisted with a Group namespace' do
        let(:group) { build_stubbed(:group) }
        let(:project) { build_stubbed(:project, namespace: group) }

        context 'when user can read billing for the project namespace' do
          before do
            allow(helper).to receive(:can?).with(user, :read_billing, group).and_return(true)
          end

          it 'returns project namespace billings path' do
            result = helper.compare_plans_url(user: user, project: project)

            expect(result).to eq("/groups/#{group.full_path}/-/billings")
          end
        end

        context 'when user cannot read billing for the project namespace' do
          before do
            allow(helper).to receive(:can?).with(user, :read_billing, group).and_return(false)
          end

          it 'returns promo pricing URL' do
            result = helper.compare_plans_url(user: user, project: project)

            expect(result).to eq(promo_pricing_url)
          end
        end
      end

      context 'when project is present and persisted with a User namespace' do
        let(:project_owner_namespace) { build_stubbed(:user_namespace) }
        let(:project) { build_stubbed(:project, namespace: project_owner_namespace) }

        it 'returns promo pricing URL since user namespaces are not Groups' do
          result = helper.compare_plans_url(user: user, project: project)

          expect(result).to eq(promo_pricing_url)
        end
      end

      context 'when project is not persisted' do
        let(:project) { build(:project) }

        it 'returns promo pricing URL' do
          result = helper.compare_plans_url(user: user, project: project)

          expect(result).to eq(promo_pricing_url)
        end
      end

      context 'when no group or project is provided' do
        it 'returns promo pricing URL' do
          result = helper.compare_plans_url(user: user)

          expect(result).to eq(promo_pricing_url)
        end
      end

      context 'when dealing with edge cases' do
        it 'handles nil values gracefully' do
          result = helper.compare_plans_url(user: user, project: nil, group: nil)

          expect(result).to eq(promo_pricing_url)
        end

        it 'handles authorization check with nil target_group' do
          result = helper.compare_plans_url(user: user)

          expect(result).to eq(promo_pricing_url)
        end
      end

      context 'when order priority is important' do
        let(:group) { build_stubbed(:group) }
        let(:project_group) { build_stubbed(:group) }
        let(:project) { build_stubbed(:project, namespace: project_group) }

        before do
          allow(helper).to receive(:can?).with(user, :read_billing, group).and_return(true)
          allow(helper).to receive(:can?).with(user, :read_billing, project_group).and_return(true)
        end

        it 'prioritizes group over project namespace' do
          result = helper.compare_plans_url(user: user, project: project, group: group)

          expect(result).to eq("/groups/#{group.full_path}/-/billings")
        end

        it 'uses project namespace when no group is provided' do
          result = helper.compare_plans_url(user: user, project: project)

          expect(result).to eq("/groups/#{project_group.full_path}/-/billings")
        end
      end
    end
  end

  describe '#project_sidebar_context_data' do
    let(:project) { build(:project) }
    let(:user) { build(:user) }

    before do
      allow(helper).to receive(:project_jira_issues_integration?).and_return(false)
      allow(helper).to receive(:can_view_pipeline_editor?).with(project).and_return(true)
      allow(helper).to receive(:show_gke_cluster_integration_callout?).with(project).and_return(false)
    end

    it 'returns the correct context data hash' do
      current_ref = 'main'

      expected_hash = {
        current_user: user,
        container: project,
        current_ref: current_ref,
        ref_type: nil,
        jira_issues_integration: false,
        can_view_pipeline_editor: true,
        show_cluster_hint: false,
        learn_gitlab_enabled: false,
        show_get_started_menu: false,
        show_discover_project_security: false,
        show_promotions: false
      }

      expect(helper.project_sidebar_context_data(project, user, current_ref)).to eq(expected_hash)
    end

    context 'when learn_gitlab is available' do
      it 'sets learn_gitlab_enabled to true' do
        allow(::Onboarding::LearnGitlab).to receive(:available?).with(project.namespace, user).and_return(true)

        expect(helper.project_sidebar_context_data(project, user, nil)[:learn_gitlab_enabled]).to be true
      end
    end

    context 'when show_get_started_menu is available' do
      it 'sets show_get_started_menu to true' do
        allow(helper).to receive(:current_path?).with('projects/get_started#show').and_return(true)

        expect(helper.project_sidebar_context_data(project, user, nil)[:show_get_started_menu]).to be true
      end
    end
  end

  describe '#super_sidebar_logged_out_context (EE-specific)' do
    let(:panel) { {} }
    let(:panel_type) { 'project' }
    let(:current_user_mode) { Gitlab::Auth::CurrentUserMode.new(nil) }

    subject(:logged_out_context) do
      helper.super_sidebar_logged_out_context(panel: panel, panel_type: panel_type)
    end

    before do
      allow(panel).to receive_messages(super_sidebar_menu_items: nil, super_sidebar_context_header: nil)
      allow(helper).to receive_messages(current_user: nil, current_user_mode: current_user_mode)
    end

    context 'when gitlab_com_subscriptions feature is available', :saas do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'includes trial_registration_path' do
        expect(logged_out_context).to include(trial_registration_path: new_trial_registration_path)
      end
    end

    context 'when gitlab_com_subscriptions feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not include trial_registration_path' do
        expect(logged_out_context).not_to have_key(:trial_registration_path)
      end
    end
  end

  describe '#super_sidebar_logged_in_context' do
    let_it_be(:group) { build_stubbed(:group) }
    let_it_be(:user) { build_stubbed(:user) }

    let(:panel_type) { 'group' }
    let(:panel) { {} }

    subject(:logged_in_context) do
      helper.super_sidebar_logged_in_context(
        user,
        group: group,
        project: nil,
        panel: panel,
        panel_type: panel_type
      )
    end

    before do
      allow(panel).to receive_messages(super_sidebar_menu_items: nil, super_sidebar_context_header: nil)

      allow(helper).to receive_messages(
        show_buy_pipeline_with_subtext?: false,
        create_new_menu_groups: [],
        current_user_mode: Gitlab::Auth::CurrentUserMode.new(user)
      )
    end

    it 'includes free group upgrade link presenter attributes' do
      allow_next_instance_of(GitlabSubscriptions::FreeGroupUpgradeLinkPresenter) do |instance|
        allow(instance).to receive(:attributes).and_return({ upgrade_link: 'test' })
      end

      expect(logged_in_context).to include(upgrade_link: 'test')
    end
  end

  describe '#super_sidebar_default_pins' do
    it 'appends group_epic_list and epic_boards for group panel' do
      expect(helper.send(:super_sidebar_default_pins, 'group')).to eq(
        %w[group_overview members group_issue_list issue_boards group_merge_request_list group_epic_list epic_boards]
      )
    end

    it 'returns CE defaults for project panel' do
      expect(helper.send(:super_sidebar_default_pins, 'project')).to eq(
        %w[project_overview members project_issue_list branches project_merge_request_list pipelines]
      )
    end
  end

  describe '#show_feature_library_feedback?' do
    it 'is true when there is no current license' do
      allow(License).to receive(:current).and_return(nil)

      expect(helper.send(:show_feature_library_feedback?)).to be(true)
    end

    it 'is true when the current license is not an offline cloud license' do
      allow(License).to receive(:current).and_return(
        instance_double(License, offline_cloud_license?: false)
      )

      expect(helper.send(:show_feature_library_feedback?)).to be(true)
    end

    it 'is false when the current license is an offline cloud license' do
      allow(License).to receive(:current).and_return(
        instance_double(License, offline_cloud_license?: true)
      )

      expect(helper.send(:show_feature_library_feedback?)).to be(false)
    end
  end
end
