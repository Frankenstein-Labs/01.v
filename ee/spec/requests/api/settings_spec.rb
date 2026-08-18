# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Settings, 'EE Settings', :aggregate_failures, feature_category: :shared do
  using RSpec::Parameterized::TableSyntax
  include StubENV

  let(:user) { create(:user) }
  let(:admin) { create(:admin) }
  let(:project) { create(:project) }
  let(:path) { "/application/settings" }

  let_it_be(:default_organization) { create(:organization) }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  it_behaves_like 'GET request permissions for admin mode'

  describe 'GET /application/settings' do
    it "returns application settings" do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an Hash
      expect(json_response['receptive_cluster_agents_enabled']).to be(false)
    end
  end

  describe "PUT /application/settings" do
    it_behaves_like 'PUT request permissions for admin mode' do
      let(:params) { { file_template_project_id: project.id } }
    end

    it 'sets EE specific settings' do
      stub_licensed_features(
        custom_file_templates: true,
        cluster_receptive_agents: true
      )

      put api(path, admin, admin_mode: true),
        params: {
          file_template_project_id: project.id,
          package_metadata_purl_types: [1],
          receptive_cluster_agents_enabled: true
        }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['file_template_project_id']).to eq(project.id)
      expect(json_response['package_metadata_purl_types']).to eq([1])
      expect(json_response['receptive_cluster_agents_enabled']).to be(true)
    end

    context 'service access tokens expiration enforced setting' do
      let(:params) { { file_template_project_id: project.id, service_access_tokens_expiration_enforced: false } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets setting' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['service_access_tokens_expiration_enforced']).to be(false)
      end
    end

    context 'allow top_level group owners to create service accounts' do
      let(:params) { { file_template_project_id: project.id, allow_top_level_group_owners_to_create_service_accounts: true } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets setting' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['allow_top_level_group_owners_to_create_service_accounts']).to be(true)
      end
    end

    context 'use_nats_for_audit_streaming setting' do
      let(:params) { { use_nats_for_audit_streaming: true } }

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets the setting' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['use_nats_for_audit_streaming']).to be(true)
        expect(ApplicationSetting.current.use_nats_for_audit_streaming).to be(true)
      end
    end

    context 'allow enforce_pipl_compliance in application settings' do
      let(:params) { { enforce_pipl_compliance: true } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets setting when licensed feature is available' do
        stub_saas_features(pipl_compliance: true)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['enforce_pipl_compliance']).to be(true)
      end

      it 'does not set the value when licensed feature is not available' do
        params[:enforce_pipl_compliance] = false
        stub_saas_features(pipl_compliance: false)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['enforce_pipl_compliance']).to be(false)
      end
    end

    context 'with duo_features_enabled settings' do
      let(:params) { { duo_features_enabled: false, lock_duo_features_enabled: true } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets setting when licensed feature is there' do
        stub_licensed_features(ai_features: true)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['duo_features_enabled']).to be(false)
        expect(json_response['lock_duo_features_enabled']).to be(true)
      end

      it 'does not set the value when licensed feature is not there' do
        stub_licensed_features(ai_features: false)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['duo_features_enabled']).to be(true)
        expect(json_response['lock_duo_features_enabled']).to be(false)
      end
    end

    context 'cascade duo settings on update' do
      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      before do
        stub_licensed_features(ai_features: true)
      end

      context 'when duo_features_enabled and lock_duo_features_enabled both change' do
        let(:params) { { duo_features_enabled: false, lock_duo_features_enabled: true } }

        it 'enqueues AppConfig::CascadeDuoSettingsWorker with the changed settings' do
          expect(AppConfig::CascadeDuoSettingsWorker)
            .to receive(:perform_async)
            .with(hash_including('duo_features_enabled' => false, 'lock_duo_features_enabled' => true))

          api_request
        end
      end

      context 'when only lock_duo_features_enabled changes' do
        let(:params) { { lock_duo_features_enabled: true } }

        it 'enqueues AppConfig::CascadeDuoSettingsWorker with lock_duo_features_enabled' do
          expect(AppConfig::CascadeDuoSettingsWorker)
            .to receive(:perform_async)
            .with(hash_including('lock_duo_features_enabled' => true))

          api_request
        end
      end
    end

    context 'GitLab.com restrictions for duo settings' do
      let(:params) { { duo_features_enabled: false, duo_remote_flows_enabled: false, duo_workflows_default_image_registry: 'registry.example.com' } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      context 'when on GitLab.com', :saas do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'prevents updating duo_features_enabled, duo_remote_flows_enabled, and duo_workflows_default_image_registry' do
          # Set initial values using update_columns to bypass SaaS validation
          ApplicationSetting.find_or_create_without_cache.update_columns(
            duo_features_enabled: true,
            duo_remote_flows_enabled: true,
            duo_workflows_default_image_registry: 'registry.gitlab.com'
          )

          api_request

          expect(response).to have_gitlab_http_status(:ok)
          # Values should remain unchanged
          expect(json_response['duo_features_enabled']).to be(true)
          expect(json_response['duo_remote_flows_enabled']).to be(true)
          expect(json_response['duo_workflows_default_image_registry']).to eq('registry.gitlab.com')
        end

        it 'still allows reading the settings' do
          ApplicationSetting.find_or_create_without_cache.update_columns(
            duo_features_enabled: false,
            duo_remote_flows_enabled: false,
            duo_workflows_default_image_registry: 'registry.gitlab.com'
          )

          get api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['duo_features_enabled']).to be(false)
          expect(json_response['duo_remote_flows_enabled']).to be(false)
          expect(json_response['duo_workflows_default_image_registry']).to eq('registry.gitlab.com')
        end
      end

      context 'when not on GitLab.com' do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'allows updating duo_features_enabled, duo_remote_flows_enabled, and duo_workflows_default_image_registry' do
          # Set initial values
          ApplicationSetting.find_or_create_without_cache.update_columns(
            duo_features_enabled: true,
            duo_remote_flows_enabled: true,
            duo_workflows_default_image_registry: nil
          )

          api_request

          expect(response).to have_gitlab_http_status(:ok)
          # Values should be updated
          expect(json_response['duo_features_enabled']).to be(false)
          expect(json_response['duo_remote_flows_enabled']).to be(false)
          expect(json_response['duo_workflows_default_image_registry']).to eq('registry.example.com')
        end
      end
    end

    context 'with disabled_direct_code_suggestions settings', :with_cloud_connector do
      let(:params) { { disabled_direct_code_suggestions: true } }

      it_behaves_like 'PUT request permissions for admin mode'

      subject(:api_request) do
        put api(path, admin, admin_mode: true), params: params
      end

      it 'sets setting when code suggestions are available' do
        allow(GitlabSubscriptions::AddOnPurchase)
          .to receive(:exists_for_unit_primitive?)
          .with(:complete_code, :instance)
          .and_return(true)

        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['disabled_direct_code_suggestions']).to be(true)
      end

      it 'does not set the value when code suggestions are not available' do
        api_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['disabled_direct_code_suggestions']).to be_nil
      end
    end

    context 'elasticsearch settings' do
      it 'limits namespaces and projects properly' do
        namespace_ids = create_list(:namespace, 2).map(&:id)
        project_ids = create_list(:project, 2).map(&:id)

        put api('/application/settings', admin, admin_mode: true),
          params: {
            elasticsearch_limit_indexing: true,
            elasticsearch_project_ids: project_ids.join(','),
            elasticsearch_namespace_ids: namespace_ids.join(',')
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['elasticsearch_limit_indexing']).to be(true)
        expect(json_response['elasticsearch_project_ids']).to eq(project_ids)
        expect(json_response['elasticsearch_namespace_ids']).to eq(namespace_ids)
        expect(ElasticsearchIndexedNamespace.count).to eq(2)
        expect(ElasticsearchIndexedProject.count).to eq(2)
      end

      it 'removes namespaces and projects properly' do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
        create(:elasticsearch_indexed_namespace).namespace.id
        create(:elasticsearch_indexed_project).project.id

        put api('/application/settings', admin, admin_mode: true),
          params: {
            elasticsearch_namespace_ids: []
          }.to_json,
          headers: {
            'CONTENT_TYPE' => 'application/json'
          }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['elasticsearch_namespace_ids']).to eq([])
        expect(ElasticsearchIndexedNamespace.count).to eq(0)
        expect(ElasticsearchIndexedProject.count).to eq(1)
      end

      context 'with elasticsearch_index_settings' do
        let_it_be(:_index_setting) do
          create(:elastic_index_setting, alias_name: 'api-test-index', number_of_shards: 5, number_of_replicas: 1)
        end

        subject(:get_application_setting_response) { get api('/application/settings', admin, admin_mode: true) }

        before do
          stub_licensed_features(elastic_search: true)
        end

        it 'returns elasticsearch_index_settings in response' do
          get_application_setting_response

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['elasticsearch_index_settings']).to include(
            'alias_name' => 'api-test-index',
            'number_of_shards' => 5,
            'number_of_replicas' => 1
          )
        end

        context 'when license feature :elastic_search is not available' do
          before do
            stub_licensed_features(elastic_search: false)
          end

          it 'does not return elasticsearch_index_settings in response' do
            get_application_setting_response

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).not_to have_key('elasticsearch_index_settings')
          end
        end
      end
    end

    context 'secret_detection_token_revocation_enabled is true' do
      context 'secret_detection_token_revocation_url value is present' do
        let(:revocation_url) { 'https://example.com/secret_detection_token_revocation' }
        let(:revocation_token_types_url) { 'https://example.com/secret_detection_revocation_token_types' }
        let(:revocation_token) { 'AKDD345$%^^' }

        it 'updates secret_detection_token_revocation_url' do
          put api('/application/settings', admin, admin_mode: true),
            params: {
              secret_detection_token_revocation_enabled: true,
              secret_detection_token_revocation_url: revocation_url,
              secret_detection_token_revocation_token: revocation_token,
              secret_detection_revocation_token_types_url: revocation_token_types_url
            }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['secret_detection_token_revocation_enabled']).to be(true)
          expect(json_response['secret_detection_token_revocation_url']).to eq(revocation_url)
          expect(json_response['secret_detection_revocation_token_types_url']).to eq(revocation_token_types_url)
          expect(json_response['secret_detection_token_revocation_token']).to eq(revocation_token)
        end
      end

      context 'missing secret_detection_token_revocation_url value' do
        it 'returns a blank parameter error message' do
          put api('/application/settings', admin, admin_mode: true), params: { secret_detection_token_revocation_enabled: true }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to include('secret_detection_token_revocation_url is missing, secret_detection_revocation_token_types_url is missing')
        end
      end
    end

    context 'with billable member management' do
      context 'when the feature is not available' do
        it 'does not change enable_member_promotion_management to true' do
          put api('/application/settings', admin, admin_mode: true),
            params: { enable_member_promotion_management: true }

          expect(json_response['enable_member_promotion_management']).to be(false)
        end
      end

      context 'when the feature is available' do
        before do
          allow_next_instance_of(::ApplicationSettings::UpdateService) do |instance|
            allow(instance).to receive(:member_promotion_management_feature_available?).and_return(true)
          end
        end

        where(param_value: [true, false])

        with_them do
          it 'changes enable_member_promotion_management' do
            ::Gitlab::CurrentSettings.update!(enable_member_promotion_management: !param_value)

            put api('/application/settings', admin, admin_mode: true),
              params: { enable_member_promotion_management: param_value }

            expect(json_response['enable_member_promotion_management']).to eq(param_value)
          end
        end

        context 'when there are pending promotions' do
          before do
            allow_next_instance_of(
              ::GitlabSubscriptions::MemberManagement::SelfManaged::MaxAccessLevelMemberApprovalsFinder
            ) do |instance|
              allow(instance).to receive(:execute).and_return(['mock_non_empty_return'])
            end
          end

          it 'does not change enable_member_promotion_management to false' do
            ::Gitlab::CurrentSettings.update!(enable_member_promotion_management: true)

            put api('/application/settings', admin, admin_mode: true),
              params: { enable_member_promotion_management: false }

            expect(json_response['enable_member_promotion_management']).to be(true)
          end
        end
      end
    end
  end

  shared_examples 'settings for licensed features' do
    let(:attribute_names) { settings.keys.map(&:to_s) }

    before do
      # Make sure the settings exist before the specs
      get api(path, admin, admin_mode: true)
    end

    context 'when the feature is not available' do
      before do
        stub_licensed_features(feature => false)
      end

      it 'hides the attributes in the API' do
        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        attribute_names.each do |attribute|
          expect(json_response.keys).not_to include(attribute)
        end
      end

      it 'does not update application settings' do
        put api(path, admin, admin_mode: true), params: settings

        expect(response).to have_gitlab_http_status(:ok)

        expect { put api(path, admin, admin_mode: true), params: settings }
          .not_to change { ApplicationSetting.current.reload.attributes.slice(*attribute_names) }
      end
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(feature => true)
      end

      it 'includes the attributes in the API' do
        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        attribute_names.each do |attribute|
          expect(json_response.keys).to include(attribute)
        end
      end

      it 'allows updating the settings' do
        put api(path, admin, admin_mode: true), params: settings
        expect(response).to have_gitlab_http_status(:ok)

        settings.each do |attribute, value|
          expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
        end
      end
    end
  end

  context 'mirroring settings' do
    let(:settings) { { mirror_max_capacity: 15 } }
    let(:feature) { :repository_mirrors }

    it_behaves_like 'settings for licensed features'
  end

  context 'secret_push_protection_enabled' do
    let(:settings) { { secret_push_protection_available: true } }
    let(:feature) { :secret_push_protection }

    it_behaves_like 'settings for licensed features'
  end

  context 'dependency scanning sbom scan api endpoint limit' do
    let(:settings) do
      {
        dependency_scanning_sbom_scan_api_download_limit: 500,
        dependency_scanning_sbom_scan_api_upload_limit: 500
      }
    end

    let(:feature) { :dependency_scanning }

    it_behaves_like 'settings for licensed features'
  end

  context 'custom email footer' do
    let(:settings) { { email_additional_text: 'this is a scary legal footer' } }
    let(:feature) { :email_additional_text }

    it_behaves_like 'settings for licensed features'
  end

  context 'git_two_factor_session_expiry setting' do
    before do
      stub_feature_flags(two_factor_for_cli: true)
    end

    let(:settings) { { git_two_factor_session_expiry: 10 } }
    let(:feature) { :git_two_factor_enforcement }

    it_behaves_like 'settings for licensed features'
  end

  context 'default project deletion protection' do
    let(:settings) { { default_project_deletion_protection: true } }
    let(:feature) { :default_project_deletion_protection }

    it_behaves_like 'settings for licensed features'
  end

  context 'group_owners_can_manage_default_branch_protection setting' do
    let(:settings) { { group_owners_can_manage_default_branch_protection: false } }
    let(:feature) { :default_branch_protection_restriction_in_groups }

    it_behaves_like 'settings for licensed features'
  end

  context 'custom file template project' do
    let(:settings) { { file_template_project_id: project.id } }
    let(:feature) { :custom_file_templates }

    it_behaves_like 'settings for licensed features'
  end

  context 'updating name disabled for users' do
    let(:settings) { { updating_name_disabled_for_users: true } }
    let(:feature) { :disable_name_update_for_users }

    it_behaves_like 'settings for licensed features'
  end

  context 'merge request approvers rules' do
    let(:settings) do
      {
        disable_overriding_approvers_per_merge_request: true,
        prevent_merge_requests_author_approval: true,
        prevent_merge_requests_committers_approval: true
      }
    end

    let(:feature) { :admin_merge_request_approvers_rules }

    it_behaves_like 'settings for licensed features'
  end

  context 'updating npm packages request forwarding' do
    let(:settings) { { npm_package_requests_forwarding: true } }
    let(:feature) { :package_forwarding }

    it_behaves_like 'settings for licensed features'
  end

  context 'updating rubygems packages request forwarding' do
    let(:settings) { { rubygems_package_requests_forwarding: true } }
    let(:feature) { :package_forwarding }

    it_behaves_like 'settings for licensed features'
  end

  context 'updating virtual registries endpoints api limit' do
    let(:settings) { { virtual_registries_endpoints_api_limit: 500 } }
    let(:feature) { :packages_virtual_registry }

    it_behaves_like 'settings for licensed features'
  end

  context 'maintenance mode' do
    let(:settings) do
      {
        maintenance_mode: true,
        maintenance_mode_message: 'GitLab is in maintenance'
      }
    end

    let(:feature) { :geo }

    it_behaves_like 'settings for licensed features'

    context 'when geo feature is disabled' do
      let(:attribute_names) { settings.keys.map(&:to_s) }

      context "with registration features disabled" do
        before do
          stub_application_setting(usage_ping_features_enabled: false)
        end

        it 'hides the attributes in the API' do
          get api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          attribute_names.each do |attribute|
            expect(json_response.keys).not_to include(attribute)
          end
        end

        it 'does not update application settings' do
          put api(path, admin, admin_mode: true), params: settings

          expect(response).to have_gitlab_http_status(:ok)

          expect { put api(path, admin, admin_mode: true), params: settings }
            .not_to change { ApplicationSetting.current.reload.attributes.slice(*attribute_names) }
        end
      end

      context "with registration features enabled" do
        before do
          stub_application_setting(usage_ping_features_enabled: true)
        end

        it 'includes the attributes in the API' do
          get api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          attribute_names.each do |attribute|
            expect(json_response.keys).to include(attribute)
          end
        end

        it 'allows updating the settings' do
          put api(path, admin, admin_mode: true), params: settings
          expect(response).to have_gitlab_http_status(:ok)

          settings.each do |attribute, value|
            expect(ApplicationSetting.current.public_send(attribute)).to eq(value)
          end
        end
      end
    end
  end

  context 'password complexity settings' do
    let(:settings) do
      {
        password_number_required: true,
        password_symbol_required: true,
        password_uppercase_required: true,
        password_lowercase_required: true
      }
    end

    let(:feature) { :password_complexity }

    it_behaves_like 'settings for licensed features'
  end

  context 'git abuse rate limit settings', feature_category: :insider_threat do
    let(:user) { create(:user) }

    let(:settings) do
      {
        max_number_of_repository_downloads: 5,
        max_number_of_repository_downloads_within_time_period: 60,
        git_rate_limit_users_allowlist: [user.username],
        git_rate_limit_users_alertlist: [user.id],
        auto_ban_user_on_excessive_projects_download: true
      }
    end

    let(:feature) { :git_abuse_rate_limit }

    it_behaves_like 'settings for licensed features'
  end

  context 'disable personal access tokens setting' do
    let(:settings) { { disable_personal_access_tokens: false } }
    let(:feature) { :disable_personal_access_tokens }

    it_behaves_like 'settings for licensed features'
  end

  context 'delete unconfirmed users setting' do
    let(:feature) { :delete_unconfirmed_users }
    let(:settings) do
      {
        delete_unconfirmed_users: true,
        unconfirmed_users_delete_after_days: 30
      }
    end

    before do
      # email confirmation cannot be `off` if `delete_unconfirmed_users` is true
      stub_application_setting_enum('email_confirmation_setting', 'soft')
    end

    it_behaves_like 'settings for licensed features'
  end

  describe 'auto_duo_code_review_enabled' do
    using RSpec::Parameterized::TableSyntax

    let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }
    let(:application_setting) { create(:application_setting) }

    context 'with duo_enterprise add-on' do
      let(:params) { { auto_duo_code_review_enabled: true } }

      before do
        stub_ee_application_setting(duo_features_enabled: true)
        create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
      end

      it 'allows setting auto_duo_code_review_enabled' do
        put api('/application/settings', admin, admin_mode: true), params: params
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['auto_duo_code_review_enabled']).to be(true)
      end

      it 'allows disabling auto_duo_code_review_enabled' do
        put api('/application/settings', admin, admin_mode: true), params: { auto_duo_code_review_enabled: false }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['auto_duo_code_review_enabled']).to be(false)
      end
    end

    context 'with duo_core or duo_pro add-ons' do
      let(:params) { { auto_duo_code_review_enabled: true } }

      where(:add_on_type, :add_on) do
        [
          ['duo_core', ref(:duo_core_add_on)],
          ['duo_pro',  ref(:duo_pro_add_on)]
        ]
      end

      with_them do
        before do
          stub_ee_application_setting(duo_features_enabled: true)
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on)
        end

        it "does not allow setting auto_duo_code_review_enabled with #{params[:add_on_type]} (not supported at application level yet)" do
          put api('/application/settings', admin, admin_mode: true), params: params
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['auto_duo_code_review_enabled']).to be_nil
        end
      end
    end

    context 'with duo_foundational_flows_enabled set' do
      let(:params) { { auto_duo_code_review_enabled: true } }

      where(:add_on_type, :add_on) do
        [
          ['duo_core', ref(:duo_core_add_on)],
          ['duo_pro',  ref(:duo_pro_add_on)]
        ]
      end

      with_them do
        before do
          stub_ee_application_setting(duo_features_enabled: true)
          ApplicationSetting.current.update!(duo_foundational_flows_enabled: true)
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: add_on)
        end

        it "does not enable #{params[:add_on_type]} support (setting not exposed in UI yet)" do
          put api('/application/settings', admin, admin_mode: true), params: params
          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['auto_duo_code_review_enabled']).to be_nil
        end
      end
    end

    context 'without proper configuration' do
      where(:duo_features_enabled, :has_duo_enterprise, :param, :value, :result) do
        false | false | 'auto_duo_code_review_enabled' | false | nil
        false | true  | 'auto_duo_code_review_enabled' | false | nil
        true  | false | 'auto_duo_code_review_enabled' | false | nil
        true  | false | 'auto_duo_code_review_enabled' | true  | nil
        true  | true  | 'auto_duo_code_review_enabled' | false | false
        true  | true  | 'auto_duo_code_review_enabled' | true  | true
      end

      with_them do
        let(:params) { { param => value } }

        before do
          application_setting.update!(duo_features_enabled: duo_features_enabled)

          if has_duo_enterprise
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
          end
        end

        it 'handles the setting correctly based on configuration' do
          put api('/application/settings', admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response[param]).to eq(result)
        end
      end
    end
  end

  context 'foundational_agents_statuses' do
    include_context 'with mocked Foundational Chat Agents'

    let(:foundational_agents_statuses) { nil }
    let(:params) { { foundational_agents_statuses: foundational_agents_statuses } }

    subject(:update_settings) do
      put api('/application/settings', admin, admin_mode: true), params: params
    end

    before do
      default_organization.foundational_agents_statuses = []

      update_settings
    end

    context 'when is nil' do
      let(:foundational_agents_statuses) { nil }

      it 'is optional' do
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when valid' do
      let(:foundational_agents_statuses) do
        [
          { 'reference' => foundational_chat_agent_1_ref, 'enabled' => false },
          { 'reference' => foundational_chat_agent_2_ref, 'enabled' => true }
        ]
      end

      it 'updates namespace ai settings' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(default_organization.reload.foundational_agents_statuses).to match_array([
          { description: "First agent", enabled: false, name: "Agent 1", reference: "agent_1" },
          { description: "Second agent", enabled: true, name: "Agent 2", reference: "agent_2" }
        ])
      end
    end

    context 'when record is invalid' do
      let(:foundational_agents_statuses) do
        [
          { 'reference' => foundational_chat_agent_1_ref, 'enabled' => false },
          { 'reference' => invalid_agent_reference, 'enabled' => true }
        ]
      end

      it 'is bad request' do
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']['foundational_agents_statuses']).to include('Foundational agents status records is invalid')
      end
    end
  end

  context 'duo_namespace_access_rules' do
    let_it_be(:namespace_a) { create(:group) }
    let_it_be(:namespace_b) { create(:group) }

    let(:duo_namespace_access_rules) do
      [
        { 'through_namespace' => { 'id' => namespace_a.id }, 'features' => %w[duo_classic duo_agent_platform] },
        { 'through_namespace' => { 'id' => namespace_b.id }, 'features' => %w[duo_agent_platform] }
      ]
    end

    let(:params) { { duo_namespace_access_rules: duo_namespace_access_rules } }

    context 'with valid params' do
      it 'creates instance accessible entity rules' do
        put api('/application/settings', admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:ok)
        expect(Ai::FeatureAccessRule.count).to eq(3)
      end

      context 'when features is empty' do
        let(:duo_namespace_access_rules) do
          [
            { 'through_namespace' => { 'id' => namespace_a.id }, 'features' => [] }
          ]
        end

        it 'deletes existing entity rules and does not create new ones' do
          create(:ai_instance_accessible_entity_rules, through_namespace_id: namespace_a.id)

          put api('/application/settings', admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(Ai::FeatureAccessRule.count).to eq(0)
        end
      end
    end

    context 'with an invalid entity' do
      let(:duo_namespace_access_rules) do
        [
          { 'through_namespace' => { 'id' => namespace_a.id }, 'features' => %w[duo_classic duo_agent_platform] },
          { 'through_namespace' => { 'id' => namespace_b.id }, 'features' => %w[invalid_entity] }
        ]
      end

      it 'is bad request' do
        put api('/application/settings', admin, admin_mode: true), params: params

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']['duo_namespace_access_rules'].to_s).to include(
          'Accessible entity is not included in the list'
        )
      end
    end
  end

  context 'ci_telemetry_otel_endpoint setting', feature_category: :fleet_visibility do
    let(:otel_url) { 'https://otel-collector.example.com/v1/traces' }

    it 'includes ci_telemetry_otel_endpoint in the response' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.keys).to include('ci_telemetry_otel_endpoint')
    end

    it 'allows updating ci_telemetry_otel_endpoint' do
      put api(path, admin, admin_mode: true),
        params: { ci_telemetry_otel_endpoint: otel_url }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['ci_telemetry_otel_endpoint']).to eq(otel_url)
    end

    context 'when ci_job_telemetry_settings feature flag is disabled' do
      before do
        stub_feature_flags(ci_job_telemetry_settings: false)
      end

      it 'does not include ci_telemetry_otel_endpoint in the response' do
        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).not_to include('ci_telemetry_otel_endpoint')
      end

      it 'does not update ci_telemetry_otel_endpoint' do
        put api(path, admin, admin_mode: true),
          params: { ci_telemetry_otel_endpoint: otel_url }

        expect(response).to have_gitlab_http_status(:ok)
        expect(ApplicationSetting.current.ci_telemetry_otel_endpoint).to be_nil
      end
    end
  end

  context 'ci_job_telemetry_sampling_rate setting', feature_category: :fleet_visibility do
    it 'includes ci_job_telemetry_sampling_rate in the response' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to have_key('ci_job_telemetry_sampling_rate')
    end

    it 'allows updating ci_job_telemetry_sampling_rate' do
      put api(path, admin, admin_mode: true),
        params: { ci_job_telemetry_sampling_rate: 0.5 }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['ci_job_telemetry_sampling_rate']).to eq(0.5)
    end

    context 'when ci_job_telemetry_settings feature flag is disabled' do
      before do
        stub_feature_flags(ci_job_telemetry_settings: false)
      end

      it 'does not include ci_job_telemetry_sampling_rate in the response' do
        get api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key('ci_job_telemetry_sampling_rate')
      end

      it 'does not update ci_job_telemetry_sampling_rate' do
        put api(path, admin, admin_mode: true),
          params: { ci_job_telemetry_sampling_rate: 0.5 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(ApplicationSetting.current.ci_job_telemetry_sampling_rate).to eq(0.0)
      end
    end
  end

  context 'duo_template_project_id setting', feature_category: :duo_code_review do
    let(:template_project) { create(:project) }

    context 'when ai_features license is available' do
      before do
        stub_licensed_features(ai_features: true)
        get api(path, admin, admin_mode: true)
      end

      it 'includes duo_template_project_id in the GET response' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to include('duo_template_project_id')
      end

      it 'allows setting duo_template_project_id' do
        put api(path, admin, admin_mode: true), params: { duo_template_project_id: template_project.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['duo_template_project_id']).to eq(template_project.id)
      end

      context 'on GitLab.com', :saas_gitlab_com_subscriptions do
        it 'does not include duo_template_project_id in the GET response' do
          get api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).not_to include('duo_template_project_id')
        end

        it 'does not update duo_template_project_id' do
          expect { put api(path, admin, admin_mode: true), params: { duo_template_project_id: template_project.id } }
            .not_to change { ApplicationSetting.current.reload.duo_template_project_id }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when ai_features license is not available' do
      before do
        stub_licensed_features(ai_features: false)
        get api(path, admin, admin_mode: true)
      end

      it 'does not include duo_template_project_id in the GET response' do
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).not_to include('duo_template_project_id')
      end

      it 'does not update duo_template_project_id' do
        expect { put api(path, admin, admin_mode: true), params: { duo_template_project_id: template_project.id } }
          .not_to change { ApplicationSetting.current.reload.duo_template_project_id }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  context 'built_in_project_templates_enabled setting', feature_category: :source_code_management do
    let(:feature) { :built_in_project_templates_enabled }
    let(:settings) do
      {
        built_in_project_templates_enabled: false,
        lock_built_in_project_templates_enabled: true
      }
    end

    it_behaves_like 'settings for licensed features'

    context 'on gitlab.com', :saas_gitlab_com_subscriptions do
      let(:attribute_names) { settings.keys.map(&:to_s) }

      before do
        stub_licensed_features(feature => true)

        get api(path, admin, admin_mode: true)
      end

      it 'hides the attributes in the API' do
        expect(response).to have_gitlab_http_status(:ok)
        attribute_names.each do |attribute|
          expect(json_response.keys).not_to include(attribute)
        end
      end

      it 'does not update application settings' do
        expect { put api(path, admin, admin_mode: true), params: settings }
          .not_to change { ApplicationSetting.current.attributes.slice(*attribute_names) }
      end
    end
  end
end
