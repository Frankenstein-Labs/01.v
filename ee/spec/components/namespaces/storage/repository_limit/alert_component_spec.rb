# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::RepositoryLimit::AlertComponent, :saas, feature_category: :consumables_cost_management do
  let(:group) do
    build_stubbed(
      :group,
      gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::FREE)
    )
  end

  let(:project_over_limit) { build_stubbed(:project, namespace: group) }
  let(:project_under_limit) { build_stubbed(:project, namespace: group) }
  let(:user) { build_stubbed(:user) }
  let(:alert_title_default) { "#{group.name} has 1 read-only project" }
  let(:alert_title_purchased_storage) { /You have used \d+% of the purchased storage for #{group.name}/ }
  let(:alert_title_free_tier) { "You have reached the free storage limit of 10 GiB on 1 project" }

  let(:alert_message_below_limit) do
    "When a project reaches 100% of the allocated storage (10 GiB) it will be placed in a read-only state. " \
      "You won't be able to push and add large files to your repository. To reduce storage usage, " \
      "reduce git repository and git LFS storage."
  end

  let(:alert_message_above_limit) do
    "You have consumed all available storage and can't push or add large files to projects over the " \
      "included storage (10 GiB). To remove the read-only state, manage your storage usage or purchase more storage."
  end

  let(:alert_message_above_limit_with_high_limit) do
    "You have consumed all available storage and can't push or add large files to projects over the " \
      "included storage (10 GiB). To remove the read-only state, manage your storage usage or contact support."
  end

  let(:alert_message_non_owner_copy) do
    "contact a user with the owner role for this namespace and ask them to purchase more storage"
  end

  subject(:component) { described_class.new(context: project_over_limit, user: user) }

  describe 'repository enforcement' do
    before do
      stub_ee_application_setting(repository_size_limit: 10.gigabytes)
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_ee_application_setting(automatic_purchased_storage_allocation: true)
      stub_feature_flags(namespace_storage_limit: false)

      allow(Ability).to receive(:allowed?).with(user, :admin_namespace, group).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :admin_namespace, project_over_limit).and_return(true)
      allow(Ability).to receive(:allowed?).with(user, :read_limit_alert, project_over_limit).and_return(true)

      allow(project_over_limit).to receive(:repository_size_excess).and_return(1)
    end

    context 'when namespace has no additional storage and is above size limit' do
      before do
        allow(group).to receive_messages(
          repository_size_excess_project_count: 1,
          additional_purchased_storage_size: 0
        )
        allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
          allow(size_checker).to receive_messages(
            usage_ratio: 1,
            above_size_limit?: true
          )
        end
      end

      it 'renders free tier alert title' do
        render_inline(component)
        expect(page).to have_content(alert_title_free_tier)
      end

      it 'renders the alert message' do
        render_inline(component)
        expect(page).to have_content(alert_message_above_limit)
      end

      context 'when group is paid' do
        let(:group) do
          build_stubbed(
            :group,
            gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::ULTIMATE)
          )
        end

        it 'renders the default alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title_default)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_above_limit)
        end

        context 'when group is subject to high limit' do
          before do
            allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
              allow(size_checker).to receive_messages(
                usage_ratio: 1,
                above_size_limit?: true,
                subject_to_high_limit?: true,
                has_projects_over_high_limit_warning_threshold?: true
              )
            end
          end

          it 'renders the alert message' do
            render_inline(component)
            expect(page).to have_content(alert_message_above_limit_with_high_limit)
          end
        end
      end
    end

    context 'when namespace has additional storage' do
      context 'and under storage size limit' do
        before do
          allow(group).to receive(:additional_purchased_storage_size).and_return(1)
          allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
            allow(size_checker).to receive(:usage_ratio).and_return(0.75)
          end
        end

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title_purchased_storage)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_below_limit)
        end

        it 'renders the correct callout data' do
          render_inline(component)
          expect(page).to have_css("[data-feature-id='project_repository_limit_alert_warning_threshold']")
          expect(page).to have_css("[data-dismiss-endpoint='#{group_callouts_path}']")
          expect(page).to have_css("[data-group-id='#{group.root_ancestor.id}']")
        end
      end

      context 'and above storage size limit' do
        before do
          allow(group).to receive_messages(
            repository_size_excess_project_count: 1,
            additional_purchased_storage_size: 1
          )
          allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
            allow(size_checker).to receive_messages(
              usage_ratio: 1,
              above_size_limit?: true
            )
          end
        end

        it 'renders the alert title' do
          render_inline(component)
          expect(page).to have_content(alert_title_default)
        end

        it 'renders the alert message' do
          render_inline(component)
          expect(page).to have_content(alert_message_above_limit)
        end
      end
    end

    context 'when group is paid and is approaching limit' do
      let(:group) do
        build_stubbed(
          :group,
          gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::ULTIMATE)
        )
      end

      before do
        allow_next_instance_of(PlanLimits) do |plan_limit|
          allow(plan_limit).to receive(:repository_size).and_return 1
        end
        allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
          allow(size_checker).to receive_messages(
            has_projects_over_high_limit_warning_threshold?: true
          )
        end
      end

      it 'renders the approaching limit alert title' do
        render_inline(component)
        expect(page).to have_content("We've noticed an unusually high storage usage on #{group.name}")
      end

      it 'renders the approaching limit alert message' do
        render_inline(component)
        expect(page).to have_content(
          "To manage your usage and prevent your projects from being placed in a read-only state, " \
            "you should immediately reduce storage, or contact support to help you manage your usage."
        )
      end

      context 'when there are also projects over limit' do
        before do
          allow(group).to receive(:repository_size_excess_project_count).and_return(1)
          allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
            allow(size_checker).to receive_messages(
              usage_ratio: 1,
              above_size_limit?: true,
              has_projects_over_high_limit_warning_threshold?: true
            )
          end
        end

        it 'renders above limit alert title' do
          render_inline(component)

          expect(page).to have_content(alert_title_default)
        end
      end
    end

    context 'when user is not an owner' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, group).and_return(false)
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, project_over_limit).and_return(false)
        allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
          allow(size_checker).to receive_messages(
            usage_ratio: 1,
            above_size_limit?: true
          )
        end
      end

      it 'renders the non-owner copy' do
        render_inline(component)
        expect(page).to have_content(alert_message_non_owner_copy)
      end
    end

    context 'when project is not over limit' do
      subject(:component) { described_class.new(context: project_under_limit, user: user) }

      before do
        allow(project_under_limit).to receive(:repository_size_excess).and_return(0)

        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, project_under_limit).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :read_limit_alert, project_under_limit).and_return(true)
        allow(group).to receive_messages(
          repository_size_excess_project_count: 1,
          additional_purchased_storage_size: 0
        )
        allow_next_instance_of(::Namespaces::Storage::RepositoryLimit::Enforcement) do |size_checker|
          allow(size_checker).to receive_messages(
            usage_ratio: 1,
            above_size_limit?: false
          )
        end
      end

      it 'does not render the alert' do
        render_inline(component)
        expect(page).not_to have_content(alert_title_free_tier)
      end
    end

    context 'when context is a group' do
      subject(:component) { described_class.new(context: group, user: user) }

      before do
        root_storage_size = ::Namespaces::Storage::RepositoryLimit::Enforcement.new(group)

        allow(root_storage_size).to receive_messages(
          usage_ratio: 1,
          above_size_limit?: true
        )
        allow(group).to receive_messages(
          repository_size_excess_project_count: 1,
          additional_purchased_storage_size: 0
        )
        allow(group.root_ancestor).to receive(:root_storage_size).and_return(root_storage_size)

        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, group).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :admin_namespace, group).and_return(true)
        allow(Ability).to receive(:allowed?).with(user, :read_limit_alert, group).and_return(true)
      end

      it 'does not render the alert' do
        render_inline(component)
        expect(page).not_to have_content(alert_title_free_tier)
      end

      context 'when group is a user namespace' do
        let(:group) do
          build_stubbed(
            :user_namespace,
            gitlab_subscription: build_stubbed(:gitlab_subscription, plan_code: Plan::FREE)
          )
        end

        it 'renders the alert' do
          render_inline(component)
          expect(page).to have_content(alert_title_free_tier)
        end
      end

      context 'when in group usage quotas page' do
        before do
          allow(component).to receive(:current_page?)
            .with(group_usage_quotas_path(group)).and_return(true)
        end

        it 'renders the alert' do
          render_inline(component)
          expect(page).to have_content(alert_title_free_tier)
        end
      end
    end
  end
end
