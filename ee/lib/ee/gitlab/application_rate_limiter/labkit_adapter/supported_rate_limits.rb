# frozen_string_literal: true

module EE
  module Gitlab
    module ApplicationRateLimiter
      module LabkitAdapter
        # EE-only entries for the labkit rate-limit adapter, merged into
        # the CE registry via prepend.
        #
        # See lib/gitlab/application_rate_limiter/labkit_adapter/supported_rate_limits.rb
        # for the conventions (AR-typed characteristics, limit/period, the
        # exclusion categories).
        module SupportedRateLimits
          extend ActiveSupport::Concern

          class_methods do
            extend ::Gitlab::Utils::Override

            override :rule_definitions
            def rule_definitions # rubocop:disable Metrics/AbcSize, -- static registry of EE rate-limit definitions
              super.merge(
                ai_agent_audit_event_ingest: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_ai_agent_audit_event_ingest_by_user_and_project',
                  characteristics: %i[user project],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                ai_agent_identity_registration: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_ai_agent_identity_registration_by_user_and_project',
                  characteristics: %i[user project],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                ai_agent_session_creation: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_ai_agent_session_creation_by_user_and_project',
                  characteristics: %i[user project],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                ai_catalog_item_report: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_ai_catalog_item_reports_by_user',
                  characteristics: %i[user],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                code_suggestions_connection_details: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_code_suggestions_connection_details_by_user',
                  characteristics: %i[user],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                code_suggestions_direct_access: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_code_suggestions_direct_access_by_user',
                  characteristics: %i[user],
                  limit: 50,
                  period: 1.minute,
                  action: :limit
                ),
                # code_suggestions_x_ray_dependencies / code_suggestions_x_ray_scan
                # are registered but have no current ApplicationRateLimiter call site
                # and no current call site, so they carry no static limit/period
                # (nothing resolves them today). If a call site is added, give them
                # a limit/period here, the registry's single source of truth.
                code_suggestions_x_ray_dependencies: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_code_suggestions_x_ray_dependencies_by_project',
                  characteristics: %i[project],
                  limit: 0,
                  period: 0,
                  action: :limit
                ),
                code_suggestions_x_ray_scan: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_code_suggestions_x_ray_scans_by_project',
                  characteristics: %i[project],
                  limit: 0,
                  period: 0,
                  action: :limit
                ),
                container_scanning_for_registry_scans: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_container_scanning_for_registry_scans_by_project',
                  characteristics: %i[project],
                  limit: 50,
                  period: 1.day,
                  action: :limit
                ),
                create_duo_otel_workflow: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_duo_otel_workflow_creates_by_user',
                  characteristics: %i[user],
                  limit: 5,
                  period: 1.minute,
                  action: :limit
                ),
                credit_card_verification_check_for_reuse: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_credit_card_verification_reuse_checks_by_ip',
                  characteristics: %i[ip],
                  limit: 10,
                  period: 1.hour,
                  action: :limit
                ),
                dependency_scanning_sbom_scan_api_download: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_dependency_scanning_sbom_scan_api_downloads_by_project',
                  characteristics: %i[project],
                  limit: -> {
                    ::Gitlab::CurrentSettings.current_application_settings.dependency_scanning_sbom_scan_api_download_limit
                  },
                  period: 1.hour,
                  action: :limit
                ),
                dependency_scanning_sbom_scan_api_throttling: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_sbom_scan_api_by_project',
                  characteristics: %i[project],
                  limit: 50,
                  period: 1.hour,
                  action: :limit
                ),
                dependency_scanning_sbom_scan_api_upload: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_dependency_scanning_sbom_scan_api_uploads_by_project',
                  characteristics: %i[project],
                  limit: -> {
                    ::Gitlab::CurrentSettings.current_application_settings.dependency_scanning_sbom_scan_api_upload_limit
                  },
                  period: 1.hour,
                  action: :limit
                ),
                duo_workflow_direct_access: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_duo_workflow_direct_access_by_user',
                  characteristics: %i[user],
                  limit: 50,
                  period: 1.minute,
                  action: :limit
                ),
                hard_phone_verification_transactions_limit: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_hard_phone_verification_transactions_by_scope',
                  characteristics: %i[scope],
                  limit: -> {
                    ::Gitlab::CurrentSettings.current_application_settings.hard_phone_verification_transactions_daily_limit
                  },
                  period: 1.day,
                  action: :limit
                ),
                merge_request_resync_security_policies: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_merge_request_resync_security_policies_by_merge_request',
                  characteristics: %i[merge_request],
                  limit: 1,
                  period: 1.minute,
                  action: :limit
                ),
                duo_workflow_unauthorized_access: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_duo_workflow_unauthorized_access_by_user_workflow',
                  characteristics: %i[user duo_workflow],
                  limit: 1,
                  period: 5.minutes,
                  action: :limit
                ),
                orbit_query: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_orbit_queries_by_user',
                  characteristics: %i[user],
                  limit: 60,
                  period: 1.minute,
                  action: :limit
                ),
                package_metadata: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_package_metadata_queries_by_user',
                  characteristics: %i[user],
                  limit: 1000,
                  period: 1.hour,
                  action: :limit
                ),
                partner_aws_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_aws_api_by_project',
                  characteristics: %i[project],
                  limit: 400,
                  period: 1.second,
                  action: :limit
                ),
                partner_gcp_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_gcp_api_by_project',
                  characteristics: %i[project],
                  limit: 500,
                  period: 1.second,
                  action: :limit
                ),
                partner_postman_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_postman_api_by_project',
                  characteristics: %i[project],
                  limit: 4,
                  period: 1.second,
                  action: :limit
                ),
                partner_github_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_github_api_by_project',
                  characteristics: %i[project],
                  limit: 60,
                  period: 1.hour,
                  action: :limit
                ),
                partner_openai_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_openai_api_by_project',
                  characteristics: %i[project],
                  limit: 50,
                  period: 1.minute,
                  action: :limit
                ),
                partner_anthropic_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_anthropic_api_by_project',
                  characteristics: %i[project],
                  limit: 50,
                  period: 1.minute,
                  action: :limit
                ),
                partner_heroku_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_heroku_api_by_project',
                  characteristics: %i[project],
                  limit: 75,
                  period: 1.minute,
                  action: :limit
                ),
                partner_stripe_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_stripe_api_by_project',
                  characteristics: %i[project],
                  limit: 100,
                  period: 1.minute,
                  action: :limit
                ),
                partner_datadog_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_datadog_api_by_project',
                  characteristics: %i[project],
                  limit: 50,
                  period: 1.minute,
                  action: :limit
                ),
                partner_sendgrid_api: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_partner_sendgrid_api_by_project',
                  characteristics: %i[project],
                  limit: 60,
                  period: 1.minute,
                  action: :limit
                ),
                semantic_code_search_ad_hoc_indexing: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_semantic_code_search_ad_hoc_indexing_by_namespace',
                  characteristics: %i[namespace],
                  limit: 10,
                  period: 1.hour,
                  action: :limit
                ),
                semantic_search_rate_limit: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_semantic_searches_by_user',
                  characteristics: %i[user],
                  limit: 10,
                  period: 1.minute,
                  action: :limit
                ),
                soft_phone_verification_transactions_limit: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_soft_phone_verification_transactions_by_scope',
                  characteristics: %i[scope],
                  limit: -> {
                    ::Gitlab::CurrentSettings.current_application_settings.soft_phone_verification_transactions_daily_limit
                  },
                  period: 1.day,
                  action: :limit
                ),
                # Set-based unique-cardinality rate limits.
                # `count_distinct: :project_id` flips the rule from INCR to
                # SADD/SCARD on labkit; the SET member is the downloaded
                # project's id, set explicitly by the adapter (not class-routed
                # through characteristics, hence the `_id` suffix to make the
                # bare assignment unambiguous).
                #
                # Per-call `threshold:`/`interval:` overrides route through
                # labkit's `rule_context:` keyword for every key. The namespace
                # key carries placeholder limit/period (0/0, matching the legacy
                # registry); real values live on namespace_settings and arrive
                # per-call, so this plumbing is load-bearing for it.
                unique_project_downloads_for_application: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_unique_project_downloads_by_user',
                  characteristics: %i[user],
                  limit: ->(ctx) {
                    ctx&.dig(:threshold) || ::Gitlab::CurrentSettings.current_application_settings.max_number_of_repository_downloads
                  },
                  period: ->(ctx) {
                    ctx&.dig(:interval) || ::Gitlab::CurrentSettings.current_application_settings.max_number_of_repository_downloads_within_time_period
                  },
                  action: :limit,
                  count_distinct: :project_id
                ),
                unique_project_downloads_for_namespace: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_unique_project_downloads_by_user_namespace',
                  characteristics: %i[user namespace],
                  limit: ->(ctx) { ctx&.dig(:threshold) || 0 },
                  period: ->(ctx) { ctx&.dig(:interval) || 0 },
                  action: :limit,
                  count_distinct: :project_id
                ),
                virtual_registries_endpoints_api_limit: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_virtual_registries_endpoints_api_by_ip_group',
                  characteristics: %i[ip group],
                  limit: -> {
                    ::Gitlab::CurrentSettings.current_application_settings.virtual_registries_endpoints_api_limit
                  },
                  period: 15.seconds,
                  action: :limit
                ),
                # EE overrides the CE code suggestions API endpoint threshold/interval.
                code_suggestions_api_endpoint: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_code_suggestions_by_user',
                  characteristics: %i[user],
                  limit: 60,
                  period: 1.minute,
                  action: :limit
                ),
                # EE overrides the CE Geo proxy threshold/interval.
                geo_proxy: ::Labkit::RateLimit::Rule.new(
                  name: 'limit_geo_proxy_requests_by_ip',
                  characteristics: %i[ip],
                  limit: 3600,
                  period: 1.minute,
                  action: :limit
                )
              )
            end
          end
        end
      end
    end
  end
end
