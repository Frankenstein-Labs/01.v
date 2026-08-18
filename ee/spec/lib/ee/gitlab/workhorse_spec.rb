# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Workhorse, feature_category: :knowledge_graph do
  def decode_workhorse_header(array)
    key, value = array
    command, encoded_params = value.split(":")
    params = ::Gitlab::Json.safe_parse(Base64.urlsafe_decode64(encoded_params))

    [key, command, params]
  end

  describe '.send_orbit_query' do
    let(:user) { create(:user) }
    let(:query) { '{"nodes":["MergeRequest"]}' }
    let(:format) { :raw }
    let(:endpoint) { 'localhost:50054' }
    let(:jwt_token) { 'test-jwt-token' }
    let(:source_type) { 'rest' }
    let(:validated_source_type) { source_type }
    let(:request_context) { Analytics::KnowledgeGraph::RequestContext.new(source_type: source_type) }

    subject(:response) do
      described_class.send_orbit_query(query: query, user: user, format: format, request_context: request_context)
    end

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive_messages(
        configured_endpoint: endpoint,
        outgoing_headers: { 'x-gitlab-enabled-instance-verbose-ai-logs' => 'false' }
      )
      allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
        .with(hash_including(user: user, source_type: validated_source_type)).and_return(jwt_token)
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:secure_channel?).with(endpoint).and_return(false)
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:private_address?).with(endpoint).and_return(true)
    end

    it 'sets the header correctly' do
      key, command, params = decode_workhorse_header(response)

      expect(key).to eq('Gitlab-Workhorse-Send-Data')
      expect(command).to eq('orbit-query')
      expect(params).to eq({
        'GkgServer' => {
          'address' => endpoint,
          'tls' => false,
          'headers' => {
            'authorization' => "Bearer #{jwt_token}",
            'x-gitlab-enabled-instance-verbose-ai-logs' => 'false'
          }
        },
        'Query' => query,
        'Format' => format.to_s,
        'TimeoutSeconds' => 30
      })
    end

    context 'when on SaaS with gkg_verbose_logs flag enabled', :saas do
      before do
        allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:outgoing_headers).and_call_original
        stub_application_setting(enabled_instance_verbose_ai_logs: false)
      end

      it 'includes x-gitlab-enabled-feature-flags in headers' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'headers')).to include(
          'x-gitlab-enabled-feature-flags' => 'verbose_gkg_logs'
        )
      end
    end

    context 'when instance verbose AI logs setting is enabled' do
      before do
        allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:outgoing_headers).and_call_original
        stub_application_setting(enabled_instance_verbose_ai_logs: true)
      end

      it 'includes x-gitlab-enabled-instance-verbose-ai-logs in headers' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'headers')).to include(
          'x-gitlab-enabled-instance-verbose-ai-logs' => 'true'
        )
      end
    end

    context 'when mcp_id is provided' do
      subject(:response) do
        described_class.send_orbit_query(query: query, user: user, format: format, mcp_id: 'mcp-123',
          request_context: request_context)
      end

      it 'includes McpId in the params' do
        _, _, params = decode_workhorse_header(response)

        expect(params).to include('McpId' => 'mcp-123')
      end
    end

    context 'when mcp_id is nil' do
      it 'does not include McpId in the params' do
        _, _, params = decode_workhorse_header(response)

        expect(params).not_to have_key('McpId')
      end
    end

    context 'when query_type is :named' do
      subject(:response) do
        described_class.send_orbit_query(query: query, user: user, format: format, query_type: :named,
          request_context: request_context)
      end

      it 'includes QueryType in the params' do
        _, _, params = decode_workhorse_header(response)

        expect(params).to include('QueryType' => 'named')
      end
    end

    context 'when query_type is not provided' do
      it 'does not include QueryType in the params' do
        _, _, params = decode_workhorse_header(response)

        expect(params).not_to have_key('QueryType')
      end
    end

    context 'when the channel is secure' do
      before do
        allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:secure_channel?).with(endpoint).and_return(true)
      end

      it 'sets tls to true' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'tls')).to be(true)
      end
    end

    context 'when the channel is insecure and not private' do
      before do
        allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:secure_channel?).with(endpoint).and_return(false)
        allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:private_address?).with(endpoint).and_return(false)
      end

      it 'does not include the authorization header' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'headers')).not_to have_key('authorization')
      end
    end

    context 'when source_type is provided' do
      let(:source_type) { 'rest' }

      it 'passes source_type into JWT generation' do
        response

        expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
          .with(user: user, source_type: 'rest', session_id: nil)
      end
    end

    context 'when source_type is invalid' do
      let(:source_type) { 'invalid' }
      let(:validated_source_type) { 'rest' }
      let(:request_context) { Analytics::KnowledgeGraph::RequestContext.new(source_type: source_type) }

      it 'logs a warning and falls back to rest' do
        allow(Gitlab::AppLogger).to receive(:warn)

        response

        expect(Gitlab::AppLogger).to have_received(:warn)
          .with("Invalid source_type for Orbit query: \"invalid\", falling back to 'rest'")
        expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
          .with(user: user, source_type: 'rest', session_id: nil)
      end
    end

    context 'when source_type is code_intelligence' do
      let(:source_type) { Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE }
      let(:validated_source_type) { Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE }
      let(:request_context) { Analytics::KnowledgeGraph::RequestContext.new(source_type: source_type) }

      it 'accepts it without warning and passes it to JWT generation' do
        allow(Gitlab::AppLogger).to receive(:warn)

        response

        expect(Gitlab::AppLogger).not_to have_received(:warn)
        expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
          .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE, session_id: nil)
      end
    end

    context 'when session_id is provided' do
      subject(:response) do
        request_context = Analytics::KnowledgeGraph::RequestContext.new(
          source_type: source_type, session_id: 'workflow-abc-123'
        )
        described_class.send_orbit_query(
          query: query, user: user, format: format, request_context: request_context
        )
      end

      it 'passes session_id into JWT generation' do
        response

        expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
          .with(user: user, source_type: source_type, session_id: 'workflow-abc-123')
      end
    end

    context 'when session_id is nil' do
      it 'passes nil session_id into JWT generation' do
        response

        expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
          .with(user: user, source_type: source_type, session_id: nil)
      end
    end

    context 'when user_agent is provided' do
      subject(:response) do
        request_context = Analytics::KnowledgeGraph::RequestContext.new(
          source_type: source_type, user_agent: 'TestAgent/1.0'
        )
        described_class.send_orbit_query(
          query: query, user: user, format: format, request_context: request_context
        )
      end

      it 'includes x-client-user-agent in GkgServer headers' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'headers')).to include('x-client-user-agent' => 'TestAgent/1.0')
      end
    end

    context 'when user_agent is nil' do
      it 'does not include x-client-user-agent in GkgServer headers' do
        _, _, params = decode_workhorse_header(response)

        expect(params.dig('GkgServer', 'headers')).not_to have_key('x-client-user-agent')
      end
    end
  end
end
