# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationSetting, feature_category: :shared do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- application settings specs mutate instance AI settings stored on the default organization

  subject(:setting) { described_class.create_from_defaults }

  describe 'AI infrastructure setting validations' do
    it { is_expected.to validate_length_of(:ai_gateway_url).is_at_most(2048).allow_nil }
    it { is_expected.to validate_length_of(:duo_agent_platform_service_url).is_at_most(2048).allow_nil }

    it 'validates ai_gateway_timeout_seconds is between 60 and 600' do
      expect(setting).to validate_numericality_of(:ai_gateway_timeout_seconds)
        .is_greater_than_or_equal_to(60)
        .is_less_than_or_equal_to(600)
    end

    it { is_expected.to allow_value(nil).for(:ai_gateway_timeout_seconds) }
  end

  describe 'cyclical dependency ApplicationSetting <-> License' do
    before do
      described_class.delete_all # ensure no records exist
    end

    it 'does not depend on License.feature_available? check on creation' do
      expect(License).not_to receive(:feature_available?)
      described_class.create_from_defaults
    end
  end

  describe 'default values' do
    context 'with ELASTIC_URL environment variable set' do
      let(:elastic_url) { 'http://elastic:12345' }

      before do
        stub_env('ELASTIC_URL', elastic_url)
      end

      it { expect(setting.elasticsearch_url).to eq([URI.parse(elastic_url)]) }
    end

    describe 'elasticsearch jsonb_accessor fields with defaults' do
      it 'ensures all elasticsearch fields with defaults are included in .defaults', :aggregate_failures do
        # Get elasticsearch jsonb_accessor fields
        elasticsearch_fields_with_defaults = described_class.jsonb_defaults_mapping_for_elasticsearch

        defaults = described_class.defaults

        # Check that each elasticsearch field with a default is included in ApplicationSetting.defaults
        elasticsearch_fields_with_defaults.each do |field, expected_default|
          field_symbol = field.to_sym
          expect(defaults[field_symbol]).to eq(expected_default),
            "Expected '#{field}' default to be #{expected_default} but got #{defaults[field_symbol].inspect}"
        end
      end
    end

    it 'has correct default values' do
      is_expected.to have_attributes(
        allow_all_integrations: true,
        allow_group_owners_to_manage_ldap: true,
        allowed_integrations: [],
        anonymous_searches_allowed: true,
        default_search_scope: described_class::SEARCH_SCOPE_SYSTEM_DEFAULT,
        arkose_labs_data_exchange_enabled: true,
        arkose_labs_enabled: true,
        auto_ban_user_on_excessive_projects_download: false,
        automatic_purchased_storage_allocation: false,
        built_in_project_templates_enabled: true,
        ci_requires_identity_verification_on_free_plan: true,
        ci_cd_catalog_projects_allowlist: [],
        credit_card_verification_enabled: true,
        cube_api_base_url: nil,
        cube_api_key: nil,
        custom_project_templates_group_id: nil,
        dashboard_limit: 0,
        dashboard_limit_enabled: false,
        default_project_deletion_protection: false,
        dependency_scanning_sbom_scan_api_upload_limit: 400,
        dependency_scanning_sbom_scan_api_download_limit: 6000,
        disable_invite_members: false,
        disable_personal_access_tokens: false,
        disabled_direct_code_suggestions: false,
        enabled_instance_verbose_ai_logs: false,
        duo_chat_expiration_column: 'last_updated_at',
        duo_chat_expiration_days: 30,
        duo_custom_agents_enabled: true,
        lock_duo_custom_agents_enabled: false,
        duo_custom_flows_enabled: true,
        lock_duo_custom_flows_enabled: false,
        duo_external_agents_enabled: true,
        lock_duo_external_agents_enabled: false,
        duo_workflow_oauth_application_id: nil,
        elastic_migration_worker_enabled: true,
        elasticsearch_analyzers_kuromoji_enabled: false,
        elasticsearch_analyzers_kuromoji_search: false,
        elasticsearch_analyzers_smartcn_enabled: false,
        elasticsearch_analyzers_smartcn_search: false,
        elasticsearch_aws: false,
        elasticsearch_aws_access_key: nil,
        elasticsearch_aws_region: 'us-east-1',
        elasticsearch_aws_role_arn: nil,
        elasticsearch_aws_secret_access_key: nil,
        elasticsearch_client_request_timeout: 0,
        elasticsearch_indexed_field_length_limit: 0,
        elasticsearch_indexed_file_size_limit_kb: 1024,
        elasticsearch_indexing_timeout_minutes: 30,
        elasticsearch_indexing: false,
        elasticsearch_limit_indexing: false,
        elasticsearch_max_bulk_concurrency: 10,
        elasticsearch_max_bulk_size_mb: 10,
        elasticsearch_max_code_indexing_concurrency: 30,
        elasticsearch_password: nil,
        elasticsearch_pause_indexing: false,
        elasticsearch_advanced_search_pause_indexing: false,
        active_context_pause_indexing: false,
        elasticsearch_prefix: 'gitlab',
        elasticsearch_requeue_workers: false,
        elasticsearch_retry_on_failure: 0,
        elasticsearch_search: false,
        elasticsearch_username: nil,
        elasticsearch_worker_number_of_shards: 2,
        elasticsearch_code_scope: true,
        email_additional_text: nil,
        enforce_namespace_storage_limit: false,
        fetch_observability_alerts_from_cloud: true,
        future_subscriptions: [],
        geo_node_allowed_ips: '0.0.0.0/0, ::/0',
        git_rate_limit_users_alertlist: [],
        git_rate_limit_users_allowlist: [],
        git_two_factor_session_expiry: 15,
        global_search_block_anonymous_searches_enabled: false,
        global_search_code_enabled: true,
        global_search_commits_enabled: true,
        global_search_work_items_enabled: true,
        global_search_limited_indexing_enabled: false,
        global_search_merge_requests_enabled: true,
        global_search_notes_enabled: true,
        global_search_snippet_titles_enabled: true,
        global_search_users_enabled: true,
        global_search_wiki_enabled: true,
        globally_allowed_ips: '',
        hard_phone_verification_transactions_daily_limit: 20_000,
        instance_level_ai_beta_features_enabled: false,
        license_usage_data_exported: false,
        lock_memberships_to_ldap: false,
        lock_memberships_to_saml: false,
        lock_model_prompt_cache_enabled: false,
        maintenance_mode: false,
        max_github_response_json_value_count: 250_000,
        max_github_response_size_limit: 8,
        max_http_decompressed_size: 100,
        max_http_response_json_depth: 32,
        max_http_response_json_structural_chars: 1_000_000,
        max_http_response_xml_structural_chars: 250_000,
        max_http_response_csv_structural_chars: 250_000,
        max_http_response_size_limit: 100,
        max_number_of_repository_downloads_within_time_period: 0,
        max_number_of_repository_downloads: 0,
        max_personal_access_token_lifetime: nil,
        max_ssh_key_lifetime: nil,
        mirror_capacity_threshold: Settings.gitlab['mirror_capacity_threshold'],
        mirror_max_capacity: Settings.gitlab['mirror_max_capacity'],
        mirror_max_delay: Settings.gitlab['mirror_max_delay'],
        model_prompt_cache_enabled: true,
        phone_verification_enabled: true,
        pipeline_execution_policies_per_configuration_limit: 5,
        policy_store_experiment_enabled: false,
        product_analytics_configurator_connection_string: nil,
        product_analytics_data_collector_host: nil,
        product_analytics_enabled: false,
        receptive_cluster_agents_enabled: false,
        repository_size_limit: 0,
        scan_execution_policies_action_limit: 0,
        scan_execution_policies_schedule_limit: 0,
        seat_control: 0,
        secret_detection_revocation_token_types_url: nil,
        secret_detection_service_auth_token: nil,
        secret_detection_service_url: '',
        secret_detection_token_revocation_enabled: false,
        secret_detection_token_revocation_token: nil,
        secret_detection_token_revocation_url: nil,
        security_approval_policies_limit: 5,
        soft_phone_verification_transactions_daily_limit: 16_000,
        telesign_intelligence_enabled: true,
        unverified_account_group_creation_limit: 2,
        virtual_registries_endpoints_api_limit: 4000,
        zoekt_auto_index_root_namespace: false,
        zoekt_cache_response: true,
        zoekt_cpu_to_tasks_ratio: 1.0,
        zoekt_indexing_enabled: false,
        zoekt_indexing_parallelism: 1,
        zoekt_indexing_paused: false,
        zoekt_max_restarts_15m: Search::Zoekt::Settings::DEFAULT_MAX_RESTARTS_15M,
        zoekt_rollout_batch_size: 32,
        zoekt_rollout_retry_interval: Search::Zoekt::Settings::DEFAULT_ROLLOUT_RETRY_INTERVAL,
        zoekt_trigram_max: Search::Zoekt::Settings::DEFAULT_TRIGRAM_MAX,
        zoekt_lost_node_threshold: Search::Zoekt::Settings::DEFAULT_LOST_NODE_THRESHOLD,
        zoekt_search_enabled: false,
        enforce_pipl_compliance: false,
        project_secrets_limit: 100,
        group_secrets_limit: 500
      )
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:file_template_project).class_name('Project') }
    it { is_expected.to belong_to(:workspaces_oauth_application).class_name('Doorkeeper::Application') }
  end

  describe 'validations' do
    describe 'mirror', feature_category: :source_code_management do
      it { is_expected.to validate_numericality_of(:mirror_max_delay).only_integer }
      it { is_expected.not_to allow_value(nil).for(:mirror_max_delay) }
      it { is_expected.not_to allow_value(0).for(:mirror_max_delay) }
      it { is_expected.not_to allow_value((Gitlab::Mirror::MIN_DELAY - 1.minute) / 60).for(:mirror_max_delay) }

      it { is_expected.to validate_numericality_of(:mirror_max_capacity).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:mirror_max_capacity) }

      it { is_expected.to validate_numericality_of(:mirror_capacity_threshold).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:mirror_capacity_threshold) }
      it { is_expected.not_to allow_value(setting.mirror_max_capacity + 1).for(:mirror_capacity_threshold) }
      it { is_expected.to allow_value(nil).for(:custom_project_templates_group_id) }

      it { is_expected.not_to allow_value(nil).for(:observability_backend_ssl_verification_enabled) }
    end

    describe 'security_and_compliance_setting jsonb_column`s atrributes', feature_category: :compliance_management do
      it { is_expected.to allow_values([true, false]).for(:enforce_pipl_compliance) }

      describe 'secret_push_protection JSON schema properties', feature_category: :secret_detection do
        let(:base_settings) { setting.security_and_compliance_settings }
        let(:boolean_values) { [true, false] }

        %w[secret_push_protection_available secret_push_protection_enforced].each do |property|
          it "accepts boolean values for #{property}" do
            boolean_values.each do |value|
              setting.security_and_compliance_settings = base_settings.merge(property => value)
              expect(setting).to be_valid, "expected #{property}=#{value} to be valid"
            end
          end

          it "rejects non-boolean values for #{property}" do
            setting.security_and_compliance_settings = base_settings.merge(property => 'not_a_boolean')
            expect(setting).not_to be_valid
          end
        end
      end
    end

    describe 'security_mr_report_cache_lifetime_minutes', feature_category: :vulnerability_management do
      it { is_expected.to allow_value(10).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.to allow_value(30).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.to allow_value(60).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.to allow_value(nil).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.not_to allow_value(9).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.not_to allow_value(61).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.not_to allow_value(0).for(:security_mr_report_cache_lifetime_minutes) }
      it { is_expected.not_to allow_value(-1).for(:security_mr_report_cache_lifetime_minutes) }
    end

    describe 'security_scan_stale_after_days', feature_category: :vulnerability_management do
      it { is_expected.to allow_value(7).for(:security_scan_stale_after_days) }
      it { is_expected.to allow_value(30).for(:security_scan_stale_after_days) }
      it { is_expected.to allow_value(90).for(:security_scan_stale_after_days) }
      it { is_expected.to allow_value(nil).for(:security_scan_stale_after_days) }
      it { is_expected.not_to allow_value(6).for(:security_scan_stale_after_days) }
      it { is_expected.not_to allow_value(91).for(:security_scan_stale_after_days) }
      it { is_expected.not_to allow_value(0).for(:security_scan_stale_after_days) }
      it { is_expected.not_to allow_value(-1).for(:security_scan_stale_after_days) }
    end

    describe 'elasticsearch', feature_category: :global_search do
      it { is_expected.to validate_numericality_of(:search_max_shard_size_gb).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_max_shard_size_gb) }

      it { is_expected.to validate_numericality_of(:search_max_docs_denominator).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_max_docs_denominator) }

      it { is_expected.to validate_numericality_of(:search_min_docs_before_rollover).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:search_min_docs_before_rollover) }

      it 'validates elasticsearch_worker_number_of_shards' do
        is_expected.to validate_numericality_of(:elasticsearch_worker_number_of_shards).only_integer.is_greater_than(0)
          .is_less_than_or_equal_to(Elastic::ProcessBookkeepingService::SHARDS_MAX)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_worker_number_of_shards) }

      it 'validates elasticsearch_indexed_file_size_limit_kb' do
        is_expected.to validate_numericality_of(:elasticsearch_indexed_file_size_limit_kb)
          .only_integer.is_greater_than(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_indexed_file_size_limit_kb) }

      it 'validates elasticsearch_indexing_timeout_minutes' do
        is_expected.to validate_numericality_of(:elasticsearch_indexing_timeout_minutes).only_integer.is_greater_than(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_indexing_timeout_minutes) }

      it 'validates elasticsearch_indexed_field_length_limit' do
        is_expected.to validate_numericality_of(:elasticsearch_indexed_field_length_limit)
          .only_integer.is_greater_than_or_equal_to(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_indexed_field_length_limit) }

      it { is_expected.to validate_numericality_of(:elasticsearch_max_bulk_size_mb).only_integer.is_greater_than(0) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_bulk_size_mb) }

      it 'validates elasticsearch_max_bulk_concurrency' do
        is_expected.to validate_numericality_of(:elasticsearch_max_bulk_concurrency)
          .only_integer.is_greater_than(0)
      end

      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_bulk_concurrency) }

      it 'validates elasticsearch_client_request_timeout' do
        is_expected.to validate_numericality_of(:elasticsearch_client_request_timeout)
          .only_integer.is_greater_than_or_equal_to(0)
      end

      it { is_expected.to allow_value(2).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.to allow_value(0).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(-1).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_max_code_indexing_concurrency) }
      it { is_expected.not_to allow_value(1.1).for(:elasticsearch_max_code_indexing_concurrency) }

      it { is_expected.to allow_value(30).for(:elasticsearch_client_request_timeout) }
      it { is_expected.to allow_value(0).for(:elasticsearch_client_request_timeout) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_client_request_timeout) }

      it { is_expected.to allow_value(30).for(:elasticsearch_retry_on_failure) }
      it { is_expected.to allow_value(0).for(:elasticsearch_retry_on_failure) }
      it { is_expected.not_to allow_value(-1).for(:elasticsearch_retry_on_failure) }
      it { is_expected.not_to allow_value(nil).for(:elasticsearch_retry_on_failure) }

      it { is_expected.to allow_value('').for(:elasticsearch_username) }
      it { is_expected.to allow_value('a' * 255).for(:elasticsearch_username) }
      it { is_expected.not_to allow_value('a' * 256).for(:elasticsearch_username) }

      describe 'elasticsearch_prefix validation' do
        it { is_expected.to allow_value('gitlab').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('custom-prefix').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('my_prefix').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('prefix123').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('a').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('1').for(:elasticsearch_prefix) }
        it { is_expected.to allow_value('a1b2c3').for(:elasticsearch_prefix) }

        it { is_expected.not_to allow_value('').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value(nil).for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('Prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('-prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix-').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('_prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix_').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix with spaces').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value(' prefix').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix ').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix@special').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('prefix.dot').for(:elasticsearch_prefix) }
        it { is_expected.not_to allow_value('a' * 101).for(:elasticsearch_prefix) }
      end

      describe 'elasticsearch_aws_role_arn validation' do
        let(:field) { 'elasticsearch_aws_role_arn' }

        let(:es_settings) { setting.elasticsearch }

        it { is_expected.to allow_value(es_settings.merge(field => nil)).for(:elasticsearch) }
        it { is_expected.to allow_value(es_settings.merge(field => '')).for(:elasticsearch) }
        it { is_expected.to allow_value(es_settings.merge(field => 'string')).for(:elasticsearch) }

        it { is_expected.not_to allow_value(es_settings.merge(field => 1)).for(:elasticsearch) }
      end

      describe 'default_search_scope validation' do
        let(:setting) { build(:application_setting) }

        it 'allows blobs scope on EE' do
          setting.default_search_scope = 'blobs'

          expect(setting).to be_valid
        end

        it 'allows all CE scopes on EE' do
          %w[merge_requests milestones projects snippet_titles users work_items].each do |scope|
            setting.default_search_scope = scope

            expect(setting).to be_valid, "expected #{scope} to be valid on EE"
          end
        end
      end
    end

    describe '#sdrs_jwt_signing_key' do
      let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
      let(:setting) { build(:application_setting) }

      it { is_expected.to allow_value(nil).for(:sdrs_jwt_signing_key) }
      it { is_expected.to allow_value(rsa_key.to_pem).for(:sdrs_jwt_signing_key) }

      it 'encrypts and decrypts the value' do
        setting.sdrs_jwt_signing_key = rsa_key.to_pem
        setting.save!

        # Verify encryption
        encrypted_value = described_class.connection.select_value(
          "SELECT sdrs_jwt_signing_key FROM application_settings WHERE id = #{setting.id}"
        )
        expect(encrypted_value).not_to include(rsa_key.to_pem)

        # Verify decryption
        setting.reload
        expect(setting.sdrs_jwt_signing_key).to eq(rsa_key.to_pem)
      end
    end

    describe 'security policy settings' do
      it 'validates security_approval_policies_limit' do
        is_expected.to validate_numericality_of(:security_approval_policies_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(5)
                         .is_less_than_or_equal_to(::Security::ScanResultPolicy::POLICIES_LIMIT)
      end

      it 'validates scan_execution_policies_action_limit' do
        is_expected.to validate_numericality_of(:scan_execution_policies_action_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(0)
                         .is_less_than_or_equal_to(20)
      end

      it 'validates scan_execution_policies_schedule_limit' do
        is_expected.to validate_numericality_of(:scan_execution_policies_schedule_limit)
                         .only_integer
                         .is_greater_than_or_equal_to(0)
                         .is_less_than_or_equal_to(20)
      end

      describe 'policy_store_experiment_enabled' do
        it { is_expected.not_to be_policy_store_experiment_enabled }
        it { is_expected.to allow_values(true, false).for(:policy_store_experiment_enabled) }

        it 'rejects non-boolean values' do
          setting.security_policies = setting.security_policies.merge('policy_store_experiment_enabled' => 'nope')

          expect(setting).not_to be_valid
        end

        it 'persists an enabled value' do
          setting.update!(policy_store_experiment_enabled: true)

          expect(setting.reload).to be_policy_store_experiment_enabled
        end
      end
    end

    describe 'dependency scanning limits', feature_category: :software_composition_analysis do
      where(:attribute) do
        %i[
          dependency_scanning_sbom_scan_api_upload_limit
          dependency_scanning_sbom_scan_api_download_limit
        ]
      end

      with_them do
        it { is_expected.to validate_numericality_of(attribute).only_integer.is_greater_than_or_equal_to(0) }
        it { is_expected.not_to allow_value(nil).for(attribute) }
      end
    end

    describe 'identity_verification_settings' do
      %i[
        soft_phone_verification_transactions_daily_limit
        hard_phone_verification_transactions_daily_limit
        unverified_account_group_creation_limit
      ].each do |field|
        it_behaves_like 'validates jsonb integer field', field, :identity_verification_settings
      end

      %i[
        phone_verification_enabled
        ci_requires_identity_verification_on_free_plan
        telesign_intelligence_enabled
        credit_card_verification_enabled
        arkose_labs_enabled
        arkose_labs_data_exchange_enabled
      ].each do |field|
        it_behaves_like 'validates jsonb boolean field', field, :identity_verification_settings
      end
    end

    describe 'future_subscriptions', feature_category: :subscription_management do
      it { is_expected.to allow_value([{}]).for(:future_subscriptions) }
      it { is_expected.not_to allow_value({}).for(:future_subscriptions) }
      it { is_expected.not_to allow_value(nil).for(:future_subscriptions) }
    end

    describe 'required_instance', feature_category: :pipeline_composition do
      it { is_expected.to allow_value(nil).for(:required_instance_ci_template) }
      it { is_expected.not_to allow_value("").for(:required_instance_ci_template) }
      it { is_expected.not_to allow_value("  ").for(:required_instance_ci_template) }
      it { is_expected.to allow_value("template_name").for(:required_instance_ci_template) }
    end

    describe 'max_personal_access_token', feature_category: :user_management do
      context 'when extended lifetime is not selected' do
        before do
          stub_feature_flags(buffered_token_expiration_limit: false)
        end

        it 'validates max_personal_access_token_lifetime' do
          is_expected.to validate_numericality_of(:max_personal_access_token_lifetime)
            .only_integer.is_greater_than(0).is_less_than_or_equal_to(365).allow_nil
        end
      end

      context 'when extended lifetime is selected' do
        it 'validates max_personal_access_token_lifetime' do
          is_expected.to validate_numericality_of(:max_personal_access_token_lifetime)
            .only_integer.is_greater_than(0).is_less_than_or_equal_to(400).allow_nil
        end
      end
    end

    describe 'new_user_signups', feature_category: :onboarding do
      context 'when seat_control is user cap' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1)
        end

        it 'must be an integer' do
          setting.new_user_signups_cap = 1.5

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be an integer')
        end

        it 'must be greater than 0' do
          setting.new_user_signups_cap = 0

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be greater than 0')
        end

        it 'must not be empty' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('is not a number')
        end
      end

      context 'when seat_control is off' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_OFF)
        end

        it 'can be nil' do
          setting.new_user_signups_cap = nil

          expect(setting).to be_valid
        end

        it 'can be an empty string' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_valid
        end

        it 'must not be a number' do
          setting.new_user_signups_cap = 1

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be blank')
        end
      end

      context 'when seat_control is block overages' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        it 'can be nil' do
          setting.new_user_signups_cap = nil

          expect(setting).to be_valid
        end

        it 'can be an empty string' do
          setting.new_user_signups_cap = ""

          expect(setting).to be_valid
        end

        it 'must not be a number' do
          setting.new_user_signups_cap = 1

          expect(setting).to be_invalid
          expect(setting.errors[:new_user_signups_cap]).to include('must be blank')
        end
      end
    end

    describe 'user_seat_management', feature_category: :seat_cost_management do
      context 'for seat_control' do
        it 'allows update to user cap' do
          expect { setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1) }
            .to change { setting.seat_control }
              .from(described_class::SEAT_CONTROL_OFF).to(described_class::SEAT_CONTROL_USER_CAP)
        end

        it 'allows update to off' do
          setting.update!(seat_control: described_class::SEAT_CONTROL_USER_CAP, new_user_signups_cap: 1)

          expect { setting.update!(seat_control: described_class::SEAT_CONTROL_OFF, new_user_signups_cap: nil) }
            .to change { setting.seat_control }
              .from(described_class::SEAT_CONTROL_USER_CAP).to(described_class::SEAT_CONTROL_OFF)
        end

        it 'does not allow update to value > 2' do
          expect { setting.update!(seat_control: 3) }.to raise_error(
            ActiveRecord::RecordInvalid, "Validation failed: User seat management must be a valid json schema"
          )
        end

        it 'does not allow update to value < 0' do
          expect { setting.update!(seat_control: -1) }.to raise_error(
            ActiveRecord::RecordInvalid, "Validation failed: User seat management must be a valid json schema"
          )
        end
      end
    end

    describe 'git_two_factor', feature_category: :system_access do
      it 'validates git_two_factor_session_expiry' do
        is_expected.to validate_numericality_of(:git_two_factor_session_expiry)
          .only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(10080)
      end

      it { is_expected.not_to allow_value(nil).for(:git_two_factor_session_expiry) }

      # TODO: test feature flag
      context 'when extended lifetime is selected' do
        it 'validates max_ssh_key_lifetime' do
          is_expected.to validate_numericality_of(:max_ssh_key_lifetime)
            .is_greater_than(0).is_less_than_or_equal_to(400).allow_nil
        end
      end

      context 'when extended lifetime is not selected' do
        before do
          stub_feature_flags(buffered_token_expiration_limit: false)
        end

        it 'validates max_ssh_key_lifetime' do
          is_expected.to validate_numericality_of(:max_ssh_key_lifetime)
            .is_greater_than(0).is_less_than_or_equal_to(365).allow_nil
        end
      end
    end

    describe 'namespace_storage_forks_cost_factor' do
      it 'validates namespace_storage_forks_cost_factor' do
        is_expected.to validate_numericality_of(:namespace_storage_forks_cost_factor)
          .is_greater_than_or_equal_to(0)
          .is_less_than_or_equal_to(1)
      end
    end

    describe 'dashboard', feature_category: :observability do
      it { is_expected.to validate_numericality_of(:dashboard_limit).only_integer.is_greater_than_or_equal_to(0) }
    end

    describe 'when additional email text is enabled', feature_category: :user_profile do
      before do
        stub_licensed_features(email_additional_text: true)
      end

      it { is_expected.to allow_value("a" * setting.email_additional_text_character_limit).for(:email_additional_text) }

      it 'does not allow over text character limit' do
        is_expected.not_to allow_value("a" * (setting.email_additional_text_character_limit + 1))
          .for(:email_additional_text)
      end
    end

    describe 'when secret detection token revocation is enabled', feature_category: :secret_detection do
      before do
        stub_application_setting(secret_detection_token_revocation_enabled: true)
      end

      it { is_expected.to allow_value("http://test.com").for(:secret_detection_token_revocation_url) }
      it { is_expected.to allow_value("AKVD34#$%56").for(:secret_detection_token_revocation_token) }
      it { is_expected.to allow_value("http://test.com").for(:secret_detection_revocation_token_types_url) }
    end

    describe '#set_secret_push_protection_from_mode', feature_category: :secret_detection do
      using RSpec::Parameterized::TableSyntax

      where(:mode, :expected_available, :expected_enforced) do
        'disabled'  | false | false
        'available' | true  | false
        'enforced'  | true  | true
      end

      with_them do
        it 'sets the correct attributes from mode' do
          setting.secret_push_protection_mode = mode
          setting.valid?

          expect(setting.secret_push_protection_available).to eq(expected_available)
          expect(setting.secret_push_protection_enforced).to eq(expected_enforced)
        end
      end

      context 'when mode is not set' do
        it 'does not change the attributes' do
          setting.secret_push_protection_available = true
          setting.secret_push_protection_enforced = false
          setting.secret_push_protection_mode = nil
          setting.valid?

          expect(setting.secret_push_protection_available).to be(true)
          expect(setting.secret_push_protection_enforced).to be(false)
        end
      end
    end

    describe 'scheduling analyzer status updates on secret push protection changes',
      feature_category: :secret_detection do
      context 'when secret_push_protection_enforced changes' do
        it 'schedules the instance setting changed update worker' do
          expect(Security::AnalyzersStatus::ScheduleInstanceSettingChangedUpdateWorker)
            .to receive(:perform_async).with('secret_detection')

          setting.update!(secret_push_protection_enforced: !setting.secret_push_protection_enforced)
        end
      end

      context 'when secret_push_protection_available changes' do
        it 'schedules the instance setting changed update worker' do
          expect(Security::AnalyzersStatus::ScheduleInstanceSettingChangedUpdateWorker)
            .to receive(:perform_async).with('secret_detection')

          setting.update!(secret_push_protection_available: !setting.secret_push_protection_available)
        end
      end

      context 'when unrelated settings change' do
        it 'does not schedule the instance setting changed update worker' do
          expect(Security::AnalyzersStatus::ScheduleInstanceSettingChangedUpdateWorker)
            .not_to receive(:perform_async)

          setting.update!(enforce_pipl_compliance: !setting.enforce_pipl_compliance)
        end
      end
    end

    describe 'when validating duo_chat settings' do
      it 'allows valid duo_chat_expiration_column' do
        setting.duo_chat_expiration_column = 'last_updated_at'
        expect(setting).to be_valid
      end

      it 'disallows invalid duo_chat_expiration_column' do
        setting.duo_chat_expiration_column = 'invalid_column'
        expect(setting).not_to be_valid
        expect(setting.errors.where(:duo_chat_expiration_column, :inclusion).present?).to be(true)
      end

      it 'uses the default value from jsonb_accessor' do
        expect(setting.duo_chat_expiration_column).to eq('last_updated_at')
      end
    end

    describe 'nats_settings', feature_category: :audit_events do
      it 'defaults use_nats_for_audit_streaming to false' do
        expect(setting.use_nats_for_audit_streaming).to be(false)
      end

      it 'allows use_nats_for_audit_streaming to be set to true' do
        setting.use_nats_for_audit_streaming = true

        expect(setting).to be_valid
        expect(setting.use_nats_for_audit_streaming).to be(true)
      end

      it 'rejects a non-boolean use_nats_for_audit_streaming' do
        setting.nats_settings = { 'use_nats_for_audit_streaming' => 'not-a-boolean' }

        expect(setting).not_to be_valid
        expect(setting.errors[:nats_settings]).to be_present
      end
    end

    describe 'when validating duo_workflows_default_image_registry' do
      it 'allows valid hostnames' do
        setting.duo_workflows_default_image_registry = 'registry.example.com'
        expect(setting).to be_valid
      end

      it 'allows hostnames with hyphens' do
        setting.duo_workflows_default_image_registry = 'my-registry.example.com'
        expect(setting).to be_valid
      end

      it 'allows hostnames with hyphens and port numbers' do
        setting.duo_workflows_default_image_registry = 'my-registry.example.com:5000'
        expect(setting).to be_valid
      end

      it 'allows hostnames with port numbers' do
        setting.duo_workflows_default_image_registry = 'registry.example.com:5000'
        expect(setting).to be_valid
      end

      it 'allows blank values' do
        setting.duo_workflows_default_image_registry = ''
        expect(setting).to be_valid
      end

      it 'allows nil values' do
        setting.duo_workflows_default_image_registry = nil
        expect(setting).to be_valid
      end

      it 'allows full image path' do
        setting.duo_workflows_default_image_registry = 'registry.example.com/namespace/image'
        expect(setting).to be_valid
      end

      it 'allows full image path with tag' do
        setting.duo_workflows_default_image_registry = 'registry.example.com/namespace/image:v1.0.0'
        expect(setting).to be_valid
      end

      it 'allows hostname with port, full image path, and tag' do
        setting.duo_workflows_default_image_registry =
          'registry.gitlab.com/gitlab-org/duo-workflow/default-docker-image/workflow-generic-image:v0.0.5'
        expect(setting).to be_valid
      end

      it 'allows digest pinning' do
        setting.duo_workflows_default_image_registry =
          'registry.example.com/myimage@sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
        expect(setting).to be_valid
      end

      it 'allows port + path + digest' do
        setting.duo_workflows_default_image_registry =
          'registry.example.com:5000/org/image@sha256:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
        expect(setting).to be_valid
      end

      it 'disallows invalid hostnames' do
        setting.duo_workflows_default_image_registry = 'https://registry.example.com'
        expect(setting).not_to be_valid
        expect(setting.errors[:duo_workflows_default_image_registry]).to be_present
      end

      it 'disallows values exceeding maximum length' do
        setting.duo_workflows_default_image_registry = 'a' * 513
        expect(setting).not_to be_valid
        expect(setting.errors[:duo_workflows_default_image_registry]).to be_present
      end
    end

    describe '#normalize_duo_workflows_default_image_registry' do
      it 'normalizes blank string to nil' do
        setting.duo_workflows_default_image_registry = ''
        setting.valid?

        expect(setting.duo_workflows_default_image_registry).to be_nil
      end

      it 'normalizes whitespace-only string to nil' do
        setting.duo_workflows_default_image_registry = '   '
        setting.valid?

        expect(setting.duo_workflows_default_image_registry).to be_nil
      end

      it 'does not change valid values' do
        setting.duo_workflows_default_image_registry = 'registry.example.com'
        setting.valid?

        expect(setting.duo_workflows_default_image_registry).to eq('registry.example.com')
      end

      it 'does not change nil values' do
        setting.duo_workflows_default_image_registry = nil
        setting.valid?

        expect(setting.duo_workflows_default_image_registry).to be_nil
      end
    end

    describe 'when validating ci_telemetry_otel_endpoint', feature_category: :fleet_visibility do
      before do
        setting.ci_telemetry_otel_endpoint = ci_telemetry_otel_endpoint
      end

      context 'with valid HTTPS URL' do
        let(:ci_telemetry_otel_endpoint) { 'https://otel-collector.example.com/v1/traces' }

        it { is_expected.to be_valid }
      end

      context 'with valid HTTP URL' do
        let(:ci_telemetry_otel_endpoint) { 'http://otel-collector.internal:4318/v1/traces' }

        it { is_expected.to be_valid }
      end

      context 'with blank value' do
        let(:ci_telemetry_otel_endpoint) { '' }

        it { is_expected.to be_valid }
      end

      context 'with nil value' do
        let(:ci_telemetry_otel_endpoint) { nil }

        it { is_expected.to be_valid }
      end

      context 'with non-URL value' do
        let(:ci_telemetry_otel_endpoint) { 'not-a-url' }

        it { is_expected.not_to be_valid }
      end

      context 'with value exceeding maximum length' do
        let(:ci_telemetry_otel_endpoint) { "https://example.com/#{'a' * 1025}" }

        it { is_expected.not_to be_valid }
      end
    end

    describe '#normalize_ci_telemetry_otel_endpoint', feature_category: :fleet_visibility do
      before do
        setting.ci_telemetry_otel_endpoint = ci_telemetry_otel_endpoint
        setting.valid?
      end

      context 'with blank string' do
        let(:ci_telemetry_otel_endpoint) { '' }

        it { expect(setting.ci_telemetry_otel_endpoint).to be_nil }
      end

      context 'with whitespace-only string' do
        let(:ci_telemetry_otel_endpoint) { '   ' }

        it { expect(setting.ci_telemetry_otel_endpoint).to be_nil }
      end

      context 'with valid URL' do
        let(:ci_telemetry_otel_endpoint) { 'https://otel-collector.example.com/v1/traces' }

        it { expect(setting.ci_telemetry_otel_endpoint).to eq('https://otel-collector.example.com/v1/traces') }
      end

      context 'with nil value' do
        let(:ci_telemetry_otel_endpoint) { nil }

        it { expect(setting.ci_telemetry_otel_endpoint).to be_nil }
      end
    end

    describe 'when validating ci_job_telemetry_sampling_rate', feature_category: :fleet_visibility do
      using RSpec::Parameterized::TableSyntax

      where(:ci_job_telemetry_sampling_rate, :expected_valid) do
        0.0  | true
        0.5  | true
        1.0  | true
        nil  | true
        -0.1 | false
        1.1  | false
      end

      with_them do
        before do
          setting.ci_job_telemetry_sampling_rate = ci_job_telemetry_sampling_rate
        end

        it { expect(setting.valid?).to eq(expected_valid) }
      end
    end

    describe '#duo_availability' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_features_enabled, :lock_duo_features_enabled, :expectation) do
        true  | true  | :always_on
        true  | false | :default_on
        false | false | :default_off
        false | true  | :never_on
      end

      with_them do
        before do
          setting.duo_features_enabled = duo_features_enabled
          setting.lock_duo_features_enabled = lock_duo_features_enabled
        end

        it 'returns the expected response' do
          expect(setting.duo_availability).to eq(expectation)
        end
      end
    end

    describe '#duo_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_availability, :duo_features_enabled_expectation, :lock_duo_features_enabled_expectation) do
        "always_on"   | true  | true
        "default_on"  | true  | false
        "default_off" | false | false
        "never_on"    | false | true
      end

      with_them do
        before do
          setting.duo_availability = duo_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_features_enabled).to be duo_features_enabled_expectation
          expect(setting.lock_duo_features_enabled).to be lock_duo_features_enabled_expectation
        end
      end

      context 'when value is "never_on"' do
        it 'disables instance level AI and beta features' do
          setting.duo_availability = "never_on"

          expect(setting.instance_level_ai_beta_features_enabled).to be false
        end
      end
    end

    describe '#duo_never_on?' do
      it 'returns true when duo_availability is "never_on"' do
        setting.duo_availability = "never_on"
        expect(setting.duo_never_on?).to be true
      end

      it 'returns false when duo_availability is "default_on"' do
        setting.duo_availability = "default_on"
        expect(setting.duo_never_on?).to be false
      end

      it 'returns false when duo_availability is "default_off"' do
        setting.duo_availability = "default_off"
        expect(setting.duo_never_on?).to be false
      end
    end

    describe '#duo_remote_flows_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_remote_flows_availability, :duo_remote_flows_enabled_expectation,
        :lock_duo_remote_flows_enabled_expectation) do
        true  | true  | false
        false | false | true
      end

      with_them do
        before do
          setting.duo_remote_flows_availability = duo_remote_flows_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_remote_flows_enabled).to be duo_remote_flows_enabled_expectation
          expect(setting.lock_duo_remote_flows_enabled).to be lock_duo_remote_flows_enabled_expectation
        end
      end
    end

    describe '#duo_foundational_flows_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_foundational_flows_availability, :duo_foundational_flows_enabled_expectation,
        :lock_duo_foundational_flows_enabled_expectation) do
        true  | true  | false
        false | false | true
      end

      with_them do
        before do
          setting.duo_foundational_flows_availability = duo_foundational_flows_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_foundational_flows_enabled).to be duo_foundational_flows_enabled_expectation
          expect(setting.lock_duo_foundational_flows_enabled).to be lock_duo_foundational_flows_enabled_expectation
        end
      end
    end

    describe '#duo_custom_agents_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_custom_agents_availability, :duo_custom_agents_enabled_expectation,
        :lock_duo_custom_agents_enabled_expectation) do
        true  | true  | false
        false | false | true
      end

      with_them do
        before do
          setting.duo_custom_agents_availability = duo_custom_agents_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_custom_agents_enabled).to be duo_custom_agents_enabled_expectation
          expect(setting.lock_duo_custom_agents_enabled).to be lock_duo_custom_agents_enabled_expectation
        end
      end
    end

    describe '#duo_custom_flows_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_custom_flows_availability, :duo_custom_flows_enabled_expectation,
        :lock_duo_custom_flows_enabled_expectation) do
        true  | true  | false
        false | false | true
      end

      with_them do
        before do
          setting.duo_custom_flows_availability = duo_custom_flows_availability
        end

        it 'returns the expected response' do
          expect(setting.duo_custom_flows_enabled).to be duo_custom_flows_enabled_expectation
          expect(setting.lock_duo_custom_flows_enabled).to be lock_duo_custom_flows_enabled_expectation
        end
      end
    end

    describe '#duo_external_agents_availability=' do
      using RSpec::Parameterized::TableSyntax

      where(:duo_external_agents_availability, :duo_external_agents_enabled_expectation,
        :lock_duo_external_agents_enabled_expectation) do
        true  | true  | false
        false | false | true
      end

      with_them do
        it 'sets duo_external_agents_enabled and lock_duo_external_agents_enabled' do
          setting.duo_external_agents_availability = duo_external_agents_availability

          expect(setting.duo_external_agents_enabled).to be duo_external_agents_enabled_expectation
          expect(setting.lock_duo_external_agents_enabled).to be lock_duo_external_agents_enabled_expectation
        end
      end
    end

    it_behaves_like 'tool_approval_for_session_availability setter'
    it_behaves_like 'tool_approval_for_session_availability getter'

    describe '#enabled_expanded_logging' do
      it "aliases enabled_instance_verbose_ai_logs" do
        setting.enabled_instance_verbose_ai_logs = false

        expect { setting.enabled_expanded_logging = true }
          .to change { setting.enabled_instance_verbose_ai_logs }
          .from(false).to(true)
      end
    end

    describe '#foundational_agents_default_enabled' do
      let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- ApplicationSetting facade targets the default organization

      it "updates the default organization Ai::Setting record" do
        ::Ai::Setting.for_organization(default_organization).update!(foundational_agents_default_enabled: false)

        expect { setting.foundational_agents_default_enabled = true }
          .to change { ::Ai::Setting.for_organization(default_organization).foundational_agents_default_enabled }
                .from(false).to(true)
      end
    end

    describe '#foundational_agents_statuses, #foundational_agents_statuses=' do
      include_context 'with mocked Foundational Chat Agents'

      let_it_be(:default_organization) { create(:organization) }
      let(:organization) { default_organization }

      before do
        allow(::Organizations::Organization).to receive(:default_organization).and_return(organization)
      end

      it "fetches values from ::Ai::Settings.instance" do
        default_organization.foundational_agents_statuses = [{ reference: foundational_chat_agent_1_ref,
                                                               enabled: false }]

        expect(setting.reload.foundational_agents_statuses).to include(
          hash_including(
            reference: foundational_chat_agent_1_ref, enabled: false),
          hash_including(
            reference: foundational_chat_agent_2_ref, enabled: nil)
        )

        expect(setting.reload.foundational_agents_statuses).to include(
          hash_including(reference: foundational_chat_agent_1_ref, enabled: false),
          hash_including(reference: foundational_chat_agent_2_ref, enabled: nil)
        )
      end

      context 'when default organization is nil' do
        let(:organization) { nil }

        it 'is an error' do
          expect do
            setting.foundational_agents_statuses
          end.to raise_error(RuntimeError, "Default organization not found")

          expect do
            setting.foundational_agents_statuses = []
          end.to raise_error(RuntimeError, "Default organization not found")
        end
      end
    end

    describe '#duo_namespace_access_rules' do
      let_it_be(:namespace_a) { create(:group) }
      let_it_be(:namespace_b) { create(:group) }

      context 'when rules exist' do
        before do
          create(:ai_instance_accessible_entity_rules, :duo_classic, through_namespace_id: namespace_a.id)
          create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace_id: namespace_a.id)
          create(:ai_instance_accessible_entity_rules, :duo_agent_platform, through_namespace_id: namespace_b.id)
        end

        it 'returns rules' do
          result = setting.duo_namespace_access_rules

          expect(result.keys).to contain_exactly(namespace_a.id, namespace_b.id)
          expect(result[namespace_a.id].map(&:accessible_entity)).to contain_exactly(
            'duo_classic', 'duo_agent_platform'
          )
          expect(result[namespace_b.id].map(&:accessible_entity)).to contain_exactly('duo_agent_platform')
        end
      end

      context 'when no rules exist' do
        it 'is empty' do
          expect(setting.duo_namespace_access_rules).to be_empty
        end
      end
    end

    context 'when validating geo_node_allowed_ips', feature_category: :geo_replication do
      where(:allowed_ips, :is_valid) do
        "192.1.1.1"                   | true
        "192.1.1.0/24"                | true
        "192.1.1.0/24, 192.1.20.23"   | true
        "192.1.1.0/24, 192.23.0.0/16" | true
        "192.1.1.0/34"                | false
        "192.1.1.257"                 | false
        "192.1.1.257, 192.1.1.1"      | false
        "300.1.1.0/34"                | false
      end

      with_them do
        specify do
          setting.update_column(:geo_node_allowed_ips, allowed_ips)

          expect(setting.reload.valid?).to eq(is_valid)
        end
      end
    end

    context 'when validating globally_allowed_ips', feature_category: :geo_replication do
      where(:allowed_ips, :is_valid) do
        "192.1.1.1"                   | true
        "192.1.1.0/24"                | true
        "192.1.1.0/24, 192.1.20.23"   | true
        "192.1.1.0/24, 192.23.0.0/16" | true
        "192.1.1.0/34"                | false
        "192.1.1.257"                 | false
        "192.1.1.257, 192.1.1.1"      | false
        "300.1.1.0/34"                | false
      end

      with_them do
        specify do
          setting.update_column(:globally_allowed_ips, allowed_ips)

          expect(setting.reload.valid?).to eq(is_valid)
        end
      end
    end

    context 'when validating elasticsearch_url', feature_category: :global_search do
      where(:elasticsearch_url, :is_valid) do
        "http://es.localdomain" | true
        "https://es.localdomain" | true
        "http://es.localdomain, https://es.localdomain " | true
        "http://10.0.0.1" | true
        "https://10.0.0.1" | true
        "http://10.0.0.1, https://10.0.0.1" | true
        "http://localhost" | true
        "http://127.0.0.1" | true

        "es.localdomain" | false
        "10.0.0.1" | false
        "http://es.localdomain, es.localdomain" | false
        "http://es.localdomain, 10.0.0.1" | false
        "this_isnt_a_url" | false
        "http://localhost:9200,http:/localhost:9201" | false
      end

      with_them do
        specify do
          setting.elasticsearch_url = elasticsearch_url

          expect(setting.valid?).to eq(is_valid)
        end
      end

      context 'when outbound requests are blocked except for allowlist' do
        let(:blocked_domain_url) { 'http://blocked-domain.com' }
        let(:allowed_domain_url) { 'http://allowed-domain.com' }
        let(:allow_list) { ['allowed-domain.com'] }

        before do
          stub_application_setting(outbound_local_requests_whitelist: allow_list)
          stub_application_setting(diagramsnet_enabled: false)
          stub_application_setting(update_runner_versions_enabled: false)
          stub_application_setting(help_page_documentation_base_url: '')
          stub_application_setting(deny_all_requests_except_allowed: true)
        end

        it 'fails validation when elasticsearch_url is not in the outbound local requests allowlist' do
          setting.elasticsearch_url = blocked_domain_url

          expect(setting).not_to be_valid
          expect(setting.errors[:elasticsearch_url]).to include('only supports valid HTTP(S) URLs.')
        end

        it 'passes validation when elasticsearch_url is in the outbound local requests allowlist' do
          setting.elasticsearch_url = allowed_domain_url

          expect(setting).to be_valid
        end

        it 'verifies that UrlBlocker.validate! is called with the correct allowlist parameter' do
          setting.elasticsearch_url = allowed_domain_url
          expect(Gitlab::HTTP_V2::UrlBlocker)
            .to receive(:validate!)
            .with(URI.parse(allowed_domain_url), anything)

          setting.validate
        end
      end
    end

    context 'for Sentry', feature_category: :observability do
      context 'when Sentry is enabled' do
        before do
          setting.sentry_enabled = true
        end

        it { is_expected.to allow_value(false).for(:sentry_enabled) }
        it { is_expected.not_to allow_value(nil).for(:sentry_enabled) }

        it { is_expected.to allow_value('http://example.com').for(:sentry_dsn) }
        it { is_expected.not_to allow_value("http://#{'a' * 255}.com").for(:sentry_dsn) }
        it { is_expected.not_to allow_value('example').for(:sentry_dsn) }
        it { is_expected.not_to allow_value(nil).for(:sentry_dsn) }

        it { is_expected.to allow_value('http://example.com').for(:sentry_clientside_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_clientside_dsn) }
        it { is_expected.not_to allow_value('example').for(:sentry_clientside_dsn) }
        it { is_expected.not_to allow_value("http://#{'a' * 255}.com").for(:sentry_clientside_dsn) }

        it { is_expected.to allow_value('production').for(:sentry_environment) }
        it { is_expected.not_to allow_value(nil).for(:sentry_environment) }
        it { is_expected.not_to allow_value('a' * 256).for(:sentry_environment) }
      end

      context 'when Sentry is disabled' do
        before do
          setting.sentry_enabled = false
        end

        it { is_expected.not_to allow_value(nil).for(:sentry_enabled) }
        it { is_expected.to allow_value(nil).for(:sentry_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_clientside_dsn) }
        it { is_expected.to allow_value(nil).for(:sentry_environment) }
      end
    end

    describe 'git abuse rate limit validations', feature_category: :insider_threat do
      it 'validates max_number_of_repository_downloads' do
        is_expected.to validate_numericality_of(:max_number_of_repository_downloads)
        .is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10_000)
      end

      it 'validates max_number_of_repository_downloads_within_time_period' do
        is_expected.to validate_numericality_of(:max_number_of_repository_downloads_within_time_period)
          .is_greater_than_or_equal_to(0).is_less_than_or_equal_to(10.days.to_i)
      end

      describe 'git_rate_limit_users_allowlist' do
        let_it_be(:user) { create(:user) }

        it { is_expected.to allow_value([]).for(:git_rate_limit_users_allowlist) }
        it { is_expected.to allow_value([user.username]).for(:git_rate_limit_users_allowlist) }
        it { is_expected.not_to allow_value(nil).for(:git_rate_limit_users_allowlist) }
        it { is_expected.not_to allow_value(['unknown_user']).for(:git_rate_limit_users_allowlist) }

        context 'when maximum length is exceeded' do
          it 'is not valid' do
            setting.git_rate_limit_users_allowlist = Array.new(101) { |i| "user#{i}" }

            expect(setting).not_to be_valid
            expect(setting.errors[:git_rate_limit_users_allowlist]).to include("exceeds maximum length (100 usernames)")
          end
        end

        context 'when attr is not changed' do
          before do
            setting.git_rate_limit_users_allowlist = [non_existing_record_id]
            setting.save!(validate: false)
          end

          it { is_expected.to be_valid }
        end
      end

      describe 'git_rate_limit_users_alertlist' do
        let_it_be(:user) { create(:user) }

        it { is_expected.to allow_value([]).for(:git_rate_limit_users_alertlist) }
        it { is_expected.to allow_value([user.id]).for(:git_rate_limit_users_alertlist) }
        it { is_expected.to allow_value(nil).for(:git_rate_limit_users_alertlist) }
        it { is_expected.not_to allow_value([non_existing_record_id]).for(:git_rate_limit_users_alertlist) }

        context 'when maximum length is exceeded' do
          it 'is not valid' do
            setting.git_rate_limit_users_alertlist = Array.new(101)

            expect(setting).not_to be_valid
            expect(setting.errors[:git_rate_limit_users_alertlist]).to include('exceeds maximum length (100 user ids)')
          end
        end

        context 'when attr is not changed' do
          before do
            setting.git_rate_limit_users_alertlist = [non_existing_record_id]
            setting.save!(validate: false)
          end

          it { is_expected.to be_valid }
        end

        context 'when empty' do
          let!(:active_admin) { create(:admin) }
          let!(:inactive_admin) { create(:admin, :deactivated) }

          it 'returns the user ids of the active admins' do
            expect(setting.git_rate_limit_users_alertlist).to contain_exactly(active_admin.id)
          end
        end

        context 'when not empty' do
          let(:alerted_user_ids) { [1, 3, 2] }

          before do
            setting.update_attribute(:git_rate_limit_users_alertlist, alerted_user_ids)
          end

          it 'returns the ordered set of user ids' do
            expect(setting.git_rate_limit_users_alertlist).to eq([1, 2, 3])
          end
        end
      end

      describe 'unique_project_download_limit_enabled' do
        context 'when max_number_of_repository_downloads is 0' do
          before do
            setting.max_number_of_repository_downloads = 0
            setting.max_number_of_repository_downloads_within_time_period = 300
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(false)
          end
        end

        context 'when max_number_of_repository_downloads_within_time_period is 0' do
          before do
            setting.max_number_of_repository_downloads = 1
            setting.max_number_of_repository_downloads_within_time_period = 0
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(false)
          end
        end

        context 'when neither are 0' do
          before do
            setting.max_number_of_repository_downloads = 1
            setting.max_number_of_repository_downloads_within_time_period = 300
            setting.save!
          end

          it 'allows project to be indexed' do
            expect(setting.unique_project_download_limit_enabled?).to be(true)
          end
        end
      end
    end

    describe 'when validating product analytics settings', feature_category: :product_analytics do
      context 'when product analytics is enabled' do
        before do
          setting.product_analytics_enabled = true
        end

        it { is_expected.to allow_value(false, '').for(:product_analytics_enabled) }

        it { is_expected.to allow_value('https://cube.gitlab.com', 'https://localhost:4000').for(:cube_api_base_url) }
        it { is_expected.not_to allow_value('invalid.host').for(:cube_api_base_url) }
        it { is_expected.to validate_presence_of(:cube_api_base_url) }
        it { is_expected.to validate_length_of(:cube_api_base_url).is_at_most(512) }

        it { is_expected.to allow_value('420d0e1b73b2ad4acd21c92e533be327').for(:cube_api_key) }
        it { is_expected.to validate_presence_of(:cube_api_key) }
        it { is_expected.to validate_length_of(:cube_api_key).is_at_most(255) }

        it { is_expected.to allow_value('https://collector.gitlab.com', 'http://localhost:8000').for(:product_analytics_data_collector_host) }
        it { is_expected.not_to allow_value('invalid.host').for(:product_analytics_data_collector_host) }
        it { is_expected.to validate_presence_of(:product_analytics_data_collector_host) }
        it { is_expected.to validate_length_of(:product_analytics_data_collector_host).is_at_most(255) }

        it { is_expected.to allow_value('https://configurator.gitlab.com', 'http://localhost:8000').for(:product_analytics_configurator_connection_string) }
        it { is_expected.not_to allow_value("invalid.host").for(:product_analytics_configurator_connection_string) }
        it { is_expected.to validate_presence_of(:product_analytics_configurator_connection_string) }
        it { is_expected.to validate_length_of(:product_analytics_configurator_connection_string).is_at_most(512) }

        it { is_expected.to allow_value('https://cube.gitlab.com').for(:cube_api_base_url) }
        it { is_expected.to allow_value('https://localhost:4000').for(:cube_api_base_url) }
        it { is_expected.not_to allow_value(nil).for(:cube_api_base_url) }
        it { is_expected.not_to allow_value("").for(:cube_api_base_url) }

        it { is_expected.not_to allow_value(nil).for(:product_analytics_configurator_connection_string) }
        it { is_expected.not_to allow_value("").for(:product_analytics_configurator_connection_string) }
      end

      context 'when product analytics is disabled' do
        before do
          setting.product_analytics_enabled = false
        end

        it { is_expected.to allow_value(nil).for(:cube_api_base_url) }
        it { is_expected.to allow_value(nil).for(:cube_api_key) }
        it { is_expected.to allow_value(nil).for(:product_analytics_data_collector_host) }
        it { is_expected.to allow_value(nil).for(:product_analytics_configurator_connection_string) }
      end
    end

    describe 'code_creation settings', feature_category: :code_suggestions do
      describe 'model_prompt_cache_enabled' do
        it { is_expected.to allow_value(true).for(:model_prompt_cache_enabled) }
        it { is_expected.to allow_value(false).for(:model_prompt_cache_enabled) }

        context 'when value is invalid' do
          it 'shows a validation error for nil' do
            setting.model_prompt_cache_enabled = nil
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end

          it 'shows a validation error for empty string' do
            setting.model_prompt_cache_enabled = ''
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end
        end
      end

      describe 'lock_model_prompt_cache_enabled' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be_with_reload(:project) { create(:project, group: parent_group) }

        it { is_expected.to allow_value(true).for(:lock_model_prompt_cache_enabled) }
        it { is_expected.to allow_value(false).for(:lock_model_prompt_cache_enabled) }

        context 'when value is invalid' do
          it 'shows a validation error for nil' do
            setting.lock_model_prompt_cache_enabled = nil
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end

          it 'shows a validation error for empty string' do
            setting.lock_model_prompt_cache_enabled = ''
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end
        end

        context 'when lock_model_prompt_cache_enabled is set to true' do
          before do
            project.project_setting.update!(model_prompt_cache_enabled: false)
            setting.update!(model_prompt_cache_enabled: false)
            setting.update!(lock_model_prompt_cache_enabled: true)

            allow(Gitlab::CurrentSettings).to receive_messages(
              lock_model_prompt_cache_enabled: true,
              model_prompt_cache_enabled: false
            )
          end

          it 'prevents child records from changing locked values with validation error' do
            ps = project.project_setting

            expect(ps.model_prompt_cache_enabled_locked_by_application_setting?).to be_truthy
            expect(ps.model_prompt_cache_enabled_locked?).to be_truthy

            ps.model_prompt_cache_enabled = true

            # Should prevent save
            expect(ps.save).to be_falsey
            expect(ps.errors.full_messages).to include(match(/Model prompt cache enabled cannot be changed/))
          end

          it 'ensures child records inherit the locked value' do
            ps = project.project_setting

            expect(ps.model_prompt_cache_enabled_locked?).to be_truthy
          end
        end

        context 'when lock_model_prompt_cache_enabled is set to false' do
          before do
            setting.update!(lock_model_prompt_cache_enabled: false)
            allow(Gitlab::CurrentSettings).to receive(:lock_model_prompt_cache_enabled).and_return(false)
          end

          it 'allows child records to change the value' do
            ps = project.project_setting

            ps.model_prompt_cache_enabled = true

            expect(ps.save).to be_truthy
            expect(ps.reload.model_prompt_cache_enabled).to be(true)
          end
        end
      end

      describe 'disabled_direct_code_suggestions' do
        it { is_expected.to allow_value(true).for(:disabled_direct_code_suggestions) }
        it { is_expected.to allow_value(false).for(:disabled_direct_code_suggestions) }

        context 'when value is invalid' do
          it 'shows a validation error for nil' do
            setting.disabled_direct_code_suggestions = nil
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end

          it 'shows a validation error for empty string' do
            setting.disabled_direct_code_suggestions = ''
            expect(setting).not_to be_valid
            expect(setting.errors[:code_creation]).to be_present
          end
        end
      end
    end

    describe 'package_metadata_purl_types', feature_category: :software_composition_analysis do
      it { is_expected.to allow_value(0).for(:package_metadata_purl_types) }
      it { is_expected.to allow_value(1).for(:package_metadata_purl_types) }
      it { is_expected.to allow_value(Enums::Sbom::PURL_TYPES.values.last).for(:package_metadata_purl_types) }
      it { is_expected.not_to allow_value(Enums::Sbom::PURL_TYPES.values.last + 1).for(:package_metadata_purl_types) }
    end

    describe 'import_sources', feature_category: :importers do
      before do
        stub_licensed_features(custom_project_templates: true)
      end

      it { is_expected.to allow_value(['gitlab_custom_project_template']).for(:import_sources) }
    end

    context "for unconfirmed user deletion", feature_category: :user_management do
      context 'when email confirmation is set to hard' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'hard')
        end

        it { is_expected.to validate_numericality_of(:unconfirmed_users_delete_after_days).is_greater_than(0) }
      end

      context 'when email confirmation is set to soft' do
        let(:allow_unconfirmed_access_for) { 3 }

        before do
          stub_application_setting_enum('email_confirmation_setting', 'soft')
          allow(Devise).to receive(:allow_unconfirmed_access_for).and_return(allow_unconfirmed_access_for.days)
        end

        it 'validates unconfirmed_users_delete_after_days' do
          is_expected.to validate_numericality_of(:unconfirmed_users_delete_after_days)
            .is_greater_than(allow_unconfirmed_access_for)
        end
      end

      context 'when email confirmation is is off' do
        before do
          stub_application_setting_enum('email_confirmation_setting', 'off')
        end

        it { is_expected.to allow_value(false).for(:delete_unconfirmed_users) }
        it { is_expected.not_to allow_value(true).for(:delete_unconfirmed_users) }
      end
    end

    describe 'instance_level_ai_beta_features_enabled', feature_category: :plan_provisioning do
      it { is_expected.to allow_values([true, false]).for(:instance_level_ai_beta_features_enabled) }
      it { is_expected.not_to allow_value(nil).for(:instance_level_ai_beta_features_enabled) }
    end

    describe 'integrations settings', feature_category: :not_owned do
      it { is_expected.to allow_values(%w[jira jenkins beyond_identity]).for(:allowed_integrations) }
      it { is_expected.not_to allow_values(['unknown_integration']).for(:allowed_integrations) }

      context 'when allowed_integrations has not changed' do
        before do
          setting.allowed_integrations = ['unknown_integration']
          setting.save!(validate: false)
          setting.reset
        end

        it 'allows unknown integrations' do
          is_expected.to be_valid
          expect(setting.allowed_integrations).to eq(['unknown_integration'])
        end
      end

      context 'when application settings do not allow all integrations' do
        before do
          stub_application_setting(allow_all_integrations: false)
          stub_licensed_features(integrations_allow_list: true)
        end

        it 'allows setting a new allowed integration' do
          setting.allowed_integrations = ['asana']
          expect(setting).to be_valid
        end
      end
    end

    context 'for non-null integer attributes starting from 0' do
      where(:attribute) do
        %i[
          virtual_registries_endpoints_api_limit
        ]
      end

      with_them do
        it { is_expected.to validate_numericality_of(attribute).only_integer.is_greater_than_or_equal_to(0) }
        it { is_expected.not_to allow_value(nil).for(attribute) }
      end
    end

    describe 'zoekt_indexing_timeout' do
      where(:zoekt_indexing_timeout, :is_valid) do
        '1m'    | true
        '2h'    | true
        '30d'   | true
        '1.5h'  | false
        '0'     | false
        '00'    | false
        '30D'   | false
        '5x'    | false
        '5mm'   | false
        '5md'   | false
        '0m'    | false
        '01d'   | false
        '5'     | false
        'm'     | false
        '1m '   | false
        ' 1m'   | false
      end

      with_them do
        specify do
          setting.zoekt_indexing_timeout = zoekt_indexing_timeout

          expect(setting.valid?).to eq(is_valid)
        end
      end
    end

    describe 'zoekt_indexed_file_size_limit' do
      where(:zoekt_indexed_file_size_limit, :is_valid) do
        '5B'    | true
        '1kb'   | true
        '2mb'   | true
        '3gb'   | true
        '1KB'   | true
        '20MB'  | true
        '3GB'   | true
        '05mb'  | false
        '0.5mb' | false
        '5.0kb' | false
        '2XY'   | false
        '20'    | false
        'GB'    | false
        '0mb'   | false
      end

      with_them do
        specify do
          setting.zoekt_indexed_file_size_limit = zoekt_indexed_file_size_limit

          expect(setting.valid?).to eq(is_valid)
        end
      end
    end

    describe 'zoekt_rollout_retry_interval' do
      where(:zoekt_rollout_retry_interval, :is_valid) do
        '1m'    | true
        '2h'    | true
        '30d'   | true
        '0'     | true
        '1.5h'  | false
        '00'    | false
        '30D'   | false
        '5x'    | false
        '5mm'   | false
        '5md'   | false
        '0m'    | false
        '01d'   | false
        '5'     | false
        'm'     | false
        '1m '   | false
        ' 1m'   | false
      end

      with_them do
        specify do
          setting.zoekt_rollout_retry_interval = zoekt_rollout_retry_interval

          expect(setting.valid?).to eq(is_valid)
        end
      end
    end

    describe 'auto_duo_code_review_enabled validations' do
      it { is_expected.to allow_value(true).for(:auto_duo_code_review_enabled) }
      it { is_expected.to allow_value(false).for(:auto_duo_code_review_enabled) }
      it { is_expected.not_to allow_value(nil).for(:auto_duo_code_review_enabled) }
    end

    describe 'duo_remote_flows_enabled validations' do
      it { is_expected.to allow_value(true).for(:duo_remote_flows_enabled) }
      it { is_expected.to allow_value(false).for(:duo_remote_flows_enabled) }
      it { is_expected.not_to allow_value(nil).for(:duo_remote_flows_enabled) }
    end

    describe 'duo_custom_agents_enabled validations' do
      it { is_expected.to allow_value(true).for(:duo_custom_agents_enabled) }
      it { is_expected.to allow_value(false).for(:duo_custom_agents_enabled) }

      context 'when value is invalid' do
        it 'shows a validation error for nil' do
          setting.duo_custom_agents_enabled = nil
          expect(setting).not_to be_valid
          expect(setting.errors[:duo_settings]).to be_present
        end
      end
    end

    describe 'duo_custom_flows_enabled validations' do
      it { is_expected.to allow_value(true).for(:duo_custom_flows_enabled) }
      it { is_expected.to allow_value(false).for(:duo_custom_flows_enabled) }

      context 'when value is invalid' do
        it 'shows a validation error for nil' do
          setting.duo_custom_flows_enabled = nil
          expect(setting).not_to be_valid
          expect(setting.errors[:duo_settings]).to be_present
        end
      end
    end

    describe 'duo_external_agents_enabled validations' do
      it { is_expected.to allow_value(true).for(:duo_external_agents_enabled) }
      it { is_expected.to allow_value(false).for(:duo_external_agents_enabled) }

      it 'shows a validation error for nil' do
        setting.duo_external_agents_enabled = nil
        expect(setting).not_to be_valid
        expect(setting.errors[:duo_settings]).to be_present
      end
    end

    describe 'duo_settings_immutable_on_saas', feature_category: :duo_chat do
      context 'when on GitLab.com', :saas do
        it 'prevents updating duo_features_enabled' do
          setting.update_columns(duo_features_enabled: true)
          setting.duo_features_enabled = false

          expect(setting).not_to be_valid
          expect(setting.errors[:base]).to include('Duo settings cannot be modified on GitLab.com')
        end

        it 'prevents updating duo_remote_flows_enabled' do
          setting.update_columns(duo_remote_flows_enabled: true)
          setting.duo_remote_flows_enabled = false

          expect(setting).not_to be_valid
          expect(setting.errors[:base]).to include('Duo settings cannot be modified on GitLab.com')
        end

        it 'allows reading duo settings' do
          setting.update_columns(duo_features_enabled: false, duo_remote_flows_enabled: false)

          expect(setting.duo_features_enabled).to be false
          expect(setting.duo_remote_flows_enabled).to be false
        end

        it 'allows updating other settings' do
          setting.update_columns(duo_features_enabled: true)
          setting.maintenance_mode = true

          expect(setting).to be_valid
        end
      end

      context 'when not on GitLab.com' do
        it 'allows updating duo_features_enabled' do
          setting.duo_features_enabled = false

          expect(setting).to be_valid
        end

        it 'allows updating duo_remote_flows_enabled' do
          setting.duo_remote_flows_enabled = false

          expect(setting).to be_valid
        end
      end
    end

    describe 'built_in_project_templates_enabled_immutable_on_saas', feature_category: :source_code_management do
      context 'when on GitLab.com', :saas_gitlab_com_subscriptions, :aggregate_failures do
        it 'prevents updating built_in_project_templates_enabled' do
          setting.update_columns(built_in_project_templates_enabled: true)
          setting.built_in_project_templates_enabled = false

          expect(setting).not_to be_valid
          expect(setting.errors[:base]).to include(
            'Built-in project templates enabled cannot be modified on GitLab.com'
          )
        end

        it 'prevents updating lock_built_in_project_templates_enabled' do
          setting.update_columns(lock_built_in_project_templates_enabled: false)
          setting.lock_built_in_project_templates_enabled = true

          expect(setting).not_to be_valid
          expect(setting.errors[:base]).to include(
            'Built-in project templates enabled cannot be modified on GitLab.com'
          )
        end
      end

      context 'when not on GitLab.com' do
        it 'allows updating built_in_project_templates_enabled' do
          setting.built_in_project_templates_enabled = false

          expect(setting).to be_valid
        end

        it 'allows updating lock_built_in_project_templates_enabled' do
          setting.lock_built_in_project_templates_enabled = true

          expect(setting).to be_valid
        end
      end
    end

    describe 'ci_cd_catalog_projects_allowlist', feature_category: :pipeline_composition do
      it { is_expected.to allow_value([]).for(:ci_cd_catalog_projects_allowlist) }
      it { is_expected.to allow_value(['gitlab-org/project']).for(:ci_cd_catalog_projects_allowlist) }
      it { is_expected.to allow_value(['gitlab-org/.*']).for(:ci_cd_catalog_projects_allowlist) }
      it { is_expected.to allow_value(['project'] * 1000).for(:ci_cd_catalog_projects_allowlist) }
      it { is_expected.not_to allow_value(['project'] * 1001).for(:ci_cd_catalog_projects_allowlist) }
    end

    describe 'display_gitlab_credits_user_data' do
      it 'defaults to true for new records' do
        new_setting = build(:application_setting)

        expect(new_setting.display_gitlab_credits_user_data).to be true
      end
    end

    describe 'zoekt_trigram_max' do
      it { is_expected.to validate_numericality_of(:zoekt_trigram_max).only_integer.is_greater_than(0) }
    end
  end

  describe 'callbacks' do
    describe '#remove_code_data_from_elasticsearch', feature_category: :global_search do
      context 'when elasticsearch_code_scope is opted out(true -> false)' do
        before do
          setting.elasticsearch_code_scope = true
          setting.save!(validate: false)
        end

        it 'calls Search::Elastic::DeleteWorker' do
          expect(Search::Elastic::DeleteWorker).to receive(:perform_async).with('task' => 'delete_all_blobs')

          setting.update!(elasticsearch_code_scope: false) # opted out
          expect(setting.reload.elasticsearch_code_scope).to be false
        end

        context 'when some other setting is also changed' do
          it 'calls Search::Elastic::DeleteWorker' do
            expect(Search::Elastic::DeleteWorker).to receive(:perform_async).with('task' => 'delete_all_blobs')

            setting.update!(elasticsearch_code_scope: false, elasticsearch_retry_on_failure: 3)
            expect(setting.reload.elasticsearch_code_scope).to be false
          end
        end
      end

      context 'when elasticsearch_code_scope is opted in(false -> true)' do
        before do
          setting.elasticsearch_code_scope = false
          setting.save!(validate: false)
        end

        it 'does not call Search::Elastic::DeleteWorker' do
          expect(Search::Elastic::DeleteWorker).not_to receive(:perform_async)

          setting.update!(elasticsearch_code_scope: true) # opted in
          expect(setting.reload.elasticsearch_code_scope).to be true
        end
      end

      context 'when elasticsearch_code_scope setting is untouched' do
        context 'when current elasticsearch_code_scope is true' do
          before do
            setting.elasticsearch_code_scope = true
            setting.save!(validate: false)
          end

          it 'does not call Search::Elastic::DeleteWorker' do
            expect(Search::Elastic::DeleteWorker).not_to receive(:perform_async)

            setting.update!(elasticsearch_retry_on_failure: 5)
          end
        end

        context 'when current elasticsearch_code_scope is false' do
          before do
            setting.elasticsearch_code_scope = false
            setting.save!(validate: false)
          end

          it 'does not call Search::Elastic::DeleteWorker' do
            expect(Search::Elastic::DeleteWorker).not_to receive(:perform_async)

            setting.update!(elasticsearch_retry_on_failure: 5)
          end
        end
      end
    end

    describe '#track_restricted_access_disabled_self_managed', feature_category: :seat_cost_management do
      context 'on update' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        it 'tracks restricted_access_disabled event when seat_control changes to off' do
          expect(Gitlab::InternalEvents).to receive(:track_event).with(
            'restricted_access_disabled',
            additional_properties: hash_including(seat_count: nil)
          )

          setting.update!(seat_control: described_class::SEAT_CONTROL_OFF)
        end

        it 'does not track event when other attributes change' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          setting.update!(elasticsearch_retry_on_failure: 5)
        end
      end

      context 'on create' do
        it 'does not track event' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          described_class.create_from_defaults
        end
      end
    end

    describe '#track_restricted_access_enabled_self_managed', feature_category: :seat_cost_management do
      context 'on update' do
        before do
          setting.update!(seat_control: described_class::SEAT_CONTROL_OFF)
        end

        it 'tracks restricted_access_enabled event when seat_control changes to block_overages' do
          expect(Gitlab::InternalEvents).to receive(:track_event).with(
            'restricted_access_enabled',
            additional_properties: hash_including(seat_count: nil)
          )

          setting.update!(seat_control: described_class::SEAT_CONTROL_BLOCK_OVERAGES)
        end

        it 'does not track event when other attributes change' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          setting.update!(elasticsearch_retry_on_failure: 5)
        end
      end

      context 'on create' do
        it 'does not track event' do
          expect(Gitlab::InternalEvents).not_to receive(:track_event)

          described_class.create_from_defaults
        end
      end
    end
  end

  describe 'search curation settings after .create_from_defaults', feature_category: :global_search do
    it { expect(setting.search_max_shard_size_gb).to eq(1) }
    it { expect(setting.search_max_docs_denominator).to eq(100) }
    it { expect(setting.search_min_docs_before_rollover).to eq(50) }

    context 'in production environments' do
      before do
        stub_rails_env "production"
      end

      it { expect(setting.search_max_shard_size_gb).to eq(50) }
      it { expect(setting.search_max_docs_denominator).to eq(5_000_000) }
      it { expect(setting.search_min_docs_before_rollover).to eq(100_000) }
    end
  end

  describe '#allowed_integrations_raw=' do
    before do
      setting.allowed_integrations_raw = '["asana","jira"]'
    end

    it 'sets allowed_integrations' do
      expect(setting.allowed_integrations).to contain_exactly('asana', 'jira')
    end
  end

  context 'with deeply nested JSON payload' do
    it 'raises JSON::ParserError' do
      deeply_nested = "#{'{"a":' * 33}1#{'}' * 33}"

      expect { setting.allowed_integrations_raw = deeply_nested }
        .to raise_error(JSON::ParserError)
    end
  end

  context 'with oversized JSON payload' do
    it 'raises JSON::ParserError' do
      oversized = "[\"#{'a' * 21.megabytes}\"]"

      expect { setting.allowed_integrations_raw = oversized }
        .to raise_error(JSON::ParserError)
    end
  end

  context 'with nil input' do
    it 'sets allowed_integrations to nil' do
      setting.allowed_integrations_raw = nil

      expect(setting.allowed_integrations).to be_nil
    end
  end

  describe '#seat_control_user_cap?' do
    context 'when seat_control is set to user cap' do
      before do
        setting.seat_control = described_class::SEAT_CONTROL_USER_CAP
      end

      it 'returns true' do
        expect(setting.seat_control_user_cap?).to be true
      end
    end

    context 'when seat_control is off' do
      before do
        setting.seat_control = described_class::SEAT_CONTROL_OFF
      end

      it 'returns false' do
        expect(setting.seat_control_user_cap?).to be false
      end
    end
  end

  describe '#should_check_namespace_plan?', feature_category: :groups_and_projects do
    before do
      stub_application_setting(check_namespace_plan: check_namespace_plan_column)
      allow(::Gitlab).to receive(:org_or_com?) { gl_com }

      # This stub was added in order to force a fallback to Gitlab.org_or_com?
      # call testing.
      # Gitlab.org_or_com? responds to `false` on test envs
      # and we want to make sure we're still testing
      # should_check_namespace_plan? method through the test-suite (see
      # https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/18461#note_69322821).
      allow(Rails).to receive_message_chain(:env, :development?).and_return(false)
      allow(Rails).to receive_message_chain(:env, :test?).and_return(false)
      allow(Rails).to receive_message_chain(:env, :production?).and_return(false)
    end

    subject { setting.should_check_namespace_plan? }

    context 'when check_namespace_plan true AND on GitLab.com' do
      let(:check_namespace_plan_column) { true }
      let(:gl_com) { true }

      it 'returns true' do
        is_expected.to be true
      end
    end

    context 'when check_namespace_plan true AND NOT on GitLab.com' do
      let(:check_namespace_plan_column) { true }
      let(:gl_com) { false }

      it 'returns false' do
        is_expected.to be false
      end
    end

    context 'when check_namespace_plan false AND on GitLab.com' do
      let(:check_namespace_plan_column) { false }
      let(:gl_com) { true }

      it 'returns false' do
        is_expected.to be false
      end
    end
  end

  describe '#repository_size_limit column', feature_category: :source_code_management do
    it 'support values up to 8 exabytes' do
      setting.update_column(:repository_size_limit, 8.exabytes - 1)

      setting.reload

      expect(setting.repository_size_limit).to eql(8.exabytes - 1)
    end
  end

  describe 'elasticsearch licensing', feature_category: :global_search do
    before do
      setting.elasticsearch_search = true
      setting.elasticsearch_indexing = true
    end

    def expect_is_es_licensed
      expect(License).to receive(:feature_available?).with(:elastic_search).at_least(:once)
    end

    it 'disables elasticsearch when unlicensed' do
      expect_is_es_licensed.and_return(false)

      expect(setting.elasticsearch_indexing?).to be_falsy
      expect(setting.elasticsearch_indexing).to be_falsy
      expect(setting.elasticsearch_search?).to be_falsy
      expect(setting.elasticsearch_search).to be_falsy
    end

    it 'enables elasticsearch when licensed' do
      expect_is_es_licensed.and_return(true)

      expect(setting.elasticsearch_indexing?).to be_truthy
      expect(setting.elasticsearch_indexing).to be_truthy
      expect(setting.elasticsearch_search?).to be_truthy
      expect(setting.elasticsearch_search).to be_truthy
    end

    it 'enables elasticsearch through usage ping features' do
      stub_usage_ping_features(true)
      allow(License).to receive(:current).and_return(nil)

      expect(setting.elasticsearch_indexing?).to be_truthy
      expect(setting.elasticsearch_indexing).to be_truthy
      expect(setting.elasticsearch_search?).to be_truthy
      expect(setting.elasticsearch_search).to be_truthy
    end
  end

  describe '#elasticsearch_enabled_groups', feature_category: :global_search do
    let_it_be(:group) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }

    context 'when limited indexing is disabled' do
      it 'returns all groups' do
        expect(setting.elasticsearch_enabled_groups).to contain_exactly(group, group2, sub_group)
      end
    end

    context 'when limited indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
        create(:elasticsearch_indexed_namespace, namespace: group)
      end

      it 'returns all group and subgroups of the elastic enabled group' do
        expect(setting.elasticsearch_enabled_groups).to contain_exactly(group, sub_group)
      end
    end
  end

  describe '#elasticsearch_enabled_projects', feature_category: :global_search do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:sub_project) { create(:project, group: sub_group) }
    let_it_be(:project2) { create(:project) }

    context 'when limited indexing is disabled' do
      it 'returns all projects' do
        expect(setting.elasticsearch_enabled_projects).to contain_exactly(project, sub_project, project2)
      end
    end

    context 'when limited indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
        create(:elasticsearch_indexed_namespace, namespace: group)
      end

      it 'returns all projects under the elastic enabled group' do
        expect(setting.elasticsearch_enabled_projects).to contain_exactly(project, sub_project)
      end
    end
  end

  describe '#elasticsearch_url', feature_category: :global_search do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- Keep one-line table syntax in this case
    where(:input_value, :expected_urls) do
      'http://example.com'                                                                | [URI.parse('http://example.com')]
      'http://example.com,https://invalid.invalid:9200'                                   | [URI.parse('http://example.com'), URI.parse('https://invalid.invalid:9200')]
      ' http://example.com, https://invalid.invalid:9200 '                                | [URI.parse('http://example.com'), URI.parse('https://invalid.invalid:9200')]
      'http://example.com/, https://example.com:9200/, https://example.com:9200/prefix//' | [URI.parse('http://example.com'), URI.parse('https://example.com:9200'), URI.parse('https://example.com:9200/prefix')]

      # Array inputs
      ['http://example.com']                                                              | [URI.parse('http://example.com')]
      ['http://example.com', 'https://other.example.com:9200']                            | [URI.parse('http://example.com'), URI.parse('https://other.example.com:9200')]
      ['http://example.com, https://other.example.com:9200']                              | [URI.parse('http://example.com'), URI.parse('https://other.example.com:9200')]
      [' http://example.com ', ' https://other.example.com:9200 ']                        | [URI.parse('http://example.com'), URI.parse('https://other.example.com:9200')]

      # Edge cases
      []                                                                                  | []
      [URI.parse('http://example.com')]                                                   | [URI.parse('http://example.com')]
      ''                                                                                  | []
      nil                                                                                 | []
      123                                                                                 | []
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it 'correctly parses the array input' do
        setting.elasticsearch_url = input_value

        expect(setting.elasticsearch_url).to match_array(expected_urls)
      end
    end
  end

  describe '#elasticsearch_index_settings', feature_category: :global_search do
    subject(:elasticsearch_index_settings) { setting.elasticsearch_index_settings }

    before do
      Elastic::IndexSetting.delete_all
    end

    context 'when no index settings exist' do
      it { is_expected.to be_empty }
    end

    context 'when one index setting exists' do
      let!(:_index_setting) do
        create(:elastic_index_setting, alias_name: 'test-index', number_of_shards: 3, number_of_replicas: 2)
      end

      it 'returns the index setting with correct attributes' do
        expect(elasticsearch_index_settings).to contain_exactly(
          have_attributes(alias_name: 'test-index', number_of_shards: 3, number_of_replicas: 2)
        )
      end
    end

    context 'when multiple index settings exist' do
      let!(:index_alpha) { create(:elastic_index_setting, alias_name: 'index-alpha') }
      let!(:index_beta) { create(:elastic_index_setting, alias_name: 'index-beta') }
      let!(:index_gamma) { create(:elastic_index_setting, alias_name: 'index-gamma') }

      it { is_expected.to eq [index_alpha, index_beta, index_gamma] }
    end
  end

  describe '#elasticsearch_url_with_credentials', feature_category: :global_search do
    let(:elasticsearch_url) { "#{host1},#{host2}" }
    let(:host1) { 'http://example.com' }
    let(:host2) { 'https://example.org:9200' }
    let(:elasticsearch_username) { 'elastic' }
    let(:elasticsearch_password) { 'password' }

    before do
      setting.elasticsearch_url = elasticsearch_url
      setting.elasticsearch_username = elasticsearch_username
      setting.elasticsearch_password = elasticsearch_password
    end

    context 'when credentials are embedded in url' do
      let(:elasticsearch_url) { 'http://username:password@example.com,https://test:test@example.org:9200' }

      it 'ignores them and uses elasticsearch_username and elasticsearch_password settings' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            {
              scheme: 'http',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.com',
              path: '',
              port: 80
            },
            {
              scheme: 'https',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.org',
              path: '',
              port: 9200
            }
          ])
      end
    end

    context 'when credential settings are blank' do
      let(:elasticsearch_username) { nil }
      let(:elasticsearch_password) { nil }

      it 'does not return credential info' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            { scheme: 'http', host: 'example.com', path: '', port: 80 },
            { scheme: 'https', host: 'example.org', path: '', port: 9200 }
          ])
      end

      context 'and url contains credentials' do
        let(:elasticsearch_url) { 'http://username:password@example.com,https://test:test@example.org:9200' }

        it 'returns credentials from url' do
          expect(setting.elasticsearch_url_with_credentials).to match_array(
            [
              { scheme: 'http', user: 'username', password: 'password', host: 'example.com', path: '', port: 80 },
              { scheme: 'https', user: 'test', password: 'test', host: 'example.org', path: '', port: 9200 }
            ])
        end
      end

      context 'and url contains credentials with special characters' do
        let(:elasticsearch_url) { 'http://admin:p%40ssword@localhost:9200/' }

        it 'returns decoded credentials from url' do
          expect(setting.elasticsearch_url_with_credentials).to match_array(
            [
              { scheme: 'http', user: 'admin', password: 'p@ssword', host: 'localhost', path: '', port: 9200 }
            ])
        end
      end
    end

    context 'when credentials settings have special characters' do
      let(:elasticsearch_username) { 'foo/admin' }
      let(:elasticsearch_password) { 'b@r+baz!$' }

      it 'returns the correct values' do
        expect(setting.elasticsearch_url_with_credentials).to match_array(
          [
            {
              scheme: 'http',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.com',
              path: '',
              port: 80
            },
            {
              scheme: 'https',
              user: elasticsearch_username,
              password: elasticsearch_password,
              host: 'example.org',
              path: '',
              port: 9200
            }
          ])
      end
    end
  end

  describe '#elasticsearch_password', feature_category: :global_search do
    it 'does not modify password if it is unchanged in the form' do
      setting.elasticsearch_password = 'foo'
      setting.elasticsearch_password = ApplicationSetting::MASK_PASSWORD

      expect(setting.elasticsearch_password).to eq('foo')
    end
  end

  describe '#elasticsearch_config', feature_category: :global_search do
    it 'places all elasticsearch configuration values into a hash' do
      allow(Rails.env).to receive(:test?).and_return(false)

      setting.update!(
        elasticsearch_url: 'http://example.com:9200',
        elasticsearch_username: 'foo',
        elasticsearch_password: 'bar',
        elasticsearch_aws: false,
        elasticsearch_aws_region: 'test-region',
        elasticsearch_aws_access_key: 'test-access-key',
        elasticsearch_aws_secret_access_key: 'test-secret-access-key',
        elasticsearch_max_bulk_size_mb: 67,
        elasticsearch_max_bulk_concurrency: 8,
        elasticsearch_client_request_timeout: 30,
        elasticsearch_client_adapter: :net_http
      )

      expect(setting.elasticsearch_config).to eq(
        url: [Search::Elastic::Helper.connection_settings(uri: URI.parse('http://foo:bar@example.com:9200'))],
        aws: false,
        aws_region: 'test-region',
        aws_access_key: 'test-access-key',
        aws_secret_access_key: 'test-secret-access-key',
        client_adapter: 'net_http',
        client_request_timeout: 30,
        max_bulk_size_bytes: 67.megabytes,
        max_bulk_concurrency: 8
      )

      setting.update!(
        elasticsearch_client_request_timeout: 0
      )

      expect(setting.elasticsearch_config)
        .to include(client_request_timeout: described_class::ELASTIC_REQUEST_TIMEOUT)
    end

    context 'when in test environment' do
      it 'uses the ELASTIC_REQUEST_TIMEOUT value instead of the database default' do
        expect(setting.elasticsearch_config)
          .to include(client_request_timeout: described_class::ELASTIC_REQUEST_TIMEOUT)
      end
    end

    context 'when limiting namespaces and projects' do
      before do
        setting.update!(elasticsearch_indexing: true)
        setting.update!(elasticsearch_limit_indexing: true)
      end

      context 'on namespaces' do
        context 'with personal namespaces' do
          let(:namespaces) { create_list(:namespace, 2) }
          let!(:indexed_namespace) { create :elasticsearch_indexed_namespace, namespace: namespaces.last }

          it 'tells you if a namespace is allowed to be indexed' do
            expect(setting.elasticsearch_indexes_namespace?(namespaces.last)).to be_truthy
            expect(setting.elasticsearch_indexes_namespace?(namespaces.first)).to be_falsey
          end
        end

        context 'with groups' do
          let(:groups) { create_list(:group, 2) }
          let!(:indexed_namespace) { create(:elasticsearch_indexed_namespace, namespace: groups.last) }
          let!(:child_group) { create(:group, parent: groups.first) }
          let!(:child_group_indexed_through_parent) { create(:group, parent: groups.last) }

          specify do
            create(:elasticsearch_indexed_namespace, namespace: child_group)

            expect(setting.elasticsearch_limited_namespaces).to match_array(
              [groups.last, child_group, child_group_indexed_through_parent])
            expect(setting.elasticsearch_limited_namespaces(true)).to match_array(
              [groups.last, child_group])
          end
        end

        describe '#elasticsearch_indexes_project?' do
          shared_examples 'whether the project is indexed' do
            context 'when project is in a subgroup' do
              let(:root_group) { create(:group) }
              let(:subgroup) { create(:group, parent: root_group) }
              let(:project) { create(:project, group: subgroup) }

              before do
                create(:elasticsearch_indexed_namespace, namespace: root_group)
              end

              it 'allows project to be indexed' do
                expect(setting.elasticsearch_indexes_project?(project)).to be(true)
              end
            end

            context 'when project is in a namespace' do
              let(:namespace) { create(:namespace) }
              let(:project) { create(:project, namespace: namespace) }

              before do
                create(:elasticsearch_indexed_namespace, namespace: namespace)
              end

              it 'allows project to be indexed' do
                expect(setting.elasticsearch_indexes_project?(project)).to be(true)
              end
            end
          end

          it_behaves_like 'whether the project is indexed'
        end
      end

      context 'on projects' do
        let(:projects) { create_list(:project, 2) }
        let!(:indexed_project) { create :elasticsearch_indexed_project, project: projects.last }

        it 'tells you if a project is allowed to be indexed' do
          expect(setting.elasticsearch_indexes_project?(projects.last)).to be(true)
          expect(setting.elasticsearch_indexes_project?(projects.first)).to be(false)
        end

        it 'returns projects that are allowed to be indexed' do
          project_indexed_through_namespace = create(:project)
          create :elasticsearch_indexed_namespace, namespace: project_indexed_through_namespace.namespace

          expect(setting.elasticsearch_limited_projects).to match_array(
            [projects.last, project_indexed_through_namespace])
        end

        it 'uses the ElasticsearchEnabledCache cache' do
          expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:fetch).and_return(true)

          expect(setting.elasticsearch_indexes_project?(projects.first)).to be(true)
        end
      end
    end
  end

  describe '#active_context_indexing_paused?', feature_category: :global_search do
    where(:elasticsearch_pause_indexing, :active_context_pause_indexing, :expected) do
      false | false | false
      true  | false | true
      false | true  | true
      true  | true  | true
    end

    with_them do
      before do
        setting.update!(
          elasticsearch_pause_indexing: elasticsearch_pause_indexing,
          active_context_pause_indexing: active_context_pause_indexing
        )
      end

      it 'returns true if either global or feature-level pause is set' do
        expect(setting.active_context_indexing_paused?).to eq(expected)
      end
    end
  end

  describe '#advanced_search_indexing_paused?', feature_category: :global_search do
    where(:elasticsearch_pause_indexing, :elasticsearch_advanced_search_pause_indexing, :expected) do
      false | false | false
      true  | false | true
      false | true  | true
      true  | true  | true
    end

    with_them do
      before do
        setting.update!(
          elasticsearch_pause_indexing: elasticsearch_pause_indexing,
          elasticsearch_advanced_search_pause_indexing: elasticsearch_advanced_search_pause_indexing
        )
      end

      it 'returns true if either global or feature-level pause is set' do
        expect(setting.advanced_search_indexing_paused?).to eq(expected)
      end
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for projects and namespaces' do
      expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:delete).with(:project)
      expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:delete).with(:namespace)

      setting.invalidate_elasticsearch_indexes_cache!
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache_for_project!', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for a single project' do
      project_id = 1
      expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:delete_record).with(:project, project_id)

      setting.invalidate_elasticsearch_indexes_cache_for_project!(project_id)
    end
  end

  describe '#invalidate_elasticsearch_indexes_cache_for_namespace!', feature_category: :global_search do
    it 'deletes the ElasticsearchEnabledCache for a namespace' do
      namespace_id = 1
      expect(::Search::Elastic::ElasticsearchEnabledCache).to receive(:delete_record).with(:namespace, namespace_id)

      setting.invalidate_elasticsearch_indexes_cache_for_namespace!(namespace_id)
    end
  end

  describe '#search_using_elasticsearch?', feature_category: :global_search do
    # Constructs a truth table to run the specs against
    where(
      indexing: [true, false],
      searching: [true, false],
      limiting: [true, false],
      global_search_limited_indexing_enabled:
      [true, false]
    )

    with_them do
      let_it_be(:included_project_container) { create(:elasticsearch_indexed_project) }
      let_it_be(:included_namespace_container) { create(:elasticsearch_indexed_namespace) }

      let_it_be(:included_project) { included_project_container.project }
      let_it_be(:included_namespace) { included_namespace_container.namespace }

      let_it_be(:excluded_project) { create(:project) }
      let_it_be(:excluded_namespace) { create(:namespace) }

      let(:only_when_enabled_globally) { indexing && searching && !limiting }

      subject { setting.search_using_elasticsearch?(scope: scope) }

      before do
        setting.update!(
          elasticsearch_indexing: indexing,
          elasticsearch_search: searching,
          elasticsearch_limit_indexing: limiting
        )

        stub_ee_application_setting(global_search_limited_indexing_enabled: global_search_limited_indexing_enabled)
      end

      context 'for global scope' do
        let(:scope) { nil }

        it { is_expected.to eq(indexing && searching && (!limiting || global_search_limited_indexing_enabled)) }
      end

      context 'for namespace (in scope)' do
        let(:scope) { included_namespace }

        it { is_expected.to eq(indexing && searching) }
      end

      context 'for namespace (not in scope)' do
        let(:scope) { excluded_namespace }

        it { is_expected.to eq(only_when_enabled_globally) }
      end

      context 'for project (in scope)' do
        let(:scope) { included_project }

        it { is_expected.to eq(indexing && searching) }
      end

      context 'for project (not in scope)' do
        let(:scope) { excluded_project }

        it { is_expected.to eq(only_when_enabled_globally) }
      end
    end
  end

  describe 'custom project templates', feature_category: :groups_and_projects do
    let(:group) { create(:group) }
    let(:projects) { create_list(:project, 3, namespace: group) }

    before do
      setting.update_column(:custom_project_templates_group_id, group.id)

      setting.reload
    end

    context 'when custom_project_templates feature is enabled' do
      before do
        stub_licensed_features(custom_project_templates: true)
      end

      describe '#custom_project_templates_enabled?' do
        it 'returns true' do
          expect(setting.custom_project_templates_enabled?).to be_truthy
        end
      end

      describe '#custom_project_template_id' do
        it 'returns group id' do
          expect(setting.custom_project_templates_group_id).to eq group.id
        end
      end

      describe '#available_custom_project_templates' do
        it 'returns group projects' do
          expect(setting.available_custom_project_templates).to match_array(projects)
        end

        it 'returns an empty array if group is not set' do
          allow(setting).to receive(:custom_project_template_id).and_return(nil)

          expect(setting.available_custom_project_templates).to eq []
        end
      end
    end

    context 'when custom_project_templates feature is disabled' do
      before do
        stub_licensed_features(custom_project_templates: false)
      end

      describe '#custom_project_templates_enabled?' do
        it 'returns false' do
          expect(setting.custom_project_templates_enabled?).to be false
        end
      end

      describe '#custom_project_template_id' do
        it 'returns nil' do
          expect(setting.custom_project_templates_group_id).to be_nil
        end
      end

      describe '#available_custom_project_templates' do
        it 'returns an empty relation' do
          expect(setting.available_custom_project_templates).to be_empty
        end
      end
    end
  end

  describe '#instance_review_permitted?', feature_category: :onboarding do
    subject(:instance_review_permitted?) { setting.instance_review_permitted? }

    context 'for instances with a valid license' do
      before do
        license = create(:license, plan: ::License::PREMIUM_PLAN)
        allow(License).to receive(:current).and_return(license)
      end

      it 'is not permitted' do
        expect(instance_review_permitted?).to be_falsey
      end
    end

    context 'for instances without a valid license' do
      before do
        allow(License).to receive(:current).and_return(nil)
        allow(Rails.cache).to receive(:fetch).and_return(
          ::ApplicationSetting::INSTANCE_REVIEW_MIN_USERS + users_over_minimum
        )
      end

      where(users_over_minimum: [-1, 0, 1])

      with_them do
        it { is_expected.to be(users_over_minimum >= 0) }
      end
    end
  end

  describe '#max_personal_access_token_lifetime_from_now', feature_category: :user_management do
    subject(:max_personal_access_token_lifetime_from_now) { setting.max_personal_access_token_lifetime_from_now }

    let(:days_from_now) { nil }

    before do
      stub_application_setting(max_personal_access_token_lifetime: days_from_now)
    end

    context 'when max_personal_access_token_lifetime is defined' do
      let(:days_from_now) { 30 }

      it 'is a date time' do
        expect(max_personal_access_token_lifetime_from_now).to be_a Date
      end

      it 'is in the future' do
        expect(max_personal_access_token_lifetime_from_now).to be > Date.current
      end

      it 'is in days_from_now' do
        expect((max_personal_access_token_lifetime_from_now.to_date - Date.current).to_i).to eq days_from_now
      end
    end

    context 'when max_personal_access_token_lifetime is nil' do
      it 'is nil' do
        expect(max_personal_access_token_lifetime_from_now).to be_nil
      end
    end
  end

  describe 'updates to max_personal_access_token_lifetime', feature_category: :user_management do
    context 'without personal_access_token_expiration_policy licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: false)
      end

      it "doesn't call the update lifetime service" do
        expect(::PersonalAccessTokens::Instance::UpdateLifetimeService).not_to receive(:new)

        setting.save!
      end
    end

    context 'with personal_access_token_expiration_policy licensed' do
      before do
        setting.max_personal_access_token_lifetime = 30
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      it 'executes the update lifetime service' do
        expect_next_instance_of(::PersonalAccessTokens::Instance::UpdateLifetimeService) do |service|
          expect(service).to receive(:execute)
        end

        setting.save!
      end
    end
  end

  describe '#compliance_frameworks', feature_category: :compliance_management do
    it 'sorts the list' do
      setting.compliance_frameworks = [5, 4, 1, 3, 2]

      expect(setting.compliance_frameworks).to eq([1, 2, 3, 4, 5])
    end

    it 'removes duplicates' do
      setting.compliance_frameworks = [1, 2, 2, 3, 3, 3]

      expect(setting.compliance_frameworks).to eq([1, 2, 3])
    end

    it 'sets empty values' do
      setting.compliance_frameworks = [""]

      expect(setting.compliance_frameworks).to eq([])
    end
  end

  describe 'maintenance mode setting', feature_category: :geo_replication do
    it 'defaults to false' do
      expect(setting.maintenance_mode).to be false
    end
  end

  describe "#max_ssh_key_lifetime_from_now", :freeze_time, feature_category: :system_access do
    subject(:max_ssh_key_lifetime_from_now) { setting.max_ssh_key_lifetime_from_now }

    let(:days_from_now) { nil }

    before do
      stub_application_setting(max_ssh_key_lifetime: days_from_now)
    end

    context 'when max_ssh_key_lifetime is defined' do
      let(:days_from_now) { 30 }

      it 'is a date time' do
        is_expected.to be_a Time
      end

      it 'is in the future' do
        is_expected.to be_future
      end

      it 'is in days_from_now' do
        expect(max_ssh_key_lifetime_from_now.to_date - Time.zone.today).to eq days_from_now
      end
    end

    context 'when max_ssh_key_lifetime is nil' do
      it 'is nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#personal_access_tokens_disabled?', feature_category: :user_management do
    subject { setting.personal_access_tokens_disabled? }

    context 'when disable_personal_access_tokens feature is available' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
      end

      context 'when personal access tokens are disabled' do
        before do
          stub_application_setting(disable_personal_access_tokens: true)
        end

        it { is_expected.to be true }
      end

      context 'when personal access tokens are not disabled' do
        it { is_expected.to be false }
      end
    end
  end

  describe '#disable_feed_token', feature_category: :user_management do
    subject { setting.disable_feed_token }

    before do
      setting.update!(disable_feed_token: false)
    end

    context 'when personal access tokens are disabled' do
      before do
        stub_licensed_features(disable_personal_access_tokens: true)
        stub_application_setting(disable_personal_access_tokens: true)
      end

      it { is_expected.to be true }
    end

    context 'when personal access tokens are enabled' do
      it { is_expected.to be false }
    end
  end

  describe '#push_rule' do
    let(:push_rule_record) { create(:organization_push_rule) }

    before do
      setting.update!(push_rule_id: push_rule_record.id)
    end

    it 'returns nil' do
      expect(setting.push_rule).to be_nil
    end
  end

  describe 'ClickHouseForAnalyticsEnabledEvent publishing' do
    it 'publishes the event when use_clickhouse_for_analytics is changed to enabled', :freeze_time do
      setting.update!(use_clickhouse_for_analytics: false)
      expect do
        setting.update!(use_clickhouse_for_analytics: true)
      end.to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
                     .with(enabled_at: Time.current.iso8601)
    end

    it 'does not publish the event when use_clickhouse_for_analytics is changed to disabled' do
      setting.update!(use_clickhouse_for_analytics: true)
      expect do
        setting.update!(use_clickhouse_for_analytics: false)
      end.not_to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
    end

    it 'does not publish the event when use_clickhouse_for_analytics is not changed' do
      setting.update!(use_clickhouse_for_analytics: true)
      expect do
        setting.update!(use_clickhouse_for_analytics: true)
      end.not_to publish_event(::Analytics::ClickHouseForAnalyticsEnabledEvent)
    end
  end

  describe '#auto_duo_code_review_settings_available?' do
    let(:application_setting) { build(:application_setting) }
    let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
    let!(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    subject(:settings_available) { application_setting.auto_duo_code_review_settings_available? }

    before do
      application_setting.duo_features_enabled = true
    end

    context 'when duo_features_enabled is false' do
      before do
        application_setting.duo_features_enabled = false
      end

      it { is_expected.to be_falsey }
    end

    context 'when duo_features_enabled is true' do
      context 'without any duo add-on' do
        it { is_expected.to be_falsey }
      end

      context 'with active duo_enterprise add-on' do
        before do
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
        end

        it 'returns true' do
          expect(settings_available).to be_truthy
        end
      end

      context 'with expired duo_enterprise add-on' do
        before do
          create(:gitlab_subscription_add_on_purchase, :expired, :self_managed, add_on: duo_enterprise_add_on)
        end

        it 'returns false' do
          expect(settings_available).to be_falsey
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

          it "returns false for #{params[:add_on_type]} (not yet supported at application setting level)" do
            expect(settings_available).to be_falsey
          end
        end
      end

      context 'when duo_foundational_flows_enabled is set' do
        before do
          application_setting.duo_foundational_flows_enabled = true
          create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)
        end

        it 'does not affect duo_core availability (setting not exposed yet)' do
          expect(settings_available).to be_falsey
        end
      end
    end
  end

  describe '#ci_cd_catalog_projects_allowlist_raw' do
    it 'returns the allowlist as a newline-separated string' do
      setting.ci_cd_catalog_projects_allowlist = ['gitlab-org/project1', 'gitlab-org/.*']

      expect(setting.ci_cd_catalog_projects_allowlist_raw).to eq("gitlab-org/project1\ngitlab-org/.*")
    end

    it 'returns nil when allowlist is empty' do
      setting.ci_cd_catalog_projects_allowlist = []

      expect(setting.ci_cd_catalog_projects_allowlist_raw).to eq("")
    end
  end

  describe '#ci_cd_catalog_projects_allowlist_raw=' do
    it 'sets the allowlist from a newline-separated string' do
      setting.ci_cd_catalog_projects_allowlist_raw = "gitlab-org/project1\ngitlab-org/.*"

      expect(setting.ci_cd_catalog_projects_allowlist).to match_array(['gitlab-org/project1', 'gitlab-org/.*'])
    end

    it 'handles comma-separated values' do
      setting.ci_cd_catalog_projects_allowlist_raw = "gitlab-org/project1, gitlab-org/project2"

      expect(setting.ci_cd_catalog_projects_allowlist).to match_array(['gitlab-org/project1', 'gitlab-org/project2'])
    end

    it 'removes empty entries and duplicates' do
      setting.ci_cd_catalog_projects_allowlist_raw = "gitlab-org/project1\n\ngitlab-org/project1"

      expect(setting.ci_cd_catalog_projects_allowlist).to eq(['gitlab-org/project1'])
    end
  end

  describe '#security_mr_report_cache_lifetime_minutes', feature_category: :vulnerability_management do
    context 'when value is not set in the database' do
      before do
        setting.security_and_compliance_settings =
          setting.security_and_compliance_settings.except('security_mr_report_cache_lifetime_minutes')
      end

      it 'returns the default of 10 minutes' do
        expect(setting.security_mr_report_cache_lifetime_minutes).to eq(10)
      end
    end

    context 'when value is set in the database' do
      before do
        setting.security_mr_report_cache_lifetime_minutes = 45
      end

      it 'returns the configured value' do
        expect(setting.security_mr_report_cache_lifetime_minutes).to eq(45)
      end
    end
  end

  describe '#duo_agent_platform_enabled', feature_category: :duo_agent_platform do
    let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- ApplicationSetting facade targets the default organization

    it 'defaults to true via the default organization Ai::Setting record' do
      expect(setting.duo_agent_platform_enabled).to be(true)
    end

    it 'writes through to the default organization Ai::Setting record' do
      setting.duo_agent_platform_enabled = false

      expect(::Ai::Setting.for_organization(default_organization).duo_agent_platform_enabled).to be(false)
    end
  end

  describe '#ai_audit_events_streaming_enabled', feature_category: :audit_events do
    let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- ApplicationSetting facade targets the default organization

    it 'reads from the default organization Ai::Setting record' do
      ::Ai::Setting.for_organization(default_organization).update!(ai_audit_events_streaming_enabled: true)

      expect(setting.ai_audit_events_streaming_enabled).to be(true)
    end

    it 'writes through to the default organization Ai::Setting record' do
      setting.ai_audit_events_streaming_enabled = true

      expect(::Ai::Setting.for_organization(default_organization).ai_audit_events_streaming_enabled).to be(true)
    end
  end

  describe '#security_scan_stale_after_days', feature_category: :vulnerability_management do
    context 'when value is not set in the database' do
      before do
        setting.security_and_compliance_settings =
          setting.security_and_compliance_settings.except('security_scan_stale_after_days')
      end

      context 'on GitLab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it 'returns the GitLab.com default of 30 days' do
          expect(setting.security_scan_stale_after_days).to eq(30)
        end
      end

      context 'on self-managed instances' do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        it 'returns the self-managed default of 90 days' do
          expect(setting.security_scan_stale_after_days).to eq(90)
        end
      end
    end

    context 'when value is set in the database' do
      before do
        setting.security_scan_stale_after_days = 45
      end

      it 'returns the configured value' do
        expect(setting.security_scan_stale_after_days).to eq(45)
      end

      context 'on GitLab.com' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it 'returns the configured value instead of the default' do
          expect(setting.security_scan_stale_after_days).to eq(45)
        end
      end
    end
  end

  describe '#vac_project_ids', feature_category: :software_composition_analysis do
    it 'stores project IDs as an array in security_and_compliance_settings' do
      setting.vac_project_ids = [1, 2, 3]
      setting.save!

      expect(setting.reload.vac_project_ids).to match_array([1, 2, 3])
      expect(setting.security_and_compliance_settings['vac_project_ids']).to match_array([1, 2, 3])
    end

    it 'defaults to an empty array' do
      expect(setting.vac_project_ids).to eq([])
    end
  end

  describe '#vac_project_ids_raw', feature_category: :software_composition_analysis do
    it 'converts array to newline-separated string for display' do
      setting.vac_project_ids = [10, 20, 30]
      expect(setting.vac_project_ids_raw).to eq("10\n20\n30")
    end

    it 'returns empty string for empty array' do
      setting.vac_project_ids = []
      expect(setting.vac_project_ids_raw).to eq('')
    end
  end

  describe '#vac_project_ids_raw=', feature_category: :software_composition_analysis do
    it 'parses comma-separated values' do
      setting.vac_project_ids_raw = '100, 200, 300'
      expect(setting.vac_project_ids).to match_array([100, 200, 300])
    end

    it 'parses newline-separated values' do
      setting.vac_project_ids_raw = "400\n500\n600"
      expect(setting.vac_project_ids).to match_array([400, 500, 600])
    end

    it 'parses mixed format (commas, newlines, spaces)' do
      setting.vac_project_ids_raw = "700,800\n900, 1000  \n  1100"
      expect(setting.vac_project_ids).to match_array([700, 800, 900, 1000, 1100])
    end

    it 'filters out non-numeric values' do
      setting.vac_project_ids_raw = '1, abc, 2, xyz, 3'
      expect(setting.vac_project_ids).to match_array([1, 2, 3])
    end

    it 'filters out zeros' do
      setting.vac_project_ids_raw = '0, 1, 0, 2'
      expect(setting.vac_project_ids).to match_array([1, 2])
    end
  end

  describe 'security_and_compliance_settings JSON schema validation',
    feature_category: :software_composition_analysis do
    context 'with valid vac_project_ids' do
      it 'accepts an array of integers' do
        setting.security_and_compliance_settings = { 'vac_project_ids' => [1, 2, 3] }
        expect(setting).to be_valid
      end

      it 'accepts an empty array' do
        setting.security_and_compliance_settings = { 'vac_project_ids' => [] }
        expect(setting).to be_valid
      end
    end

    context 'with invalid vac_project_ids' do
      it 'rejects an array of strings' do
        setting.security_and_compliance_settings = { 'vac_project_ids' => %w[one two] }
        expect(setting).not_to be_valid
        expect(setting.errors[:security_and_compliance_settings]).to include(/is not an integer/)
      end

      it 'rejects a string value' do
        setting.security_and_compliance_settings = { 'vac_project_ids' => '1, 2, 3' }
        expect(setting).not_to be_valid
        expect(setting.errors[:security_and_compliance_settings]).to include(/is not an array/)
      end

      it 'rejects unknown properties due to additionalProperties: false' do
        setting.security_and_compliance_settings = { 'unknown_field' => true }
        expect(setting).not_to be_valid
        expect(setting.errors[:security_and_compliance_settings]).to include(/is a disallowed additional property/)
      end
    end
  end

  describe '#default_security_tracked_context_quota', feature_category: :vulnerability_management do
    it 'has a default of 2' do
      expect(setting.default_security_tracked_context_quota).to eq(2)
    end

    context 'when validating' do
      it 'allows nil' do
        setting.default_security_tracked_context_quota = nil
        expect(setting).to be_valid
      end

      it 'allows positive integers' do
        setting.default_security_tracked_context_quota = 10
        expect(setting).to be_valid
      end

      it 'does not allow 0' do
        setting.default_security_tracked_context_quota = 0
        expect(setting).not_to be_valid
        expect(setting.errors[:default_security_tracked_context_quota]).to be_present
      end

      it 'does not allow negative numbers' do
        setting.default_security_tracked_context_quota = -1
        expect(setting).not_to be_valid
      end

      it 'does not allow non-integers' do
        setting.default_security_tracked_context_quota = 1.5
        expect(setting).not_to be_valid
      end
    end
  end

  describe '#allow_instance_built_in_project_templates?', feature_category: :source_code_management do
    using RSpec::Parameterized::TableSyntax

    subject(:allow_built_in) { setting.allow_instance_built_in_project_templates? }

    where(:available, :templates_enabled, :expected) do
      true  | true  | true
      true  | false | false
      false | false | true
      false | true  | true
    end

    with_them do
      before do
        allow(setting).to receive(:instance_built_in_project_templates_enabled_available?)
          .and_return(available)
        setting.built_in_project_templates_enabled = templates_enabled
      end

      it { is_expected.to eq(expected) }
    end
  end
end
