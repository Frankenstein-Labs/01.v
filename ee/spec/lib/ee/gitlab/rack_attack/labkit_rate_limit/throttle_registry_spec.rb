# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry, feature_category: :rate_limiting do
  describe '.all' do
    subject(:entries) { described_class.all }

    it 'classifies the incident-management throttle into its own limiter' do
      entry = entries.fetch('throttle_incident_management_notification_web')

      expect(entry.limiter).to eq('rack_request_incident_management')
      expect(entry.characteristics).to eq([:path])
      expect(entry.cohort).to eq(1)
      expect(entry.claims?).to be(true)
      expect(entry.rule_name).to eq('incident_management_notification_web')
      expect(entry.definition).to be_a(Gitlab::RackAttack::ThrottleDefinition)
    end

    it 'keeps the incident-management limiter disjoint from the CE limiters' do
      incident = entries.fetch('throttle_incident_management_notification_web')

      expect([described_class::GENERAL, described_class::PROTECTED]).not_to include(incident.limiter)
    end
  end

  describe '.skip_matches' do
    it 'adds a geo skip gated on an unauthenticated request' do
      expect(described_class.skip_matches['skip_geo']).to eq(
        verified_geo_request: true, requester_id: nil, runner_id: nil
      )
    end

    it 'adds a virtual-registries skip gated on an unauthenticated request', :aggregate_failures do
      match = described_class.skip_matches['skip_virtual_registries']

      expect(match).to include(requester_id: nil, runner_id: nil)
      expect(match[:path].match?('/api/v4/virtual_registries/packages/maven/1/foo')).to be(true)
      expect(match[:path].match?('/v2/virtual_registries/container/1/bar')).to be(true)
      expect(match[:path].match?('/api/v4/projects')).to be(false)
    end
  end

  describe 'ALERTS_NOTIFY_PATH_REGEX' do
    let(:regex) { ::EE::Gitlab::RackAttack::LabkitRateLimit::ThrottleRegistry::ALERTS_NOTIFY_PATH_REGEX }

    # alerts_notify? is web_request? && logical_path.include?('alerts/notify'), folded
    # into one path matcher so the rule needs no web fact. Pin it to WEB_PATH_REGEX's
    # web lookaheads (which the CE spec pins to web_request?) so a change there that
    # this stops tracking fails here.
    it 'is WEB_PATH_REGEX web lookaheads followed by the alerts/notify substring' do
      web = described_class::WEB_PATH_REGEX

      expect(regex.source).to eq("#{web.source}.*alerts/notify")
      expect(regex.options & Regexp::MULTILINE).to eq(Regexp::MULTILINE)
    end

    it 'matches a web alerts/notify path and rejects non-web or non-alerts paths', :aggregate_failures do
      expect(regex.match?('/my-group/my-project/alerts/notify.json')).to be(true) # web path + alerts/notify
      expect(regex.match?('/api/v4/alerts/notify')).to be(false)                  # API path, not web
      expect(regex.match?('/-/health/alerts/notify')).to be(false)               # health path, not web
      expect(regex.match?('/x/oauth/alerts/notify')).to be(false)                # /oauth/ anywhere, not web
      expect(regex.match?('/my-group/my-project/pipelines')).to be(false)        # web, but no alerts/notify
    end
  end
end
