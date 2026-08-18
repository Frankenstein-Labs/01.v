# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BillingPlansHelper, :saas, feature_category: :subscription_management do
  include Devise::Test::ControllerHelpers
  include FreeUserCapHelpers

  describe '#subscription_plan_data_attributes' do
    let(:group) { build(:group) }
    let(:customer_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_manage_url }
    let(:subscription_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_url }
    let(:add_seats_href) { "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/extra_seats" }
    let(:plan_renew_href) { "#{subscription_portal_url}/gitlab/namespaces/#{group.id}/renew" }
    let(:billable_seats_href) { helper.group_usage_quotas_path(group, anchor: 'seats-quota-tab') }
    let(:refresh_seats_href) { helper.refresh_seats_group_billings_url(group) }
    let(:read_only) { true }

    let(:plan) do
      double('plan', id: 'external-paid-plan-hash-code', name: 'Bronze Plan')
    end

    context 'when group and plan with ID present' do
      let(:base_attrs) do
        {
          namespace_id: group.id,
          namespace_name: group.name,
          add_seats_href: add_seats_href,
          plan_renew_href: plan_renew_href,
          customer_portal_url: customer_portal_url,
          billable_seats_href: billable_seats_href,
          plan_name: plan.name,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns data attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'when group not present' do
      let(:group) { nil }

      it 'returns empty data attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only)).to eq({})
      end
    end

    context 'when plan not present' do
      let(:plan) { nil }

      let(:base_attrs) do
        {
          add_seats_href: add_seats_href,
          billable_seats_href: billable_seats_href,
          customer_portal_url: customer_portal_url,
          namespace_id: nil,
          namespace_name: group.name,
          plan_renew_href: plan_renew_href,
          plan_name: nil,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns attributes' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'when plan with ID not present' do
      let(:plan) { double('plan', id: nil, name: 'Bronze Plan') }

      let(:base_attrs) do
        {
          namespace_id: group.id,
          namespace_name: group.name,
          customer_portal_url: customer_portal_url,
          billable_seats_href: billable_seats_href,
          add_seats_href: add_seats_href,
          plan_renew_href: plan_renew_href,
          plan_name: plan.name,
          read_only: read_only.to_s,
          seats_last_updated: nil
        }
      end

      it 'returns data attributes without upgrade href' do
        expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
          .to eq(base_attrs.merge(refresh_seats_href: refresh_seats_href))
      end

      context 'with refresh_billings_seats feature flag off' do
        before do
          stub_feature_flags(refresh_billings_seats: false)
        end

        it 'returns data attributes' do
          expect(helper.subscription_plan_data_attributes(group, plan, read_only: read_only))
            .to eq(base_attrs)
        end
      end
    end

    context 'with different namespaces' do
      subject { helper.subscription_plan_data_attributes(namespace, plan) }

      context 'with namespace' do
        let(:namespace) { build(:namespace) }

        it 'does not return billable_seats_href' do
          expect(subject).not_to include(billable_seats_href: helper.group_usage_quotas_path(namespace,
            anchor: 'seats-quota-tab'))
        end
      end

      context 'with group' do
        let(:namespace) { build(:group) }

        it 'returns billable_seats_href for group' do
          expect(subject).to include(billable_seats_href: helper.group_usage_quotas_path(namespace,
            anchor: 'seats-quota-tab'))
        end
      end
    end

    context 'when seats_last_updated is being assigned' do
      let(:enqueue_time) { Time.new(2023, 2, 21, 12, 13, 14, "+00:00") }

      subject(:seats_last_updated) do
        helper.subscription_plan_data_attributes(group, plan, read_only: read_only)[:seats_last_updated]
      end

      context 'when the subscription has a last_seat_refresh_at' do
        let(:gitlab_subscription) { build(:gitlab_subscription, namespace: group, last_seat_refresh_at: enqueue_time) }

        before do
          allow(group).to receive(:gitlab_subscription).and_return(gitlab_subscription)
        end

        it { is_expected.to eq '12:13:14' }
      end

      context 'when no last_seat_refresh_at is available' do
        it { is_expected.to be_nil }
      end
    end
  end

  describe '#free_trial_plan_billing_attributes' do
    let_it_be(:plans_data) do
      [Hashie::Mash.new(id: 1, code: ::Plan::PREMIUM),
        Hashie::Mash.new(id: 2, code: ::Plan::ULTIMATE)]
    end

    let(:user) { build(:user) }
    let(:gitlab_subscription) { build(:gitlab_subscription) }
    let(:namespace) { build(:group, id: 1, gitlab_subscription: gitlab_subscription) }
    let(:subscription_portal_url) { ::Gitlab::Routing.url_helpers.subscription_portal_url }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(gitlab_subscription).to receive(:seats_in_use).and_return(5)
    end

    it 'returns billing attributes' do
      expect(helper.free_trial_plan_billing_attributes(namespace, plans_data)).to eql({
        manageSeatsPath: group_usage_quotas_path(namespace, anchor: 'seats-quota-tab'),
        seatsInUse: gitlab_subscription.seats_in_use,
        startTrialPath: new_trial_path(namespace_id: namespace.id),
        totalSeats: gitlab_subscription.seats,
        trialActive: false,
        trialEndsOn: nil,
        eligibleForTrial: false,
        upgradeToPremiumUrl: plan_purchase_url(namespace, plans_data[0]),
        upgradeToUltimateUrl: plan_purchase_url(namespace, plans_data[1]),
        upgradeToPremiumTrackingUrl:
          track_cart_abandonment_gitlab_subscriptions_hand_raise_leads_path(namespace_id: namespace.id,
            plan: ::Plan::PREMIUM),
        upgradeToUltimateTrackingUrl:
          track_cart_abandonment_gitlab_subscriptions_hand_raise_leads_path(namespace_id: namespace.id,
            plan: ::Plan::ULTIMATE),
        purchaseCreditsTrackingUrl:
          track_cart_abandonment_gitlab_subscriptions_hand_raise_leads_path(namespace_id: namespace.id,
            credits: 0),
        purchaseCreditsPath: "#{subscription_portal_url}/subscriptions/purchases/gitlab?deployment_type=gitlab_com&gl_namespace_id=#{namespace.id}&plan_type=gitlab_credits",
        gitlabCreditsDashboardPath: group_settings_gitlab_credits_dashboard_index_path(namespace),
        monthlyCommitmentPurchased: 0
      })
    end

    it 'includes monthly credits related attributes when monthly_commitment_purchased is provided' do
      expect(helper.free_trial_plan_billing_attributes(namespace, plans_data, monthly_commitment_purchased: 100)).to include(
        purchaseCreditsPath: "#{subscription_portal_url}/subscriptions/purchases/gitlab?deployment_type=gitlab_com&gl_namespace_id=#{namespace.id}&plan_type=gitlab_credits",
        gitlabCreditsDashboardPath: group_settings_gitlab_credits_dashboard_index_path(namespace),
        monthlyCommitmentPurchased: 100,
        purchaseCreditsTrackingUrl:
          track_cart_abandonment_gitlab_subscriptions_hand_raise_leads_path(namespace_id: namespace.id,
            credits: 100)
      )
    end

    context 'when enforce_cap' do
      let(:namespace) { build(:group, :private) }

      before do
        enforce_free_user_caps
      end

      it 'returns dashboard limit as total seats' do
        expect(helper.free_trial_plan_billing_attributes(namespace, plans_data))
          .to include(totalSeats: ::Namespaces::FreeUserCap.dashboard_limit)
      end
    end

    context 'when trial is active' do
      let(:gitlab_subscription) { build(:gitlab_subscription, :active_trial) }

      it 'returns active trial' do
        expect(helper.free_trial_plan_billing_attributes(namespace, plans_data)).to include(
          trialActive: true,
          trialEndsOn: gitlab_subscription.trial_ends_on.strftime('%B %-d, %Y'),
          eligibleForTrial: false
        )
      end
    end

    context 'when trial is expired' do
      let(:gitlab_subscription) { build(:gitlab_subscription, :expired_trial) }

      it 'returns expired trial' do
        expect(helper.free_trial_plan_billing_attributes(namespace, plans_data)).to include(
          trialActive: false,
          eligibleForTrial: false
        )
      end

      context 'when the namespace is eligible to re-trial' do
        before do
          allow(namespace).to receive(:eligible_for_trial?).and_return(true)
        end

        it 'reports the namespace as eligible so it renders the start-trial CTA' do
          expect(helper.free_trial_plan_billing_attributes(namespace, plans_data)).to include(
            trialActive: false,
            eligibleForTrial: true
          )
        end
      end
    end
  end

  describe '#can_edit_billing?' do
    let(:auditor_group) { build(:group) }
    let(:auditor) { create(:auditor) }
    let(:dev) { create(:user) }
    let(:admin) { create(:user, admin: true) }

    before do
      auditor_group.add_developer(dev)
      auditor_group.add_guest(auditor)
      auditor_group.add_owner(admin)
    end

    it 'is false for guest' do
      allow(helper).to receive(:current_user).and_return(auditor)

      expect(helper.can_edit_billing?(auditor_group)).to be(false)
    end

    it 'is false for developer' do
      allow(helper).to receive(:current_user).and_return(dev)

      expect(helper.can_edit_billing?(auditor_group)).to be(false)
    end

    it 'is true for admin' do
      allow(helper).to receive(:current_user).and_return(admin)

      expect(helper.can_edit_billing?(auditor_group)).to be(true)
    end
  end

  describe '#show_contact_sales_button?' do
    using RSpec::Parameterized::TableSyntax

    where(:link_action, :result) do
      'upgrade' | true
      'no_upgrade' | false
    end

    with_them do
      subject { helper.show_contact_sales_button?(link_action) }

      it { is_expected.to eq(result) }
    end
  end

  describe '#show_upgrade_button?' do
    using RSpec::Parameterized::TableSyntax

    where(:link_action, :allow_upgrade, :result) do
      'upgrade'    | true  | true
      'upgrade'    | false | false
      'upgrade'    | nil   | true
      'no_upgrade' | true  | false
      'no_upgrade' | false | false
      'no_upgrade' | nil   | false
    end

    with_them do
      subject { helper.show_upgrade_button?(link_action, allow_upgrade) }

      it { is_expected.to eq(result) }
    end
  end

  describe '#plan_feature_list' do
    let(:plan) { Hashie::Mash.new(code: plan_code) }

    context 'when premium' do
      let(:plan_code) { 'premium' }

      let(:expected_features_list) do
        [
          s_('BillingPlans|Everything from Free, plus:'),
          s_('BillingPlans|Cross-team project management'),
          s_('BillingPlans|Multiple approval rules'),
          s_('BillingPlans|Multi-region support'),
          s_('BillingPlans|Priority support'),
          s_('BillingPlans|10000 compute minutes'),
          s_('BillingPlans|GitLab Duo Agent Platform'),
          s_('BillingPlans|Includes $12 in GitLab Credits per user per month')
        ]
      end

      it 'returns features list' do
        features_list = helper.plan_feature_list(plan).map(&:title)

        expect(features_list).to eq(expected_features_list)
      end
    end

    context 'when ultimate' do
      let(:plan_code) { 'ultimate' }

      let(:expected_features_list) do
        [
          s_('BillingPlans|Everything from Premium, plus:'),
          s_('BillingPlans|Company wide portfolio management'),
          s_('BillingPlans|Advanced application security'),
          s_('BillingPlans|Executive level insights'),
          s_('BillingPlans|Compliance automation'),
          s_('BillingPlans|Free guest users'),
          s_('BillingPlans|50000 compute minutes'),
          s_('BillingPlans|GitLab Duo Agent Platform'),
          s_('BillingPlans|Includes $24 in GitLab Credits per user per month')
        ]
      end

      it 'returns features list' do
        features_list = helper.plan_feature_list(plan).map(&:title)

        expect(features_list).to eq(expected_features_list)
      end
    end
  end

  describe '#plan_purchase_or_upgrade_url' do
    let(:plan) { double('Plan') }

    it 'is upgradable' do
      group = double(Group.sti_name, upgradable?: true)

      expect(helper).to receive(:plan_upgrade_url)

      helper.plan_purchase_or_upgrade_url(group, plan)
    end

    it 'is purchasable' do
      group = double(Group.sti_name, upgradable?: false)

      expect(helper).to receive(:plan_purchase_url)
      helper.plan_purchase_or_upgrade_url(group, plan)
    end
  end

  describe '#plan_purchase_url' do
    let_it_be(:group) { create(:group) }

    let(:plan) { double('Plan', id: 'plan-id') }

    it 'builds correct gitlab url with some source' do
      user = create(:user)

      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:params).and_return({ source: 'some_source' })

      expect(helper.plan_purchase_url(group, plan))
        .to eq("#{Gitlab::Routing.url_helpers.subscription_portal_new_subscription_url}?gl_namespace_id=#{group.id}&plan_id=plan-id&source=some_source")
    end

    it 'builds correct url for the old purchase flow' do
      user = create(:user, name: 'First')
      allow(helper).to receive(:current_user).and_return(user)

      expect(helper.plan_purchase_url(group, plan))
        .to eq("#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{group.id}&plan_id=plan-id")
    end
  end

  describe '#upgrade_button_css_classes' do
    let(:plan_data) { double(deprecated?: plan_is_deprecated) }
    let(:namespace) do
      build(
        :group,
        gitlab_subscription:
          build(:gitlab_subscription,
            trial: trial_active,
            trial_starts_on: Time.current,
            trial_ends_on: 1.week.from_now))
    end

    subject { helper.upgrade_button_css_classes(namespace, plan_data, is_current_plan) }

    before do
      allow(namespace.gitlab_subscription).to receive(:upgradable?).and_return(upgradable)
    end

    where(
      is_current_plan: [true, false],
      trial_active: [true, false],
      plan_is_deprecated: [true, false],
      upgradable: [true, false]
    )

    with_them do
      it 'returns the expected list of CSS classes' do
        expected_classes = [].tap do |ary|
          ary << 'disabled' if is_current_plan && !trial_active
          ary << '!gl-invisible' if plan_is_deprecated
          ary << "billing-cta-purchase#{'-new' unless upgradable}"
        end.join(' ')

        is_expected.to eq(expected_classes)
      end
    end
  end

  describe '#billing_available_plans' do
    let(:plan) { double('Plan', deprecated?: false, code: 'premium', hide_deprecated_card?: false) }
    let(:deprecated_plan) { double('Plan', deprecated?: true, code: 'bronze', hide_deprecated_card?: false) }
    let(:plans_data) { [plan, deprecated_plan] }

    context 'when namespace is not on a plan' do
      it 'returns plans without deprecated' do
        expect(helper.billing_available_plans(plans_data, nil)).to eq([plan])
      end
    end

    context 'when namespace is on an active plan' do
      let(:current_plan) { double('plan', code: 'premium') }

      it 'returns plans without deprecated' do
        expect(helper.billing_available_plans(plans_data, nil)).to eq([plan])
      end
    end

    context 'when namespace is on a deprecated plan' do
      let(:current_plan) { double('plan', code: 'bronze') }

      it 'returns plans with a deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq(plans_data)
      end
    end

    context 'when namespace is on a deprecated plan that has hide_deprecated_card set to true' do
      let(:current_plan) { double('plan', code: 'bronze') }
      let(:deprecated_plan) { double('Plan', deprecated?: true, code: 'bronze', hide_deprecated_card?: true) }

      it 'returns plans without the deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq([plan])
      end
    end

    context 'when namespace is on a plan that has hide_deprecated_card set to true, but deprecated? is false' do
      let(:current_plan) { double('plan', code: 'premium') }
      let(:plan) { double('Plan', deprecated?: false, code: 'premium', hide_deprecated_card?: true) }

      it 'returns plans with the deprecated plan' do
        expect(helper.billing_available_plans(plans_data, current_plan)).to eq([plan])
      end
    end
  end

  describe '#subscription_plan_info' do
    it 'returns the current plan' do
      other_plan = Hashie::Mash.new(code: 'bronze')
      current_plan = Hashie::Mash.new(code: 'ultimate')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'ultimate')).to eq(current_plan)
    end

    it 'returns nil if no plan matches the code' do
      plan_a = Hashie::Mash.new(code: 'bronze')
      plan_b = Hashie::Mash.new(code: 'ultimate')

      expect(helper.subscription_plan_info([plan_a, plan_b], 'default')).to be_nil
    end

    it 'breaks a tie with the current_subscription_plan attribute if multiple plans have the same code' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'premium')
      current_plan = Hashie::Mash.new(current_subscription_plan: true, code: 'premium')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'premium')).to eq(current_plan)
    end

    it 'returns nil if no plan matches the code even if current_subscription_plan is true' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'free')
      current_plan = Hashie::Mash.new(current_subscription_plan: true, code: 'bronze')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'default')).to be_nil
    end

    it 'returns the plan matching the plan code even if current_subscription_plan is false' do
      other_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'bronze')
      current_plan = Hashie::Mash.new(current_subscription_plan: false, code: 'premium')

      expect(helper.subscription_plan_info([other_plan, current_plan], 'premium')).to eq(current_plan)
    end
  end

  describe '#show_plans?' do
    using RSpec::Parameterized::TableSyntax

    let(:group) { build(:group) }

    where(:free_personal, :trial_active, :ultimate_plan, :opensource_plan, :expectations) do
      false | false | false | false | true
      false | true  | false | false | true
      false | false | true  | false | false
      false | true  | true  | false | true
      false | false | false | true  | false
      false | true  | false | true  | true
      false | false | true  | true  | false
      false | true  | true  | true  | true
      true  | true  | true  | true  | false
      false | false | false | true  | false
    end

    with_them do
      before do
        allow(group).to receive(:free_personal?).and_return(free_personal)
        allow(group).to receive(:trial_active?).and_return(trial_active)
        allow(group).to receive(:ultimate_plan?).and_return(ultimate_plan)
        allow(group).to receive(:opensource_plan?).and_return(opensource_plan)
      end

      it 'returns boolean' do
        expect(helper.show_plans?(group)).to eql(expectations)
      end
    end
  end

  describe '#billing_upgrade_button_data' do
    let(:plan) { double('Plan', code: '_code_') }
    let(:data) do
      {
        track_action: 'click_button',
        track_label: 'upgrade',
        track_property: plan.code,
        testid: "upgrade-to-#{plan.code}"
      }
    end

    it 'has expected data' do
      expect(helper.billing_upgrade_button_data(plan)).to eq data
    end
  end

  describe '#user_billing_data_attributes' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:free_group) { create(:group, name: 'Free Group') }
    let_it_be(:trial_group) { create(:group, name: 'Trial Group') }
    let_it_be(:free_project) { create(:project, namespace: free_group) }

    let(:premium_plan) { double('Plan', code: ::Plan::PREMIUM, id: 1) }
    let(:ultimate_plan) { double('Plan', code: ::Plan::ULTIMATE, id: 2) }
    let(:plans_data) { [premium_plan, ultimate_plan] }

    before_all do
      free_group.add_owner(current_user)
      trial_group.add_owner(current_user)

      create(:gitlab_subscription, namespace: free_group, hosted_plan: create(:free_plan))
      create(:gitlab_subscription, :active_trial, namespace: trial_group)
    end

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow(current_user).to receive(:can?).with(:access_duo_entry_point, free_group).and_return(false)
      allow(current_user).to receive(:can?).with(:access_duo_entry_point, trial_group).and_return(true)
    end

    subject { helper.user_billing_data_attributes(plans_data) }

    context 'when validating input' do
      context 'when plans_data is nil' do
        let(:plans_data) { nil }

        it 'returns empty groups array' do
          expect(subject).to eq({ groups: [] })
        end
      end

      context 'when plans_data is empty array' do
        let(:plans_data) { [] }

        it 'returns empty groups array' do
          expect(subject).to eq({ groups: [] })
        end
      end

      context 'when plans_data does not contain a premium plan' do
        let(:plans_data) { [ultimate_plan] }

        it 'returns empty groups array' do
          expect(subject).to eq({ groups: [] })
        end
      end
    end

    it 'returns user billing data with free and trial groups' do
      expect(subject[:groups]).to contain_exactly(
        {
          id: free_group.id,
          name: 'Free Group',
          trial_active: false,
          group_billings_href: group_billings_path(free_group),
          upgrade_to_premium_href: plan_purchase_url(free_group, premium_plan),
          can_access_duo_chat: false,
          explore_links: {
            mergeTrains: project_settings_merge_requests_path(free_project),
            escalationPolicies: project_incident_management_escalation_policies_path(free_project),
            repositoryPullMirroring: project_settings_repository_path(free_project, anchor: "js-push-remote-settings"),
            mergeRequestApprovals: project_settings_merge_requests_path(free_project,
              anchor: "js-merge-request-approval-settings"),
            duoChat: group_settings_gitlab_duo_seat_utilization_index_path(free_group),
            epics: group_epics_path(free_group)
          }
        },
        {
          id: trial_group.id,
          name: 'Trial Group',
          trial_active: true,
          group_billings_href: group_billings_path(trial_group),
          upgrade_to_premium_href: plan_purchase_url(trial_group, premium_plan),
          can_access_duo_chat: true,
          explore_links: {
            mergeTrains: nil,
            escalationPolicies: nil,
            repositoryPullMirroring: nil,
            mergeRequestApprovals: nil,
            duoChat: nil,
            epics: group_epics_path(trial_group)
          }
        }
      )
      expect(subject[:dashboardGroupsHref]).to eq(dashboard_groups_path)
    end

    context 'when a group is scheduled for deletion' do
      it 'excludes the group scheduled for deletion' do
        create(
          :group_deletion_schedule,
          group: free_group,
          marked_for_deletion_on: 1.day.ago,
          deleting_user: current_user
        )

        group_ids = subject[:groups].pluck(:id)

        expect(group_ids).not_to include(free_group.id)
        expect(group_ids).to include(trial_group.id)
      end
    end

    context 'when user has no owned groups' do
      let(:current_user) { create(:user) }

      it 'returns empty groups array' do
        expect(subject[:groups]).to be_empty
        expect(subject[:dashboardGroupsHref]).to eq(dashboard_groups_path)
      end
    end
  end

  describe '#trusted_by_logos' do
    it 'returns the expected logos array' do
      expected = [
        { name: 'T-Mobile', path: 'marketing/t-mobile.svg' },
        { name: 'Goldman Sachs', path: 'marketing/goldman-sachs.svg' },
        { name: 'Airbus', path: 'marketing/airbus.svg' },
        { name: 'Lockheed Martin', path: 'marketing/lockheed-martin.svg' },
        { name: 'Carfax', path: 'marketing/carfax.svg', no_invert: true },
        { name: 'NVIDIA', path: 'marketing/nvidia.svg' },
        { name: 'UBS', path: 'marketing/ubs.svg' }
      ]

      expect(helper.trusted_by_logos).to eq(expected)
    end
  end
end
