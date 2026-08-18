# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::CreateService, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:production) { create(:cd_environment, organization: organization, name: 'production') }
  let_it_be(:production_binding) { create(:cd_environment_driver_binding, environment: production) }

  let!(:flow_definition) do
    create(:cd_application_flow_definition, application: application, definition: production_deploy_yaml)
  end

  let(:params) do
    {
      version_set: version_set
    }
  end

  subject(:result) do
    described_class.new(parent: organization, current_user: current_user, params: params).execute
  end

  def deploy_yaml(*environment_names)
    environments = environment_names.index_with do |name|
      {
        'services' => {
          'web' => {
            'namespace' => 'argocd',
            'application' => "web-#{name}",
            'manifest_repository' => {
              'type' => 'gitlab',
              'host' => 'https://gitlab.example.com',
              'project' => 'group/gitops',
              'branch' => 'main',
              'manifests_path' => 'manifests'
            }
          }
        }
      }
    end

    steps = environment_names.each_with_index.map do |name, index|
      {
        'type' => 'com.gitlab.cd.steps.stage',
        'name' => "stage-#{index}",
        'steps' => [
          {
            'type' => 'com.gitlab.cd.argo.rolling.deploy',
            'environment' => name,
            'services' => [{ 'name' => 'web' }]
          }
        ]
      }
    end

    YAML.dump('environments' => environments, 'steps' => steps)
  end

  def production_deploy_yaml
    deploy_yaml('production')
  end

  describe '#execute' do
    it 'creates the rollout' do
      expect { result }.to change { ::Cd::Rollout.count }.by(1)

      rollout = result.payload[:rollout]
      expect(result).to be_success
      expect(rollout).to be_persisted
      expect(rollout).to have_attributes(
        organization: organization,
        application: application,
        version_set: version_set,
        application_flow_definition: flow_definition
      )
    end

    it 'assigns a per-application iid to the rollout' do
      expect(result.payload[:rollout].iid).to eq(1)
    end

    it 'creates one pending rollout step per node in the flow definition tree', :aggregate_failures do
      rollout = result.payload[:rollout]
      rollout_environment = rollout.rollout_environments.sole

      expect(rollout.rollout_steps.map(&:step_type)).to contain_exactly(
        'com.gitlab.cd.steps.stage', 'com.gitlab.cd.argo.rolling.deploy'
      )
      expect(rollout.rollout_steps).to all(be_pending)

      deploy_step = rollout.rollout_steps.find_by(step_type: 'com.gitlab.cd.argo.rolling.deploy')
      expect(deploy_step.rollout_environment).to eq(rollout_environment)
      expect(deploy_step.params).to eq('services' => [{ 'name' => 'web' }])

      stage_step = rollout.rollout_steps.find_by(step_type: 'com.gitlab.cd.steps.stage')
      expect(stage_step.rollout_environment).to be_nil
      expect(stage_step.name).to eq('stage-0')
    end

    context 'when persisting rollout steps fails' do
      before do
        allow(::Cd::RolloutStep).to receive(:bulk_insert!)
          .and_raise(ActiveRecord::RecordInvalid.new(::Cd::RolloutStep.new))
      end

      it 'rolls back the whole rollout, including its environments and deployments' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(::Cd::RolloutEnvironment.count).to eq(0)
      end
    end

    it 'records the initial transition journal entry attributing the rollout to the current user' do
      rollout = result.payload[:rollout]

      expect(rollout.rollout_transitions.count).to eq(1)
      expect(rollout.rollout_transitions.first).to have_attributes(
        event: 'create',
        from_state: 'initial',
        to_state: 'pending',
        principal: "user:#{current_user.id}"
      )
    end

    context 'when current_user is not provided' do
      subject(:result) do
        described_class.new(parent: organization, current_user: nil, params: params).execute
      end

      it 'creates the rollout without an initial transition journal entry', :aggregate_failures do
        expect { result }.to change { ::Cd::Rollout.count }.by(1)

        rollout = result.payload[:rollout]
        expect(result).to be_success
        expect(rollout.rollout_transitions).to be_empty
      end
    end

    context 'when the application has multiple flow definitions' do
      let!(:newer_flow_definition) do
        create(:cd_application_flow_definition, application: application, definition: production_deploy_yaml)
      end

      it 'assigns the latest application flow definition' do
        rollout = result.payload[:rollout]

        expect(rollout.application_flow_definition).to eq(newer_flow_definition)
      end
    end

    context 'when the application has no flow definition' do
      let_it_be(:application) { create(:cd_application, organization: organization) }
      let_it_be(:version_set) { create(:cd_version_set, application: application) }
      let(:flow_definition) { nil }

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/requires at least one environment/i))
      end
    end

    context 'when no step in the flow definition names an environment' do
      let!(:flow_definition) do
        create(:cd_application_flow_definition, application: application, definition: <<~YAML)
          steps:
            - type: com.gitlab.cd.steps.wait
              seconds: 0
        YAML
      end

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/requires at least one environment/i))
      end
    end

    it 'enqueues the kickoff worker for the created rollout' do
      expect(::Cd::Rollouts::StartWorker).to receive(:perform_async).with(kind_of(Integer))

      result
    end

    context 'when the version set has entries' do
      let_it_be(:web_service) { create(:cd_service, application: application) }
      let_it_be(:worker_service) { create(:cd_service, application: application) }

      let(:version_set) do
        create(:cd_version_set, application: application).tap do |set|
          [web_service, worker_service].each do |service|
            artifact_source = create(:cd_artifact_source, service: service)
            version = create(:cd_version, artifact_source: artifact_source)
            create(:cd_version_set_entry, version_set: set, version: version)
          end
        end
      end

      it 'creates one pending deployment per service in each rollout environment' do
        rollout = result.payload[:rollout]
        rollout_environment = rollout.rollout_environments.sole

        expect(rollout_environment.deployments.map(&:service)).to contain_exactly(web_service, worker_service)
        expect(rollout_environment.deployments).to all(be_pending)
      end

      it 'leaves the rollout environment in the pending state' do
        rollout_environment = result.payload[:rollout].rollout_environments.sole

        expect(rollout_environment).to be_pending
      end

      it 'journals a creation transition per deployment, attributed to the requesting user', :aggregate_failures do
        rollout_environment = result.payload[:rollout].rollout_environments.sole
        transitions = ::Cd::DeploymentTransition.where(deployment: rollout_environment.deployments)

        expect(transitions.count).to eq(2)
        expect(transitions).to all(have_attributes(
          event: 'create',
          from_state: 'initial',
          to_state: 'pending',
          principal: "user:#{current_user.id}"
        ))
      end
    end

    context 'when there is no requesting user' do
      let(:current_user) { nil }

      let(:version_set) do
        create(:cd_version_set, application: application).tap do |set|
          service = create(:cd_service, application: application)
          artifact_source = create(:cd_artifact_source, service: service)
          version = create(:cd_version, artifact_source: artifact_source)
          create(:cd_version_set_entry, version_set: set, version: version)
        end
      end

      it 'creates the deployments but journals no creation transition' do
        rollout_environment = result.payload[:rollout].rollout_environments.sole

        expect(rollout_environment.deployments).not_to be_empty
        expect(::Cd::DeploymentTransition.where(deployment: rollout_environment.deployments)).to be_empty
      end
    end

    context 'when a service has more than one artifact source in the version set' do
      let_it_be(:service) { create(:cd_service, application: application) }

      let(:version_set) do
        create(:cd_version_set, application: application).tap do |set|
          2.times do
            artifact_source = create(:cd_artifact_source, service: service)
            version = create(:cd_version, artifact_source: artifact_source)
            create(:cd_version_set_entry, version_set: set, version: version)
          end
        end
      end

      it 'creates exactly one deployment for that service' do
        rollout_environment = result.payload[:rollout].rollout_environments.sole

        expect(rollout_environment.deployments.map(&:service)).to contain_exactly(service)
      end
    end

    context 'when the version set has no entries' do
      it 'creates no deployments' do
        rollout_environment = result.payload[:rollout].rollout_environments.sole

        expect(rollout_environment.deployments).to be_empty
      end
    end

    context 'when the flow definition references environments by name' do
      let_it_be(:staging) { create(:cd_environment, organization: organization, name: 'staging') }
      let_it_be(:staging_binding) { create(:cd_environment_driver_binding, environment: staging) }

      let!(:flow_definition) do
        create(:cd_application_flow_definition, application: application,
          definition: deploy_yaml('production', 'production', 'staging'))
      end

      it 'creates one rollout environment per distinct referenced environment, ordered by first appearance',
        :aggregate_failures do
        rollout = result.payload[:rollout]

        expect(result).to be_success
        expect(rollout.rollout_environments.order(:position).map(&:environment)).to eq([production, staging])
      end

      it 'assigns the latest driver binding for the environment' do
        newer_binding = create(:cd_environment_driver_binding, environment: production)

        rollout = result.payload[:rollout]

        expect(rollout.rollout_environments.order(:position).first.driver_binding).to eq(newer_binding)
      end
    end

    context 'when a step references an environment that does not exist' do
      let!(:flow_definition) do
        create(:cd_application_flow_definition, application: application, definition: <<~YAML)
          steps:
            - type: com.gitlab.cd.steps.stage
              name: canary
              steps:
                - type: com.gitlab.cd.argo.rolling.deploy
                  environment: "nonexistent-environment"
                  services:
                    - name: web
        YAML
      end

      it 'does not create a rollout and returns an error naming the unknown environment' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/unknown environment 'nonexistent-environment'/i))
      end
    end

    context 'when the flow definition is unparseable' do
      let!(:flow_definition) do
        create(:cd_application_flow_definition, application: application).tap do |fd|
          fd.file.store!(CarrierWaveStringFile.new('steps: ['))
        end
      end

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/unparseable/i))
      end
    end

    context 'when the flow definition does not parse to a mapping' do
      let!(:flow_definition) do
        create(:cd_application_flow_definition, application: application).tap do |fd|
          fd.file.store!(CarrierWaveStringFile.new("- production\n- staging\n"))
        end
      end

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/requires at least one environment/i))
      end
    end

    context 'when the version set is missing' do
      let(:params) { super().merge(version_set: nil) }

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
      end
    end

    context 'when the version set belongs to another organization' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:other_application) { create(:cd_application, organization: other_organization) }
      let_it_be(:other_version_set) { create(:cd_version_set, application: other_application) }

      let(:params) { super().merge(version_set: other_version_set) }

      it 'does not create a rollout and returns an error' do
        expect { result }.not_to change { ::Cd::Rollout.count }

        expect(result).to be_error
        expect(result.message).to include(a_string_matching(/do not belong to the organization/i))
      end

      it 'does not enqueue the kickoff worker' do
        expect(::Cd::Rollouts::StartWorker).not_to receive(:perform_async)

        result
      end
    end
  end
end
