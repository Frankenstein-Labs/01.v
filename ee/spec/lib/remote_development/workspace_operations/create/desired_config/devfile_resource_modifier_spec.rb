# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileResourceModifier, feature_category: :workspaces do
  include_context "with constant modules"

  let(:base_deployment_resource) do
    {
      kind: "Deployment",
      spec: {
        template: {
          spec: {
            containers: [
              {
                name: "c1",
                resources: { limits: { cpu: "1", memory: "1Gi" }, requests: { cpu: "250m", memory: "256Mi" } },
                volumeMounts: []
              },
              { name: "c2", resources: {}, volumeMounts: [] }
            ],
            initContainers: [
              { name: "ic1", resources: {}, volumeMounts: [] }
            ],
            volumes: []
          }
        }
      }
    }
  end

  let(:non_deployment_resource) do
    { kind: "Service", spec: { foo: "bar" } }
  end

  let(:desired_config_array) do
    [
      base_deployment_resource,
      non_deployment_resource
    ]
  end

  let(:context) do
    {
      workspace_name: workspace_name,
      desired_config_array: desired_config_array,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: default_runtime_class,
      allow_privilege_escalation: allow_privilege_escalation,
      default_resources_per_workspace_container: default_resources_per_workspace_container,
      env_secret_name: env_secret_name,
      file_secret_name: file_secret_name
    }
  end

  let(:use_kubernetes_user_namespaces) { true }
  let(:default_runtime_class) { "my-runtime-class" }
  let(:allow_privilege_escalation) { false }
  let(:default_resources_per_workspace_container) do
    { limits: { memory: "2Gi" }, requests: { cpu: "500m", memory: "512Mi" } }
  end

  let(:workspace_name) { "myworkspacename" }
  let(:env_secret_name) { "#{workspace_name}-env-var" }
  let(:file_secret_name) { "#{workspace_name}-file" }

  let(:expected_pod_security_context) do
    {
      runAsNonRoot: true,
      runAsUser: create_constants_module::RUN_AS_USER,
      fsGroup: 0,
      fsGroupChangePolicy: "OnRootMismatch"
    }
  end

  let(:expected_container_security_context) do
    {
      allowPrivilegeEscalation: false,
      privileged: false,
      runAsNonRoot: true,
      runAsUser: create_constants_module::RUN_AS_USER
    }
  end

  let(:expected_volume) do
    {
      name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME,
      projected: {
        defaultMode: workspace_operations_constants_module::VARIABLES_VOLUME_DEFAULT_MODE,
        sources: [{ secret: { name: file_secret_name } }]
      }
    }
  end

  let(:expected_volume_mount) do
    {
      name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME,
      mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH
    }
  end

  let(:expected_env_from) do
    [{ secretRef: { name: env_secret_name } }]
  end

  subject(:result) { described_class.modify(context) }

  it 'adds :desired_config_array to context' do
    expect(result).to include(:desired_config_array)
  end

  it 'does not modify non-Deployment resources' do
    service = result[:desired_config_array].find { |r| r[:kind] == "Service" }
    expect(service).to eq(non_deployment_resource.deep_symbolize_keys)
  end

  describe 'modifies Deployment resources' do
    let(:deployment) { result[:desired_config_array].find { |r| r[:kind] == "Deployment" } }
    let(:pod_spec) { deployment[:spec][:template][:spec] }

    it 'unsets hostUsers if use_kubernetes_user_namespaces is true' do
      expect(pod_spec[:hostUsers]).to be(false)
    end

    it 'sets runtimeClassName if default_runtime_class is present' do
      expect(pod_spec[:runtimeClassName]).to eq(default_runtime_class)
    end

    it 'sets pod and container security contexts' do
      expect(pod_spec[:securityContext]).to eq(expected_pod_security_context)
      pod_spec[:containers].each do |container|
        expect(container[:securityContext]).to eq(expected_container_security_context)
      end
      pod_spec[:initContainers].each do |container|
        expect(container[:securityContext]).to eq(expected_container_security_context)
      end
    end

    it 'deep merges default_resources_per_workspace_container into all containers' do
      expect(pod_spec[:containers][0][:resources][:limits]).to eq(cpu: "1", memory: "1Gi")
      expect(pod_spec[:containers][0][:resources][:requests]).to eq(cpu: "250m", memory: "256Mi")
      expect(pod_spec[:containers][1][:resources][:limits]).to eq(memory: "2Gi")
      expect(pod_spec[:containers][1][:resources][:requests]).to eq(cpu: "500m", memory: "512Mi")
      expect(pod_spec[:initContainers][0][:resources][:limits]).to eq(memory: "2Gi")
      expect(pod_spec[:initContainers][0][:resources][:requests]).to eq(cpu: "500m", memory: "512Mi")
    end

    it 'injects secrets as volumes, mounts, and envFrom' do
      expect(pod_spec[:volumes]).to include(expected_volume)
      pod_spec[:containers].each do |container|
        expect(container[:volumeMounts]).to include(expected_volume_mount)
        expect(container[:envFrom]).to eq(expected_env_from)
      end
      pod_spec[:initContainers].each do |container|
        expect(container[:volumeMounts]).to include(expected_volume_mount)
        expect(container[:envFrom]).to eq(expected_env_from)
      end
    end

    it 'sets serviceAccountName' do
      expect(pod_spec[:serviceAccountName]).to eq(workspace_name)
    end
  end

  context 'when use_kubernetes_user_namespaces is false' do
    let(:use_kubernetes_user_namespaces) { false }

    it 'does not set hostUsers' do
      deployment = result[:desired_config_array].find { |r| r[:kind] == "Deployment" }
      expect(deployment[:spec][:template][:spec]).not_to have_key(:hostUsers)
    end
  end

  context 'when default_runtime_class is empty' do
    let(:default_runtime_class) { '' }

    it 'does not set runtimeClassName' do
      deployment = result[:desired_config_array].find { |r| r[:kind] == "Deployment" }
      expect(deployment[:spec][:template][:spec]).not_to have_key(:runtimeClassName)
    end
  end
end
