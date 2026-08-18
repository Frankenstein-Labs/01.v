# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::Agent, feature_category: :deployment_management do
  let_it_be(:agent_1) { create(:ee_cluster_agent) }
  let_it_be(:agent_2) { create(:ee_cluster_agent) }
  let_it_be(:agent_3) { create(:ee_cluster_agent) }

  it { is_expected.to include_module(EE::Clusters::Agent) }
  it { is_expected.to have_many(:vulnerability_reads) }

  it do
    is_expected.to have_one(:agent_url_configuration)
      .class_name('Clusters::Agents::UrlConfiguration')
      .inverse_of(:agent)
  end

  describe 'unversioned_latest_workspaces_agent_config scopes' do
    let_it_be(:agent_with_remote_development_enabled) do
      create(:ee_cluster_agent, :with_existing_workspaces_agent_config).tap do |agent|
        agent.unversioned_latest_workspaces_agent_config.update!(enabled: true)
      end
    end

    let_it_be(:agent_with_remote_development_config_disabled) do
      create(:ee_cluster_agent, :with_existing_workspaces_agent_config).tap do |agent|
        agent.unversioned_latest_workspaces_agent_config.update!(enabled: false)
      end
    end

    describe '.with_workspaces_agent_config' do
      it 'return agents with unversioned_latest_workspaces_agent_config' do
        expect(described_class.with_workspaces_agent_config)
          .to contain_exactly(
            agent_with_remote_development_enabled, agent_with_remote_development_config_disabled)
        expect(described_class.with_workspaces_agent_config).not_to include(agent_1, agent_2,
          agent_3)
      end
    end

    describe '.without_workspaces_agent_config' do
      it 'return agents without unversioned_latest_workspaces_agent_config' do
        expect(described_class.without_workspaces_agent_config)
          .not_to include(agent_with_remote_development_enabled, agent_with_remote_development_config_disabled)
        expect(described_class.without_workspaces_agent_config).to include(agent_1, agent_2, agent_3)
      end
    end

    describe '.with_remote_development_enabled' do
      it 'returns agents with with_remote_development_enabled' do
        expect(described_class.with_remote_development_enabled)
          .to contain_exactly(agent_with_remote_development_enabled)
        expect(described_class.with_remote_development_enabled).not_to include(
          agent_1, agent_2, agent_3, agent_with_remote_development_config_disabled)
      end
    end

    describe '#resource_management_enabled?' do
      subject { agent_1.resource_management_enabled? }

      context 'when licensed feature is not available' do
        before do
          stub_licensed_features(agent_managed_resources: false)
        end

        it { is_expected.to be_falsey }
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(agent_managed_resources: true)
        end

        it { is_expected.to be_truthy }
      end
    end
  end
end
