# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::FreeUserCap::NonOwnerPreEnforcementAlertComponent, :with_trial_types, :saas, :aggregate_failures, feature_category: :seat_cost_management do
  let(:namespace) { build_stubbed(:group) }
  let(:user) { build_stubbed(:user) }
  let(:qualifies?) { true }
  let(:over_limit?) { true }
  let(:free_user_limit) { ::Namespaces::FreeUserCap.dashboard_limit }
  let(:title) do
    "Your namespace #{namespace.name} is over the #{free_user_limit} user limit"
  end

  subject(:component) do
    described_class.new(namespace: namespace, user: user, content_class: '_content_class_')
  end

  before do
    allow_next_instance_of(::Namespaces::FreeUserCap::PreEnforcement) do |pre_enforcement|
      allow(pre_enforcement).to receive(:qualifies?).and_return(qualifies?)
    end

    allow_next_instance_of(::Namespaces::FreeUserCap::EnforcementWithoutStorage) do |enforcement|
      allow(enforcement).to receive(:over_limit?).and_return(over_limit?)
    end
  end

  context 'when user is authorized to see alert' do
    before do
      stub_member_access_level(namespace, guest: user)
    end

    it 'renders the alert' do
      render_inline(component)

      expect(page).to have_content(title)
      expect(page).to have_link("the #{free_user_limit} user limit", href: help_page_path('user/free_user_limit.md'))

      expect(page).to have_content(
        "Free top-level namespaces with private visibility cannot have more than #{free_user_limit} users."
      )
      expect(page).to have_content('August 15, 2026')
      expect(page).to have_link('a read-only state',
        href: help_page_path('user/read_only_namespaces.md', anchor: 'read-only-namespaces')
      )

      expect(page).to have_content('Contact your top-level group Owner')
      expect(page).not_to have_link('Explore paid plans')
      expect(page).not_to have_link('Contact sales')
      expect(page).not_to have_link('View your seat usage')
    end

    it 'renders all the expected tracking items' do
      render_inline(component)

      property = 'non_owner_pre_enforcement_user_limit_banner'

      expect(page).to have_tracking(testid: 'pre-enforcement-user-limit-alert', action: 'render', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'free_user_limit', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'read_only_namespaces', property: property)
    end

    context 'when the namespace does not qualify for pre-enforcement' do
      let(:qualifies?) { false }

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(title)
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

  context 'when user is a group owner' do
    before do
      stub_member_access_level(namespace, owner: user)
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
