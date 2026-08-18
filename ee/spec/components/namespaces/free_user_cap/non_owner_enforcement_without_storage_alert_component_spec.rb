# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::FreeUserCap::NonOwnerEnforcementWithoutStorageAlertComponent, :saas, :aggregate_failures, feature_category: :seat_cost_management do
  let_it_be(:namespace) { build_stubbed(:group) }
  let_it_be(:user) { build_stubbed(:user) }
  let(:content_class) { '_content_class_' }
  let(:over_limit?) { true }
  let(:body) do
    "Your private namespace is over the 5 user limit. Contact your group Owner to reduce the " \
      "number of users in the namespace, make the namespace public, or upgrade to a paid tier."
  end

  subject(:component) do
    described_class.new(namespace: namespace, user: user, content_class: content_class)
  end

  before do
    stub_ee_application_setting(dashboard_limit: 5)

    allow_next_instance_of(::Namespaces::FreeUserCap::Enforcement) do |enforcement|
      allow(enforcement).to receive(:over_limit?).and_return(over_limit?)
    end
  end

  context 'when user is authorized to see alert' do
    before do
      stub_member_access_level(namespace, guest: user)
    end

    it 'renders the alert' do
      render_inline(component)

      expect(page).to have_content(body)
      expect(page).to have_link('a read-only state',
        href: help_page_path('user/read_only_namespaces.md', anchor: 'read-only-namespaces')
      )
      expect(page).to have_link('the 5 user limit',
        href: help_page_path('user/free_user_limit.md')
      )

      expect(page).not_to have_link('Explore paid plans')
      expect(page).not_to have_css('.js-hand-raise-lead-trigger')
      expect(page).not_to have_link('View your seat usage')
    end

    it 'renders all the expected tracking items' do
      render_inline(component)

      property = 'non_owner_enforcement_without_storage_user_limit_banner'

      expect(page).to have_tracking(
        testid: 'enforcement-without-storage-user-limit-alert',
        action: 'render',
        property: property
      )
      expect(page).to have_tracking(action: 'click_link', label: 'free_user_limit', property: property)
      expect(page).to have_tracking(action: 'click_link', label: 'read_only_namespaces', property: property)
    end

    context 'when the namespace is not over the user limit' do
      let(:over_limit?) { false }

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(body)
      end
    end
  end

  context 'when user is a group owner' do
    before do
      stub_member_access_level(namespace, owner: user)
    end

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content(body)
    end
  end

  context 'when user does not exist' do
    let(:user) { nil }

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content(body)
    end
  end
end
