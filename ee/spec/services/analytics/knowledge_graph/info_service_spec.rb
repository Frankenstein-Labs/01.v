# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::InfoService, :silence_stdout, feature_category: :knowledge_graph do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger, options: options) }
  let(:options) { {} }

  before do
    allow(logger).to receive(:info)
    allow(Feature).to receive_messages(
      current_request: nil,
      enabled?: false,
      persisted_name?: false
    )

    allow(Gitlab).to receive(:version_info).and_return(Gitlab::VersionInfo.new(17, 8, 0))
    allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
    allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(false)
    stub_knowledge_graph_config(enabled: false)
    allow(License).to receive(:feature_available?).and_return(false)
    allow(Group).to receive_message_chain(:top_level, :count).and_return(0)
    allow(Analytics::KnowledgeGraph::EnabledNamespace).to receive(:count).and_return(0)
    allow(Analytics::KnowledgeGraph::CodeIndexingTask).to receive_message_chain(:where, :count).and_return(0)
    stub_env('ORBIT_INFO_USER', nil)
    allow(Feature).to receive(:persisted_names).and_return([])
  end

  describe '#execute' do
    context 'when displaying settings section' do
      before do
        stub_knowledge_graph_config(enabled: true, grpc_endpoint: 'gkg.example.com:50054')
        allow(License).to receive(:feature_available?).with(:orbit).and_return(true)
      end

      it 'displays the Orbit / Knowledge Graph header and settings', :aggregate_failures do
        service.execute

        expect(logger).to have_received(:info)
          .with("\n#{Rainbow('Orbit / Knowledge Graph').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(/GitLab version:.+17\.8\.0/)
        expect(logger).to have_received(:info).with(/Deployment:.+Self-managed/)
        expect(logger).to have_received(:info).with(/knowledge_graph\.enabled:.+#{Rainbow('yes').green}/)
        expect(logger).to have_received(:info).with(/gRPC endpoint:.+gkg\.example\.com:50054/).at_least(:once)
        expect(logger).to have_received(:info).with(/License :orbit available:.+#{Rainbow('yes').green}/)
      end

      context 'when on SaaS' do
        before do
          allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        end

        it 'displays SaaS deployment and per-namespace license note', :aggregate_failures do
          service.execute

          expect(logger).to have_received(:info).with(/Deployment:.+SaaS/)
          expect(logger).to have_received(:info).with(/License :orbit available:.+per-namespace on SaaS/)
        end
      end

      context 'when on Dedicated' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance?).and_return(true)
        end

        it 'displays Dedicated deployment type' do
          service.execute

          expect(logger).to have_received(:info).with(/Deployment:.+Dedicated/)
        end
      end

      context 'when knowledge_graph config is missing' do
        before do
          stub_knowledge_graph_config_missing
        end

        it 'displays knowledge_graph.enabled as no' do
          service.execute

          expect(logger).to have_received(:info).with(/knowledge_graph\.enabled:.+no/)
        end
      end

      context 'when gRPC endpoint is the default' do
        before do
          stub_knowledge_graph_config(enabled: true, grpc_endpoint: 'localhost:50054')
        end

        it 'flags the endpoint as not explicitly configured' do
          service.execute

          expect(logger).to have_received(:info).with(/gRPC endpoint:.+localhost:50054.+not explicitly configured/)
        end
      end
    end

    context 'when displaying service health section' do
      context 'when ORBIT_INFO_USER is not set' do
        it 'skips the cluster health probe' do
          service.execute

          expect(logger).to have_received(:info).with(/Cluster health:.+skipped/)
        end
      end

      context 'when ORBIT_INFO_USER is a numeric ID' do
        let_it_be(:user) { create(:user) }
        let(:rest_context) { having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::REST) }

        before do
          stub_env('ORBIT_INFO_USER', user.id.to_s)
        end

        it 'resolves by ID and probes cluster health', :aggregate_failures do
          client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
          allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
          allow(client).to receive(:get_cluster_health)
            .with(user: user, request_context: rest_context).and_return(
              {
                status: 'healthy',
                version: '1.2.3',
                timestamp: '2025-01-15T10:00:00Z',
                components: [
                  { name: 'graph-db', status: 'healthy' },
                  { name: 'indexer', status: 'healthy' }
                ]
              }
            )

          service.execute

          expect(logger).to have_received(:info).with(/Cluster health status:.+healthy/)
          expect(logger).to have_received(:info).with(/Cluster health version:.+1\.2\.3/)
          expect(logger).to have_received(:info).with(/graph-db:.+healthy/)
          expect(logger).to have_received(:info).with(/indexer:.+healthy/)
        end

        it 'passes a REST source_type in the request context' do
          client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
          allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
          allow(client).to receive(:get_cluster_health).and_return({ status: 'healthy', components: [] })

          service.execute

          expect(client).to have_received(:get_cluster_health)
            .with(user: user, request_context: rest_context)
        end

        context 'when the GKG client returns an error hash' do
          it 'displays the gracefully degraded response', :aggregate_failures do
            client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
            allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
            allow(client).to receive(:get_cluster_health)
              .with(user: user, request_context: rest_context)
              .and_return({ status: 'unknown', error: 'Service unreachable' })

            service.execute

            expect(logger).to have_received(:info).with(/Cluster health status:.+unknown/)
            expect(logger).to have_received(:info).with(/Cluster health error:.+Service unreachable/)
          end
        end

        context 'when the gRPC client raises AuthorizationError' do
          it 'logs the error and continues', :aggregate_failures do
            client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
            allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
            allow(client).to receive(:get_cluster_health)
              .with(user: user, request_context: rest_context)
              .and_raise(Analytics::KnowledgeGraph::GrpcClient::AuthorizationError,
                'Failed to generate authorization header')

            service.execute

            expect(logger).to have_received(:info).with(/Cluster health status:.+unknown/)
            expect(logger).to have_received(:info)
              .with(/Cluster health error:.+Failed to generate authorization header/)
            expect(logger).to have_received(:info)
              .with("\n#{Rainbow('Indexing status').bright.yellow.underline}")
          end
        end

        context 'when the gRPC client raises ConnectionError' do
          it 'logs the error and continues', :aggregate_failures do
            client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
            allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
            allow(client).to receive(:get_cluster_health)
              .with(user: user, request_context: rest_context)
              .and_raise(Analytics::KnowledgeGraph::GrpcClient::ConnectionError,
                'Connection refused')

            service.execute

            expect(logger).to have_received(:info).with(/Cluster health status:.+unknown/)
            expect(logger).to have_received(:info)
              .with(/Cluster health error:.+Connection refused/)
          end
        end
      end

      context 'when ORBIT_INFO_USER is a username' do
        let_it_be(:user) { create(:user, username: 'orbit_admin') }
        let(:rest_context) { having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::REST) }

        before do
          stub_env('ORBIT_INFO_USER', 'orbit_admin')
        end

        it 'resolves by username and probes cluster health', :aggregate_failures do
          client = instance_double(Analytics::KnowledgeGraph::GrpcClient)
          allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(client)
          allow(client).to receive(:get_cluster_health)
            .with(user: user, request_context: rest_context)
            .and_return({ status: 'healthy', version: '2.0.0', components: [] })

          service.execute

          expect(logger).to have_received(:info).with(/Cluster health status:.+healthy/)
          expect(logger).to have_received(:info).with(/Cluster health version:.+2\.0\.0/)
        end
      end

      context 'when ORBIT_INFO_USER is a non-existent numeric ID' do
        before do
          stub_env('ORBIT_INFO_USER', '999999999')
        end

        it 'displays user not found' do
          service.execute

          expect(logger).to have_received(:info).with(/Cluster health:.+user '999999999' not found/)
        end
      end

      context 'when ORBIT_INFO_USER is a non-existent username' do
        before do
          stub_env('ORBIT_INFO_USER', 'no_such_user')
        end

        it 'displays user not found' do
          service.execute

          expect(logger).to have_received(:info).with(/Cluster health:.+user 'no_such_user' not found/)
        end
      end
    end

    context 'when displaying indexing status section' do
      before do
        allow(Group).to receive_message_chain(:top_level, :count).and_return(42)
        allow(Analytics::KnowledgeGraph::EnabledNamespace).to receive(:count).and_return(5)
        allow(Analytics::KnowledgeGraph::CodeIndexingTask).to receive_message_chain(:where, :count).and_return(100)
      end

      it 'displays indexing status counts', :aggregate_failures do
        service.execute

        expect(logger).to have_received(:info)
          .with("\n#{Rainbow('Indexing status').bright.yellow.underline}")
        expect(logger).to have_received(:info).with(/Group count \(top-level\):.+42/)
        expect(logger).to have_received(:info).with(/EnabledNamespace count:.+5/)
        expect(logger).to have_received(:info).with(/CodeIndexingTask count \(last 24h\):.+100/)
      end
    end

    context 'when displaying feature flags sections' do
      context 'with persisted orbit flags' do
        before do
          persisted = %w[knowledge_graph orbit_foundational_agent other_flag]
          allow(Feature).to receive(:persisted_names).and_return(persisted)
          allow(Feature).to receive(:persisted_name?) do |name|
            %w[knowledge_graph orbit_foundational_agent].include?(name)
          end
          allow(Feature::Definition).to receive_messages(
            definitions: {},
            has_definition?: false
          )
          allow(Feature::Definition).to receive(:has_definition?)
            .with(:knowledge_graph).and_return(true)
          allow(Feature::Definition).to receive(:has_definition?)
            .with(:orbit_foundational_agent).and_return(true)
          allow(Feature).to receive(:enabled?)
            .with(:knowledge_graph, nil).and_return(true)
          allow(Feature).to receive(:enabled?)
            .with(:orbit_foundational_agent, nil).and_return(false)
        end

        it 'displays non-default feature flags with color-coded states', :aggregate_failures do
          service.execute

          expect(logger).to have_received(:info)
            .with("\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/knowledge_graph:.+enabled/)
          expect(logger).to have_received(:info)
            .with(/orbit_foundational_agent:.+disabled/)
        end
      end

      context 'with no persisted orbit flags' do
        it 'displays "none" for non-default flags', :aggregate_failures do
          service.execute

          expect(logger).to have_received(:info)
            .with("\n#{Rainbow('Feature Flags (Non-Default Values)').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/Feature flags:.+none/)
        end
      end

      context 'with default orbit flags' do
        before do
          allow(Feature::Definition).to receive_messages(
            definitions: {
              knowledge_graph: instance_double(Feature::Definition),
              orbit_user_preference: instance_double(Feature::Definition),
              unrelated_flag: instance_double(Feature::Definition)
            },
            has_definition?: true
          )
          allow(Feature).to receive(:enabled?)
            .with(:knowledge_graph, nil).and_return(false)
          allow(Feature).to receive(:enabled?)
            .with(:orbit_user_preference, nil).and_return(true)
        end

        it 'displays default feature flags', :aggregate_failures do
          service.execute

          expect(logger).to have_received(:info)
            .with("\n#{Rainbow('Feature Flags (Default Values)').bright.yellow.underline}")
          expect(logger).to have_received(:info).with(/knowledge_graph:.+disabled/)
          expect(logger).to have_received(:info).with(/orbit_user_preference:.+enabled/)
        end
      end
    end

    context 'when extended_mode is false' do
      let(:options) { { extended_mode: false } }

      it 'does not display enabled namespace details' do
        service.execute

        expect(logger).not_to have_received(:info)
          .with("\n#{Rainbow('Enabled Namespace Details').bright.yellow.underline}")
      end
    end

    context 'when extended_mode is true' do
      let(:options) { { extended_mode: true } }

      it 'displays the enabled namespace details header' do
        service.execute

        expect(logger).to have_received(:info)
          .with("\n#{Rainbow('Enabled Namespace Details').bright.yellow.underline}")
      end
    end
  end

  private

  def stub_knowledge_graph_config(enabled: false, grpc_endpoint: 'localhost:50054')
    config = double('knowledge_graph_config') # rubocop:disable RSpec/VerifiedDoubles -- stub for config
    allow(config).to receive(:[]).with('enabled').and_return(enabled)
    gitlab_config = double('gitlab_config', knowledge_graph: config) # rubocop:disable RSpec/VerifiedDoubles -- stub for config
    allow(Gitlab).to receive(:config).and_return(gitlab_config)
    allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:configured_endpoint).and_return(grpc_endpoint)
  end

  def stub_knowledge_graph_config_missing
    config = double('knowledge_graph_config') # rubocop:disable RSpec/VerifiedDoubles -- testing missing config
    allow(config).to receive(:[]).with('enabled').and_raise(Gitlab::Configs::MissingConfig, 'missing')
    gitlab_config = double('gitlab_config', knowledge_graph: config) # rubocop:disable RSpec/VerifiedDoubles -- stub for config
    allow(Gitlab).to receive(:config).and_return(gitlab_config)
    allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:configured_endpoint).and_return('localhost:50054')
  end
end
