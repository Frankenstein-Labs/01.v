# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Version, feature_category: :continuous_delivery do
  let_it_be(:artifact_source) { create(:cd_artifact_source) }

  describe 'associations' do
    it { is_expected.to belong_to(:artifact_source).required }
    it { is_expected.to have_many(:version_set_entries) }
  end

  describe '#environments' do
    let_it_be(:organization) { artifact_source.organization }
    let_it_be(:service) { artifact_source.service }
    let_it_be(:application) { service.application }
    let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:version_set_entry) do
      create(:cd_version_set_entry, version_set: version_set, version: version)
    end

    it 'returns the environments derived by .environments_for' do
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      environment = create(:cd_environment, organization: organization)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
      create(:cd_deployment, service: service, rollout_environment: rollout_environment)

      expect(version.environments).to contain_exactly(environment)
    end
  end

  describe '.environments_for' do
    let_it_be(:organization) { artifact_source.organization }
    let_it_be(:service) { artifact_source.service }
    let_it_be(:application) { service.application }
    let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:version_set_entry) do
      create(:cd_version_set_entry, version_set: version_set, version: version)
    end

    context 'when given no versions' do
      it 'returns an empty hash' do
        expect(described_class.environments_for([])).to eq({})
      end
    end

    context 'when the version has not been deployed to any environment' do
      it 'returns no environments for it' do
        expect(described_class.environments_for([version])).to eq(version.id => [])
      end
    end

    context 'when the version has never been added to any version_set' do
      it 'returns no environments for it without querying deployments' do
        version_without_entries = create(:cd_version, artifact_source: artifact_source, name: 'unreleased')

        expect(described_class.environments_for([version_without_entries]))
          .to eq(version_without_entries.id => [])
      end
    end

    context 'when the version has been deployed to environments' do
      it 'returns the distinct environments the version was deployed to' do
        rollout = create(:cd_rollout, version_set: version_set, application: application)
        staging = create(:cd_environment, :staging, organization: organization)
        production = create(:cd_environment, :production, organization: organization)
        staging_rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: staging,
          position: 1)
        production_rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: production,
          position: 2)
        create(:cd_deployment, service: service, rollout_environment: staging_rollout_environment)
        create(:cd_deployment, service: service, rollout_environment: production_rollout_environment)

        result = described_class.environments_for([version])

        expect(result[version.id]).to contain_exactly(staging, production)
      end

      it 'does not duplicate an environment deployed to multiple times' do
        environment = create(:cd_environment, organization: organization)
        # Only one non-terminal rollout is allowed per application at a time,
        # so the first rollout must reach a terminal state before the second
        # can be created.
        first_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-1')
        second_rollout = create(:cd_rollout, version_set: version_set, application: application)
        first_rollout_environment = create(:cd_rollout_environment, rollout: first_rollout, environment: environment)
        second_rollout_environment = create(:cd_rollout_environment, rollout: second_rollout,
          environment: environment)
        create(:cd_deployment, service: service, rollout_environment: first_rollout_environment)
        create(:cd_deployment, service: service, rollout_environment: second_rollout_environment)

        result = described_class.environments_for([version])

        expect(result[version.id]).to contain_exactly(environment)
      end
    end

    context 'when another version has been deployed to an environment' do
      it 'does not return that environment' do
        rollout = create(:cd_rollout, version_set: version_set, application: application)
        other_artifact_source = create(:cd_artifact_source, service: service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        create(:cd_version_set_entry, version_set: version_set, version: other_version)
        environment = create(:cd_environment, organization: organization)
        rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
        # Deploys a *different* service than the one under test, to a version_set
        # that does include the version under test's entry.
        other_service = create(:cd_service, application: application)
        create(:cd_deployment, service: other_service, rollout_environment: rollout_environment)

        result = described_class.environments_for([version])

        expect(result[version.id]).to eq([])
      end
    end

    context 'when a service has multiple artifact sources deployed together' do
      # Regression test: Cd::Deployment is per-service, not per-artifact-source,
      # so a service with several sources has several version_set_entries in the
      # same version_set but only ONE deployment row for that (service,
      # rollout_environment) pair. Any version belonging to any of that
      # service's sources must resolve the same environments once the service
      # is deployed, since deploying the service deploys all of its sources'
      # versions together.
      it "returns the environment for every one of the service's sources, not just the deployed entry's source" do
        other_artifact_source = create(:cd_artifact_source, service: service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        create(:cd_version_set_entry, version_set: version_set, version: other_version)

        rollout = create(:cd_rollout, version_set: version_set, application: application)
        environment = create(:cd_environment, organization: organization)
        rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
        create(:cd_deployment, service: service, rollout_environment: rollout_environment)

        result = described_class.environments_for([version, other_version])

        expect(result[version.id]).to contain_exactly(environment)
        expect(result[other_version.id]).to contain_exactly(environment)
      end
    end

    context 'when given multiple versions across different services' do
      it 'resolves environments for each version in a single query per distinct service' do
        # A separate application, since only one non-terminal rollout is
        # allowed per application at a time.
        other_application = create(:cd_application, organization: organization)
        other_service = create(:cd_service, application: other_application)
        other_artifact_source = create(:cd_artifact_source, service: other_service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        other_version_set = create(:cd_version_set, application: other_application)
        create(:cd_version_set_entry, version_set: other_version_set, version: other_version)

        rollout = create(:cd_rollout, version_set: version_set, application: application)
        environment = create(:cd_environment, organization: organization)
        rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
        create(:cd_deployment, service: service, rollout_environment: rollout_environment)

        other_rollout = create(:cd_rollout, version_set: other_version_set, application: other_application)
        other_environment = create(:cd_environment, organization: organization)
        other_rollout_environment = create(:cd_rollout_environment, rollout: other_rollout,
          environment: other_environment)
        create(:cd_deployment, service: other_service, rollout_environment: other_rollout_environment)

        result = nil
        # Two distinct services among the requested versions, so this should
        # execute a small, fixed number of queries (one to load the version
        # set entries, plus one per distinct service) rather than one query
        # per version.
        queries = ActiveRecord::QueryRecorder.new do
          result = described_class.environments_for([version, other_version])
        end

        expect(queries.count).to be <= 3
        expect(result[version.id]).to contain_exactly(environment)
        expect(result[other_version.id]).to contain_exactly(other_environment)
      end
    end
  end

  describe '.for_service_environments' do
    let_it_be(:organization) { artifact_source.organization }
    let_it_be(:service) { artifact_source.service }
    let_it_be(:application) { service.application }
    let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:version_set_entry) do
      create(:cd_version_set_entry, version_set: version_set, version: version)
    end

    let_it_be(:environment) { create(:cd_environment, organization: organization) }

    def deploy(service:, environment:, version_set:, rollout_state: :pending, started_at: nil)
      workflow_ref = rollout_state == :pending ? nil : "wf-#{SecureRandom.hex(4)}"
      rollout = create(:cd_rollout, version_set: version_set, application: version_set.application,
        state: rollout_state, workflow_ref: workflow_ref)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
      create(:cd_deployment, service: service, rollout_environment: rollout_environment, started_at: started_at)
    end

    context 'when given no pairs' do
      it 'returns an empty hash' do
        expect(described_class.for_service_environments([])).to eq({})
      end
    end

    context 'when the service has no deployment in the environment' do
      it 'returns no versions for that pair' do
        expect(described_class.for_service_environments([[service.id, environment.id]]))
          .to eq([service.id, environment.id] => [])
      end
    end

    context 'when the service is deployed in the environment' do
      it 'returns the version deployed there' do
        deploy(service: service, environment: environment, version_set: version_set)

        result = described_class.for_service_environments([[service.id, environment.id]])

        expect(result[[service.id, environment.id]]).to contain_exactly(version)
      end

      it 'accepts objects responding to service_id and environment_id' do
        deploy(service: service, environment: environment, version_set: version_set)
        health = create(:cd_service_environment_health, service: service, environment: environment)

        result = described_class.for_service_environments([health])

        expect(result[[service.id, environment.id]]).to contain_exactly(version)
      end
    end

    context 'when the service has multiple artifact sources deployed together' do
      it 'returns a version for every one of the service sources in the deployed version_set' do
        other_artifact_source = create(:cd_artifact_source, service: service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        create(:cd_version_set_entry, version_set: version_set, version: other_version)
        deploy(service: service, environment: environment, version_set: version_set)

        result = described_class.for_service_environments([[service.id, environment.id]])

        expect(result[[service.id, environment.id]]).to contain_exactly(version, other_version)
      end
    end

    context 'when the service has been deployed to the environment more than once' do
      it 'returns the versions from the most recent deployment' do
        newer_version = create(:cd_version, artifact_source: artifact_source, name: 'v2')
        newer_version_set = create(:cd_version_set, application: application)
        create(:cd_version_set_entry, version_set: newer_version_set, version: newer_version)

        deploy(service: service, environment: environment, version_set: version_set,
          rollout_state: :completed, started_at: 2.hours.ago)
        deploy(service: service, environment: environment, version_set: newer_version_set,
          rollout_state: :pending, started_at: 1.hour.ago)

        result = described_class.for_service_environments([[service.id, environment.id]])

        expect(result[[service.id, environment.id]]).to contain_exactly(newer_version)
      end
    end

    context 'when the service is deployed to two environments with different versions' do
      it 'returns the version deployed in each environment' do
        other_environment = create(:cd_environment, organization: organization)
        other_version = create(:cd_version, artifact_source: artifact_source, name: 'v2')
        other_version_set = create(:cd_version_set, application: application)
        create(:cd_version_set_entry, version_set: other_version_set, version: other_version)

        deploy(service: service, environment: environment, version_set: version_set,
          rollout_state: :completed)
        deploy(service: service, environment: other_environment, version_set: other_version_set,
          rollout_state: :completed)

        result = described_class.for_service_environments(
          [[service.id, environment.id], [service.id, other_environment.id]]
        )

        expect(result[[service.id, environment.id]]).to contain_exactly(version)
        expect(result[[service.id, other_environment.id]]).to contain_exactly(other_version)
      end
    end

    context 'when given pairs across multiple services' do
      it 'resolves versions in a fixed number of queries regardless of the number of services' do
        other_application = create(:cd_application, organization: organization)
        other_service = create(:cd_service, application: other_application)
        other_artifact_source = create(:cd_artifact_source, service: other_service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        other_version_set = create(:cd_version_set, application: other_application)
        create(:cd_version_set_entry, version_set: other_version_set, version: other_version)
        other_environment = create(:cd_environment, organization: organization)

        deploy(service: service, environment: environment, version_set: version_set)
        deploy(service: other_service, environment: other_environment, version_set: other_version_set)

        result = nil
        queries = ActiveRecord::QueryRecorder.new do
          result = described_class.for_service_environments(
            [[service.id, environment.id], [other_service.id, other_environment.id]]
          )
        end

        expect(queries.count).to be <= 4
        expect(result[[service.id, environment.id]]).to contain_exactly(version)
        expect(result[[other_service.id, other_environment.id]]).to contain_exactly(other_version)
      end
    end
  end

  describe 'validations' do
    subject { build(:cd_version, artifact_source: artifact_source) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }

    describe 'name format' do
      it { is_expected.to allow_value('my-version').for(:name) }
      it { is_expected.to allow_value('my_version').for(:name) }
      it { is_expected.to allow_value('MyVersion').for(:name) }
      it { is_expected.to allow_value('version1').for(:name) }
      it { is_expected.to allow_value('1version').for(:name) }
      it { is_expected.not_to allow_value('-version').for(:name) }
      it { is_expected.not_to allow_value('version-').for(:name) }
      it { is_expected.not_to allow_value('my version').for(:name) }
      it { is_expected.not_to allow_value('version/name').for(:name) }
      it { is_expected.not_to allow_value('version!').for(:name) }
      it { is_expected.to allow_value('v1.0.0').for(:name) }
      it { is_expected.not_to allow_value('.version').for(:name) }
      it { is_expected.not_to allow_value('version.').for(:name) }
    end

    it { is_expected.to validate_length_of(:digest).is_at_most(255) }
    it { is_expected.to validate_length_of(:reference).is_at_most(1024) }

    it 'enforces uniqueness of name scoped to artifact_source_id at the database level' do
      create(:cd_version, artifact_source: artifact_source, name: 'v1_0_0')

      expect { create(:cd_version, artifact_source: artifact_source, name: 'v1_0_0') }
        .to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end
  end

  describe 'sharding key' do
    subject { build(:cd_version, artifact_source: artifact_source) }

    it { is_expected.to populate_sharding_key(:organization_id).with(artifact_source.organization_id) }
  end
end
