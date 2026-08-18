# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- Can we have fewer?
# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::AgentConfigOperations::Updater, feature_category: :workspaces do
  include ResultMatchers

  let(:enabled) { true }
  let(:enabled_present) { true }
  let(:dns_zone_present) { true }
  let_it_be(:dns_zone) { 'my-awesome-domain.me' }
  let(:unlimited_quota) { -1 }
  let(:saved_quota) { 5 }
  let(:quota) { 5 }
  let(:logger) { instance_double(::Logger) }

  let(:network_policy_present) { false }
  let(:network_policy_egress) do
    [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }]
  end

  let(:network_policy_enabled) { true }
  let(:network_policy_without_egress) do
    { enabled: network_policy_enabled }
  end

  let(:network_policy_with_egress) do
    {
      enabled: network_policy_enabled,
      egress: network_policy_egress
    }
  end

  let(:network_policy) { network_policy_without_egress }
  let(:gitlab_workspaces_proxy_present) { false }
  let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces' }
  let(:gitlab_workspaces_proxy_namespace_present) { true }
  let(:gitlab_workspaces_proxy_http_enabled) { true }
  let(:gitlab_workspaces_proxy_http_enabled_present) { true }
  let(:gitlab_workspaces_proxy_ssh_enabled) { true }
  let(:gitlab_workspaces_proxy_ssh_enabled_present) { true }
  let(:gitlab_workspaces_proxy) do
    val = {}
    val[:namespace] = gitlab_workspaces_proxy_namespace if gitlab_workspaces_proxy_namespace_present
    val[:http_enabled] = gitlab_workspaces_proxy_http_enabled if gitlab_workspaces_proxy_http_enabled_present
    val[:ssh_enabled] = gitlab_workspaces_proxy_ssh_enabled if gitlab_workspaces_proxy_ssh_enabled_present

    val
  end

  let(:default_resources_per_workspace_container) { {} }
  let(:max_resources_per_workspace) { {} }

  let(:max_active_hours_before_stop) { 36 }
  let(:max_active_hours_before_stop_present) { false }
  let(:max_stopped_hours_before_termination) { 744 }
  let(:max_stopped_hours_before_termination_present) { false }

  let(:allow_privilege_escalation) { false }
  let(:use_kubernetes_user_namespaces) { false }
  let(:default_runtime_class) { "" }
  let(:annotations) { {} }
  let(:labels) { {} }
  let(:image_pull_secrets) { [] }

  let(:saved_shared_namespace) { "" }
  let(:shared_namespace) { nil }

  let_it_be_with_refind(:agent) { create(:cluster_agent) }

  let(:dns_zone_in_config) { dns_zone }

  let(:config) do
    remote_development_config = {}
    remote_development_config['dns_zone'] = dns_zone_in_config if dns_zone_present
    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    remote_development_config['enabled'] = enabled if enabled_present
    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    remote_development_config['network_policy'] = network_policy if network_policy_present
    remote_development_config['gitlab_workspaces_proxy'] = gitlab_workspaces_proxy if gitlab_workspaces_proxy_present
    remote_development_config['default_resources_per_workspace_container'] = default_resources_per_workspace_container
    remote_development_config['max_resources_per_workspace'] = max_resources_per_workspace

    if max_active_hours_before_stop_present
      # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
      remote_development_config['max_active_hours_before_stop'] = max_active_hours_before_stop
    end

    if max_stopped_hours_before_termination_present
      remote_development_config['max_stopped_hours_before_termination'] = max_stopped_hours_before_termination
    end

    if quota
      remote_development_config['workspaces_quota'] = quota
      remote_development_config['workspaces_per_user_quota'] = quota
    end

    remote_development_config['shared_namespace'] = shared_namespace if shared_namespace

    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    remote_development_config['allow_privilege_escalation'] = allow_privilege_escalation if allow_privilege_escalation
    remote_development_config['use_kubernetes_user_namespaces'] = use_kubernetes_user_namespaces
    remote_development_config['default_runtime_class'] = default_runtime_class
    remote_development_config['annotations'] = annotations
    remote_development_config['labels'] = labels
    # noinspection RubyMismatchedArgumentType - RubyMine is misinterpreting types for Hash values
    remote_development_config['image_pull_secrets'] = image_pull_secrets

    {
      remote_development: HashWithIndifferentAccess.new(remote_development_config)
    }
  end

  subject(:result) do
    described_class.update(agent: agent, config: config, logger: logger) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
  end

  context 'when config passed is empty' do
    let(:config) { {} }

    it "does not update and returns an ok Result containing a hash indicating update was skipped" do
      expect { result }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }

      expect(result)
        .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new(
          { skipped_reason: :no_config_file_entry_found }
        ))
    end
  end

  context 'when config passed is not empty' do
    shared_examples 'successful update' do
      it 'creates a config record and returns an ok Result containing the agent config' do
        expect { result }.to change { RemoteDevelopment::WorkspacesAgentConfig.count }.by(expected_configs_created)

        config_instance = agent.reload.unversioned_latest_workspaces_agent_config
        expect(config_instance.allow_privilege_escalation).to eq(allow_privilege_escalation)
        expect(config_instance.annotations.deep_symbolize_keys).to eq(annotations)
        expect(config_instance.default_resources_per_workspace_container.deep_symbolize_keys)
          .to eq(default_resources_per_workspace_container)
        expect(config_instance.default_runtime_class).to eq(default_runtime_class)
        expect(config_instance.dns_zone).to eq(expected_dns_zone)
        expect(config_instance.enabled).to eq(expected_enabled)
        expect(config_instance.gitlab_workspaces_proxy_namespace).to eq(gitlab_workspaces_proxy_namespace)
        expect(config_instance.labels.deep_symbolize_keys).to eq(labels)
        expect(config_instance.max_active_hours_before_stop).to eq(max_active_hours_before_stop)
        expect(config_instance.max_resources_per_workspace.deep_symbolize_keys).to eq(max_resources_per_workspace)
        expect(config_instance.max_stopped_hours_before_termination).to eq(max_stopped_hours_before_termination)
        expect(config_instance.network_policy_egress.map(&:deep_symbolize_keys)).to eq(network_policy_egress)
        expect(config_instance.network_policy_enabled).to eq(network_policy_enabled)
        expect(config_instance.project_id).to eq(agent.project_id)
        expect(config_instance.use_kubernetes_user_namespaces).to eq(use_kubernetes_user_namespaces)
        expect(config_instance.workspaces_per_user_quota).to eq(saved_quota)
        expect(config_instance.workspaces_quota).to eq(saved_quota)
        expect(config_instance.image_pull_secrets).to eq(image_pull_secrets)
        expect(config_instance.shared_namespace).to eq(saved_shared_namespace)

        expect(result)
          .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
            { workspaces_agent_config: config_instance }
          ))

        expect(config_instance.workspaces.desired_state_not_terminated)
          .to all(have_attributes(force_include_all_resources: true))
      end
    end

    context 'when a config file is valid' do
      let(:expected_enabled) { true }
      let(:expected_dns_zone) { dns_zone }
      let(:expected_configs_created) { 1 }

      context "without existing workspaces_agent_config" do
        it_behaves_like 'successful update'

        context 'when enabled is not present in the config passed' do
          let(:config) { { remote_development: { dns_zone: dns_zone } } }

          it 'creates a config record with a default context of enabled as false' do
            expect { result }.to change { RemoteDevelopment::WorkspacesAgentConfig.count }
            expect(result).to be_ok_result
            expect(agent.reload.unversioned_latest_workspaces_agent_config.enabled).to be(false)
          end
        end

        context 'when network_policy key is present in the config passed' do
          let(:network_policy_present) { true }

          context 'when network_policy key is empty hash in the config passed' do
            let(:network_policy) { {} }

            it_behaves_like 'successful update'
          end

          context 'when network_policy.enabled is explicitly specified in the config passed' do
            let(:network_policy_enabled) { false }

            it_behaves_like 'successful update'
          end

          context 'when network_policy.egress is explicitly specified in the config passed' do
            let(:network_policy_egress) do
              [
                {
                  allow: "0.0.0.0/0",
                  except: %w[10.0.0.0/8]
                }
              ].freeze
            end

            let(:network_policy) { network_policy_with_egress }

            it_behaves_like 'successful update'
          end

          context 'when delayed termination fields are explicitly specified in the config passed' do
            let(:max_active_hours_before_stop_present) { true }
            let(:max_stopped_hours_before_termination_present) { true }
            let(:max_active_hours_before_stop) { 24 }
            let(:max_stopped_hours_before_termination) { 168 }

            it_behaves_like 'successful update'
          end
        end

        context 'when shared_namespace is not explicitly specified in the config passed' do
          let(:shared_namespace) { nil }
          let(:saved_shared_namespace) { "" }

          it_behaves_like 'successful update'
        end

        context 'when shared_namespace key is explicitly specified in the config passed' do
          let(:shared_namespace) { "my-shared-namespace" }
          let(:saved_shared_namespace) { "my-shared-namespace" }

          it_behaves_like 'successful update'
        end

        context 'when gitlab_workspaces_proxy is present in the config passed' do
          let(:gitlab_workspaces_proxy_present) { true }

          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:gitlab_workspaces_proxy) { {} }

            it_behaves_like 'successful update'
          end

          context 'when gitlab_workspaces_proxy.namespace is explicitly specified in the config passed' do
            let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces-specified' }

            it_behaves_like 'successful update'
          end

          context 'when gitlab_workspaces_proxy.http_enabled is explicitly specified in the config passed' do
            let(:gitlab_workspaces_proxy_http_enabled) { false }

            it_behaves_like 'successful update'

            context 'when dns_zone is not set' do
              let(:dns_zone_present) { false }
              let(:expected_dns_zone) { "" }

              it_behaves_like 'successful update'
            end

            context 'when dns_zone is empty' do
              let(:dns_zone) { "" }

              it_behaves_like 'successful update'
            end
          end

          context 'when gitlab_workspaces_proxy.ssh_enabled is explicitly specified in the config passed' do
            let(:gitlab_workspaces_proxy_ssh_enabled) { false }

            it_behaves_like 'successful update'
          end
        end

        context 'when default_resources_per_workspace_container is present in the config passed' do
          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:default_resources_per_workspace_container) { {} }

            it_behaves_like 'successful update'
          end

          context 'when default_resources_per_workspace_container is explicitly specified in the config passed' do
            let(:default_resources_per_workspace_container) do
              { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
            end

            it_behaves_like 'successful update'
          end
        end

        context 'when max_resources_per_workspace is present in the config passed' do
          context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
            let(:max_resources_per_workspace) { {} }

            it_behaves_like 'successful update'
          end

          context 'when max_resources_per_workspace is explicitly specified in the config passed' do
            let(:max_resources_per_workspace) do
              { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
            end

            it_behaves_like 'successful update'
          end
        end

        context 'when workspace quotas are not explicitly specified in the config passed' do
          let(:quota) { nil }
          let(:saved_quota) { -1 }

          it_behaves_like 'successful update'
        end
      end

      context 'when allow_privilege_escalation is explicitly specified in the config passed' do
        let(:allow_privilege_escalation) { true }

        context 'when use_kubernetes_user_namespaces is explicitly specified in the config passed' do
          let(:use_kubernetes_user_namespaces) { true }

          it_behaves_like 'successful update'
        end

        context 'when default_runtime_class is explicitly specified in the config passed' do
          let(:default_runtime_class) { "test" }

          it_behaves_like 'successful update'
        end
      end

      context 'when use_kubernetes_user_namespaces is explicitly specified in the config passed' do
        let(:use_kubernetes_user_namespaces) { true }

        it_behaves_like 'successful update'
      end

      context 'when default_runtime_class is explicitly specified in the config passed' do
        let(:default_runtime_class) { "test" }

        it_behaves_like 'successful update'
      end

      context 'when annotations is explicitly specified in the config passed' do
        let(:annotations) { { a: "1" } }

        it_behaves_like 'successful update'
      end

      context 'when labels is explicitly specified in the config passed' do
        let(:labels) { { b: "2" } }

        it_behaves_like 'successful update'
      end

      context "with existing workspaces_agent_config" do
        let(:expected_configs_created) { 0 }
        let_it_be_with_refind(:workspaces_agent_config) do
          create(:workspaces_agent_config, dns_zone: dns_zone, agent: agent)
        end

        before do
          agent.reload
        end

        it_behaves_like 'successful update'
      end

      context "when enabled is a string" do
        context "and is 'true'" do
          let(:enabled) { "true" }

          it_behaves_like 'successful update'
        end

        context "and is 'false'" do
          let(:enabled) { "false" }
          let(:expected_enabled) { false }

          it_behaves_like 'successful update'
        end
      end

      context "when enabled is false" do
        let(:enabled) { false }
        let(:expected_enabled) { false }

        it_behaves_like 'successful update'
      end

      context "when enabled is not present" do
        let(:enabled_present) { false }
        let(:expected_enabled) { false }

        it_behaves_like 'successful update'
      end
    end

    context 'when config file is invalid' do
      before do
        allow(logger).to receive(:warn)
      end

      shared_examples 'failed agent config update' do
        it 'does not create the record, logs and returns error' do
          expect(logger).to receive(:warn).with(
            message: "Failed to save agent configuration file",
            agent_id: agent.id,
            error: satisfy { |arg| arg.match?(error_pattern) }
          )
          expect { result }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }
          expect(agent.reload.unversioned_latest_workspaces_agent_config).to be_nil

          expect(result).to be_err_result do |message|
            expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
            message.content => { errors: ActiveModel::Errors => errors }
            expect(errors.full_messages.join(', ')).to match(error_pattern)
          end
        end
      end

      context 'when dns_zone is invalid' do
        let(:dns_zone) { "invalid dns zone" }
        let(:error_pattern) { /dns zone/i }

        it_behaves_like 'failed agent config update'
      end

      context 'when dns_zone is empty' do
        let(:dns_zone) { "" }
        let(:error_pattern) { /dns zone/i }

        it_behaves_like 'failed agent config update'
      end

      context 'when allow_privilege_escalation is explicitly specified in the config passed' do
        let(:allow_privilege_escalation) { true }
        let(:error_pattern) { /allow privilege escalation/i }

        it_behaves_like 'failed agent config update'
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
