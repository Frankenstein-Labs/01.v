# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::AiPresenter, feature_category: :ai_abstraction_layer do
  include SubscriptionPortalHelper
  using RSpec::Parameterized::TableSyntax

  describe '#settings' do
    subject(:settings) { described_class.new(user).settings }

    let(:user) { build(:user) }
    let(:application_setting_attributes) do
      {
        disabled_direct_code_suggestions?: false,
        duo_availability: 'default_off',
        enabled_expanded_logging: true,
        gitlab_dedicated_instance?: false,
        instance_level_ai_beta_features_enabled?: true,
        model_prompt_cache_enabled?: true
      }
    end

    let(:ai_settings_attributes) do
      {
        amazon_q_ready?: true,
        duo_core_features_enabled?: true,
        duo_workflow_service_account_user: {
          id: 1,
          username: 'admin',
          name: 'Administrator',
          avatar_url: 'http://localhost:3000/uploads/avatar.png'
        }
      }
    end

    let(:license) do
      build(
        :license,
        data: build(
          :gitlab_license,
          restrictions: {
            subscription_name: subscription_name
          }
        ).export
      )
    end

    let(:ai_settings) { instance_double(Ai::Setting, **ai_settings_attributes) }
    let(:amazon_q_available?) { true }
    let(:any_add_on_purchase) { build(:gitlab_subscription_add_on_purchase, :duo_enterprise, :self_managed, :active) }
    let(:active_add_on_purchase_for_self_managed?) { true }
    let(:active_self_managed_duo_pro_or_enterprise) { any_add_on_purchase }
    let(:auto_review_enabled) { true }
    let(:can_manage_instance_model_selection) { true }
    let(:can_manage_self_hosted_settings) { true }
    let(:beta_self_hosted_models_enabled) { true }
    let(:is_saas) { true }
    let(:self_hosted_models) { true }
    let(:subscription_name) { 'A-S0000001' }
    let(:usage_billing_license_available) { true }
    let(:active_duo_add_ons_exist?) { true }

    before do
      allow(GitlabSubscriptions::AddOnPurchase)
      .to receive(:active_duo_add_ons_exist?)
      .with(:instance)
      .and_return(active_duo_add_ons_exist?)

      stub_current_organization(build(:organization))
      allow(Ai::Setting).to receive(:for_organization_read_only).and_return(ai_settings)

      allow(Ai::TestingTermsAcceptance)
      .to receive(:has_accepted?)
      .and_return(beta_self_hosted_models_enabled)

      allow(License).to receive(:feature_available?).and_call_original
      allow(License).to receive(:feature_available?).with(:self_hosted_models).and_return self_hosted_models
      allow(License).to receive(:feature_available?).with(:usage_billing).and_return(usage_billing_license_available)

      allow(License).to receive(:current).and_return license

      allow(Ability).to receive(:allowed?).with(user,
        :manage_instance_model_selection).and_return(can_manage_instance_model_selection)
      allow(Ability).to receive(:allowed?).with(user,
        :manage_self_hosted_models_settings).and_return(can_manage_self_hosted_settings)
      allow(Ability).to receive(:allowed?).with(user,
        :update_dap_self_hosted_model).and_return(true)

      allow(Gitlab::CurrentSettings)
        .to receive_messages(
          current_application_settings: instance_double(ApplicationSetting, **application_setting_attributes),
          slack_app_enabled: true
        )

      allow(GitlabSubscriptions::DuoEnterprise).to receive_messages(
        active_add_on_purchase_for_self_managed?: active_add_on_purchase_for_self_managed?
      )

      allow(GitlabSubscriptions::Duo).to receive_messages(
        active_self_managed_duo_pro_or_enterprise: active_self_managed_duo_pro_or_enterprise
      )

      stub_saas_features(gitlab_com_subscriptions: is_saas)

      allow(Ai::AmazonQ).to receive(:feature_available?).and_return amazon_q_available?
      allow(Integrations::AmazonQ).to receive(:for_instance)
        .and_return [instance_double(Integrations::AmazonQ, auto_review_enabled: auto_review_enabled)]

      stub_env('CUSTOMER_PORTAL_URL', nil)
    end

    specify do
      expect(settings).to include(
        add_duo_pro_seats_url: "#{staging_customers_url}/gitlab/subscriptions/A-S0000001/duo_pro_seats",
        expose_duo_agent_platform_service_url: 'true',
        amazon_q_auto_review_enabled: 'true',
        amazon_q_configuration_path: '/admin/application_settings/integrations/amazon_q/edit',
        amazon_q_ready: 'true',
        are_experiment_settings_allowed: 'true',
        are_prompt_cache_settings_allowed: 'true',
        beta_self_hosted_models_enabled: 'true',
        can_manage_self_hosted_models: 'true',
        can_manage_instance_model_selection: 'true',
        direct_code_suggestions_enabled: 'true',
        duo_workflow_service_account: {
          id: 1,
          username: 'admin',
          name: 'Administrator',
          avatar_url: 'http://localhost:3000/uploads/avatar.png'
        }.to_json,
        duo_add_on_end_date: any_add_on_purchase.expires_on,
        duo_add_on_start_date: any_add_on_purchase.started_at,
        duo_availability: 'default_off',
        are_duo_core_features_enabled: 'true',
        duo_configuration_path: '/admin/gitlab_duo/configuration',
        duo_seat_utilization_path: '/admin/gitlab_duo/seat_utilization',
        duo_instance_model_selection_path: '/admin/gitlab_duo/model_selection',
        enabled_expanded_logging: 'true',
        experiment_features_enabled: 'true',
        is_bulk_add_on_assignment_enabled: 'true',
        is_saas: 'true',
        show_sm_purchase_button: 'false',
        is_sm_trial: '',
        prompt_cache_enabled: 'true',
        self_managed_purchase_credits_path: ::Gitlab::Routing.url_helpers.subscription_portal_self_managed_purchase_credits_url,
        redirect_path: '/admin/gitlab_duo',
        subscription_name: 'A-S0000001',
        gitlab_credits_dashboard_path: ''
      )
    end

    context 'with another subscription name' do
      let(:subscription_name) { 'A-S0000002' }

      it { expect(settings).to include(subscription_name: 'A-S0000002') }
    end

    context 'when there is no license (e.g. credits-only free-tier SM)' do
      let(:license) { nil }

      it 'does not raise and returns nil for license-delegated fields' do
        expect { settings }.not_to raise_error
        expect(settings).to include(subscription_name: '', is_sm_trial: '', show_sm_purchase_button: 'true')
      end
    end

    context 'with auto review unset' do
      let(:auto_review_enabled) { nil }

      it { expect(settings).to include(amazon_q_auto_review_enabled: 'false') }
    end

    context 'with auto review disabled' do
      let(:auto_review_enabled) { false }

      it { expect(settings).to include(amazon_q_auto_review_enabled: 'false') }
    end

    context 'without Amazon Q ready' do
      let(:ai_settings_attributes) { super().merge(amazon_q_ready?: false) }

      it { expect(settings).to include(amazon_q_ready: 'false') }
    end

    context 'without active Duo add-on' do
      let(:active_duo_add_ons_exist?) { false }

      it { expect(settings).to include(are_experiment_settings_allowed: 'false') }
    end

    context 'with beta_self_hosted_models_enabled' do
      let(:beta_self_hosted_models_enabled) { 'false' }

      it { expect(settings).to include(beta_self_hosted_models_enabled: 'false') }
    end

    context 'with instance-level model selection disabled' do
      let(:can_manage_instance_model_selection) { false }

      it { expect(settings).to include(can_manage_instance_model_selection: 'false') }
    end

    context 'when user cannot manage self-hosted settings' do
      let(:can_manage_self_hosted_settings) { false }

      it { expect(settings).to include(can_manage_self_hosted_models: 'false') }
    end

    context 'when user cannot update DAP self-hosted models' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :update_dap_self_hosted_model).and_return(false)
      end

      it { expect(settings).to include(expose_duo_agent_platform_service_url: 'false') }
    end

    context 'without add-on purchase for Duo Pro or Duo Enterprise' do
      let(:active_self_managed_duo_pro_or_enterprise) { nil }

      it { expect(settings).to include(duo_add_on_end_date: nil, duo_add_on_start_date: nil) }
    end

    context 'with disabled direct code suggestions' do
      let(:application_setting_attributes) { super().merge(disabled_direct_code_suggestions?: true) }

      it { expect(settings).to include(direct_code_suggestions_enabled: 'false') }
    end

    context 'without service account' do
      let(:ai_settings_attributes) { super().merge(duo_workflow_service_account_user: nil) }

      it { expect(settings).to include(duo_workflow_service_account: nil) }
    end

    context 'with other Duo availability' do
      let(:application_setting_attributes) { super().merge(duo_availability: 'always_off') }

      it { expect(settings).to include(duo_availability: 'always_off') }
    end

    context 'with Duo Core features disabled' do
      let(:ai_settings_attributes) { super().merge(duo_core_features_enabled?: false) }

      it { expect(settings).to include(are_duo_core_features_enabled: 'false') }
    end

    context 'without expanded logging' do
      let(:application_setting_attributes) { super().merge(enabled_expanded_logging: false) }

      it { expect(settings).to include(enabled_expanded_logging: 'false') }
    end

    context 'without prompt cache' do
      let(:application_setting_attributes) { super().merge(model_prompt_cache_enabled?: false) }

      it { expect(settings).to include(prompt_cache_enabled: 'false') }
    end

    context 'for usage billing' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns empty path regardless of license' do
        expect(settings).to include(gitlab_credits_dashboard_path: '')
      end
    end

    context 'when on Self-Managed' do
      let(:is_saas) { false }

      it { expect(settings).to include(is_saas: 'false') }

      context 'when the instance is on a trial license' do
        before do
          allow(license).to receive(:trial?).and_return(true)
        end

        it { expect(settings).to include(is_sm_trial: 'true') }
      end

      context 'when the instance is not on a trial license' do
        before do
          allow(license).to receive(:trial?).and_return(false)
        end

        it { expect(settings).to include(is_sm_trial: 'false') }
      end

      context 'when the instance has the SM credits add-on' do
        before do
          allow(License).to receive(:has_active_gitlab_credits_add_on?).and_return(true)
        end

        it { expect(settings).to include(show_sm_purchase_button: 'true') }
      end

      context 'when there is no license' do
        let(:license) { nil }

        it { expect(settings).to include(show_sm_purchase_button: 'true') }
      end

      context 'when the instance is on a paid non-trial license with no credits add-on' do
        before do
          allow(license).to receive(:trial?).and_return(false)
          allow(License).to receive(:has_active_gitlab_credits_add_on?).and_return(false)
        end

        it { expect(settings).to include(show_sm_purchase_button: 'false') }
      end

      context 'for usage billing' do
        where(:setting_enabled, :gitlab_credits_dashboard_path) do
          true  | '/admin/gitlab_credits_dashboard'
          false | ''
        end

        with_them do
          let(:usage_billing_license_available) { setting_enabled }

          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it { expect(settings).to include(gitlab_credits_dashboard_path: gitlab_credits_dashboard_path) }
        end
      end

      context 'when instance only has a gitlab_credits add-on' do
        let(:usage_billing_license_available) { false }

        before do
          stub_saas_features(gitlab_com_subscriptions: false)
          allow(License).to receive(:gitlab_credits_entitled?).and_return(true)
        end

        it { expect(settings).to include(gitlab_credits_dashboard_path: '/admin/gitlab_credits_dashboard') }
      end
    end
  end
end
