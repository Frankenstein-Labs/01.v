# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::AgentsFinder, feature_category: :deployment_management do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:reporter) { create(:user) }

    let(:current_user) { user }

    subject { described_class.new(project, current_user).execute }

    context 'user does not have permission' do
      let(:current_user) { reporter }

      before_all do
        project.add_reporter(reporter)
      end

      it { is_expected.to be_empty }
    end

    context 'filtering by has_vulnerabilities' do
      let(:params) { { has_vulnerabilities: has_vulnerabilities } }
      let_it_be(:agent_without_vulnerabilities) { create(:cluster_agent, project: project, has_vulnerabilities: false) }
      let_it_be(:agent_with_vulnerabilities) { create(:cluster_agent, project: project, has_vulnerabilities: true) }

      subject { described_class.new(project, user, params: params).execute }

      context 'when params are not provided' do
        let(:params) { {} }

        it { is_expected.to contain_exactly(agent_without_vulnerabilities, agent_with_vulnerabilities) }
      end

      context 'when has_vulnerabilities is set to true' do
        let(:has_vulnerabilities) { true }

        it { is_expected.to contain_exactly(agent_with_vulnerabilities) }
      end

      context 'when has_vulnerabilities is set to false' do
        let(:has_vulnerabilities) { false }

        it { is_expected.to contain_exactly(agent_without_vulnerabilities) }
      end
    end

    context 'filtering by has_workspaces_agent_config' do
      let(:params) { { has_workspaces_agent_config: has_workspaces_agent_config } }
      let_it_be(:agent_with_workspaces_agent_config) do
        create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project)
      end

      let_it_be(:agent_without_workspaces_agent_config) do
        create(:ee_cluster_agent, project: project)
      end

      subject { described_class.new(project, user, params: params).execute }

      context 'when params are not provided' do
        let(:params) { {} }

        it do
          is_expected.to contain_exactly(
            agent_without_workspaces_agent_config,
            agent_with_workspaces_agent_config
          )
        end
      end

      context 'when has_workspaces_agent_config is set to true' do
        let(:has_workspaces_agent_config) { true }

        it { is_expected.to contain_exactly(agent_with_workspaces_agent_config) }
      end

      context 'when has_workspaces_agent_config is set to false' do
        let(:has_workspaces_agent_config) { false }

        it { is_expected.to contain_exactly(agent_without_workspaces_agent_config) }
      end
    end

    context 'when filtering by has_remote_development_enabled' do
      let(:params) { { has_remote_development_enabled: has_remote_development_enabled } }

      let_it_be(:agent_with_enabled_config) { create(:ee_cluster_agent, project: project) }
      let_it_be(:agent_without_enabled_config) { create(:ee_cluster_agent, project: project) }

      let_it_be(:config_for_enabled_agent) do
        create(:workspaces_agent_config, agent: agent_with_enabled_config, enabled: true)
      end

      let_it_be(:config_for_disabled_agent) do
        create(:workspaces_agent_config, agent: agent_without_enabled_config, enabled: false)
      end

      subject { described_class.new(project, user, params: params).execute }

      context 'when params are not provided' do
        let(:params) { {} }

        it do
          is_expected.to contain_exactly(
            agent_with_enabled_config,
            agent_without_enabled_config
          )
        end
      end

      context 'when has_remote_development_enabled is set' do
        let(:has_remote_development_enabled) { true }

        it { is_expected.to contain_exactly(agent_with_enabled_config) }
      end
    end
  end
end
