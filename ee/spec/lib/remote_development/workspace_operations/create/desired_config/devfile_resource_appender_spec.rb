# frozen_string_literal: true

require "fast_spec_helper"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Needed in specs

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileResourceAppender, :freeze_time, feature_category: :workspaces do
  include_context "with remote development shared fixtures"
  include_context "with constant modules"

  # rubocop:disable RSpec/VerifiedDoubleReference -- fast_spec_helper does not load Rails models, so we must use a quoted class name here.let(:env_var) do
  let(:env_var) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "ENV_KEY",
      value: "ENV_VALUE"
    )
  end

  let(:file_var) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "FILE_KEY",
      value: "FILE_VALUE"
    )
  end

  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      name: "workspace-991-990-fedcba",
      namespace: "gl-rd-ns-991-990-fedcba",
      workspace_variables: [env_var, file_var],
      id: "991-990-fedcba",
      agent: instance_double("Clusters::Agent", id: "991"),
      actual_state: "RUNNING"
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  let(:labels) { { "app" => "workspace", "tier" => "development", "agent.gitlab.com/id" => "991" } }
  let(:workspace_inventory_annotations) { { "environment" => "production", "team" => "engineering" } }
  let(:workspace_inventory_annotations_for_partial_reconciliation) do
    workspace_inventory_annotations.merge(
      { workspace_operations_constants_module::ANNOTATION_KEY_INCLUDE_IN_PARTIAL_RECONCILIATION => "true" }
    )
  end

  let(:common_annotations) do
    { "workspaces.gitlab.com/host-template" => "3000-#{workspace.name}.workspaces.localdev.me" }
  end

  let(:common_annotations_for_partial_reconciliation) do
    common_annotations.merge(
      { workspace_operations_constants_module::ANNOTATION_KEY_INCLUDE_IN_PARTIAL_RECONCILIATION => "true" }
    )
  end

  let(:workspace_inventory_name) { "#{workspace.name}-workspace-inventory" }
  let(:workspace_scripts_configmap_name) { "#{workspace.name}-scripts" }
  let(:secrets_inventory_name) { "#{workspace.name}-secrets-inventory" }
  let(:secrets_inventory_annotations) { { "config.k8s.io/owning-inventory" => secrets_inventory_name } }
  let(:scripts_configmap_name) { "#{workspace.name}-scripts" }
  let(:processed_devfile_yaml) { example_processed_devfile_yaml }
  let(:gitlab_workspaces_proxy_http_enabled) { true }
  let(:gitlab_workspaces_proxy_namespace) { "gitlab-workspaces" }
  let(:gitlab_workspaces_proxy_ssh_enabled) { true }
  let(:network_policy_enabled) { true }
  let(:network_policy_egress) { [{ allow: "0.0.0.0/0", except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16] }] }
  let(:image_pull_secrets) { [] }
  let(:max_resources_per_workspace) { {} }
  let(:shared_namespace) { "" }
  let(:env_secret_name) { "#{workspace.name}-env-var" }
  let(:file_secret_name) { "#{workspace.name}-file" }
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

  let(:desired_config_array) do
    [
      base_deployment_resource
    ]
  end

  let(:context) do
    {
      desired_config_array: desired_config_array,
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      workspace_inventory_annotations: workspace_inventory_annotations,
      workspace_inventory_annotations_for_partial_reconciliation:
        workspace_inventory_annotations_for_partial_reconciliation,
      common_annotations: common_annotations,
      common_annotations_for_partial_reconciliation: common_annotations_for_partial_reconciliation,
      workspace_inventory_name: workspace_inventory_name,
      secrets_inventory_name: secrets_inventory_name,
      secrets_inventory_annotations: secrets_inventory_annotations,
      scripts_configmap_name: scripts_configmap_name,
      processed_devfile_yaml: processed_devfile_yaml,
      gitlab_workspaces_proxy_http_enabled: gitlab_workspaces_proxy_http_enabled,
      gitlab_workspaces_proxy_namespace: gitlab_workspaces_proxy_namespace,
      gitlab_workspaces_proxy_ssh_enabled: gitlab_workspaces_proxy_ssh_enabled,
      network_policy_enabled: network_policy_enabled,
      network_policy_egress: network_policy_egress,
      image_pull_secrets: image_pull_secrets,
      max_resources_per_workspace: max_resources_per_workspace,
      shared_namespace: shared_namespace,
      env_secret_name: env_secret_name,
      file_secret_name: file_secret_name,
      project_path: "test-project"
    }
  end

  subject(:appended_context) { described_class.append(context) }

  it "appends all expected resource kinds and names to the config array" do
    result = appended_context[:desired_config_array]
    kinds_and_names = result.map { |r| [r[:kind], r.dig(:metadata, :name)] }
    expect(kinds_and_names).to include(["ConfigMap", workspace_inventory_name])
    expect(kinds_and_names).to include(["ServiceAccount", workspace.name])
    expect(kinds_and_names).to include(["NetworkPolicy", workspace.name])
    expect(kinds_and_names).to include(["Secret", env_secret_name])
    expect(kinds_and_names).to include(["Secret", file_secret_name])

    resources_included_in_partial_reconciliation = [
      { kind: "ConfigMap", name: workspace_inventory_name },
      { kind: "ServiceAccount", name: workspace.name },
      { kind: "NetworkPolicy", name: workspace.name },
      { kind: "ConfigMap", name: workspace_scripts_configmap_name }
    ]

    result.each do |resource|
      kind = resource[:kind]
      name = resource.dig(:metadata, :name)
      key = workspace_operations_constants_module::ANNOTATION_KEY_INCLUDE_IN_PARTIAL_RECONCILIATION

      included_in_partial_reconciliation, excluded_from_partial_reconciliation = result.partition do |r|
        resources_included_in_partial_reconciliation.any? do |spec|
          spec[:kind] == r[:kind] && spec[:name] == r.dig(:metadata, :name)
        end
      end

      included_in_partial_reconciliation.each do |r|
        expect(r.dig(:metadata, :annotations, key)).to eq("true"),
          "Expected #{kind}/#{name} to have annotation #{key}=true, but got #{r.dig(:metadata, :annotations)}"
      end

      excluded_from_partial_reconciliation.each do |r|
        expect(r.dig(:metadata, :annotations, key)).to be_nil,
          "Expected annotation #{key} to not be present in #{kind}/#{name}, but it is"
      end
    end

    secret_resources = result.select { |r| r[:kind] == "Secret" }
    secret_resources.each do |secret|
      expect(secret[:data]).to eq({})
    end
  end

  context "when network policy is disabled" do
    let(:network_policy_enabled) { false }

    it "does not include a NetworkPolicy resource" do
      result = appended_context[:desired_config_array]
      kinds_and_names = result.map { |r| [r[:kind], r.dig(:metadata, :name)] }
      expect(kinds_and_names).not_to include(["NetworkPolicy", workspace.name])
    end
  end

  context "when gitlab_workspaces_proxy_http_enabled and gitlab_workspaces_proxy_http_enabled are set to false" do
    let(:gitlab_workspaces_proxy_http_enabled) { false }
    let(:gitlab_workspaces_proxy_ssh_enabled) { false }

    it "contains empty ingress attributes of the NetworkPolicy resource" do
      result = appended_context[:desired_config_array]
      np = result.find { |r| r[:kind] == "NetworkPolicy" }
      expect(np[:spec][:ingress]).to eq([])
      expect(np[:spec][:policyTypes]).not_to include("Ingress")
    end
  end

  context "when gitlab_workspaces_proxy_http_enabled is true and gitlab_workspaces_proxy_ssh_enabled is false" do
    let(:gitlab_workspaces_proxy_ssh_enabled) { false }

    it "contains empty ingress attributes of the NetworkPolicy resource" do
      result = appended_context[:desired_config_array]
      np = result.find { |r| r[:kind] == "NetworkPolicy" }
      expect(np[:spec][:ingress]).not_to eq([])
      expect(np[:spec][:policyTypes]).to include("Ingress")
    end
  end

  context "when gitlab_workspaces_proxy_http_enabled is false and gitlab_workspaces_proxy_ssh_enabled is true" do
    let(:gitlab_workspaces_proxy_http_enabled) { false }

    it "contains empty ingress attributes of the NetworkPolicy resource" do
      result = appended_context[:desired_config_array]
      np = result.find { |r| r[:kind] == "NetworkPolicy" }
      expect(np[:spec][:ingress]).not_to eq([])
      expect(np[:spec][:policyTypes]).to include("Ingress")
    end
  end

  context "when max_resources_per_workspace is set" do
    let(:max_resources_per_workspace) do
      { limits: { cpu: "1.5", memory: "786Mi" }, requests: { cpu: "0.6", memory: "512Mi" } }
    end

    it "includes a ResourceQuota resource" do
      result = appended_context[:desired_config_array]
      kinds = result.map { |r| r[:kind] }
      expect(kinds).to include("ResourceQuota")
    end
  end

  context "when shared_namespace is set" do
    let(:shared_namespace) { "shared-ns" }

    it "does not include a ResourceQuota resource" do
      result = appended_context[:desired_config_array]
      kinds = result.map { |r| r[:kind] }
      expect(kinds).not_to include("ResourceQuota")
    end
  end

  context "when image_pull_secrets are provided" do
    let(:image_pull_secrets) { [{ name: "secret-name" }] }

    it "includes a ServiceAccount with imagePullSecrets" do
      result = appended_context[:desired_config_array]
      sa = result.find { |r| r[:kind] == "ServiceAccount" }
      expect(sa[:imagePullSecrets]).to eq([{ name: "secret-name" }])
    end
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
