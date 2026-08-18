# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Application, feature_category: :continuous_delivery do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to have_many(:services) }
    it { is_expected.to have_many(:version_sets) }
    it { is_expected.to have_many(:rollouts) }
    it { is_expected.to have_many(:application_flow_definitions) }

    it 'orders application_flow_definitions by version descending' do
      application = create(:cd_application)
      # Created in ascending version order so the assertion proves the
      # association returns them version-descending.
      first = create(:cd_application_flow_definition, application: application)
      second = create(:cd_application_flow_definition, application: application)

      expect(application.application_flow_definitions).to eq([second, first])
    end
  end

  describe 'validations' do
    subject { create(:cd_application) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:organization_id) }

    describe 'name format' do
      it { is_expected.to allow_value('my-app').for(:name) }
      it { is_expected.to allow_value('my_app').for(:name) }
      it { is_expected.to allow_value('MyApp').for(:name) }
      it { is_expected.to allow_value('app1').for(:name) }
      it { is_expected.to allow_value('1app').for(:name) }
      it { is_expected.not_to allow_value('-app').for(:name) }
      it { is_expected.not_to allow_value('app-').for(:name) }
      it { is_expected.not_to allow_value('my app').for(:name) }
      it { is_expected.not_to allow_value('app/name').for(:name) }
      it { is_expected.not_to allow_value('app.name').for(:name) }
      it { is_expected.not_to allow_value('app!').for(:name) }
    end

    it { is_expected.to validate_length_of(:description).is_at_most(2000) }

    describe 'sharding key' do
      it 'is invalid without an organization' do
        application = build(:cd_application, organization: nil)

        expect(application).not_to be_valid
      end
    end
  end

  describe '.for_organization' do
    it 'returns applications belonging to the given organization' do
      application = create(:cd_application)
      create(:cd_application)

      expect(described_class.for_organization(application.organization_id)).to contain_exactly(application)
    end
  end

  describe '.in_organization' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:org_application) { create(:cd_application, organization: organization) }
    let_it_be(:other_org_application) { create(:cd_application, organization: other_organization) }

    it 'returns applications belonging to the organization' do
      expect(described_class.in_organization(organization)).to contain_exactly(org_application)
    end
  end

  describe '.search' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:payments) do
      create(:cd_application, organization: organization, name: 'payments-platform',
        description: 'Handles billing and invoices')
    end

    let_it_be(:web) do
      create(:cd_application, organization: organization, name: 'web-frontend',
        description: 'Customer facing UI')
    end

    def search(term)
      described_class.in_organization(organization).search(term)
    end

    it 'matches on name' do
      expect(search('payments')).to contain_exactly(payments)
    end

    it 'matches on description' do
      expect(search('invoices')).to contain_exactly(payments)
    end

    it 'is case-insensitive' do
      expect(search('PAYMENTS')).to contain_exactly(payments)
    end

    it 'returns nothing when nothing matches' do
      expect(search('nonexistent')).to be_empty
    end

    it 'treats LIKE wildcards as literal characters rather than matching everything' do
      expect(search('%')).to be_empty
    end
  end

  describe '#environments' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:application) { create(:cd_application, organization: organization) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }

    context 'when the application has no rollouts' do
      it 'returns no environments' do
        expect(application.environments).to be_empty
      end
    end

    context 'when the application has rolled out to environments' do
      it 'returns the distinct environments targeted by its rollouts' do
        staging = create(:cd_environment, :staging, organization: organization)
        production = create(:cd_environment, :production, organization: organization)
        rollout = create(:cd_rollout, version_set: version_set, application: application)
        create(:cd_rollout_environment, rollout: rollout, environment: staging, position: 1)
        create(:cd_rollout_environment, rollout: rollout, environment: production, position: 2)

        expect(application.environments).to contain_exactly(staging, production)
      end

      it 'does not duplicate an environment targeted by multiple rollouts' do
        environment = create(:cd_environment, organization: organization)
        # Only one non-terminal rollout is allowed per application at a time,
        # so the first rollout must reach a terminal state before the second
        # can be created.
        first_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-1')
        second_rollout = create(:cd_rollout, version_set: version_set, application: application)
        create(:cd_rollout_environment, rollout: first_rollout, environment: environment)
        create(:cd_rollout_environment, rollout: second_rollout, environment: environment)

        expect(application.environments).to contain_exactly(environment)
      end
    end

    context 'when another application has rolled out to an environment' do
      it 'does not return that environment' do
        other_application = create(:cd_application, organization: organization)
        other_version_set = create(:cd_version_set, application: other_application)
        environment = create(:cd_environment, organization: organization)
        other_rollout = create(:cd_rollout, version_set: other_version_set, application: other_application)
        create(:cd_rollout_environment, rollout: other_rollout, environment: environment)

        expect(application.environments).to be_empty
      end
    end

    context 'when the application has more rollouts than RECENT_ROLLOUTS_LIMIT' do
      it 'ignores environments only targeted by rollouts outside the limit' do
        stub_const('Cd::Application::RECENT_ROLLOUTS_LIMIT', 2)

        old_environment = create(:cd_environment, organization: organization)
        recent_environment = create(:cd_environment, organization: organization)

        old_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-1')
        create(:cd_rollout_environment, rollout: old_rollout, environment: old_environment)
        create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-2')
        create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-3')
        recent_rollout = create(:cd_rollout, version_set: version_set, application: application)
        create(:cd_rollout_environment, rollout: recent_rollout, environment: recent_environment)

        expect(application.environments).to contain_exactly(recent_environment)
      end
    end
  end

  describe '#deployments' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:application) { create(:cd_application, organization: organization) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }
    let_it_be(:service) { create(:cd_service, application: application) }

    context 'when the application has no deployments' do
      it 'returns none' do
        expect(application.deployments).to be_empty
      end
    end

    context 'when the application has deployments across its rollouts' do
      it 'returns all deployments for the application' do
        rollout = create(:cd_rollout, version_set: version_set, application: application)
        rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
        deployment = create(:cd_deployment, service: service, rollout_environment: rollout_environment)

        expect(application.deployments).to contain_exactly(deployment)
      end
    end

    context 'when another application has deployments' do
      it 'does not return that deployment' do
        other_application = create(:cd_application, organization: organization)
        other_version_set = create(:cd_version_set, application: other_application)
        other_service = create(:cd_service, application: other_application)
        other_rollout = create(:cd_rollout, version_set: other_version_set, application: other_application)
        other_rollout_environment = create(:cd_rollout_environment, rollout: other_rollout, environment: environment)
        create(:cd_deployment, service: other_service, rollout_environment: other_rollout_environment)

        expect(application.deployments).to be_empty
      end
    end

    context 'when the application has more rollouts than RECENT_ROLLOUTS_LIMIT' do
      it 'ignores deployments from rollouts outside the limit' do
        stub_const('Cd::Application::RECENT_ROLLOUTS_LIMIT', 1)

        old_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-1')
        old_rollout_environment = create(:cd_rollout_environment, rollout: old_rollout, environment: environment)
        create(:cd_deployment, service: service, rollout_environment: old_rollout_environment)

        recent_rollout = create(:cd_rollout, version_set: version_set, application: application)
        recent_rollout_environment = create(:cd_rollout_environment, rollout: recent_rollout, environment: environment)
        recent_deployment = create(:cd_deployment, service: service, rollout_environment: recent_rollout_environment)

        expect(application.deployments).to contain_exactly(recent_deployment)
      end
    end
  end

  describe '#last_deployed_at' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:application) { create(:cd_application, organization: organization) }
    let_it_be(:version_set) { create(:cd_version_set, application: application) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }
    let_it_be(:service) { create(:cd_service, application: application) }

    context 'when the application has no deployments' do
      it 'returns nil' do
        expect(application.last_deployed_at).to be_nil
      end
    end

    context 'when the application has multiple finished deployments' do
      it 'returns the most recent finished_at timestamp' do
        rollout = create(:cd_rollout, version_set: version_set, application: application)
        rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
        other_environment = create(:cd_environment, organization: organization)
        other_rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: other_environment)
        create(:cd_deployment, service: service, rollout_environment: rollout_environment,
          finished_at: 2.days.ago)
        most_recent = create(:cd_deployment, service: service, rollout_environment: other_rollout_environment,
          finished_at: 1.hour.ago)

        expect(application.last_deployed_at).to be_within(1.second).of(most_recent.finished_at)
      end
    end

    context 'when the most recently finished deployment belongs to a rollout outside RECENT_ROLLOUTS_LIMIT' do
      it 'ignores it' do
        stub_const('Cd::Application::RECENT_ROLLOUTS_LIMIT', 1)

        old_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'wf-1')
        old_rollout_environment = create(:cd_rollout_environment, rollout: old_rollout, environment: environment)
        create(:cd_deployment, service: service, rollout_environment: old_rollout_environment,
          finished_at: 1.minute.ago)

        recent_rollout = create(:cd_rollout, version_set: version_set, application: application)
        recent_rollout_environment = create(:cd_rollout_environment, rollout: recent_rollout, environment: environment)
        create(:cd_deployment, service: service, rollout_environment: recent_rollout_environment, finished_at: nil)

        expect(application.last_deployed_at).to be_nil
      end
    end
  end

  describe '#next_rollout_iid!' do
    let(:application) { create(:cd_application) }

    it 'returns the next number on each call' do
      expect([application.next_rollout_iid!, application.next_rollout_iid!]).to eq([1, 2])
    end

    it 'persists the counter to last_rollout_iid' do
      application.next_rollout_iid!

      expect(application.reload.last_rollout_iid).to eq(1)
    end
  end

  describe '.with_worst_health' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }

    def app_with_service_healths(*healths)
      application = create(:cd_application, organization: organization)
      healths.each do |health|
        create(:cd_service_environment_health,
          service: create(:cd_service, application: application), environment: environment, health: health)
      end
      application
    end

    it 'matches applications whose worst service health equals the value' do
      healthy = app_with_service_healths(:healthy, :unknown)
      degraded = app_with_service_healths(:healthy, :degraded)
      failed = app_with_service_healths(:degraded, :failed)

      expect(described_class.with_worst_health('healthy', organization: organization)).to contain_exactly(healthy)
      expect(described_class.with_worst_health('degraded', organization: organization)).to contain_exactly(degraded)
      expect(described_class.with_worst_health('healthy', organization: organization)).not_to include(failed)
      expect(described_class.with_worst_health('degraded', organization: organization)).not_to include(failed)
    end

    it 'ignores applications with no reported health' do
      app_with_service_healths

      expect(described_class.with_worst_health('healthy', organization: organization)).to be_empty
    end

    it 'ignores health reported for applications in another organization' do
      other_organization = create(:organization)
      other_environment = create(:cd_environment, organization: other_organization)
      other_application = create(:cd_application, organization: other_organization)
      create(:cd_service_environment_health,
        service: create(:cd_service, application: other_application), environment: other_environment,
        health: :healthy)

      expect(described_class.with_worst_health('healthy', organization: organization)).to be_empty
    end
  end

  describe '.deploying' do
    let_it_be(:organization) { create(:organization) }

    it 'matches only applications with a rollout in progress' do
      deploying = create(:cd_rollout, state: :in_progress, workflow_ref: 'workflow-1',
        version_set: create(:cd_version_set, application: create(:cd_application, organization: organization))
      ).application
      create(:cd_rollout, state: :completed, workflow_ref: 'workflow-1')

      expect(described_class.deploying(organization: organization)).to contain_exactly(deploying)
    end

    it 'ignores rollouts in progress for applications in another organization' do
      other_organization = create(:organization)
      create(:cd_rollout, state: :in_progress, workflow_ref: 'workflow-1',
        version_set: create(:cd_version_set, application: create(:cd_application, organization: other_organization)))

      expect(described_class.deploying(organization: organization)).to be_empty
    end
  end

  describe '.with_statuses' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }

    let_it_be(:degraded_app) do
      app = create(:cd_application, organization: organization)
      create(:cd_service_environment_health, service: create(:cd_service, application: app),
        environment: environment, health: :degraded)
      app
    end

    let_it_be(:deploying_app) do
      app = create(:cd_application, organization: organization)
      create(:cd_rollout, version_set: create(:cd_version_set, application: app),
        state: :in_progress, workflow_ref: 'workflow-1')
      app
    end

    it 'returns applications matching a single backed status' do
      expect(described_class.with_statuses(%w[degraded], organization: organization)).to contain_exactly(degraded_app)
    end

    it 'unions backed statuses and ignores unbacked ones' do
      expect(described_class.with_statuses(%w[degraded deploying awaiting_approval], organization: organization))
        .to contain_exactly(degraded_app, deploying_app)
    end

    it 'returns none when every requested status is unbacked' do
      expect(described_class.with_statuses(%w[awaiting_approval], organization: organization)).to be_empty
    end

    it 'ignores matches belonging to another organization' do
      other_organization = create(:organization)
      other_environment = create(:cd_environment, organization: other_organization)
      other_app = create(:cd_application, organization: other_organization)
      create(:cd_service_environment_health, service: create(:cd_service, application: other_app),
        environment: other_environment, health: :degraded)

      expect(described_class.with_statuses(%w[degraded], organization: other_organization))
        .to contain_exactly(other_app)
    end
  end

  describe '.statuses_by_id' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }

    def app_with_service_health(health)
      application = create(:cd_application, organization: organization)
      create(:cd_service_environment_health,
        service: create(:cd_service, application: application), environment: environment, health: health)
      application
    end

    def app_with_rollout_in_progress
      application = create(:cd_application, organization: organization)
      create(:cd_rollout, version_set: create(:cd_version_set, application: application),
        state: :in_progress, workflow_ref: 'workflow-1')
      application
    end

    it 'returns degraded for an application whose worst service health is degraded' do
      degraded = app_with_service_health(:degraded)

      expect(described_class.statuses_by_id([degraded.id])).to eq(degraded.id => 'degraded')
    end

    it 'returns healthy for an application whose worst service health is healthy' do
      healthy = app_with_service_health(:healthy)

      expect(described_class.statuses_by_id([healthy.id])).to eq(healthy.id => 'healthy')
    end

    it 'returns deploying for an application with a rollout in progress' do
      deploying = app_with_rollout_in_progress

      expect(described_class.statuses_by_id([deploying.id])).to eq(deploying.id => 'deploying')
    end

    it 'prefers degraded over an in-progress rollout' do
      application = app_with_service_health(:degraded)
      create(:cd_rollout, version_set: create(:cd_version_set, application: application),
        state: :in_progress, workflow_ref: 'workflow-1')

      expect(described_class.statuses_by_id([application.id])).to eq(application.id => 'degraded')
    end

    it 'prefers an in-progress rollout over a healthy rollup' do
      application = app_with_service_health(:healthy)
      create(:cd_rollout, version_set: create(:cd_version_set, application: application),
        state: :in_progress, workflow_ref: 'workflow-1')

      expect(described_class.statuses_by_id([application.id])).to eq(application.id => 'deploying')
    end

    it 'omits applications with no reported health and no rollout in progress' do
      application = create(:cd_application, organization: organization)

      expect(described_class.statuses_by_id([application.id])).to be_empty
    end

    it 'omits applications whose worst health is failed or unknown' do
      failed = app_with_service_health(:failed)
      unknown = app_with_service_health(:unknown)

      expect(described_class.statuses_by_id([failed.id, unknown.id])).to be_empty
    end
  end
end
