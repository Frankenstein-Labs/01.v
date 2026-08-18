# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/dashboard/index.html.haml', :enable_admin_mode, feature_category: :system_access do
  include Devise::Test::ControllerHelpers
  include LicenseHelper

  let(:reflections) do
    Gitlab::Database.database_base_models.transform_values do |base_model|
      ::Gitlab::Database::Reflection.new(base_model)
    end
  end

  let_it_be(:user) { create(:admin) }

  before do
    counts = Admin::DashboardController::COUNTED_ITEMS.index_with { 100 }

    assign(:counts, counts)
    assign(:projects, create_list(:project, 1))
    assign(:users, create_list(:user, 1))
    assign(:groups, create_list(:group, 1))
    assign(:database_reflections, reflections)

    allow(view).to receive(:admin?).and_return(true)
    allow(view).to receive(:current_application_settings).and_return(Gitlab::CurrentSettings.current_application_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  context 'when license is present' do
    before do
      assign(:license, create(:license))
    end

    it 'includes notices above license breakdown' do
      assign(:notices, [{ type: :alert, message: 'An alert' }])

      render

      expect(rendered).to have_content(/An alert.*Users in subscription/)
    end

    it 'includes license overview' do
      render

      expect(rendered).to have_content _('License overview')
      expect(rendered).to have_content _('Plan:')
      expect(rendered).to have_content s_('Subscriptions|End date:')
      expect(rendered).to have_content _('Licensed to:')
      expect(rendered).to have_content _('Type:')
      expect(rendered).to have_link _('View details'), href: admin_subscription_path
    end

    it 'includes license breakdown' do
      render

      expect(rendered).to have_content _('Users in subscription')
      expect(rendered).to have_content _('Billable users')
      expect(rendered).to have_content _('Maximum Users')
      expect(rendered).to have_content _('Users over License')
    end

    it 'does not show subscription summary', :with_license do
      render

      expect(rendered).not_to have_content "Active subscription"
      expect(rendered).not_to have_content "GitLab Free"
    end
  end

  context 'when license is not present' do
    it 'does not show content' do
      render

      expect(rendered).not_to have_content "Users in subscription"
    end

    it 'shows subscription summary with tracking on ctas', :without_license do
      render

      expect(rendered).to have_content "GitLab Free"
      expect(rendered).to have_content "Active subscription"

      expect(rendered).to have_css(
        "a[data-event-tracking='click_start_trial_cta_sm_admin_dashboard'][href='#{new_self_managed_trials_path}']",
        text: 'Start free trial'
      )
      expect(rendered).to have_css(
        "a[data-event-tracking='click_explore_plans_cta_sm_admin_dashboard'][href='#{promo_pricing_url(query: { deployment: 'self-managed' })}']",
        text: 'Explore plans'
      )
    end

    it 'does not show subscription summary if on saas', :without_license, :saas_gitlab_com_subscriptions do
      render

      expect(rendered).not_to have_content "Active subscription"
      expect(rendered).not_to have_content "GitLab Free"
    end

    context 'when without license', :without_license do
      it 'shows Start free trial and Explore plans buttons' do
        render

        expect(rendered).to have_link('Start free trial', href: new_self_managed_trials_path)
      end

      it 'shows trial activation messaging' do
        render
        expect(rendered).to have_content('GitLab Free')
        expect(rendered).to have_content('Active subscription')
        expect(rendered).to have_content('Try a 30 day free trial of Ultimate')
      end
    end

    context 'when license is present' do
      before do
        assign(:license, create(:license))
      end

      it 'does not show trial activation UI', :with_license do
        render
        expect(rendered).not_to have_content('Try a 30 day free trial of Ultimate')
        expect(rendered).not_to have_link('Start free trial')
        expect(rendered).not_to have_link('Explore plans')
      end
    end

    context 'on GitLab.com', :without_license, :saas_gitlab_com_subscriptions do
      before do
        assign(:license, nil)
      end

      it 'does not show trial activation UI' do
        render
        expect(rendered).not_to have_content('Try a 30 day free trial of Ultimate')
        expect(rendered).not_to have_link('Start free trial')
        expect(rendered).not_to have_link('Explore plans')
      end
    end
  end

  describe 'license expirations' do
    today = DateTime.parse("2025-08-09 12:00:00 UTC")

    shared_examples_for 'expiration message' do |start_date:, expire_date:, is_trial:, message:|
      before do
        assign(
          :license,
          create(
            :license,
            restrictions: { trial: is_trial },
            data: create(
              :gitlab_license,
              licensee: { 'Company' => 'GitLab', 'Email' => 'test@gitlab.com' },
              starts_at: start_date,
              expires_at: expire_date
            ).export
          )
        )
      end

      it "shows '#{message}'" do
        travel_to(today) do
          render
          expect(rendered).to have_content message.to_s
        end
      end
    end

    context 'when paid license is loaded' do
      context 'when is active' do
        it_behaves_like 'expiration message',
          start_date: today - 30.days,
          expire_date: today + 30.days,
          is_trial: false,
          message: "#{s_('Subscriptions|End date:')} #{(today + 30.days).strftime('%b %-d, %Y')}"
      end

      context 'when is expired' do
        it_behaves_like 'expiration message',
          start_date: today - 60.days,
          expire_date: today - 30.days,
          is_trial: false,
          message: "#{_('Expired:')} #{(today - 30.days).strftime('%b %-d, %Y')}"
      end

      context 'when never expires' do
        it_behaves_like 'expiration message',
          start_date: today - 30.days,
          expire_date: nil,
          is_trial: false,
          message: "#{s_('Subscriptions|End date:')} #{s_('Subscriptions|None')}"
      end
    end

    context 'when trial license is loaded' do
      context 'when is active' do
        days_left = 23
        it_behaves_like 'expiration message',
          start_date: today - 30.days,
          expire_date: today + days_left.days,
          is_trial: true,
          message: "#{s_('Subscriptions|End date:')} Free trial will expire in #{days_left} days"
      end

      context 'when is expired' do
        it_behaves_like 'expiration message',
          start_date: today - 60.days,
          expire_date: today - 30.days,
          is_trial: true,
          message: "#{_('Expired:')} #{(today - 30.days).strftime('%b %-d, %Y')}"
      end

      context 'when never expires' do
        it_behaves_like 'expiration message',
          start_date: today - 30.days,
          expire_date: nil,
          is_trial: true,
          message: "#{s_('Subscriptions|End date:')} #{s_('Subscriptions|None')}"
      end
    end
  end

  describe 'Components' do
    describe 'Geo' do
      context 'when no Geo sites are configured' do
        it 'does not render the number of sites' do
          render

          expect(rendered).not_to have_content "site"
        end
      end

      context 'when 1 Geo site is configured' do
        let_it_be(:site1) { create(:geo_node, :primary) }

        it 'renders 1 site' do
          render

          expect(rendered).to have_content "1 site"
        end

        context 'when a 2nd Geo site is configured' do
          let_it_be(:site2) { create(:geo_node, :secondary) }

          it 'renders 2 sites' do
            render

            expect(rendered).to have_content "2 sites"
          end

          context 'when a 3rd Geo site is configured' do
            let_it_be(:site3) { create(:geo_node, :secondary) }

            it 'renders 3 sites' do
              render

              expect(rendered).to have_content "3 sites"
            end
          end
        end
      end
    end
  end

  describe 'Features' do
    it 'shows EE features together with settings links', :aggregate_failures do
      render

      expect(rendered).to have_content 'Advanced Search'
      expect(rendered).to have_link href: search_admin_application_settings_path(anchor: 'js-elasticsearch-settings')
      expect(rendered).to have_content 'Geo'
      expect(rendered).to have_link href: admin_geo_nodes_path
    end
  end

  context 'when user is assigned a custom admin role' do
    let_it_be(:user) { create(:user) }
    let_it_be(:role) { create(:admin_member_role, :read_admin_users, user: user) }

    before do
      assign(:license, create(:license))
    end

    it 'includes license overview without the link to details', :aggregate_failures do
      render

      expect(rendered).to have_content _('License overview')
      expect(rendered).to have_content _('Plan:')
      expect(rendered).to have_content s_('Subscriptions|End date:')
      expect(rendered).to have_content _('Licensed to:')
      expect(rendered).to have_content _('Type:')
      expect(rendered).not_to have_link _('View details'), href: admin_subscription_path
    end

    it 'does not show Projects, Groups and Users lists and links to create new entities', :aggregate_failures do
      render

      expect(rendered).not_to have_content 'Projects'
      expect(rendered).not_to have_content 'Total Users'
      expect(rendered).not_to have_content 'Groups'

      expect(rendered).not_to have_link _('New project'), href: new_project_path
      expect(rendered).not_to have_link _('New user'), href: new_admin_user_path
      expect(rendered).not_to have_link _('New group'), href: new_admin_group_path

      expect(rendered).not_to have_link _('View latest projects'), href: admin_projects_path(sort: 'created_desc')
      expect(rendered).not_to have_link _('View latest users'), href: admin_users_path(sort: 'created_desc')
      expect(rendered).not_to have_link _('Users statistics'), href: admin_dashboard_stats_path
      expect(rendered).not_to have_link _('View latest groups'), href: admin_groups_path(sort: 'created_desc')
    end

    describe 'Features' do
      it 'shows features but without settings links', :aggregate_failures do
        render

        expect(rendered).to have_content 'Sign up'
        expect(rendered).not_to have_link href: general_admin_application_settings_path(anchor: 'js-signup-settings')
        expect(rendered).to have_content 'LDAP'
        expect(rendered).to have_link href: help_page_path('administration/auth/ldap/_index.md') # just a help page
        expect(rendered).to have_content 'Gravatar'
        expect(rendered).not_to have_link href: general_admin_application_settings_path(anchor: 'js-account-settings')
        expect(rendered).to have_content 'OmniAuth'
        expect(rendered).not_to have_link href: general_admin_application_settings_path(anchor: 'js-signin-settings')
        expect(rendered).to have_content 'Reply by email'
        expect(rendered).to have_link href: help_page_path('administration/reply_by_email.md') # just a help page
        expect(rendered).to have_content 'Advanced Search'
        expect(rendered).not_to have_link href: search_admin_application_settings_path(anchor: 'js-elasticsearch-settings')
        expect(rendered).to have_content 'Geo'
        expect(rendered).not_to have_link href: admin_geo_nodes_path
        expect(rendered).to have_content 'Container registry'
        expect(rendered).not_to have_link href: ci_cd_admin_application_settings_path(anchor: 'js-registry-settings')
        expect(rendered).to have_content 'GitLab Pages'
        expect(rendered).to have_link href: help_instance_configuration_url # just a help page
        expect(rendered).to have_content 'Instance Runners'
        expect(rendered).not_to have_link href: admin_runners_path
      end
    end
  end

  context 'for duo_amazon_q_alert' do
    before do
      allow(view).to receive(:current_user).and_return(build_stubbed(:user))
      stub_saas_features(subscriptions_trials: false)
      allow(GitlabSubscriptions::DuoAmazonQ)
        .to receive(:any_add_on_purchase).and_return(build_stubbed(:gitlab_subscription_add_on_purchase))

      render
    end

    subject { view.content_for(:page_level_alert) }

    it { is_expected.to have_content(s_('AmazonQ|GitLab Duo with Amazon Q')) }
  end
end
