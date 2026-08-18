# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::ConfigToApplyBuilder, :unlimited_max_formatted_output_length, feature_category: :workspaces do
  include_context "with constant modules"

  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version of these models, so we can use fast_spec_helper.
  let(:workspace_variable_environment) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "ENV_VAR1",
      value: "env-var-value1"
    )
  end

  let(:workspace_variable_file) do
    instance_double(
      "RemoteDevelopment::WorkspaceVariable",
      key: "FILE_VAR1",
      value: "file-var-value1"
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  # rubocop:disable RSpec/VerifiedDoubles -- This is a scope which is of type ActiveRecord::Associations::CollectionProxy, it can't be a verified double
  let(:workspace_variables) do
    double(
      :workspace_variables,
      with_variable_type_environment: [workspace_variable_environment],
      with_variable_type_file: [workspace_variable_file]
    )
  end
  # rubocop:enable RSpec/VerifiedDoubles

  let(:include_all_resources) { true }
  let(:actual_state) { states_module::RUNNING }
  let(:desired_state_running) { false }
  let(:desired_state_terminated) { false }
  let(:expected_replicas) { desired_state_running ? 1 : 0 }

  # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version of these models, so we can use fast_spec_helper.
  let(:workspace) do
    instance_double("RemoteDevelopment::Workspace",
      name: "workspace-991-990-fedcba",
      namespace: "gl-rd-ns-991-990-fedcba",
      workspace_variables: workspace_variables,
      desired_state_running?: desired_state_running,
      desired_state_terminated?: desired_state_terminated,
      actual_state: actual_state
    )
  end
  # rubocop:enable RSpec/VerifiedDoubleReference

  let(:input_desired_config) do
    replicas = 99 # Replicas set to 99 in original input desired_config, to ensure it gets updated
    desired_config_array =
      desired_config_array_with_partial_reconciliation_annotation(replicas: replicas) +
      resources_without_partial_reconciliation_annotation +
      secrets_inventory_configmap_resource +
      env_and_file_secrets

    RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(
      desired_config_array: desired_config_array
    )
  end

  subject(:config_to_apply) do
    # noinspection RubyMismatchedArgumentType -- workspace is mocked but RubyMine does not like it
    described_class.build(
      workspace: workspace,
      include_all_resources: include_all_resources,
      desired_config: input_desired_config
    )
  end

  shared_examples "returns expected config_to_apply" do
    it "returns expected config_to_apply" do
      expect(config_to_apply).to eq(expected_config_to_apply)
    end
  end

  shared_examples "has correct terminated behavior" do
    let(:desired_state_terminated) { true }
    let(:expected_config_to_apply) do
      workspace_inventory_configmap_resource +
        secrets_inventory_configmap_resource
    end

    it_behaves_like "returns expected config_to_apply"
  end

  context "when include_all_resources is true" do
    let(:expected_config_to_apply) do
      desired_config_array_with_partial_reconciliation_annotation(replicas: expected_replicas) +
        resources_without_partial_reconciliation_annotation +
        secrets_inventory_configmap_resource +
        populated_env_and_file_secrets
    end

    it_behaves_like "returns expected config_to_apply"

    it_behaves_like "has correct terminated behavior"

    it "populates secret data" do
      all_secrets_populated = config_to_apply.map do |resource|
        resource[:kind] == "Secret" ? resource[:data].present? : true
      end.all?
      expect(all_secrets_populated).to be true
    end
  end

  context "when include_all_resources is false" do
    let(:include_all_resources) { false }
    let(:expected_config_to_apply) do
      desired_config_array_with_partial_reconciliation_annotation(replicas: expected_replicas)
    end

    it_behaves_like "returns expected config_to_apply"

    it_behaves_like "has correct terminated behavior"
  end

  # @return [Array]
  def workspace_inventory_configmap_resource
    [
      {
        kind: "ConfigMap",
        metadata: {
          name: "workspace-991-990-fedcba-workspace-inventory",
          annotations: {
            "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
          }
        }
      }
    ]
  end

  # @param [Integer] replicas
  # @return [Array]
  def desired_config_array_with_partial_reconciliation_annotation(replicas:)
    workspace_inventory_configmap_resource +
      [
        {
          kind: "Deployment",
          spec: {
            replicas: replicas # A value which is not 0 or 1, to ensure it gets updated
          },
          metadata: {
            annotations: {
              "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
            }
          }
        },
        {
          kind: "object-with-annotation",
          metadata: {
            name: "workspace-991-990-fedcba",
            annotations: {
              "workspaces.gitlab.com/include-in-partial-reconciliation": "true"
            }
          }
        }
      ]
  end

  # @return [Array]
  def secrets_inventory_configmap_resource
    [
      {
        kind: "ConfigMap",
        metadata: {
          name: "workspace-991-990-fedcba-secrets-inventory"
        }
      }
    ]
  end

  # @return [Array]
  def resources_without_partial_reconciliation_annotation
    [
      {
        kind: "object-without-annotation",
        metadata: {
          name: "workspace-991-990-fedcba"
        }
      }
    ]
  end

  # @return [Array]
  def env_and_file_secrets
    [
      {
        kind: "Secret",
        metadata: {
          name: "workspace-991-990-fedcba-env-var"
        },
        data: {}
      },
      {
        kind: "Secret",
        metadata: {
          name: "workspace-991-990-fedcba-file"
        },
        data: {}
      }
    ]
  end

  # @return [Array]
  def populated_env_and_file_secrets
    [
      {
        kind: "Secret",
        metadata: {
          name: "workspace-991-990-fedcba-env-var"
        },
        data: { ENV_VAR1: "ZW52LXZhci12YWx1ZTE=" }
      },
      {
        kind: "Secret",
        metadata: {
          name: "workspace-991-990-fedcba-file"
        },
        data: {
          FILE_VAR1: "ZmlsZS12YXItdmFsdWUx",
          "gl_workspace_reconciled_actual_state.txt": "UnVubmluZw=="
        }
      }
    ]
  end
end
