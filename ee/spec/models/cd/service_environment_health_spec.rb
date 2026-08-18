# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ServiceEnvironmentHealth, feature_category: :continuous_delivery do
  let_it_be(:application) { create(:cd_application) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:environment) { create(:cd_environment) }

  describe 'factory' do
    it 'creates a valid service environment health using factory defaults' do
      expect(create(:cd_service_environment_health)).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:service).required }
    it { is_expected.to belong_to(:environment).required }
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'enums' do
    it 'defines health enum' do
      is_expected.to define_enum_for(:health).with_values(
        unknown: 0,
        healthy: 1,
        degraded: 2,
        failed: 3
      )
    end
  end

  describe 'validations' do
    subject { build(:cd_service_environment_health, service: service, environment: environment) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:observed_at) }

    it 'rejects a second health row for the same service and environment' do
      create(:cd_service_environment_health, service: service, environment: environment)

      duplicate = build(:cd_service_environment_health, service: service, environment: environment)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:environment_id]).to be_present
    end
  end

  describe 'sharding key' do
    subject { build(:cd_service_environment_health, service: service, environment: environment) }

    it { is_expected.to populate_sharding_key(:organization_id).with(service.organization_id) }
  end

  describe 'HEALTH_SEVERITY_ORDER' do
    it 'assigns a severity rank to every known health value' do
      expect(described_class::HEALTH_SEVERITY_ORDER).to match_array(described_class.healths.keys)
    end
  end

  describe '.ordered_by_severity' do
    it 'orders failed, degraded, healthy, unknown from worst to best' do
      healthy_env = create(:cd_environment, organization: application.organization)
      degraded_env = create(:cd_environment, organization: application.organization)
      failed_env = create(:cd_environment, organization: application.organization)
      unknown_env = create(:cd_environment, organization: application.organization)

      healthy = create(:cd_service_environment_health, service: service, environment: healthy_env, health: :healthy)
      degraded = create(:cd_service_environment_health, service: service, environment: degraded_env,
        health: :degraded)
      failed = create(:cd_service_environment_health, service: service, environment: failed_env, health: :failed)
      unknown = create(:cd_service_environment_health, service: service, environment: unknown_env, health: :unknown)

      expect(described_class.where(service: service).ordered_by_severity)
        .to eq([failed, degraded, healthy, unknown])
    end

    context 'when a row has a health value not present in HEALTH_SEVERITY_ORDER' do
      it 'sorts it after all known values' do
        stub_const('Cd::ServiceEnvironmentHealth::HEALTH_SEVERITY_ORDER', %w[failed])

        failed_env = create(:cd_environment, organization: application.organization)
        healthy_env = create(:cd_environment, organization: application.organization)

        failed = create(:cd_service_environment_health, service: service, environment: failed_env, health: :failed)
        healthy = create(:cd_service_environment_health, service: service, environment: healthy_env,
          health: :healthy)

        expect(described_class.where(service: service).ordered_by_severity).to eq([failed, healthy])
      end
    end
  end

  describe '.worst_health_by_application' do
    let_it_be(:other_application) { create(:cd_application) }

    def report_health(target_service, health)
      create(:cd_service_environment_health,
        service: target_service,
        environment: create(:cd_environment, organization: target_service.organization),
        health: health)
    end

    it 'returns the worst health across each application, keyed by application id' do
      degraded_service = create(:cd_service, application: application)
      report_health(service, :healthy)
      report_health(degraded_service, :degraded)
      report_health(create(:cd_service, application: other_application), :failed)

      expect(described_class.worst_health_by_application([application.id, other_application.id]))
        .to eq(application.id => 'degraded', other_application.id => 'failed')
    end

    it 'omits applications with no reported health' do
      expect(described_class.worst_health_by_application([application.id])).to eq({})
    end

    context 'with unknown health' do
      it 'does not let unknown override a known health signal' do
        report_health(service, :healthy)
        report_health(create(:cd_service, application: application), :unknown)

        expect(described_class.worst_health_by_application([application.id]))
          .to eq(application.id => 'healthy')
      end

      it 'rolls up to unknown only when every service is unknown' do
        report_health(service, :unknown)
        report_health(create(:cd_service, application: application), :unknown)

        expect(described_class.worst_health_by_application([application.id]))
          .to eq(application.id => 'unknown')
      end
    end
  end

  describe '.applications_count_by_environment' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment_a) { create(:cd_environment, organization: organization) }
    let_it_be(:environment_b) { create(:cd_environment, organization: organization) }
    let_it_be(:empty_environment) { create(:cd_environment, organization: organization) }
    let_it_be(:app1) { create(:cd_application, organization: organization) }
    let_it_be(:app2) { create(:cd_application, organization: organization) }

    before_all do
      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_a)
      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_a)
      create(:cd_service_environment_health, service: create(:cd_service, application: app2),
        environment: environment_a)

      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_b)
    end

    it 'returns the distinct application count per environment, keyed by environment id' do
      result = described_class.applications_count_by_environment(
        [environment_a.id, environment_b.id, empty_environment.id]
      )

      expect(result).to eq(environment_a.id => 2, environment_b.id => 1)
    end

    it 'omits environments with no services' do
      expect(described_class.applications_count_by_environment([empty_environment.id])).to eq({})
    end
  end

  describe '.service_environment_healths_by_application' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }
    let_it_be(:other_environment) { create(:cd_environment, organization: organization) }
    let_it_be(:empty_environment) { create(:cd_environment, organization: organization) }
    let_it_be(:zebra_app) { create(:cd_application, organization: organization, name: 'zebra') }
    let_it_be(:alpha_app) { create(:cd_application, organization: organization, name: 'alpha') }
    let_it_be(:alpha_api) { create(:cd_service, application: alpha_app, name: 'api') }
    let_it_be(:alpha_worker) { create(:cd_service, application: alpha_app, name: 'worker') }
    let_it_be(:zebra_web) { create(:cd_service, application: zebra_app, name: 'web') }

    before_all do
      create(:cd_service_environment_health, service: alpha_worker, environment: environment)
      create(:cd_service_environment_health, service: alpha_api, environment: environment)
      create(:cd_service_environment_health, service: zebra_web, environment: environment)

      # A service of alpha_app in a different environment must not appear here.
      create(:cd_service_environment_health, service: create(:cd_service, application: alpha_app),
        environment: other_environment)
    end

    it 'returns health rows grouped by application, ordered by application then service name' do
      result = described_class.service_environment_healths_by_application(environment)

      expect(result.keys).to eq([alpha_app.id, zebra_app.id])
      expect(result[alpha_app.id].map(&:service)).to eq([alpha_api, alpha_worker])
      expect(result[zebra_app.id].map(&:service)).to eq([zebra_web])
    end

    it 'returns an empty hash for an environment with no services' do
      expect(described_class.service_environment_healths_by_application(empty_environment)).to eq({})
    end
  end

  describe '.services_count_by_environment' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment_a) { create(:cd_environment, organization: organization) }
    let_it_be(:environment_b) { create(:cd_environment, organization: organization) }
    let_it_be(:empty_environment) { create(:cd_environment, organization: organization) }
    let_it_be(:app1) { create(:cd_application, organization: organization) }
    let_it_be(:app2) { create(:cd_application, organization: organization) }

    before_all do
      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_a)
      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_a)
      create(:cd_service_environment_health, service: create(:cd_service, application: app2),
        environment: environment_a)

      create(:cd_service_environment_health, service: create(:cd_service, application: app1),
        environment: environment_b)
    end

    it 'returns the service count per environment, keyed by environment id' do
      result = described_class.services_count_by_environment(
        [environment_a.id, environment_b.id, empty_environment.id]
      )

      expect(result).to eq(environment_a.id => 3, environment_b.id => 1)
    end

    it 'omits environments with no services' do
      expect(described_class.services_count_by_environment([empty_environment.id])).to eq({})
    end
  end
end
