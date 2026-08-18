# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::RackAttack::LabkitRateLimit::ClassifiedRequest, feature_category: :rate_limiting do
  let(:request) { described_class.new(Rack::MockRequest.env_for('/')) }

  describe '#labkit_facts' do
    describe 'incident management notification enable setting' do
      it 'exposes the enable setting the incident rule matches on' do
        stub_application_setting(throttle_incident_management_notification_enabled: true)

        expect(request.labkit_facts).to include(setting_incident_management_notification: true)
      end

      it 'reflects the disabled setting' do
        stub_application_setting(throttle_incident_management_notification_enabled: false)

        expect(request.labkit_facts).to include(setting_incident_management_notification: false)
      end
    end

    # The geo-JWT skips are exposed as an EE fact for the should_be_skipped
    # path/JWT decomposition (the EE geo skip rule matches it). It lives in the EE
    # classifier (not CE) because the two predicates are EE-only - referencing them
    # from CE would raise under FOSS.
    describe 'the verified_geo_request fact' do
      it 'is true for a verified Geo request' do
        allow(request).to receive(:verified_geo_request?).and_return(true)

        expect(request.labkit_facts).to include(verified_geo_request: true)
      end

      it 'is true for a geo-proxy workhorse request' do
        allow(request).to receive_messages(verified_geo_request?: false, geo_proxy_workhorse_request?: true)

        expect(request.labkit_facts).to include(verified_geo_request: true)
      end

      it 'is false for a normal request' do
        allow(request).to receive_messages(verified_geo_request?: false, geo_proxy_workhorse_request?: false)

        expect(request.labkit_facts).to include(verified_geo_request: false)
      end
    end
  end
end
