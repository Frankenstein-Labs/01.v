# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::FreeUserCap::EnforcementAtLimitAlertComponent, :with_trial_types, :saas, :aggregate_failures, feature_category: :seat_cost_management do
  let(:namespace) { build_stubbed(:group) }
  let(:content_class) { '_content_class_' }
  let(:user) { build_stubbed(:user) }
  let(:free_user_cap_at_limit?) { true }
  let(:read_billable_member?) { true }
  let(:title) do
    "Your top-level group #{namespace.name} has reached the " \
      "#{::Namespaces::FreeUserCap.dashboard_limit} user limit"
  end

  subject(:component) do
    described_class.new(namespace: namespace, user: user, content_class: content_class)
  end

  before do
    allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement) do |free_user_cap|
      allow(free_user_cap).to receive(:at_limit?).and_return(free_user_cap_at_limit?)
    end

    allow(Ability).to receive(:allowed?).with(user, :read_billable_member, namespace).and_return(read_billable_member?)
  end

  context 'when user is authorized to see alert' do
    context 'when at the limit' do
      it 'has content for the alert' do
        render_inline(component)

        expect(page).to have_content(title)
        expect(page).to have_css('.gl-alert-actions')
        expect(page).to have_link('Manage members', href: group_usage_quotas_path(namespace))

        expect(page).to have_link(
          'Explore paid plans',
          href: group_billings_path(namespace, source: 'user-limit-alert-enforcement')
        )

        expect(page).to have_css(".#{content_class}")

        expect(page)
          .to have_css("[data-testid='user-over-limit-free-plan-alert']" \
                       "[data-dismiss-endpoint='#{group_callouts_path}']" \
                       "[data-feature-id='#{described_class::ENFORCEMENT_AT_LIMIT_ALERT}']" \
                       "[data-group-id='#{namespace.id}']")
      end

      context 'with singular user limit' do
        before do
          allow(::Namespaces::FreeUserCap).to receive(:dashboard_limit).and_return(1)
        end

        it 'displays singular form in title and body' do
          render_inline(component)

          expect(page).to have_content("has reached the 1 user limit")
          expect(page).to have_content("reduce the number of users in your top-level group to 1 user or less")
        end
      end

      context 'with plural user limit' do
        before do
          allow(::Namespaces::FreeUserCap).to receive(:dashboard_limit).and_return(5)
        end

        it 'displays plural form' do
          render_inline(component)

          expect(page).to have_content("has reached the 5 user limit")
          expect(page).to have_content("reduce the number of users in your top-level group to 5 users or less")
        end
      end

      it 'renders all the expected tracking items' do
        render_inline(component)

        property = 'enforcement_at_limit_user_limit_banner'

        expect(page).to have_tracking(action: 'render', label: 'user_limit_banner', property: property)
        expect(page).to have_tracking(action: 'click_button', label: 'manage_members', property: property)
        expect(page).to have_tracking(action: 'click_button', label: 'explore_paid_plans', property: property)
        expect(page).to have_tracking(action: 'dismiss_banner', label: 'user_limit_banner', property: property)
      end

      context 'when alert has been dismissed' do
        before do
          allow(user).to receive(:dismissed_callout_for_group?).with(
            feature_name: described_class::ENFORCEMENT_AT_LIMIT_ALERT,
            group: namespace
          ).and_return(true)
        end

        it 'does not render the alert' do
          render_inline(component)

          expect(page).not_to have_content(title)
        end
      end
    end

    context 'when limit has not been reached' do
      let(:free_user_cap_at_limit?) { false }

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(title)
      end
    end
  end

  context 'when user is not authorized to see alert' do
    let(:read_billable_member?) { false }

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
