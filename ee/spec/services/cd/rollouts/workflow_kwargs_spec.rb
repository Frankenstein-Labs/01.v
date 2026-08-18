# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::Rollouts::WorkflowKwargs, feature_category: :continuous_delivery do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }

  let(:flow_definition_yaml) do
    <<~YAML
      environments:
        "42":
          services:
            gitlab-runner:
              namespace: argocd
              application: gitlab-runner
              manifest_repository:
                type: gitlab
                host: https://gitlab.com
                project: cam_swords/hello-cd
                branch: main
                manifests_path: manifests
      steps:
        - type: com.gitlab.cd.steps.stage
          name: production
          steps:
            - type: com.gitlab.cd.argo.canary.deploy
              environment: "42"
              services:
                - { name: gitlab-runner, weight: 25 }
    YAML
  end

  let(:flow_definition) do
    create(:cd_application_flow_definition, application: application, definition: flow_definition_yaml)
  end

  let(:version_set) { create(:cd_version_set, application: application) }
  let(:rollout) do
    create(:cd_rollout, application: application, version_set: version_set,
      application_flow_definition: flow_definition)
  end

  subject(:kwargs) { described_class.new(rollout).to_h }

  it 'has rollout_id, organization_id, environments, flow_definition and version_set top-level keys' do
    expect(kwargs.keys).to contain_exactly(
      'rollout_id', 'organization_id', 'environments', 'flow_definition', 'version_set'
    )
  end

  it 'passes the rollout id as a string' do
    expect(kwargs['rollout_id']).to eq(rollout.id.to_s)
  end

  it 'passes the organization id as a string' do
    expect(kwargs['organization_id']).to eq(organization.id.to_s)
  end

  it 'passes the flow definition through verbatim' do
    expect(kwargs['flow_definition']).to eq(YAML.safe_load(flow_definition_yaml))
  end

  context 'when the rollout has rollout environments' do
    let(:environment) { create(:cd_environment, organization: organization, name: 'production') }
    let(:driver_binding) do
      create(:cd_environment_driver_binding, environment: environment,
        driver_config: { 'cluster_agent_id' => '987654' })
    end

    let!(:rollout_environment) do
      create(:cd_rollout_environment, rollout: rollout, environment: environment, driver_binding: driver_binding,
        position: 1)
    end

    it 'keys the environments kwarg by environment name with the driver cluster_agent_id' do
      expect(kwargs['environments']).to eq(
        'production' => { 'cluster_agent_id' => '987654' }
      )
    end

    context 'when the driver config is missing cluster_agent_id' do
      # driver_config: {} can no longer be created through normal validation (the driver's own
      # schema now requires cluster_agent_id), so simulate a pre-existing/legacy record via
      # update_column to still exercise WorkflowKwargs's own defensive check.
      let(:driver_binding) do
        create(:cd_environment_driver_binding, environment: environment).tap { |b| b.update_column(:driver_config, {}) }
      end

      it 'raises InvalidConfigError' do
        expect { kwargs }.to raise_error(described_class::InvalidConfigError, /cluster_agent_id/)
      end
    end
  end

  context 'when the flow definition YAML is unparseable' do
    let(:flow_definition) do
      create(:cd_application_flow_definition, application: application).tap do |fd|
        fd.file.store!(CarrierWaveStringFile.new("environments:\n  \"42\": ["))
        fd.remove_instance_variable(:@definition)
      end
    end

    it 'raises InvalidConfigError' do
      expect { kwargs }.to raise_error(described_class::InvalidConfigError, /flow definition/)
    end
  end

  context 'when the rollout has a version set with services and artifacts' do
    let(:service) { create(:cd_service, application: application, name: 'gitlab-runner') }
    let(:runner_source) do
      create(:cd_artifact_source, service: service,
        source_ref: 'docker.io/gitlab/gitlab-runner',
        source_config: { 'type' => 'oci_image', 'name' => 'runner' })
    end

    let(:helper_source) do
      create(:cd_artifact_source, service: service,
        source_ref: 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper',
        source_config: { 'type' => 'oci_image', 'name' => 'helper' })
    end

    let!(:runner_entry) do
      create(:cd_version_set_entry, version_set: version_set,
        version: create(:cd_version, artifact_source: runner_source, name: 'alpine-v19-1-0',
          reference: 'docker.io/gitlab/gitlab-runner:alpine-v19.1.0'))
    end

    let!(:helper_entry) do
      create(:cd_version_set_entry, version_set: version_set,
        version: create(:cd_version, artifact_source: helper_source, name: 'x86-64-v19-1-0',
          reference: 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v19.1.0'))
    end

    it 'groups artifacts by service' do
      expect(kwargs['version_set']['services'].length).to eq(1)
      expect(kwargs['version_set']['services'].first['name']).to eq('gitlab-runner')
      expect(kwargs['version_set']['services'].first['artifacts']).to match_array([
        {
          'name' => 'runner',
          'version' => 'alpine-v19-1-0',
          'source' => { 'type' => 'oci_image', 'image' => 'docker.io/gitlab/gitlab-runner' }
        },
        {
          'name' => 'helper',
          'version' => 'x86-64-v19-1-0',
          'source' => {
            'type' => 'oci_image',
            'image' => 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper'
          }
        }
      ])
    end

    context 'when an artifact source config is missing the name key' do
      let(:runner_source) do
        create(:cd_artifact_source, service: service,
          source_ref: 'docker.io/gitlab/gitlab-runner',
          source_config: { 'type' => 'oci_image' })
      end

      it 'raises InvalidConfigError' do
        expect { kwargs }.to raise_error(described_class::InvalidConfigError, /name/)
      end
    end
  end
end
