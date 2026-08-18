# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettingsController, feature_category: :settings do
  include StubENV

  let(:admin) { create(:admin) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
  end

  describe 'PUT #update', feature_category: :settings do
    before do
      sign_in(admin)
    end

    it 'updates the EE specific application settings' do
      settings = {
        repository_size_limit: 1024,
        shared_runners_minutes: 60,
        geo_status_timeout: 30,
        check_namespace_plan: true,
        authorized_keys_enabled: true,
        allow_group_owners_to_manage_ldap: false,
        lock_memberships_to_ldap: true,
        geo_node_allowed_ips: '0.0.0.0/0, ::/0',
        allow_account_deletion: true,
        namespace_storage_forks_cost_factor: 0.5
      }

      put :update, params: { application_setting: settings }

      expect(response).to redirect_to(general_admin_application_settings_path)

      settings.except(:repository_size_limit).each do |setting, value|
        expect(ApplicationSetting.current.public_send(setting)).to eq(value)
      end

      expect(ApplicationSetting.current.repository_size_limit).to eq(settings[:repository_size_limit].megabytes)
    end

    shared_examples 'settings for licensed features' do
      it 'does not update settings when licensed feature is not available' do
        stub_licensed_features(license_feature => false)
        attribute_names = settings.keys.map(&:to_s)

        expect { put :update, params: { application_setting: settings } }
          .not_to change { ApplicationSetting.current.reload.attributes.slice(*attribute_names) }
      end

      it 'updates settings when the feature is available' do
        stub_licensed_features(license_feature => true)

        put :update, params: { application_setting: settings }

        settings.each do |attribute, value|
          expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
        end
      end
    end

    shared_examples 'settings for registration features' do
      it 'does not update settings when registration features are not available' do
        stub_application_setting(usage_ping_features_enabled: false)

        attribute_names = settings.keys.map(&:to_s)

        expect { put :update, params: { application_setting: settings } }
          .not_to change { ApplicationSetting.current.reload.attributes.slice(*attribute_names) }
      end

      it 'updates settings when the registration features are available' do
        stub_application_setting(usage_ping_features_enabled: true)

        put :update, params: { application_setting: settings }

        settings.each do |attribute, value|
          expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
        end
      end
    end

    context 'for mirror settings' do
      let(:settings) do
        {
          mirror_max_delay: (Gitlab::Mirror.min_delay_upper_bound / 60) + 1,
          mirror_max_capacity: 200,
          mirror_capacity_threshold: 2
        }
      end

      let(:license_feature) { :repository_mirrors }

      it_behaves_like 'settings for licensed features'
    end

    context 'for boolean attributes' do
      shared_examples_for 'updates boolean attribute' do |attribute|
        specify do
          existing_value = ApplicationSetting.current.public_send(attribute)
          new_value = !existing_value

          put :update, params: { application_setting: { attribute => new_value } }

          expect(response).to redirect_to(general_admin_application_settings_path)
          expect(ApplicationSetting.current.public_send(attribute)).to eq(new_value)
        end
      end

      it_behaves_like 'updates boolean attribute', :receptive_cluster_agents_enabled
      it_behaves_like 'updates boolean attribute', :policy_store_experiment_enabled
    end

    context 'for default project deletion protection' do
      let(:settings) { { default_project_deletion_protection: true } }
      let(:license_feature) { :default_project_deletion_protection }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating name disabled for users setting' do
      let(:settings) { { updating_name_disabled_for_users: true } }
      let(:license_feature) { :disable_name_update_for_users }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating `group_owners_can_manage_default_branch_protection` setting' do
      let(:settings) { { group_owners_can_manage_default_branch_protection: false } }
      let(:license_feature) { :default_branch_protection_restriction_in_groups }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating maven packages request forwarding setting' do
      let(:settings) { { maven_package_requests_forwarding: true } }
      let(:license_feature) { :package_forwarding }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating npm packages request forwarding setting' do
      let(:settings) { { npm_package_requests_forwarding: true } }
      let(:license_feature) { :package_forwarding }

      it_behaves_like 'settings for licensed features'
    end

    context 'for virtual registries' do
      let(:license_feature) { :packages_virtual_registry }

      context 'when updating the API rate limit' do
        let(:settings) { { virtual_registries_endpoints_api_limit: 500 } }

        it_behaves_like 'settings for licensed features'
      end
    end

    context 'for sign-up restrictions' do
      context 'with seat control' do
        context 'and member promotion management' do
          let(:settings) do
            { enable_member_promotion_management: true }
          end

          let(:promotion_management_available) { true }

          before do
            allow_next_instance_of(::ApplicationSettings::UpdateService) do |instance|
              allow(instance).to receive(:member_promotion_management_feature_available?)
                                   .and_return(promotion_management_available)
            end
          end

          context 'with promotion management available' do
            it 'updates the setting' do
              put :update, params: { application_setting: settings }

              expect(ApplicationSetting.current.enable_member_promotion_management).to be(true)
            end
          end

          context 'with promotion management unavailable' do
            let(:promotion_management_available) { false }

            it 'does not update the setting' do
              put :update, params: { application_setting: settings }

              expect(ApplicationSetting.current.enable_member_promotion_management).to be(false)
            end
          end
        end

        context 'with new_user_signup_cap' do
          let(:settings) do
            { new_user_signups_cap: 100, seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP }
          end

          it 'updates the setting to user_cap' do
            attribute_names = settings.keys.map(&:to_s)

            expect { put :update, params: { application_setting: settings } }
              .to change { ApplicationSetting.current.reload.attributes.slice(*attribute_names) }
          end
        end
      end
    end

    context 'when updating password complexity settings' do
      let(:settings) do
        { password_number_required: true,
          password_symbol_required: true,
          password_uppercase_required: true,
          password_lowercase_required: true }
      end

      let(:license_feature) { :password_complexity }

      it_behaves_like 'settings for licensed features'
      it_behaves_like 'settings for registration features'
    end

    context 'when updating pypi packages request forwarding setting' do
      let(:settings) { { pypi_package_requests_forwarding: true } }
      let(:license_feature) { :package_forwarding }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating service_access_tokens_expiration_enforced setting' do
      let(:settings) { { service_access_tokens_expiration_enforced: false } }

      it 'updates settings' do
        put :update, params: { application_setting: settings }

        settings.each do |attribute, value|
          expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
        end
      end
    end

    context 'when updating allow_top_level_group_owners_to_create_service_accounts setting' do
      let(:settings) { { allow_top_level_group_owners_to_create_service_accounts: false } }

      it 'updates settings' do
        put :update, params: { application_setting: settings }

        settings.each do |attribute, value|
          expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
        end
      end
    end

    context 'when updating disable_invite_members settings' do
      let(:settings) { { disable_invite_members: true } }
      let(:license_feature) { :disable_invite_members }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating `git_two_factor_session_expiry` setting' do
      before do
        stub_feature_flags(two_factor_for_cli: true)
      end

      let(:settings) { { git_two_factor_session_expiry: 10 } }
      let(:license_feature) { :git_two_factor_enforcement }

      it_behaves_like 'settings for licensed features'
    end

    context 'when updating maintenance mode setting' do
      let(:settings) do
        {
          maintenance_mode: true,
          maintenance_mode_message: 'GitLab is in maintenance'
        }
      end

      let(:license_feature) { :geo }

      it_behaves_like 'settings for licensed features'
      it_behaves_like 'settings for registration features'
    end

    context 'with additional email footer' do
      let(:settings) { { email_additional_text: 'scary legal footer' } }
      let(:license_feature) { :email_additional_text }

      it_behaves_like 'settings for licensed features'
      it_behaves_like 'settings for registration features'
    end

    context 'with custom project templates settings' do
      let(:group) { create(:group) }
      let(:settings) { { custom_project_templates_group_id: group.id } }
      let(:license_feature) { :custom_project_templates }

      it_behaves_like 'settings for licensed features'
    end

    context 'with merge request approvers rules' do
      let(:settings) do
        {
          disable_overriding_approvers_per_merge_request: true,
          prevent_merge_requests_author_approval: true,
          prevent_merge_requests_committers_approval: true
        }
      end

      let(:license_feature) { :admin_merge_request_approvers_rules }

      it_behaves_like 'settings for licensed features'
    end

    context 'with globally allowed IPs' do
      let(:settings) { { globally_allowed_ips: '10.0.0.0/8, 192.168.1.0/24' } }
      let(:license_feature) { :group_ip_restriction }

      it_behaves_like 'settings for licensed features'
    end

    context 'with required instance ci template' do
      let(:settings) { { required_instance_ci_template: 'Auto-DevOps' } }
      let(:license_feature) { :required_ci_templates }

      it_behaves_like 'settings for licensed features'

      context 'when ApplicationSetting already has a required_instance_ci_template value' do
        before do
          ApplicationSetting.current.update!(required_instance_ci_template: 'Auto-DevOps')
        end

        context 'with a valid value' do
          let(:settings) { { required_instance_ci_template: 'Code-Quality' } }

          it_behaves_like 'settings for licensed features'
        end

        context 'with an empty value' do
          it 'sets required_instance_ci_template as nil' do
            stub_licensed_features(required_ci_templates: true)

            put :update, params: { application_setting: { required_instance_ci_template: '' } }

            expect(ApplicationSetting.current.required_instance_ci_template).to be_nil
          end
        end

        context 'without key' do
          it 'does not set required_instance_ci_template to nil' do
            put :update, params: { application_setting: {} }

            expect(ApplicationSetting.current.required_instance_ci_template).to eq 'Auto-DevOps'
          end
        end
      end
    end

    context 'with dependency scanning settings' do
      let(:license_feature) { :dependency_scanning }

      context 'when updating `dependency_scanning_sbom_scan_api_upload_limit`' do
        let(:settings) { { dependency_scanning_sbom_scan_api_upload_limit: 500 } }

        it_behaves_like 'settings for licensed features'
      end

      context 'when updating `dependency_scanning_sbom_scan_api_download_limit`' do
        let(:settings) { { dependency_scanning_sbom_scan_api_download_limit: 500 } }

        it_behaves_like 'settings for licensed features'
      end
    end

    context 'with secret detection settings' do
      let(:settings) { { secret_push_protection_available: true } }
      let(:license_feature) { :secret_push_protection }

      before do
        stub_licensed_features(license_feature => true)
      end

      it_behaves_like 'settings for licensed features'

      it 'updates secret_push_protection_available setting' do
        expect { put :update, params: { application_setting: settings } }
          .to change { ApplicationSetting.current.reload.attributes['secret_push_protection_available'] }
      end
    end

    it 'updates repository_size_limit' do
      put :update, params: { application_setting: { repository_size_limit: '100' } }

      expect(response).to redirect_to(general_admin_application_settings_path)
      expect(controller).to set_flash[:notice].to('Application settings saved successfully')
    end

    it 'does not accept negative repository_size_limit' do
      put :update, params: { application_setting: { repository_size_limit: '-100' } }

      expect(response).to render_template(:general)
      expect(assigns(:application_setting).errors[:repository_size_limit]).to be_present
    end

    it 'does not accept invalid repository_size_limit' do
      put :update, params: { application_setting: { repository_size_limit: 'one thousand' } }

      expect(response).to render_template(:general)
      expect(assigns(:application_setting).errors[:repository_size_limit]).to be_present
    end

    it 'does not accept empty repository_size_limit' do
      put :update, params: { application_setting: { repository_size_limit: '' } }

      expect(response).to render_template(:general)
      expect(assigns(:application_setting).errors[:repository_size_limit]).to be_present
    end

    it 'updates duo_workflows_default_image_registry' do
      put :update, params: { application_setting: { duo_workflows_default_image_registry: 'registry.example.com' } }

      expect(response).to redirect_to(general_admin_application_settings_path)
      expect(ApplicationSetting.current.duo_workflows_default_image_registry).to eq('registry.example.com')
    end

    it 'accepts blank duo_workflows_default_image_registry' do
      ApplicationSetting.current.update!(duo_workflows_default_image_registry: 'registry.example.com')

      put :update, params: { application_setting: { duo_workflows_default_image_registry: '' } }

      expect(response).to redirect_to(general_admin_application_settings_path)
      expect(ApplicationSetting.current.duo_workflows_default_image_registry).to be_nil
    end

    describe 'verify panel actions' do
      Admin::ApplicationSettingsController::EE_VALID_SETTING_PANELS
        .excluding('namespace_storage').each do |valid_action|
          it_behaves_like 'renders correct panels' do
            let(:action) { valid_action }
          end
        end

      it_behaves_like 'renders correct panels' do
        before do
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        let(:action) { 'namespace_storage' }
      end
    end

    context 'with maintenance mode settings' do
      let(:message) { 'Maintenance mode is on.' }

      before do
        stub_licensed_features(geo: true)
      end

      it "updates maintenance_mode setting" do
        put :update, params: { application_setting: { maintenance_mode: true } }

        expect(response).to redirect_to(general_admin_application_settings_path)
        expect(ApplicationSetting.current.maintenance_mode).to be_truthy
      end

      it "updates maintenance_mode_message setting" do
        put :update, params: { application_setting: { maintenance_mode_message: message } }

        expect(response).to redirect_to(general_admin_application_settings_path)
        expect(ApplicationSetting.current.maintenance_mode_message).to eq(message)
      end

      context 'when update disables maintenance mode' do
        it 'removes maintenance_mode_message setting' do
          put :update, params: { application_setting: { maintenance_mode: false } }

          expect(response).to redirect_to(general_admin_application_settings_path)
          expect(ApplicationSetting.current.maintenance_mode).to be_falsy
          expect(ApplicationSetting.current.maintenance_mode_message).to be_nil
        end
      end

      context 'when update does not disable maintenance mode' do
        it 'does not remove maintenance_mode_message' do
          set_maintenance_mode(message)

          put :update, params: { application_setting: {} }

          expect(ApplicationSetting.current.maintenance_mode_message).to eq(message)
        end
      end

      context 'when updating maintenance_mode_message with empty string' do
        it 'removes maintenance_mode_message' do
          set_maintenance_mode(message)

          put :update, params: { application_setting: { maintenance_mode_message: '' } }

          expect(ApplicationSetting.current.maintenance_mode_message).to be_nil
        end
      end
    end

    context 'with private profile disabled for users' do
      let(:settings) { { make_profile_private: false } }
      let(:license_feature) { :disable_private_profiles }

      it_behaves_like 'settings for licensed features'
    end

    context 'when setting disabled_direct_code_suggestions' do
      it 'does not update settings when duo pro is not available' do
        expect { put :update, params: { application_setting: { disabled_direct_code_suggestions: true } } }
          .not_to change { ApplicationSetting.current.reload.disabled_direct_code_suggestions }
      end

      it 'updates settings when duo pro is available' do
        allow(GitlabSubscriptions::AddOnPurchase)
          .to receive(:exists_for_unit_primitive?)
          .and_return(true)

        put :update, params: { application_setting: { disabled_direct_code_suggestions: true } }

        expect(ApplicationSetting.current.disabled_direct_code_suggestions).to be_truthy
      end
    end

    context 'when updating auto_duo_code_review_enabled setting' do
      let(:settings) { { auto_duo_code_review_enabled: true } }
      let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
      let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
      let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

      before do
        ApplicationSetting.current.update!(duo_features_enabled: true)
      end

      context 'when duo features are disabled' do
        before do
          ApplicationSetting.current.update!(duo_features_enabled: false)
        end

        it 'does not update the setting when not available' do
          expect { put :update, params: { application_setting: settings } }
            .not_to change { ApplicationSetting.current.reload.auto_duo_code_review_enabled }

          expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_falsey
        end
      end

      context 'when duo features are enabled' do
        context 'without any duo add-on' do
          it 'does not update the setting when not available' do
            expect { put :update, params: { application_setting: settings } }
              .not_to change { ApplicationSetting.current.reload.auto_duo_code_review_enabled }

            expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_falsey
          end
        end

        context 'with duo_enterprise add-on' do
          before do
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
          end

          it 'updates the setting and it is available' do
            put :update, params: { application_setting: settings }
            expect(ApplicationSetting.current.auto_duo_code_review_enabled).to be_truthy
            expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_truthy
          end

          it 'can disable the setting' do
            ApplicationSetting.current.update!(auto_duo_code_review_enabled: true)

            put :update, params: { application_setting: { auto_duo_code_review_enabled: false } }

            expect(ApplicationSetting.current.auto_duo_code_review_enabled).to be_falsey
            expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_truthy
          end
        end

        context 'with duo_core or duo_pro add-ons' do
          where(:add_on_type, :add_on) do
            [
              ['duo_core', ref(:duo_core_add_on)],
              ['duo_pro',  ref(:duo_pro_add_on)]
            ]
          end

          with_them do
            before do
              create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on)
            end

            it "does not update the setting with #{params[:add_on_type]} (not supported at application level yet)" do
              expect { put :update, params: { application_setting: settings } }
                .not_to change { ApplicationSetting.current.reload.auto_duo_code_review_enabled }

              expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_falsey
            end
          end
        end

        context 'with duo_foundational_flows_enabled set' do
          before do
            ApplicationSetting.current.update!(duo_foundational_flows_enabled: true)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)
          end

          it 'does not enable duo_core support (setting not exposed in UI yet)' do
            expect { put :update, params: { application_setting: settings } }
              .not_to change { ApplicationSetting.current.reload.auto_duo_code_review_enabled }

            expect(ApplicationSetting.current.auto_duo_code_review_settings_available?).to be_falsey
          end
        end
      end
    end

    context 'when updating built_in_project_templates_enabled setting' do
      before do
        stub_licensed_features(built_in_project_templates_enabled: true)
      end

      it 'updates built_in_project_templates_enabled setting' do
        put :update, params: { application_setting: { built_in_project_templates_enabled: false } }

        expect(response).to redirect_to(general_admin_application_settings_path)
        expect(ApplicationSetting.current.built_in_project_templates_enabled).to be(false)
      end

      it 'updates lock_built_in_project_templates_enabled setting' do
        put :update, params: { application_setting: { lock_built_in_project_templates_enabled: true } }

        expect(response).to redirect_to(general_admin_application_settings_path)
        expect(ApplicationSetting.current.lock_built_in_project_templates_enabled).to be(true)
      end

      context 'when the feature is unlicensed' do
        before do
          stub_licensed_features(built_in_project_templates_enabled: false)
        end

        it 'does not update built_in_project_templates_enabled setting' do
          expect { put :update, params: { application_setting: { built_in_project_templates_enabled: false } } }
            .not_to change { ApplicationSetting.current.reload.built_in_project_templates_enabled }.from(true)
        end

        it 'does not update lock_built_in_project_templates_enabled setting' do
          expect { put :update, params: { application_setting: { lock_built_in_project_templates_enabled: true } } }
            .not_to change { ApplicationSetting.current.reload.lock_built_in_project_templates_enabled }.from(false)
        end
      end
    end

    context 'when updating dependency_firewall_enabled setting', feature_category: :dependency_firewall do
      before do
        stub_licensed_features(dependency_firewall: true)
      end

      it 'updates the setting on a self-managed instance' do
        expect { put :update, params: { application_setting: { dependency_firewall_enabled: true } } }
          .to change { ApplicationSetting.current.reload.dependency_firewall_enabled }.from(false).to(true)
      end

      context 'when the feature is unavailable' do
        before do
          stub_licensed_features(dependency_firewall: false)
        end

        it 'does not permit the setting' do
          expect { put :update, params: { application_setting: { dependency_firewall_enabled: true } } }
            .not_to change { ApplicationSetting.current.reload.dependency_firewall_enabled }.from(false)
        end
      end
    end
  end

  describe '#search', feature_category: :global_search do
    before do
      sign_in(admin)
      request.env['HTTP_REFERER'] = search_admin_application_settings_path
    end

    context 'with check search version is compatability' do
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:helper, freeze: false) { ::Search::Elastic::Helper.default }

      before do
        allow(helper).to receive(:ping?).and_return(true)
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      end

      it 'does not alert when version is compatible' do
        allow(helper).to receive(:supported_version?).and_return(true)

        get :search
        expect(assigns[:search_error_if_version_incompatible]).to be_falsey
      end

      it 'does not set search_error_if_version_incompatible when ES is not reachable' do
        allow(helper).to receive(:ping?).and_return(false)

        get :search
        expect(assigns[:search_error_if_version_incompatible]).to be_nil
      end

      it 'alerts when version is incompatible' do
        allow(::Search::Elastic::Helper.default).to receive(:supported_version?).and_return(false)

        get :search
        expect(assigns[:search_error_if_version_incompatible]).to be_truthy
      end
    end

    context 'with warning if not using index aliases' do
      let_it_be(:helper, freeze: false) { ::Search::Elastic::Helper.default }

      before do
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
        allow(helper).to receive_messages(index_exists?: true, ping?: true)
      end

      it 'warns when NOT using index aliases' do
        allow(helper).to receive(:alias_missing?).and_return true
        get :search
        expect(assigns[:elasticsearch_warn_if_not_using_aliases]).to be_truthy
      end

      it 'does NOT warn when using index aliases' do
        allow(helper).to receive(:alias_missing?).and_return false
        get :search
        expect(assigns[:elasticsearch_warn_if_not_using_aliases]).to be_falsy
      end

      it 'does NOT blow up if ping? returns false' do
        allow(helper).to receive(:ping?).and_return(false)
        get :search
        expect(assigns[:elasticsearch_warn_if_not_using_aliases]).to be_falsy
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does NOT blow up if elasticsearch is unreachable' do
        allow(helper).to receive(:alias_missing?).and_raise(::Elasticsearch::Transport::Transport::ServerError, 'boom')
        get :search
        expect(assigns[:elasticsearch_warn_if_not_using_aliases]).to be_falsy
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'does NOT warn when default index does not exist' do
        allow(helper).to receive_messages(alias_missing?: true, index_exists?: false)
        get :search
        expect(assigns[:elasticsearch_warn_if_not_using_aliases]).to be_falsey
      end
    end

    context 'with warning outdated code search mappings' do
      let_it_be(:helper, freeze: false) { ::Search::Elastic::Helper.default }

      before do
        allow(helper).to receive(:ping?).and_return(true)
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      end

      it 'warns when outdated code mappings are used' do
        allow(helper).to receive(:get_meta).and_return('created_by' => '15.4.9')
        get :search
        expect(assigns[:search_outdated_code_analyzer_detected]).to be_truthy
      end

      it 'warns when meta field is not present' do
        allow(helper).to receive(:get_meta).and_return(nil)
        get :search
        expect(assigns[:search_outdated_code_analyzer_detected]).to be_truthy
      end

      it 'does NOT warn when using new mappings' do
        allow(helper).to receive(:get_meta).and_return('created_by' => '15.5.0')
        get :search
        expect(assigns[:search_outdated_code_analyzer_detected]).to be_falsey
      end

      it 'does NOT blow up if elasticsearch is unreachable' do
        allow(helper).to receive(:get_meta).and_raise(::Elasticsearch::Transport::Transport::ServerError, 'boom')
        get :search
        expect(assigns[:search_outdated_code_analyzer_detected]).to be_falsey
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when alerting for pending obsolete migrations' do
      let_it_be(:helper, freeze: false) { ::Search::Elastic::Helper.default }

      before do
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      end

      context 'when elasticsearch is reachable' do
        # `freeze: false` is required in this spec: one or more `let_it_be` subjects
        # cannot be frozen by default (deep_freeze traversal failure, a non-AR
        # subject, or an in-memory mutation that survives reload/refind). Do not
        # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
        # (see gitlab-org/gitlab#602925).
        let_it_be(:migration_1, freeze: false) { Elastic::MigrationRecord.new(name: '1', version: Time.now.to_i, filename: nil) }
        let_it_be(:migration_2, freeze: false) { Elastic::MigrationRecord.new(name: '2', version: Time.now.to_i, filename: nil) }

        before do
          allow(migration_1).to receive(:load_migration).and_return(Class.new)
          allow(migration_2).to receive(:load_migration).and_return(Class.new)
          allow(Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration_1, migration_2])
          allow(helper).to receive(:ping?).and_return(true)
        end

        it 'alerts when there are pending obsolete migrations' do
          allow(migration_1).to receive(:obsolete?).and_return(true)
          allow(migration_2).to receive(:obsolete?).and_return(false)

          get :search
          expect(assigns[:elasticsearch_pending_obsolete_migrations]).to eq([migration_1])
          expect(assigns[:elasticsearch_warn_if_obsolete_migrations]).to be_truthy
        end

        it 'does not alert when there are pending non-obsolete migrations' do
          allow(migration_1).to receive(:obsolete?).and_return(false)
          allow(migration_2).to receive(:obsolete?).and_return(false)

          get :search
          expect(assigns[:elasticsearch_pending_obsolete_migrations]).to eq([])
        end
      end

      context 'when elasticsearch is unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'does not alert' do
          get :search
          expect(assigns[:elasticsearch_warn_if_obsolete_migrations]).to be_falsey
        end
      end
    end

    context 'with advanced search settings' do
      it 'updates the advanced search settings' do
        settings = {
          elasticsearch_url: URI.parse('http://my-elastic.search:9200'),
          elasticsearch_indexing: false,
          elasticsearch_aws: true,
          elasticsearch_aws_access_key: 'elasticsearch_aws_access_key',
          elasticsearch_aws_secret_access_key: 'elasticsearch_aws_secret_access_key',
          elasticsearch_aws_region: 'elasticsearch_aws_region',
          elasticsearch_search: true
        }

        patch :search, params: { application_setting: settings }

        expect(response).to redirect_to(search_admin_application_settings_path)
        settings.except(:elasticsearch_url).each do |setting, value|
          expect(ApplicationSetting.current.public_send(setting)).to eq(value)
        end
        expect(ApplicationSetting.current.elasticsearch_url).to contain_exactly(settings[:elasticsearch_url])
      end
    end

    context 'when zero-downtime elasticsearch reindexing' do
      render_views

      let!(:task) { create(:elastic_reindexing_task) }

      it 'assigns last elasticsearch reindexing task' do
        get :search

        expect(assigns(:last_elasticsearch_reindexing_task)).to eq(task)
        expect(response.body).to have_selector('[role="alert"]', text: /Status: starting/)
      end
    end

    context 'when elasticsearch_aws_secret_access_key setting is blank' do
      let(:settings) do
        {
          elasticsearch_aws_access_key: 'elasticsearch_aws_access_key',
          elasticsearch_aws_secret_access_key: ''
        }
      end

      it 'does not update the elasticsearch_aws_secret_access_key setting' do
        expect { patch :search, params: { application_setting: settings } }
          .not_to change { ApplicationSetting.current.reload.elasticsearch_aws_secret_access_key }
      end
    end

    describe 'semantic search settings', :aggregate_failures do
      where(:semantic_search_available) { [false, true] }

      with_them do
        before do
          allow(::Ai::ActiveContext).to receive(:semantic_search_available?).and_return(semantic_search_available)
        end

        it 'assigns semantic_search_available' do
          get :search

          expect(response).to have_gitlab_http_status(:ok)
          expect(assigns(:semantic_search_available)).to be(semantic_search_available)
        end
      end
    end
  end

  describe 'GET #seat_link_payload', feature_category: :plan_provisioning do
    context 'when a non-admin user attempts a request' do
      before do
        sign_in(create(:user))
      end

      it 'returns a 404 response' do
        get :seat_link_payload, format: :html

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when an admin user attempts a request' do
      let_it_be(:yesterday) { Time.current.utc.yesterday }
      let_it_be(:max_count) { 15 }
      let_it_be(:current_count) { 10 }

      around do |example|
        freeze_time { example.run }
      end

      before_all do
        create(:historical_data, recorded_at: yesterday - 1.day, active_user_count: max_count)
        create(:historical_data, recorded_at: yesterday, active_user_count: current_count)
      end

      before do
        sign_in(admin)
      end

      it 'returns HTML data', :aggregate_failures do
        get :seat_link_payload, format: :html

        expect(response).to have_gitlab_http_status(:ok)

        body = response.body
        expect(body).to start_with('<span id="LC1" class="line" data-lang="json">')
        expect(body).to include('<span class="nl">"license_key"</span>')
        expect(body).to include("<span class=\"s2\">\"#{yesterday.iso8601}\"</span>")
        expect(body).to include("<span class=\"mi\">#{max_count}</span>")
        expect(body).to include("<span class=\"mi\">#{current_count}</span>")
      end

      it 'returns JSON data', :aggregate_failures do
        get :seat_link_payload, format: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to eq(Gitlab::SeatLinkData.new.to_json)
      end
    end
  end

  describe 'GET #namespace_storage', feature_category: :consumables_cost_management do
    before do
      sign_in(admin)
    end

    it 'returns not found when gitlab_com_subscriptions are not available' do
      get :namespace_storage

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns ok when gitlab_com_subscriptions are available' do
      stub_saas_features(gitlab_com_subscriptions: true)

      get :namespace_storage

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'PUT #namespace_storage', feature_category: :consumables_cost_management do
    before do
      sign_in(admin)
    end

    it 'returns not found when namespace plans are not checked' do
      put :namespace_storage

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  def set_maintenance_mode(message)
    ApplicationSetting.current.update!(
      maintenance_mode: true,
      maintenance_mode_message: message
    )
  end
end
