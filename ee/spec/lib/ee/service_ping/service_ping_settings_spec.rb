# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServicePing::ServicePingSettings, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  describe '#enabled_and_consented?' do
    where(
      :usage_ping_enabled,
      :customer_service_enabled,
      :requires_usage_stats_consent,
      :offline_cloud_license,
      :expected_enabled_and_consented
    ) do
      # Online cloud licenses: operational metrics forces ping regardless of admin toggle
      true  | true  | false | false | true
      false | true  | true  | false | false
      false | true  | false | false | true
      true  | true  | true  | false | false

      # Offline cloud licenses: operational metrics does NOT force, admin toggle respected
      true  | true  | false | true  | true
      false | true  | true  | true  | false
      false | true  | false | true  | false
      true  | true  | true  | true  | false

      # License disabled operational metrics (same for online/offline)
      true  | false | false | false | true
      true  | false | true  | false | false
      false | false | false | false | false
      false | false | true  | false | false

      true  | false | false | true  | true
      true  | false | true  | true  | false
      false | false | false | true  | false
      false | false | true  | true  | false

      # When there is no license it should have same behaviour as CE
      true  | nil | false | nil | true
      false | nil | false | nil | false
      false | nil | true  | nil | false
      true  | nil | true  | nil | false
    end

    with_them do
      before do
        allow(User).to receive(:single_user)
          .and_return(instance_double(User, :user, requires_usage_stats_consent?: requires_usage_stats_consent))
        stub_config_setting(usage_ping_enabled: usage_ping_enabled)

        unless customer_service_enabled.nil?
          create_current_license(
            cloud_licensing_enabled: true,
            offline_cloud_licensing_enabled: offline_cloud_license,
            operational_metrics_enabled: customer_service_enabled
          )
        end
      end

      it 'has the correct enabled_and_consented?' do
        expect(described_class.enabled_and_consented?).to eq(expected_enabled_and_consented)
      end
    end
  end

  describe '#license_operational_metric_enabled?' do
    where(:customer_service_enabled, :offline_cloud_license, :expected_license_operational_metric_enabled) do
      # Online cloud licenses: license forces operational metric when enabled
      true  | false | true
      false | false | false

      # Offline cloud licenses: license never forces; admin toggle is honored
      true  | true  | false
      false | true  | false
    end

    with_them do
      before do
        create_current_license(
          cloud_licensing_enabled: true,
          offline_cloud_licensing_enabled: offline_cloud_license,
          operational_metrics_enabled: customer_service_enabled
        )
      end

      it 'returns the correct value for license_operational_metric_enabled?' do
        expect(described_class.license_operational_metric_enabled?).to eq(expected_license_operational_metric_enabled)
      end
    end
  end

  describe '#enabled?' do
    where(:usage_ping_enabled, :customer_service_enabled, :offline_cloud_license, :expected_enabled) do
      # Online cloud: license can force ping on when operational metrics enabled
      true  | true  | false | true
      false | true  | false | true
      true  | false | false | true
      false | false | false | false

      # Offline cloud: admin toggle is load-bearing, license cannot force-enable
      true  | true  | true  | true
      false | true  | true  | false
      true  | false | true  | true
      false | false | true  | false
    end

    with_them do
      before do
        stub_config_setting(usage_ping_enabled: usage_ping_enabled)
        create_current_license(
          cloud_licensing_enabled: true,
          offline_cloud_licensing_enabled: offline_cloud_license,
          operational_metrics_enabled: customer_service_enabled
        )
      end

      it 'has the correct enabled?' do
        expect(described_class.enabled?).to eq(expected_enabled)
      end
    end
  end
end
