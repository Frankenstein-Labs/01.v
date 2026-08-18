# frozen_string_literal: true

require 'spec_helper'

# The EE incident-management throttle (throttle_incident_management_notification_web)
# fires only on alerts/notify requests, and alerts_notify? requires web_request?,
# so it always co-fires with the general web throttle. Rack::Attack counts such a
# request under both throttles independently, so the Labkit shadow must too: the
# incident throttle lives in its own limiter (rack_request_incident_management,
# counted by path) while the web throttle stays in rack_request (counted by ip).
#
# This proves one alerts/notify request increments both counters once, in disjoint
# keyspaces, rather than one masking the other (which a shared limiter would cause,
# since the middleware records only the first throttle that fires per limiter).
RSpec.describe 'Labkit::RateLimit rack middleware (EE throttles)', :clean_gitlab_redis_rate_limiting, feature_category: :rate_limiting do
  let(:path) { '/group/project/alerts/notify' }

  before do
    stub_application_setting(
      throttle_unauthenticated_enabled: true,
      throttle_incident_management_notification_enabled: true,
      throttle_incident_management_notification_per_period: 100,
      throttle_incident_management_notification_period_in_seconds: 60
    )

    # spec/support/rate_limiter_labkit_rack_shadow.rb stubs all cohort flags to
    # false globally to keep the shadow out of unrelated specs; re-enable both
    # cohorts here so the middleware actually runs for the throttles under test.
    stub_feature_flags(
      rate_limiter_use_labkit_rack_cohort_1: true,
      rate_limiter_use_labkit_rack_cohort_2: true
    )
  end

  # Sum every labkit counter under a limiter's keyspace. The ':' delimiter after
  # the limiter name keeps rack_request from matching rack_request_protected_paths
  # or rack_request_incident_management, so each limiter is counted in isolation.
  def labkit_total_for(limiter)
    Gitlab::Redis::RateLimiting.with do |redis|
      keys = redis.scan_each(match: "labkit:rl:#{limiter}:*").to_a
      keys.sum { |key| redis.get(key).to_i }
    end
  end

  it 'counts one alerts/notify request in both the incident and web limiters' do
    post path

    expect(labkit_total_for('rack_request_incident_management')).to eq(1)
    expect(labkit_total_for('rack_request')).to eq(1)
  end
end
