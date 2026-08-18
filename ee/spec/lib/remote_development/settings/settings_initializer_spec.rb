# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::Settings::SettingsInitializer,
  feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  let(:all_possible_requested_setting_names) { RemoteDevelopment::Settings::DefaultSettings.default_settings.keys }
  let(:requested_setting_names) { all_possible_requested_setting_names }
  let(:context) do
    { requested_setting_names: requested_setting_names }
  end

  let(:default_devfile_yaml) do
    read_devfile_yaml("example.default_devfile.yaml.erb")
  end

  subject(:returned_value) do
    described_class.init(context)
  end

  it "invokes DefaultSettingsParser and sets up necessary values in context for subsequent steps" do
    expect(returned_value).to match(
      {
        requested_setting_names:
          # NOTE: This fixture array is sorted to enforce that the actual order of the keys
          #       in default_settings is kept in alphabetical order.
          [
            :allow_privilege_escalation,
            :annotations,
            :default_branch_name,
            :default_devfile_yaml,
            :default_resources_per_workspace_container,
            :default_runtime_class,
            :dns_zone,
            :full_reconciliation_interval_seconds,
            :gitlab_kas_external_url,
            :gitlab_workspaces_proxy_http_enabled,
            :gitlab_workspaces_proxy_namespace,
            :gitlab_workspaces_proxy_ssh_enabled,
            :image_pull_secrets,
            :labels,
            :max_active_hours_before_stop,
            :max_resources_per_workspace,
            :max_stopped_hours_before_termination,
            :network_policy_egress,
            :network_policy_enabled,
            :partial_reconciliation_interval_seconds,
            :shared_namespace,
            :tools_injector_image,
            :use_kubernetes_user_namespaces,
            :workspaces_per_user_quota,
            :workspaces_quota
          ].sort,
        settings: {
          allow_privilege_escalation: false,
          annotations: {},
          default_branch_name: nil,
          default_devfile_yaml: default_devfile_yaml,
          default_resources_per_workspace_container: {},
          default_runtime_class: "",
          dns_zone: "",
          full_reconciliation_interval_seconds: 3600,
          gitlab_kas_external_url: "",
          gitlab_workspaces_proxy_http_enabled: true,
          gitlab_workspaces_proxy_namespace: "gitlab-workspaces",
          gitlab_workspaces_proxy_ssh_enabled: true,
          image_pull_secrets: [],
          labels: {},
          max_active_hours_before_stop: 36,
          max_resources_per_workspace: {},
          max_stopped_hours_before_termination: 744,
          network_policy_egress: [{
            allow: "0.0.0.0/0",
            except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
          }],
          network_policy_enabled: true,
          partial_reconciliation_interval_seconds: 10,
          shared_namespace: "",
          tools_injector_image:
            workspace_operations_constants_module::WORKSPACE_TOOLS_IMAGE,
          use_kubernetes_user_namespaces: false,
          workspaces_per_user_quota: -1,
          workspaces_quota: -1
        },
        setting_types: {
          allow_privilege_escalation: :Boolean,
          annotations: Hash,
          default_branch_name: String,
          default_devfile_yaml: String,
          default_resources_per_workspace_container: Hash,
          default_runtime_class: String,
          dns_zone: String,
          full_reconciliation_interval_seconds: Integer,
          gitlab_kas_external_url: String,
          gitlab_workspaces_proxy_http_enabled: :Boolean,
          gitlab_workspaces_proxy_namespace: String,
          gitlab_workspaces_proxy_ssh_enabled: :Boolean,
          image_pull_secrets: Array,
          labels: Hash,
          max_active_hours_before_stop: Integer,
          max_resources_per_workspace: Hash,
          max_stopped_hours_before_termination: Integer,
          network_policy_egress: Array,
          network_policy_enabled: :Boolean,
          partial_reconciliation_interval_seconds: Integer,
          tools_injector_image: String,
          shared_namespace: String,
          use_kubernetes_user_namespaces: :Boolean,
          workspaces_per_user_quota: Integer,
          workspaces_quota: Integer
        },
        env_var_prefix: "GITLAB_REMOTE_DEVELOPMENT",
        env_var_failed_message_class: RemoteDevelopment::Settings::Messages::SettingsEnvironmentVariableOverrideFailed
      }
    )
  end

  context "when mutually dependent settings are not all specified" do
    context "for full_reconciliation_interval_seconds and partial_reconciliation_interval_seconds" do
      let(:requested_setting_names) { [:full_reconciliation_interval_seconds] }

      it "raises a descriptive exception" do
        expect { returned_value }.to raise_error(
          /full_reconciliation_interval_seconds and partial_reconciliation_interval_seconds.*mutually dependent/
        )
      end
    end
  end
end
