# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '1_settings', feature_category: :settings do
  include_context 'when loading 1_settings initializer'

  describe 'cron jobs' do
    let(:expected_jobs) do
      %w[
        adjourned_group_deletion_worker
        adjourned_projects_deletion_cron_worker
        admin_email_worker
        ai_active_context_bulk_process_worker
        ai_active_context_code_scheduling_worker
        ai_active_context_migration_worker
        ai_active_context_task_worker
        ai_catalog_items_aggregate_last30_day_usage_worker
        ai_conversation_cleanup_cron_worker
        ai_duo_workflows_fail_stuck_workflows_worker
        analytics_cycle_analytics_consistency_worker
        analytics_cycle_analytics_incremental_worker
        analytics_cycle_analytics_reaggregation_worker
        analytics_cycle_analytics_stage_aggregation_worker
        analytics_devops_adoption_create_all_snapshots_worker
        analytics_dump_ai_user_metrics_database_write_buffer_cron_worker
        analytics_refresh_ai_events_counts_cron_worker
        analytics_usage_trends_count_job_trigger_worker
        analytics_value_stream_dashboard_count_worker
        app_sec_dast_profile_schedule_worker
        arkose_blocked_users_report_worker
        authn_data_retention_authentication_event_archive_worker
        authn_data_retention_oauth_access_grant_archive_worker
        authn_data_retention_oauth_access_token_archive_worker
        authorized_project_update_periodic_recalculate_worker
        background_operations_worker_main_database
        background_operations_worker_ci_database
        background_operations_worker_sec_database
        background_operations_worker_cell_local_main_database
        background_operations_worker_cell_local_ci_database
        background_operations_worker_cell_local_sec_database
        batched_background_migrations_worker
        batched_background_migration_worker_ci_database
        batched_background_migration_worker_sec_database
        batched_git_ref_updates_cleanup_scheduler_worker
        background_operation_environments_auto_delete
        bbo_users_delete_unconfirmed_secondary
        bulk_imports_stale_import_worker
        cells_schedule_claims_verification_worker
        ci_archive_traces_cron_worker
        ci_catalog_resources_aggregate_last30_day_usage_worker
        ci_catalog_resources_cleanup_last_usages_worker
        ci_catalog_resources_process_sync_events_worker
        ci_click_house_finished_pipelines_sync_worker
        ci_delete_unit_tests_worker
        ci_namespace_mirrors_consistency_check_worker
        ci_partitioning_worker
        ci_pipelines_expire_artifacts_worker
        ci_project_mirrors_consistency_check_worker
        ci_runners_stale_group_runners_prune_worker_cron
        ci_runners_stale_machines_cleanup_worker
        ci_runner_versions_reconciliation_worker
        ci_schedule_bulk_delete_job_artifact_cron_worker
        ci_schedule_delete_objects_worker
        ci_schedule_old_pipelines_removal_cron_worker
        ci_schedule_unlock_pipelines_in_queue_worker
        ci_stuck_pipelines_process_worker
        cleanup_container_registry_worker
        cleanup_dangling_debian_package_files_worker
        cleanup_dependency_proxy_worker
        cleanup_package_registry_worker
        click_house_ci_finished_builds_sync_worker
        click_house_dump_all_write_buffers_cron_worker
        click_house_event_authors_consistency_cron_worker
        click_house_event_namespace_paths_consistency_cron_worker
        click_house_events_sync_worker
        click_house_rebuild_materialized_view_cron_worker
        compliance_violations_consistency_worker
        concurrency_limit_resume_worker
        container_expiration_policy_worker
        database_monitor_locked_tables_cron_worker
        deactivated_pages_deployments_delete_cron_worker
        deactivate_expired_deployments_cron_worker
        delete_expired_dependency_exports_worker
        delete_expired_trigger_token_worker
        delete_expired_vulnerability_exports_worker
        deploy_tokens_expiring_worker
        search_elastic_cluster_reindexing_cron_worker
        search_elastic_index_bulk_cron_worker
        search_elastic_index_initial_bulk_cron_worker
        elastic_migration_worker
        elastic_remove_expired_namespace_subscriptions_from_index_cron_worker
        emit_secrets_stored_billable_event_cron_worker
        environments_auto_stop_cron_worker
        framework_evaluation_scheduler_worker
        geo_checksum_mismatch_reporting_worker
        geo_ci_job_artifact_verification_summary_calculator_worker
        geo_metrics_update_worker
        geo_prune_event_log_worker
        geo_registry_sync_worker
        geo_repository_registry_sync_worker
        geo_secondary_registry_consistency_worker
        geo_secondary_usage_data_cron_worker
        geo_sync_timeout_cron_worker
        geo_verification_cron_worker
        gitlab_export_prune_project_export_jobs_worker
        gitlab_import_import_file_cleanup_worker
        gitlab_service_ping_worker
        gitlab_subscriptions_add_on_purchases_cleanup_worker
        gitlab_subscriptions_add_on_purchases_schedule_bulk_refresh_user_assignments_worker
        gitlab_subscriptions_offline_cloud_license_provision_worker
        group_secret_rotation_reminder_batch_worker
        group_secrets_manager_maintenance_tasks_cron_worker
        group_secrets_manager_reap_orphan_tasks_cron_worker
        historical_data_worker
        image_ttl_group_policy_worker
        import_export_project_cleanup_worker
        import_placeholder_user_cleanup_worker
        import_stuck_project_import_jobs
        inactive_projects_deletion_cron_worker
        incident_management_persist_oncall_rotation_worker
        incident_management_schedule_escalation_check_worker
        incident_sla_exceeded_check_worker
        issue_due_scheduler_worker
        issues_reschedule_stuck_issue_rebalances
        iterations_generator_worker
        iterations_update_status_worker
        jira_import_stuck_jira_import_jobs
        ldap_add_on_seat_sync_worker
        ldap_admin_sync_worker
        ldap_group_sync_worker
        ldap_sync_worker
        licenses_reset_submit_license_usage_data_banner
        loose_foreign_keys_ci_pipelines_builds_cleanup_worker
        loose_foreign_keys_cleanup_worker
        loose_foreign_keys_merge_request_diff_commit_cleanup_worker
        lost_transaction_recovery_worker
        topology_service_stale_requests_cleanup_worker
        manage_evidence_worker
        member_invitation_reminder_emails_worker
        members_expiring_worker
        members_schedule_prune_deletions_worker
        merge_requests_process_scheduled_merge
        merge_trains_unstick_stuck_merges_cron_worker
        minimal_access_provisioning_notification_worker
        mobile_push_prune_stale_subscriptions_worker
        namespaces_enable_descendants_cache_cron_worker
        namespaces_process_outdated_namespace_descendants_cron_worker
        namespaces_prune_aggregation_schedules_worker
        namespaces_stuck_transfers_cancel_cron_worker
        object_storage_delete_stale_direct_uploads_worker
        observability_alert_query_worker
        okr_checkin_reminder_emails
        package_metadata_advisories_sync_worker
        package_metadata_cve_enrichment_sync_worker
        package_metadata_licenses_sync_worker
        package_metadata_malware_advisories_sync_worker
        packages_cleanup_delete_orphaned_dependencies_worker
        pages_domain_removal_cron_worker
        pages_domain_ssl_renewal_cron_worker
        pages_domain_verification_cron_worker
        pause_control_resume_worker
        performance_bar_stats
        personal_access_tokens_expired_notification_worker
        personal_access_tokens_expiring_worker
        pipeline_schedule_worker
        postgres_dynamic_partitions_dropper
        postgres_dynamic_partitions_manager
        projects_schedule_refresh_build_artifacts_size_statistics_worker
        project_secrets_manager_maintenance_tasks_cron_worker
        project_secrets_manager_reap_orphan_tasks_cron_worker
        project_secret_rotation_reminder_batch_worker
        prune_old_events_worker
        publish_release_worker
        reconcile_namespace_secret_counts_cron_worker
        remove_expired_group_links_worker
        remove_expired_members_worker
        remove_unaccepted_member_invites_worker
        remove_unreferenced_lfs_objects_worker
        report_security_policies_metrics_worker
        repository_archive_cache_worker
        repository_check_worker
        resource_access_tokens_inactive_tokens_deletion_cron_worker
        schedule_merge_request_cleanup_refs_worker
        schedule_migrate_external_diffs_worker
        search_elastic_metrics_update_cron_worker
        search_elastic_migration_cleanup_cron_worker
        search_zoekt_metrics_update_cron_worker
        search_zoekt_rollout_worker
        search_zoekt_scheduling_worker
        security_analyzer_namespace_statuses_schedule_worker
        security_create_orchestration_policy_worker
        security_dependency_firewall_flush_activity_stats_write_buffer_cron_worker
        security_destroy_expired_sbom_scans_worker
        security_orchestration_policy_rule_schedule_worker
        security_pipeline_execution_policies_schedule_worker
        security_pipeline_execution_schedule_policies_cleanup_stale_test_runs_worker
        security_scan_execution_policies_schedule_worker
        security_scans_purge_worker
        security_finding_enrichments_purge_worker
        security_unassign_policy_configurations_for_expired_licenses_worker
        service_desk_custom_email_verification_cleanup
        ssh_keys_expired_notification_worker
        ssh_keys_expiring_soon_notification_worker
        stuck_ci_jobs_worker
        stuck_export_jobs_worker
        stuck_merge_jobs_worker
        sync_seat_link_worker
        sync_service_token_worker
        timeout_pending_status_check_responses_worker
        update_container_registry_info_worker
        update_locked_unknown_artifacts_worker
        usage_events_dump_write_buffer_cron_worker
        users_create_statistics_worker
        users_deactivate_dormant_users_worker
        users_delete_unconfirmed_users_worker
        users_migrate_records_to_ghost_user_in_batches_worker
        users_migrate_human_records_to_ghost_user_in_batches_worker
        users_migrate_service_account_records_to_ghost_user_in_batches_worker
        users_migrate_project_bot_records_to_ghost_user_in_batches_worker
        users_security_policy_bot_cleanup_cron_worker
        user_status_cleanup_batch_worker
        version_version_check_cron
        vulnerability_archival_schedule_worker
        vulnerability_historical_statistics_deletion_worker
        vulnerability_namespace_statistics_schedule_worker
        vulnerability_orphaned_remediations_cleanup_worker
        vulnerability_statistics_schedule_worker
        virtual_registries_cleanup_enqueue_policy_worker
        work_items_traversal_ids_healing_cron_worker
        x509_issuer_crl_check_worker
        drop_timed_out_worker
      ]
    end

    let(:expected_saas_jobs) do
      %w[
        block_pipl_users_worker
        cleanup_build_name_worker
        delete_pipl_users_worker
        disable_legacy_open_source_license_for_inactive_projects
        gitlab_subscriptions_schedule_refresh_seats_worker
        namespaces_schedule_dormant_member_removal_worker
        notify_seats_exceeded_batch_worker
        send_recurring_notifications_worker
      ]
    end

    subject(:cron_jobs) { Gitlab::SidekiqConfig.cron_jobs }

    around do |example|
      Gitlab::SidekiqConfig::CronJobs.reset!
      example.run
      Gitlab::SidekiqConfig::CronJobs.reset!
    end

    it 'configures the expected jobs' do
      expect(cron_jobs.keys).to match_array(expected_jobs)
    end

    context 'for saas', :saas do
      it 'configures the expected jobs' do
        expect(cron_jobs.keys).to match_array(expected_jobs + expected_saas_jobs)
      end

      it 'disables gitlab_subscriptions_offline_cloud_license_provision_worker' do
        expect(cron_jobs['gitlab_subscriptions_offline_cloud_license_provision_worker']['status']).to eq('disabled')
      end
    end

    context 'for jihu' do
      before do
        stub_const(
          'Gitlab::SidekiqConfig::CronJobs::JH_SCHEDULE_PATH',
          Rails.root.join('spec/fixtures/jh_cron_schedule.yml')
        )
        allow(Gitlab).to receive(:jh?).and_return(true)
      end

      it 'disables gitlab_subscriptions_offline_cloud_license_provision_worker' do
        expect(cron_jobs['gitlab_subscriptions_offline_cloud_license_provision_worker']['status']).to eq('disabled')
      end
    end
  end

  describe 'cloud_connector' do
    subject(:cloud_connector_base_url) { Settings.cloud_connector.base_url }

    before do
      stub_env("CLOUD_CONNECTOR_BASE_URL", base_url)
      load_settings
    end

    context 'when const CLOUD_CONNECTOR_BASE_URL is set' do
      let(:base_url) { 'https://www.cloud.example.com' }

      it { is_expected.to eq('https://www.cloud.example.com') }
    end

    context 'when const CLOUD_CONNECTOR_BASE_URL is not set' do
      let(:base_url) { nil }

      it { is_expected.to eq('https://cloud.gitlab.com') }
    end
  end

  describe 'duo_workflow' do
    let(:default_base_url) { "https://cloud.gitlab.com" }
    let(:config) { {} }
    let(:base_url) { default_base_url }

    before do
      Settings.duo_workflow = config
      stub_env("CLOUD_CONNECTOR_BASE_URL", base_url)
      load_settings
    end

    after do
      Settings.duo_workflow = {}
      stub_env("CLOUD_CONNECTOR_BASE_URL", default_base_url)
      load_settings
    end

    it 'provides default config' do
      expect(Settings.duo_workflow.service_url).to be_nil
      expect(Settings.duo_workflow.secure).to be(true)
      expect(Settings.duo_workflow.debug).to be(false)
    end

    context 'when service_url is set' do
      let(:config) do
        {
          service_url: "duo-workflow-service.example.com:50052",
          secure: false,
          debug: true
        }
      end

      it 'uses provided config' do
        expect(Settings.duo_workflow.service_url).to eq('duo-workflow-service.example.com:50052')
        expect(Settings.duo_workflow.secure).to be(false)
        expect(Settings.duo_workflow.debug).to be(true)
      end
    end
  end

  describe '`secure` attribute for Duo Workflow' do
    context 'secure setting' do
      before do
        Settings.duo_workflow = {}
      end

      after do
        Settings.duo_workflow = {}
        load_settings
      end

      context 'when secure is not set via config' do
        before do
          load_settings
        end

        it 'defaults to true' do
          expect(Settings.duo_workflow.secure).to be(true)
        end
      end

      context 'when secure is already set via config' do
        context 'and config secure is true' do
          let(:config) { { secure: true } }

          before do
            Settings.duo_workflow = config
            load_settings
          end

          it 'preserves the config value' do
            expect(Settings.duo_workflow.secure).to be(true)
          end
        end

        context 'and config secure is false' do
          let(:config) { { secure: false } }

          before do
            Settings.duo_workflow = config
            load_settings
          end

          it 'preserves the config value' do
            expect(Settings.duo_workflow.secure).to be(false)
          end
        end

        context 'and config secure is nil' do
          let(:config) { { secure: nil } }

          before do
            Settings.duo_workflow = config
            load_settings
          end

          it 'preserves the config value' do
            expect(Settings.duo_workflow.secure).to be_nil
          end
        end
      end
    end
  end

  describe 'ActionCable allowed origins' do
    let(:config) { {} }

    before do
      Settings.gitlab = config
      load_settings
    end

    after do
      Settings.gitlab = {}
      load_settings
    end

    it 'returns default setting' do
      expect(Settings.gitlab.action_cable_allowed_origins).to eq([])
    end

    context 'with settings' do
      let(:config) { { action_cable_allowed_origins: %w[http://origin1.url http://origin2.url] } }

      it 'uses provided config' do
        expect(Settings.gitlab.action_cable_allowed_origins).to eq(%w[http://origin1.url http://origin2.url])
      end
    end
  end

  describe 'geo' do
    let(:config) { {} }

    before do
      Settings.geo = config
      load_settings
    end

    after do
      Settings.geo = {}
      load_settings
    end

    it 'provides default config' do
      expect(Settings.geo.node_name).to eq(Settings.gitlab['url'])
      expect(Settings.geo.registry_replication['enabled']).to be(false)
    end

    context 'when config is provided' do
      let(:config) do
        {
          node_name: 'my primary node',
          registry_replication: { enabled: true, primary_api_url: 'http://primary.url' }
        }
      end

      it 'uses provided config' do
        expect(Settings.geo.node_name).to eq('my primary node')
        expect(Settings.geo.registry_replication['enabled']).to be(true)
        expect(Settings.geo.registry_replication['primary_api_url']).to eq('http://primary.url')
      end
    end
  end
end
