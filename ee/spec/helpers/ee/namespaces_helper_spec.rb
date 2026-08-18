# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NamespacesHelper, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax
  include NamespacesTestHelper

  let!(:user) { create(:user) }
  let!(:user_project_creation_level) { nil }

  let(:user_group) do
    create(
      :namespace,
      :with_ci_minutes,
      project_creation_level: user_project_creation_level,
      owner: user,
      ci_minutes_used: ci_minutes_used
    )
  end

  let(:ci_minutes_used) { 100 }

  describe '#buy_additional_minutes_path', feature_category: :consumables_cost_management do
    let(:namespace) { build_stubbed(:group) }

    subject { helper.buy_additional_minutes_path(namespace) }

    it { is_expected.to eql get_buy_minutes_path(namespace) }

    context 'when called for a personal namespace' do
      let(:namespace) { build_stubbed(:user_namespace) }

      it 'returns correct path' do
        more_minutes_url = ::Gitlab::Utils.add_url_parameters(
          ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url,
          gl_namespace_id: namespace.root_ancestor.id
        )

        expect(helper.buy_additional_minutes_path(namespace)).to eq more_minutes_url
      end
    end

    context 'when called from a subgroup' do
      let(:group) { create(:group) }
      let(:subgroup) { create(:group, parent: group) }

      it 'returns the selected group id as the parent group' do
        link = helper.buy_additional_minutes_path(subgroup)
        expect(link).to eq get_buy_minutes_path(group)
      end
    end
  end

  describe '#buy_additional_minutes_url', feature_category: :consumables_cost_management do
    subject { helper.buy_additional_minutes_url(namespace) }

    let(:namespace) { build_stubbed(:group) }

    it { is_expected.to eq buy_minutes_subscriptions_url(selected_group: namespace.id) }

    context 'when called for a personal namespace' do
      let(:namespace) { build_stubbed(:user_namespace) }

      it 'returns correct path' do
        more_minutes_url = ::Gitlab::Utils.add_url_parameters(
          ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url,
          gl_namespace_id: namespace.root_ancestor.id
        )

        is_expected.to eq more_minutes_url
      end
    end

    context 'when called from a subgroup' do
      let(:group) { build_stubbed(:group) }
      let(:namespace) { build_stubbed(:group, parent: group) }

      it { is_expected.to eq buy_minutes_subscriptions_url(selected_group: group.id) }
    end
  end

  describe '#buy_storage_path', feature_category: :consumables_cost_management do
    subject { helper.buy_storage_path(namespace) }

    let(:namespace) { build_stubbed(:group) }

    it { is_expected.to eq get_buy_storage_path(namespace) }

    context 'when called from a subgroup' do
      let(:group) { create(:group) }
      let(:subgroup) { create(:group, parent: group) }

      it 'returns the buy URL with the parent group id' do
        expect(helper.buy_storage_path(subgroup)).to eq get_buy_storage_path(group)
      end
    end

    context 'when called for a personal namespace' do
      let(:user) { create(:user) }
      let(:personal_namespace) { build_stubbed(:user_namespace) }

      let(:more_storage_url) do
        ::Gitlab::Utils.add_url_parameters(
          ::Gitlab::Routing.url_helpers.subscription_portal_more_storage_url,
          gl_namespace_id: personal_namespace.root_ancestor.id
        )
      end

      it 'returns the default purchase' do
        expect(helper.buy_storage_path(personal_namespace)).to eq more_storage_url
      end
    end
  end

  describe '#buy_storage_url', feature_category: :consumables_cost_management do
    subject { helper.buy_storage_url(namespace) }

    let(:namespace) { build_stubbed(:group) }

    it { is_expected.to eq get_buy_storage_url(namespace) }

    context 'when called from a subgroup' do
      let(:group) { create(:group) }
      let(:subgroup) { create(:group, parent: group) }

      it 'returns the buy URL with the parent group id' do
        expect(helper.buy_storage_url(subgroup)).to eq get_buy_storage_url(group)
      end
    end

    context 'when called for a personal namespace' do
      let(:user) { create(:user) }
      let(:personal_namespace) { build_stubbed(:user_namespace) }

      let(:more_storage_url) do
        ::Gitlab::Utils.add_url_parameters(
          ::Gitlab::Routing.url_helpers.subscription_portal_more_storage_url,
          gl_namespace_id: personal_namespace.root_ancestor.id
        )
      end

      it 'returns the default purchase' do
        expect(helper.buy_storage_url(personal_namespace)).to eq more_storage_url
      end
    end
  end

  describe '#buy_addon_target_attr', feature_category: :consumables_cost_management do
    subject { helper.buy_addon_target_attr(namespace) }

    let(:namespace) { create(:group) }

    it { is_expected.to eq '_self' }

    context 'when called for a personal namespace' do
      let(:user) { create(:user) }
      let(:personal_namespace) { build_stubbed(:user_namespace) }

      it 'returns _blank' do
        expect(helper.buy_addon_target_attr(personal_namespace)).to eq '_blank'
      end
    end
  end

  describe '#pipeline_usage_app_data', feature_category: :consumables_cost_management do
    let(:minutes_usage) { user_group.ci_minutes_usage }
    let(:minutes_usage_presenter) { ::Ci::Minutes::UsagePresenter.new(minutes_usage) }

    context 'when gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns a hash with proper SaaS data' do
        more_minutes_url = ::Gitlab::Utils.add_url_parameters(
          ::Gitlab::Routing.url_helpers.subscription_portal_more_minutes_url,
          gl_namespace_id: user_group.root_ancestor.id
        )

        expect(helper.pipeline_usage_app_data(user_group)).to eql({
          namespace_actual_plan_name: user_group.actual_plan_name,
          namespace_id: user_group.id,
          user_namespace: user_group.user_namespace?.to_s,
          page_size: Kaminari.config.default_per_page,
          ci_minutes: {
            any_project_enabled: minutes_usage_presenter.any_project_enabled?.to_s,
            last_reset_date: minutes_usage.reset_date,
            display_minutes_available_data: minutes_usage_presenter.display_minutes_available_data?.to_s,
            monthly_minutes_used: minutes_usage_presenter.monthly_minutes_used,
            monthly_minutes_used_percentage: minutes_usage_presenter.monthly_percent_used,
            monthly_minutes_limit: minutes_usage_presenter.monthly_minutes_limit_text,
            purchased_minutes_used: minutes_usage_presenter.purchased_minutes_used,
            purchased_minutes_used_percentage: minutes_usage_presenter.purchased_percent_used,
            purchased_minutes_limit: minutes_usage_presenter.purchased_minutes_limit
          },
          buy_additional_minutes_path: more_minutes_url,
          buy_additional_minutes_target: '_blank'
        })
      end
    end

    context 'when gitlab_com_subscriptions saas feature is not available' do
      it 'returns a hash without SaaS data' do
        expect(helper.pipeline_usage_app_data(user_group)).to eql({
          namespace_actual_plan_name: user_group.actual_plan_name,
          namespace_id: user_group.id,
          user_namespace: user_group.user_namespace?.to_s,
          page_size: Kaminari.config.default_per_page,
          ci_minutes: {
            any_project_enabled: minutes_usage_presenter.any_project_enabled?.to_s,
            last_reset_date: minutes_usage.reset_date,
            display_minutes_available_data: minutes_usage_presenter.display_minutes_available_data?.to_s,
            monthly_minutes_used: minutes_usage_presenter.monthly_minutes_used,
            monthly_minutes_used_percentage: minutes_usage_presenter.monthly_percent_used,
            monthly_minutes_limit: minutes_usage_presenter.monthly_minutes_limit_text
          }
        })
      end
    end
  end

  describe '#purchase_storage_url', feature_category: :consumables_cost_management do
    subject { helper.purchase_storage_url(user_group) }

    let(:more_storage_url) do
      ::Gitlab::Utils.add_url_parameters(
        ::Gitlab::Routing.url_helpers.subscription_portal_more_storage_url,
        gl_namespace_id: user_group.root_ancestor.id
      )
    end

    it { is_expected.to eq(more_storage_url) }
  end

  describe '#storage_usage_app_data', :saas, feature_category: :consumables_cost_management do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:namespace) { create(:namespace_with_plan) }
    let_it_be_with_reload(:admin) { create(:user, namespace: namespace) }

    let(:repository_size_limit) { 1000 }
    let(:storage_size_limit) { 1 }

    let(:more_storage_url) do
      ::Gitlab::Utils.add_url_parameters(
        ::Gitlab::Routing.url_helpers.subscription_portal_more_storage_url,
        gl_namespace_id: namespace.root_ancestor.id
      )
    end

    where(enforcement_type: [:project_repository_limit, :namespace_storage_limit])

    with_them do
      before do
        namespace.actual_plan.actual_limits.update!(storage_size_limit: storage_size_limit)
        allow(Namespaces::Storage::NamespaceLimit::Enforcement).to(
          receive(:enforce_limit?).and_return(enforcement_type == :namespace_storage_limit)
        )
        allow(namespace.root_storage_size).to receive(:enforcement_type).and_return(enforcement_type)
        allow(helper).to receive(:current_user).and_return(admin)
        stub_saas_features(gitlab_com_subscriptions: true)
        stub_ee_application_setting(repository_size_limit: repository_size_limit)
      end

      it 'returns a hash with storage data' do
        expect(helper.storage_usage_app_data(namespace)).to eql({
          namespace_id: namespace.id,
          namespace_path: namespace.full_path,
          user_namespace: namespace.user_namespace?.to_s,
          default_per_page: Kaminari.config.default_per_page,
          namespace_plan_name: namespace.actual_plan_name.capitalize,
          purchase_storage_url: more_storage_url,
          buy_addon_target_attr: '_blank',
          per_project_storage_limit: repository_size_limit,
          namespace_storage_limit: storage_size_limit * 1.megabyte,
          is_in_namespace_limits_pre_enforcement: 'false',
          enforcement_type: enforcement_type,
          above_size_limit: 'false',
          subject_to_high_limit: 'false',
          total_repository_size_excess: 0
        })
      end
    end
  end
end
