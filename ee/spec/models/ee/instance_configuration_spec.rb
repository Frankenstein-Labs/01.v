# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InstanceConfiguration, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- controller that is using that model is also not owned
  describe '#settings' do
    describe '#ai_gateway_url' do
      it 'returns ai gateway url' do
        expect(described_class.new.settings).to include(:ai_gateway_url)
      end
    end

    describe '#rate_limits' do
      before do
        Gitlab::CurrentSettings.current_application_settings.update!(
          throttle_incident_management_notification_enabled: true,
          throttle_incident_management_notification_per_period: 3600,
          throttle_incident_management_notification_period_in_seconds: 3600
        )
      end

      it 'returns incident management notification rate limit' do
        rate_limits = described_class.new.settings[:rate_limits]

        expect(rate_limits[:incident_management_notification]).to eq({
          enabled: true,
          requests_per_period: 3600,
          period_in_seconds: 3600
        })
      end
    end
  end
end
