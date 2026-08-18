# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::AgentConfigOperations::Main, "Integration", feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:enabled) { true }
  let(:dns_zone) { 'my-awesome-domain.me' }
  let(:logger) do
    instance_double(::Logger).tap do |logger|
      allow(logger).to receive(:warn)
    end
  end

  let(:config) do
    yaml = read_fixture_file("example.agent_config.yaml")
    yaml.gsub!("dns_zone: workspaces.dev.test", "dns_zone: #{dns_zone}")
    # NOTE: YAML.safe_load will ensure that all keys are strings, not symbols.
    YAML.safe_load(yaml)
  end

  let(:context) { { agent: agent, config: config, logger: logger } }

  subject(:response) do
    described_class.main(context)
  end

  context "when a workspaces_agent_config record does not already exist" do
    let_it_be(:agent) { create(:cluster_agent) }

    context 'when config passed is empty' do
      let(:config) { {} }

      it 'does not create a config record' do
        expect { response }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }

        expect(response).to eq({
          status: :success,
          payload: { skipped_reason: :no_config_file_entry_found }
        })
      end
    end

    context 'when config passed results in updates to the workspaces_agent_config record' do
      it 'creates a config record' do
        expect { response }.to change { RemoteDevelopment::WorkspacesAgentConfig.count }.by(1)

        expect(response).to eq({
          status: :success,
          payload: { workspaces_agent_config: agent.reload.unversioned_latest_workspaces_agent_config }
        })
      end
    end

    context 'when config is invalid' do
      let(:dns_zone) { "invalid dns zone" }

      it 'does not create the record and returns error' do
        expect { response }.to not_change { RemoteDevelopment::WorkspacesAgentConfig.count }

        expect(response).to eq({
          status: :error,
          message: "Agent config update failed: Dns zone contains invalid characters (valid characters: [a-z0-9\\-])",
          reason: :bad_request
        })

        config_instance = agent.reload.unversioned_latest_workspaces_agent_config
        expect(config_instance).to be_nil
      end
    end
  end

  context "when a workspaces_agent_config record already exists" do
    let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }

    context 'when config passed is empty' do
      let(:config) { {} }

      it 'does not create a config record' do
        expect { response }.to not_change { agent.reload.unversioned_latest_workspaces_agent_config.attributes }

        expect(response).to eq({
          status: :success,
          payload: { skipped_reason: :no_config_file_entry_found }
        })
      end
    end

    context 'when config passed results in updates to the workspaces_agent_config record' do
      it 'updates the config record' do
        expect(response).to eq({
          status: :success,
          payload: { workspaces_agent_config: agent.reload.unversioned_latest_workspaces_agent_config }
        })

        expect(agent.reload.unversioned_latest_workspaces_agent_config.dns_zone).to eq(dns_zone)
      end
    end

    context 'when config is invalid' do
      let(:dns_zone) { "invalid dns zone" }

      it 'does not update the record and returns error' do
        expect { response }.to not_change { agent.reload.unversioned_latest_workspaces_agent_config.attributes }

        expect(response).to eq({
          status: :error,
          message: "Agent config update failed: Dns zone contains invalid characters (valid characters: [a-z0-9\\-])",
          reason: :bad_request
        })
      end
    end
  end
end
