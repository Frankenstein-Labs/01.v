# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::NamespaceLimit::AlertComponent, :saas_namespaces_storage_limit,
  feature_category: :consumables_cost_management do
  include NamespaceStorageHelpers
  using RSpec::Parameterized::TableSyntax

  let(:user) { build_stubbed(:user) }
  let(:gitlab_subscription) { build_stubbed(:gitlab_subscription) }
  let(:additional_purchased_storage_size) { 0 }
  let(:group) do
    build_stubbed(
      :group,
      additional_purchased_storage_size: additional_purchased_storage_size,
      gitlab_subscription: gitlab_subscription
    )
  end

  let(:context) { group }
  let(:usage_ratio) { 0.8 }
  let(:above_size_limit) { false }
  let(:alert_title) { /You have used \d+% of the storage quota for #{group.name}/ }
  let(:alert_title_free_tier) { "You have reached the free storage limit of 5 GiB for #{group.name}" }

  let(:alert_message_below_limit) do
    "If #{group.name} exceeds the storage quota, your ability to write new data to this namespace will be " \
      "restricted. Which actions become restricted? To prevent your projects from being in a read-only state manage " \
      "your storage usage, or purchase more storage."
  end

  let(:alert_message_above_limit_no_purchased_storage) do
    "#{group.name} is now read-only. Your ability to write new data to this namespace is restricted. " \
      "Which actions are restricted? To remove the read-only state manage your storage usage, or purchase " \
      "more storage."
  end

  let(:alert_message_above_limit_with_purchased_storage) do
    "#{group.name} is now read-only. Your ability to write new data to this namespace is restricted. " \
      "Which actions are restricted? To remove the read-only state manage your storage usage, or purchase " \
      "more storage."
  end

  let(:alert_message_non_owner_copy) do
    "contact a user with the owner role for this namespace and ask them to purchase more storage"
  end

  subject(:component) { described_class.new(context: context, user: user) }

  describe 'namespace enforcement' do
    before do
      enforce_namespace_storage_limit(group)

      allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
        allow(size_checker).to receive_messages(
          usage_ratio: usage_ratio,
          above_size_limit?: above_size_limit
        )
      end

      set_dashboard_limit(group, megabytes: 5120)
      stub_member_access_level(group, owner: user)
    end

    context 'when namespace has no additional storage' do
      let(:additional_purchased_storage_size) { 0 }

      context 'and under storage size limit' do
        let(:usage_ratio) { 0.8 }
        let(:above_size_limit) { false }

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_below_limit)
        end

        it 'allows to dismiss alert' do
          render_inline(component)
          expect(page).to have_css("[data-testid='close-icon']")
        end
      end

      context 'and above storage size limit' do
        let(:usage_ratio) { 1 }
        let(:above_size_limit) { true }

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title_free_tier)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_above_limit_no_purchased_storage)
        end

        it 'does not allow to dismiss alert' do
          render_inline(component)
          expect(page).not_to have_css("[data-testid='close-icon']")
        end
      end
    end

    context 'when namespace has additional storage' do
      let(:additional_purchased_storage_size) { 1 }

      context 'and under storage size limit' do
        let(:usage_ratio) { 0.8 }
        let(:above_size_limit) { false }

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_below_limit)
        end
      end

      context 'and above storage size limit' do
        let(:usage_ratio) { 1 }
        let(:above_size_limit) { true }

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_above_limit_with_purchased_storage)
        end
      end
    end

    context 'and enforcement_limit is higher than dashboard_limit' do
      before do
        set_enforcement_limit(group, megabytes: 10240)
      end

      it 'renders the title with the dashboard_limit' do
        render_inline(component)
        expect(page).to have_content('5 GiB')
      end
    end
  end

  describe '#render?' do
    where(
      :namespaces_storage_limit,
      :user_present,
      :user_has_access,
      :enforce_limit,
      :alert_level,
      :in_enforcement_rollout,
      :user_has_dismissed_alert,
      :should_render
    ) do
      true  | true  | true  | true  | :error   | false | false | true  # Happy Path
      false | true  | true  | true  | :error   | false | false | false # namespaces_storage_limit is false
      true  | false | true  | true  | :error   | false | false | false # user_present is false
      true  | true  | false | true  | :error   | false | false | false # user_has_access is false
      true  | true  | true  | false | :error   | false | false | false # enforce_limit is false
      true  | true  | true  | true  | :none    | false | false | false # alert_level is :none
      # alert_level is not :none and in_enforcement_rollout is false
      true  | true  | true  | true  | :warning | false | false | true
      # alert_level is not :none but in_enforcement_rollout is true
      true  | true  | true  | true  | :warning | true  | false | false
    end

    with_them do
      before do
        stub_saas_features(namespaces_storage_limit: namespaces_storage_limit)

        allow(::Namespaces::Storage::NamespaceLimit::Enforcement).to receive_messages(
          in_enforcement_rollout?: in_enforcement_rollout,
          enforce_limit?: enforce_limit
        )

        allow(user).to receive(:present?).and_return(user_present)
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive_messages(
            user_has_access?: user_has_access,
            alert_level: alert_level,
            user_has_dismissed_alert?: user_has_dismissed_alert
          )
        end
      end

      it 'renders the alert title' do
        render_inline(component)

        expectation = should_render ? have_content(alert_title) : be_empty
        expect(page.text).to expectation
      end
    end

    context 'for a project in a public group' do
      let(:group) do
        build_stubbed(
          :group,
          :public,
          gitlab_subscription: gitlab_subscription
        )
      end

      let(:project) { build_stubbed(:project, :public, namespace: group) }
      let(:context) { project }

      context 'when the user is not a member' do
        before do
          enforce_namespace_storage_limit(group)

          allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
            allow(size_checker).to receive(:usage_ratio).and_return(1.00)
          end
        end

        it 'does not render the alert' do
          render_inline(component)
          expect(page).not_to have_content(alert_title)
        end

        context 'when the user is at least a guest of the project' do
          before do
            stub_member_access_level(project, guest: user)
          end

          it 'renders the alert' do
            render_inline(component)
            expect(page).to have_content(alert_title)
          end
        end
      end
    end
  end

  context 'when user is not an owner' do
    where(:usage_ratio, :alert_message_copy) do
      0.85 | "exceeds the storage quota"
      1.00 | "is now read-only"
    end

    with_them do
      before do
        enforce_namespace_storage_limit(group)

        stub_member_access_level(group, maintainer: user)

        allow_next_instance_of(::Namespaces::Storage::RootSize) do |size_checker|
          allow(size_checker).to receive_messages(
            usage_ratio: usage_ratio,
            above_size_limit?: usage_ratio >= 1
          )
        end
      end

      it 'renders the message' do
        render_inline(component)
        expect(page).to have_content(alert_message_copy)
      end

      it 'renders the non-owner copy' do
        render_inline(component)
        expect(page).to have_content(alert_message_non_owner_copy)
      end
    end
  end
end
