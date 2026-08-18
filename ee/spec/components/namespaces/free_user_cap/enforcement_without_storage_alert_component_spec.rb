# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::FreeUserCap::EnforcementWithoutStorageAlertComponent, :with_trial_types, :saas, :aggregate_failures, feature_category: :seat_cost_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:namespace) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:content_class) { '_content_class_' }
  let(:over_limit?) { true }
  let(:premium_plan) { Hashie::Mash.new(id: 'premium_plan_id', code: ::Plan::PREMIUM) }
  let(:plans_data) { [premium_plan] }
  let(:title) do
    "Your namespace #{namespace.name} has been placed in a read-only state"
  end

  subject(:component) do
    described_class.new(namespace: namespace, user: user, content_class: content_class)
  end

  before do
    stub_ee_application_setting(dashboard_limit: 5)

    allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement) do |enforcement|
      allow(enforcement).to receive(:over_limit?).and_return(over_limit?)
    end

    allow(namespace).to receive(:plan_name_for_upgrading).and_return(::Plan::FREE)

    allow_next_instance_of(::GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
      allow(service).to receive(:execute).and_return(plans_data)
    end
  end

  context 'when user is authorized to see alert' do
    before do
      stub_member_access_level(namespace, owner: user)
    end

    it 'renders the alert' do
      render_inline(component)

      expect(page).to have_content(title)
      expect(page).to have_link('a read-only state',
        href: help_page_path('user/read_only_namespaces.md', anchor: 'read-only-namespaces')
      )
      expect(page).to have_link('the 5 user limit',
        href: help_page_path('user/free_user_limit.md')
      )
      expect(page).to have_content(
        'Your private namespace is over the 5 user limit.'
      )
      expect(page).to have_content(
        'If you need more time, you can start a free 30-day Ultimate trial or re-trial ' \
          '(available 120 days after your last trial started) to get unlimited users.'
      )
      expect(page).to have_link('View your seat usage',
        href: group_usage_quotas_path(namespace, anchor: 'seats-quota-tab')
      )
    end

    it 'renders hand-raise lead trigger with expected data attributes' do
      render_inline(component)

      trigger = page.find('.js-hand-raise-lead-trigger')

      expect(trigger['data-glm-content']).to eq('enforcement-user-limit')
      expect(trigger['data-button-text']).to eq('Contact sales')
      expect(Gitlab::Json.safe_parse(trigger['data-button-attributes'])).to include(
        'data-testid' => 'enforcement-without-storage-user-limit-secondary-cta'
      )
      expect(Gitlab::Json.safe_parse(trigger['data-cta-tracking'])).to eq(
        'action' => 'click_button',
        'label' => 'contact_sales',
        'property' => 'enforcement_without_storage_user_limit_banner'
      )
    end

    it 'renders the promo CTA linking to subscription checkout with promo code' do
      expected_url = ::Gitlab::Utils.add_url_parameters(
        ::Gitlab::Routing.url_helpers.subscription_portal_new_subscription_url,
        { plan_id: premium_plan.id, gl_namespace_id: namespace.id, promo_code: described_class::PROMO_CODE }
      )

      render_inline(component)

      expect(page).to have_link('Buy now at $19 per user/month', href: /promo_code=USER-LIMIT-19-2026/)
      expect(page).to have_link('Buy now at $19 per user/month', href: expected_url)
    end

    context 'when premium plan is not available' do
      where(:case_name, :plans_data) do
        'plans lookup fails'   | nil
        'premium plan missing' | []
      end

      with_them do
        it 'falls back to the default primary CTA' do
          render_inline(component)

          expect(page).to have_link('Explore paid plans or re-trial',
            href: group_billings_path(namespace, source: 'user-limit-alert-enforcement')
          )
          expect(page).to have_no_link('Buy now at $19 per user/month')
        end
      end
    end

    it 'renders all the expected tracking items' do
      render_inline(component)

      property = 'enforcement_without_storage_user_limit_banner'

      expect(page).to have_tracking(
        testid: 'enforcement-without-storage-user-limit-alert',
        action: 'render',
        property: property
      )
      expect(page).to have_tracking(action: 'click_button', label: 'buy_now', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'free_user_limit', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'read_only_namespaces', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'view_seat_usage', property: property)
    end

    context 'when the promo CTA feature flag is disabled' do
      before do
        stub_feature_flags(free_user_cap_enforcement_promo_cta: false)
      end

      it 'renders the default primary CTA linking to billings' do
        render_inline(component)

        expect(page).to have_link(
          'Explore paid plans or re-trial',
          href: group_billings_path(namespace, source: 'user-limit-alert-enforcement')
        )
        expect(page).to have_tracking(
          action: 'click_button',
          label: 'explore_paid_plans',
          property: 'enforcement_without_storage_user_limit_banner'
        )
      end
    end

    context 'when the namespace is not over the user limit' do
      let(:over_limit?) { false }

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(title)
      end
    end
  end

  context 'when user is not authorized to see alert' do
    before do
      stub_member_access_level(namespace, guest: user)
    end

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content(title)
    end
  end

  context 'when user does not exist' do
    let(:user) { nil }

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content(title)
    end
  end
end
