# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Clusters::AgentsResolver, feature_category: :environment_management do
  include GraphqlHelpers

  specify do
    expect(described_class).to have_nullable_graphql_type(Types::Clusters::AgentType.connection_type)
  end

  specify do
    expect(described_class.extras).to include(:lookahead)
  end

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let(:ctx) { { current_user: current_user } }
    let(:params) { {} }
    let_it_be(:maintainer) { create(:user, developer_of: project) }
    let_it_be(:reporter) { create(:user, reporter_of: project) }

    subject { resolve_agents(params) }

    context 'the current user has access to clusters' do
      let(:current_user) { maintainer }

      context 'when no filtering arguments are provided' do
        let_it_be(:agent_1) { create(:cluster_agent, project: project) }
        let_it_be(:agent_2) { create(:cluster_agent, project: project) }

        it 'finds all agents' do
          expect(subject).to contain_exactly(agent_1, agent_2)
        end
      end

      context 'when has_vulnerabilities argument is provided' do
        let(:params) { { has_vulnerabilities: has_vulnerabilities } }
        let_it_be(:agent_with_vulnerabilities) do
          create(:cluster_agent, project: project, has_vulnerabilities: true)
        end

        let_it_be(:agent_without_vulnerabilities) do
          create(:cluster_agent, project: project, has_vulnerabilities: false)
        end

        context 'when has_vulnerabilities is set to true' do
          let(:has_vulnerabilities) { true }

          it 'returns only agents with vulnerabilities' do
            expect(subject).to contain_exactly(agent_with_vulnerabilities)
          end
        end

        context 'when has_vulnerabilities is set to false' do
          let(:has_vulnerabilities) { false }

          it 'returns only agents without vulnerabilities' do
            expect(subject).to contain_exactly(agent_without_vulnerabilities)
          end
        end
      end

      context 'for agents with and without workspaces agent config' do
        let_it_be(:agent_with_workspaces_agent_config) do
          create(:ee_cluster_agent, :with_existing_workspaces_agent_config,
            project: project)
        end

        let_it_be(:agent_without_workspaces_agent_config) do
          create(:ee_cluster_agent, project: project)
        end

        context 'when has_workspaces_agent_config argument is provided' do
          let(:params) do
            { has_workspaces_agent_config: has_workspaces_agent_config }
          end

          context 'when has_workspaces_agent_config is set to true' do
            let(:has_workspaces_agent_config) { true }

            it 'returns only agents with workspaces_agent_config' do
              expect(subject).to contain_exactly(agent_with_workspaces_agent_config)
            end
          end

          context 'when has_workspaces_agent_config is set to false' do
            let(:has_workspaces_agent_config) { false }

            it 'returns only agents without workspaces_agent_config' do
              expect(subject).to contain_exactly(agent_without_workspaces_agent_config)
            end
          end
        end
      end

      context 'when has_remote_development_enabled argument is provided' do
        let(:params) { { has_remote_development_enabled: has_remote_development_enabled } }

        let_it_be(:agent_with_enabled_config) { create(:ee_cluster_agent, project: project) }
        let_it_be(:agent_without_enabled_config) { create(:ee_cluster_agent, project: project) }

        let_it_be(:config_for_enabled_agent) do
          create(:workspaces_agent_config, agent: agent_with_enabled_config, enabled: true)
        end

        let_it_be(:config_for_disabled_agent) do
          create(:workspaces_agent_config, agent: agent_without_enabled_config, enabled: false)
        end

        context 'when has_workspaces_agent_config is set to true' do
          let(:has_remote_development_enabled) { true }

          it 'returns only agents with workspaces_agent_config' do
            expect(subject).to contain_exactly(agent_with_enabled_config)
          end
        end
      end
    end

    context 'the current user does not have access to clusters' do
      let(:current_user) { reporter }

      it 'returns an empty result' do
        expect(subject).to be_empty
      end
    end
  end

  def resolve_agents(args = {})
    resolve(described_class, obj: project, ctx: ctx, lookahead: positive_lookahead, args: args)
  end
end
