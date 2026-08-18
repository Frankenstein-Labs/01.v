# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits,
  :clean_gitlab_redis_rate_limiting, :prometheus, feature_category: :system_access do
  subject(:all) { Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits.all }

  describe '.all' do
    it 'merges EE-only keys on top of the CE registry' do
      expect(all).to include(
        :ai_catalog_item_report,
        :code_suggestions_connection_details,
        :code_suggestions_direct_access,
        :container_scanning_for_registry_scans,
        :create_duo_otel_workflow,
        :credit_card_verification_check_for_reuse,
        :dependency_scanning_sbom_scan_api_download,
        :dependency_scanning_sbom_scan_api_throttling,
        :dependency_scanning_sbom_scan_api_upload,
        :duo_workflow_direct_access,
        :duo_workflow_unauthorized_access,
        :hard_phone_verification_transactions_limit,
        :orbit_query,
        :package_metadata,
        :partner_aws_api,
        :partner_gcp_api,
        :partner_postman_api,
        :semantic_code_search_ad_hoc_indexing,
        :semantic_search_rate_limit,
        :soft_phone_verification_transactions_limit,
        :virtual_registries_endpoints_api_limit
      )
    end

    it 'preserves CE entries' do
      expect(all).to include(:pipelines_create, :ai_action, :web_hook_test)
    end

    # EE.rate_limits overrides the threshold/interval of these two CE keys, so
    # the registry must override their limit/period too while keeping the CE
    # structural fields (otherwise the new resolve-from-registry path would
    # diverge from the legacy hash under EE).
    it "overrides only the limit/period of CE keys that EE's rate_limits overrides", :aggregate_failures do
      supported_rate_limits = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits

      expect(supported_rate_limits.limit_for(:code_suggestions_api_endpoint)).to eq(60)
      expect(supported_rate_limits.period_for(:code_suggestions_api_endpoint)).to eq(1.minute)

      expect(supported_rate_limits.limit_for(:geo_proxy)).to eq(3600)
      expect(supported_rate_limits.period_for(:geo_proxy)).to eq(1.minute)
    end

    it 'builds a cached limiter for an EE-only key' do
      limiter = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits
        .limiter_for(:ai_catalog_item_report)

      expect(limiter).to be_a(::Labkit::RateLimit::Limiter)
      expect(limiter).to be(
        Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits.limiter_for(:ai_catalog_item_report)
      )
    end

    it 'builds limiters from EE-overridden CE registry values' do
      user = build_stubbed(:user)
      limiter = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits
        .limiter_for(:code_suggestions_api_endpoint)

      60.times do
        expect(limiter.check({ user: user.id }).exceeded?).to be(false)
      end

      expect(limiter.check({ user: user.id }).exceeded?).to be(true)
    end

    it 'lets the labkit adapter dispatch an EE key through run!' do
      user = build_stubbed(:user)

      Gitlab::ApplicationRateLimiter::LabkitAdapter.run!(:ai_catalog_item_report, scope: user)

      expected_key = "labkit:rl:applimiter_ai_catalog_item_report:limit_ai_catalog_item_reports_by_user:user:#{user.id}"
      count = Gitlab::Redis::RateLimiting.with { |r| r.get(expected_key) }

      expect(count.to_i).to eq(1)
    end

    it 'gives an EE-only key the same synthetic bypass rule as CE keys', :aggregate_failures do
      user = build_stubbed(:user)

      result = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits
        .limiter_for(:ai_catalog_item_report)
        .check({ user: user.id, bypass_header: '1' })

      expect(result.skipped?).to be(true)
      expect(result.rule.name).to eq('ai_catalog_item_report_bypass')

      count = Gitlab::Redis::RateLimiting.with do |r|
        r.get("labkit:rl:applimiter_ai_catalog_item_report:limit_ai_catalog_item_reports_by_user:user:#{user.id}")
      end
      expect(count).to be_nil
    end

    it 'does not skip an EE-only key for a Boolean bypass_header (only the exact string "1" matches)' do
      user = build_stubbed(:user)

      result = Gitlab::ApplicationRateLimiter::LabkitAdapter::SupportedRateLimits
        .limiter_for(:ai_catalog_item_report)
        .check({ user: user.id, bypass_header: true })

      expect(result.skipped?).to be(false)
    end

    it 'routes a set-mode application key end-to-end as SADD/SCARD' do
      user = build_stubbed(:user)
      project_a = build_stubbed(:project)
      project_b = build_stubbed(:project)

      Gitlab::ApplicationRateLimiter::LabkitAdapter.run!(:unique_project_downloads_for_application,
        scope: user, context: { resource_id: project_a.id, threshold: 5, interval: 600 })
      Gitlab::ApplicationRateLimiter::LabkitAdapter.run!(:unique_project_downloads_for_application,
        scope: user, context: { resource_id: project_b.id, threshold: 5, interval: 600 })

      expected_key = "labkit:rl:applimiter_unique_project_downloads_for_application" \
        ":limit_unique_project_downloads_by_user:user:#{user.id}"
      members = Gitlab::Redis::RateLimiting.with { |r| r.smembers(expected_key) }

      expect(members).to contain_exactly(project_a.id.to_s, project_b.id.to_s)
    end

    # Regression guard for the BaseThrottleService flow: initialize calls
    # rate_limited?(peek: true) and execute calls rate_limited?, so every
    # request invokes the same key twice. If peek accidentally SADDed, the
    # Redis SET would carry 2x cardinality per request and ban users at
    # half the configured threshold.
    it 'does not SADD on peek when both peek and check share the same call site' do
      user = build_stubbed(:user)
      project = build_stubbed(:project)
      allow(Gitlab::CurrentSettings.current_application_settings).to receive_messages(
        max_number_of_repository_downloads: 10,
        max_number_of_repository_downloads_within_time_period: 600
      )

      Gitlab::ApplicationRateLimiter.throttled?(:unique_project_downloads_for_application,
        scope: user, resource: project, threshold: 10, interval: 600, peek: true)
      Gitlab::ApplicationRateLimiter.throttled?(:unique_project_downloads_for_application,
        scope: user, resource: project, threshold: 10, interval: 600)

      expected_key = "labkit:rl:applimiter_unique_project_downloads_for_application" \
        ":limit_unique_project_downloads_by_user:user:#{user.id}"
      members = Gitlab::Redis::RateLimiting.with { |r| r.smembers(expected_key) }

      expect(members).to contain_exactly(project.id.to_s)
    end

    it 'routes a set-mode namespace key with a user+namespace bucket' do
      user = build_stubbed(:user)
      namespace = build_stubbed(:group)
      project = build_stubbed(:project)

      Gitlab::ApplicationRateLimiter::LabkitAdapter.run!(:unique_project_downloads_for_namespace,
        scope: [user, namespace],
        context: { resource_id: project.id, threshold: 10, interval: 600 })

      expected_key = "labkit:rl:applimiter_unique_project_downloads_for_namespace" \
        ":limit_unique_project_downloads_by_user_namespace" \
        ":user:#{user.id}:namespace:#{namespace.id}"
      members = Gitlab::Redis::RateLimiting.with { |r| r.smembers(expected_key) }

      expect(members).to contain_exactly(project.id.to_s)
    end

    it 'lets the labkit adapter peek-dispatch an EE key with a Symbol :global scope' do
      Gitlab::ApplicationRateLimiter::LabkitAdapter.run!(:hard_phone_verification_transactions_limit, scope: :global)

      expect(
        Gitlab::ApplicationRateLimiter::LabkitAdapter.run_peek!(
          :hard_phone_verification_transactions_limit, scope: :global
        )
      ).to be(false)

      expected_key = "labkit:rl:applimiter_hard_phone_verification_transactions_limit" \
        ":limit_hard_phone_verification_transactions_by_scope:scope:global"
      count = Gitlab::Redis::RateLimiting.with { |r| r.get(expected_key) }

      expect(count.to_i).to eq(1)
    end
  end
end
