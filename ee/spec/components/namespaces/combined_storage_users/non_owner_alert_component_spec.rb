# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::CombinedStorageUsers::NonOwnerAlertComponent, :saas,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers

  let(:namespace) { build_stubbed(:group, :private, gitlab_subscription: build_stubbed(:gitlab_subscription)) }
  let(:user) { build_stubbed(:user) }
  let(:content_class) { '_content_class_' }
  let(:over_storage_limit) { true }
  let(:over_users_limit) { true }
  let(:alert_title) { 'Free top-level groups will soon be limited to 5 users and 5 GiB of data' }

  let(:contact_owner_message) do
    'you should contact a user with the Owner role for this group to upgrade to a paid tier'
  end

  subject(:component) { described_class.new(root_namespace: namespace, user: user, content_class: content_class) }

  before do
    stub_ee_application_setting(dashboard_limit: 5)
    set_dashboard_limit(namespace, megabytes: 5_000)
    allow(::Namespaces::Storage::NamespaceLimit::Enforcement).to receive(:show_pre_enforcement_alert?)
      .with(namespace).and_return(over_storage_limit)
    allow_next_instance_of(::Namespaces::FreeUserCap::EnforcementWithoutStorage, namespace) do |instance|
      allow(instance).to receive(:over_limit?).and_return(over_users_limit)
    end
  end

  context 'when user is authorized to see alert' do
    before do
      stub_member_access_level(namespace, developer: user)
    end

    context 'when over both limits' do
      it 'renders the alert' do
        render_inline(component)

        expect(page).to have_content(alert_title)
        expect(page).to have_content(contact_owner_message)
      end

      it 'renders all the expected tracking items' do
        render_inline(component)

        expect(page).to have_tracking(action: 'render', label: 'storage_users_limit_banner')
      end

      context 'when the user dismissed the alert under 14 days ago', :freeze_time do
        let(:user) do
          build_stubbed(
            :user,
            group_callouts: [build_stubbed(
              :group_callout,
              group: namespace,
              feature_name: 'namespace_over_storage_users_combined_alert',
              dismissed_at: 1.day.ago
            )]
          )
        end

        it 'does not render the alert' do
          render_inline(component)

          expect(page).not_to have_content(alert_title)
        end
      end

      context 'when the user dismissed the alert 14 or more days ago', :freeze_time do
        let(:user) do
          build_stubbed(
            :user,
            group_callouts: [build_stubbed(
              :group_callout,
              group: namespace,
              feature_name: 'namespace_over_storage_users_combined_alert',
              dismissed_at: 14.days.ago
            )]
          )
        end

        it 'does render the alert' do
          render_inline(component)

          expect(page).to have_content(alert_title)
        end
      end

      context 'when the user has purchased additional storage' do
        it 'includes the purchased storage in the alert' do
          namespace.additional_purchased_storage_size = 10_240
          render_inline(component)

          expect(page).to have_content('15 GiB')
        end
      end
    end

    context 'when not over one of the limits' do
      let(:over_users_limit) { false }

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(alert_title)
      end
    end
  end

  context 'when the user is not authorized to see the alert' do
    context 'when owner' do
      before do
        stub_member_access_level(namespace, owner: user)
      end

      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(alert_title)
      end
    end

    context 'when no access level' do
      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(alert_title)
      end
    end
  end

  context 'when the namespace is public' do
    let(:namespace) { build_stubbed(:group, :public, gitlab_subscription: build_stubbed(:gitlab_subscription)) }

    context 'when the user is not a member' do
      it 'does not render the alert' do
        render_inline(component)

        expect(page).not_to have_content(alert_title)
      end
    end

    context 'when the user is a member' do
      before do
        stub_member_access_level(namespace, guest: user)
      end

      it 'does render the alert' do
        render_inline(component)

        expect(page).to have_content(alert_title)
      end
    end
  end

  context 'when user does not exist' do
    let(:user) { nil }

    it 'does not render the alert' do
      render_inline(component)

      expect(page).not_to have_content(alert_title)
    end
  end
end
