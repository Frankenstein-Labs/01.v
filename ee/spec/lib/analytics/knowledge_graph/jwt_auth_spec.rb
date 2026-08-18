# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::KnowledgeGraph::JwtAuth, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before_all do
    create(:knowledge_graph_enabled_namespace, namespace: group)
    group.add_reporter(user)
    described_class.ensure_secret!
  end

  describe '.ensure_secret!' do
    context 'when secret file exists' do
      before do
        allow(File).to receive(:exist?).with(Gitlab.config.knowledge_graph.secret_file).and_return(true)
      end

      it 'does not call write_secret' do
        expect(described_class).not_to receive(:write_secret)

        described_class.ensure_secret!
      end
    end

    context 'when secret file does not exist' do
      before do
        allow(File).to receive(:exist?).with(Gitlab.config.knowledge_graph.secret_file).and_return(false)
      end

      it 'calls write_secret' do
        expect(described_class).to receive(:write_secret)

        described_class.ensure_secret!
      end
    end

    shared_examples 'rescues write error gracefully' do |error_class|
      let(:secret_path) { Gitlab.config.knowledge_graph.secret_file }
      let(:kg_logger) { instance_double(Gitlab::KnowledgeGraph::Logger) }

      before do
        allow(File).to receive(:exist?).with(Gitlab.config.knowledge_graph.secret_file).and_return(false)
        allow(described_class).to receive(:write_secret).and_raise(error_class, secret_path.to_s)
        described_class.instance_variable_set(:@logger, nil)
        allow(Gitlab::KnowledgeGraph::Logger).to receive(:build).and_return(kg_logger)
        allow(kg_logger).to receive(:warn)
      end

      after do
        described_class.instance_variable_set(:@logger, nil)
      end

      it 'does not raise and logs a warning' do
        expect { described_class.ensure_secret! }.not_to raise_error

        expect(kg_logger).to have_received(:warn).with(
          hash_including(
            message: 'Could not write Knowledge Graph secret file',
            secret_path: secret_path,
            error: error_class.name
          )
        )
      end
    end

    context 'when write_secret raises Errno::EACCES' do
      it_behaves_like 'rescues write error gracefully', Errno::EACCES
    end

    context 'when write_secret raises Errno::EPERM' do
      it_behaves_like 'rescues write error gracefully', Errno::EPERM
    end

    context 'when write_secret raises Errno::EROFS' do
      it_behaves_like 'rescues write error gracefully', Errno::EROFS
    end

    context 'when write_secret raises Errno::ENOENT' do
      it_behaves_like 'rescues write error gracefully', Errno::ENOENT
    end
  end

  describe '.generate_token' do
    let(:source_type) { Analytics::KnowledgeGraph::SourceType::REST }

    subject(:token) { described_class.generate_token(user: user, source_type: source_type) }

    it 'returns a JWT token' do
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3)
    end

    it 'includes required claims' do
      decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
      payload = decoded.first

      expect(payload['sub']).to eq("user:#{user.id}")
      expect(payload['iss']).to eq('gitlab')
      expect(payload['aud']).to eq('gitlab-knowledge-graph')
      expect(payload['user_id']).to eq(user.id)
      expect(payload['username']).to eq(user.username)
      expect(payload['min_access_level']).to eq(Gitlab::Access::REPORTER)
      expect(payload['instance_id']).to eq(Gitlab::GlobalAnonymousId.instance_id)
      expect(payload['unique_instance_id']).to eq(Gitlab::GlobalAnonymousId.instance_uuid)
      expect(payload['instance_version']).to eq(Gitlab.version_info.to_s)
      expect(payload['global_user_id']).to eq(Gitlab::GlobalAnonymousId.user_id(user))
      expect(payload['host_name']).to eq(Gitlab.config.gitlab.host)
      expect(payload['deployment_type']).to eq(::CloudConnector.deployment_type)
      expect(payload['realm']).to eq(::CloudConnector.gitlab_realm)
      expect(payload['is_gitlab_team_member']).to eq(::Gitlab::Com.gitlab_com_group_member?(user))
      expect(payload['user_type']).to eq(user.user_type)
    end

    it 'includes root_namespace_id from the user preference fallback', :saas do
      stub_saas_features(gitlab_com_subscriptions: true)
      create(:gitlab_subscription, :premium, namespace: group)

      decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
      payload = decoded.first

      expect(payload['root_namespace_id'])
        .to eq(user.user_preference.knowledge_graph_governing_namespace_with_fallback.id)
    end

    it 'includes source_type when provided' do
      decoded = JWT.decode(
        described_class.generate_token(user: user, source_type: Analytics::KnowledgeGraph::SourceType::MCP),
        described_class.secret, true, { algorithm: 'HS256' }
      )

      expect(decoded.first['source_type']).to eq(Analytics::KnowledgeGraph::SourceType::MCP)
    end

    it 'includes session_id when provided' do
      decoded = JWT.decode(
        described_class.generate_token(user: user, source_type: source_type, session_id: 'workflow-abc-123'),
        described_class.secret, true, { algorithm: 'HS256' }
      )

      expect(decoded.first['session_id']).to eq('workflow-abc-123')
    end

    it 'omits session_id when not provided' do
      decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })

      expect(decoded.first).not_to have_key('session_id')
    end

    it 'omits session_id when blank' do
      decoded = JWT.decode(
        described_class.generate_token(user: user, source_type: source_type, session_id: ''),
        described_class.secret, true, { algorithm: 'HS256' }
      )

      expect(decoded.first).not_to have_key('session_id')
    end

    it 'includes group_traversal_ids as role-tagged tuples for non-admin users' do
      decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
      payload = decoded.first

      expect(payload).to have_key('group_traversal_ids')
      expect(payload['admin']).to be(false)
      # GKG's claims::TraversalPathClaim expects `{path, access_levels}` tuples
      # so it can filter paths per-entity at SQL-compile time while retaining
      # exact role data for non-hierarchy roles.
      # Any non-empty entry must carry all keys; an admin user returns no entries
      # (handled in the admin branch below).
      payload['group_traversal_ids'].each do |entry|
        expect(entry).to include('path', 'access_levels')
        expect(entry).not_to have_key('access_level')
        expect(entry['access_levels']).to all(be_a(Integer))
      end
    end

    it 'includes organization_id from user in payload' do
      decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
      payload = decoded.first

      expect(payload['organization_id']).to eq(user.organization_id)
    end

    context 'with admin user' do
      let_it_be(:admin) { create(:admin) }

      subject(:token) { described_class.generate_token(user: admin, source_type: source_type) }

      before do
        allow(admin).to receive(:can_read_all_resources?).and_return(true)
      end

      it 'sets admin flag to true' do
        decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
        payload = decoded.first

        expect(payload['admin']).to be(true)
      end

      it 'does not include traversal_ids for admin' do
        decoded = JWT.decode(token, described_class.secret, true, { algorithm: 'HS256' })
        payload = decoded.first

        expect(payload).not_to have_key('group_traversal_ids')
      end
    end

    context 'with nil user' do
      subject(:token) { described_class.generate_token(user: nil, source_type: source_type) }

      it 'returns nil' do
        expect(token).to be_nil
      end
    end

    context 'when AuthorizationContext raises an error' do
      let(:kg_logger) { instance_double(Gitlab::KnowledgeGraph::Logger) }

      before do
        allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_raise(StandardError)
        described_class.instance_variable_set(:@logger, nil)
        allow(Gitlab::KnowledgeGraph::Logger).to receive(:build).and_return(kg_logger)
        allow(kg_logger).to receive(:error)
      end

      after do
        described_class.instance_variable_set(:@logger, nil)
      end

      it 'returns nil and logs the error with context' do
        expect(described_class.generate_token(user: user, source_type: source_type)).to be_nil

        expect(kg_logger).to have_received(:error)
          .with(hash_including(
            message: 'Knowledge Graph JWT generation failed',
            error: 'StandardError',
            Labkit::Fields::GL_USER_ID => user.id
          ))
      end
    end
  end

  describe '.decode_token' do
    let(:valid_token) do
      described_class.generate_token(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST)
    end

    it 'decodes a valid token' do
      decoded = described_class.decode_token(valid_token)

      expect(decoded).to be_an(Array)
      expect(decoded.first['user_id']).to eq(user.id)
    end

    it 'returns nil for invalid token' do
      decoded = described_class.decode_token('invalid.token.here')

      expect(decoded).to be_nil
    end

    it 'returns nil for tampered token' do
      tampered = valid_token.reverse

      decoded = described_class.decode_token(tampered)

      expect(decoded).to be_nil
    end

    it 'returns nil for token with wrong issuer' do
      payload = { sub: "user:#{user.id}", iss: 'wrong-issuer', aud: 'gitlab-knowledge-graph',
                  exp: 5.minutes.from_now.to_i }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      expect(described_class.decode_token(token)).to be_nil
    end

    it 'returns nil for token with wrong audience' do
      payload = { sub: "user:#{user.id}", iss: 'gitlab', aud: 'wrong-audience',
                  exp: 5.minutes.from_now.to_i }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      expect(described_class.decode_token(token)).to be_nil
    end

    it 'returns nil for token with missing subject' do
      payload = { iss: 'gitlab', aud: 'gitlab-knowledge-graph', exp: 5.minutes.from_now.to_i }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      expect(described_class.decode_token(token)).to be_nil
    end

    it 'accepts a custom subject prefix' do
      payload = { sub: 'service:gkg-indexer', iss: 'gitlab', aud: 'gitlab-knowledge-graph',
                  exp: 5.minutes.from_now.to_i }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      decoded = described_class.decode_token(token, expected_sub_prefix: 'service:')
      expect(decoded).not_to be_nil
      expect(decoded.first['sub']).to eq('service:gkg-indexer')
    end

    it 'rejects token when subject does not match expected prefix' do
      payload = { sub: 'service:gkg-indexer', iss: 'gitlab', aud: 'gitlab-knowledge-graph',
                  exp: 5.minutes.from_now.to_i }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      expect(described_class.decode_token(token)).to be_nil
    end

    it 'returns nil for token without exp claim' do
      payload = { sub: "user:#{user.id}", iss: 'gitlab', aud: 'gitlab-knowledge-graph',
                  iat: Time.current.to_i, user_id: user.id }
      token = JWT.encode(payload, described_class.secret, 'HS256')

      expect(described_class.decode_token(token)).to be_nil
    end

    context 'with expired token', :freeze_time do
      it 'returns nil for expired token' do
        token = described_class.generate_token(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST)
        travel_to(6.minutes.from_now)

        decoded = described_class.decode_token(token)

        expect(decoded).to be_nil
      end
    end

    context 'with KNOWLEDGE_GRAPH_JWT_SKIP_EXPIRY set', :freeze_time do
      before do
        stub_env('KNOWLEDGE_GRAPH_JWT_SKIP_EXPIRY', 'true')
      end

      it 'does not expire in development/test' do
        token = described_class.generate_token(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST)
        travel_to(1.hour.from_now)

        decoded = described_class.decode_token(token)

        expect(decoded).not_to be_nil
        expect(decoded.first['user_id']).to eq(user.id)
      end
    end

    context 'when secret file does not exist' do
      let(:kg_logger) { instance_double(Gitlab::KnowledgeGraph::Logger) }

      before do
        described_class.instance_variable_set(:@logger, nil)
        allow(Gitlab::KnowledgeGraph::Logger).to receive(:build).and_return(kg_logger)
        allow(kg_logger).to receive(:warn)
        described_class.clear_memoization(:secret)
        allow(File).to receive(:read).and_call_original
        allow(File).to receive(:read).with(Gitlab.config.knowledge_graph.secret_file).and_raise(Errno::ENOENT)
      end

      after do
        described_class.instance_variable_set(:@logger, nil)
        described_class.clear_memoization(:secret)
      end

      it 'returns nil and logs that secret is not configured' do
        expect(described_class.decode_token('any.token.here')).to be_nil

        expect(kg_logger).to have_received(:warn).with(
          hash_including(
            message: 'Knowledge Graph secret file not configured',
            error: 'Errno::ENOENT'
          )
        )
      end
    end

    context 'when JWT.decode returns nil' do
      it 'returns nil' do
        allow(JWT).to receive(:decode).and_return(nil)

        expect(described_class.decode_token('any.token.here')).to be_nil
      end
    end
  end

  describe '.skip_expiration?' do
    context 'in production environment' do
      it 'returns false regardless of env var' do
        stub_env('KNOWLEDGE_GRAPH_JWT_SKIP_EXPIRY', 'true')
        allow(Rails.env).to receive_messages(development?: false, test?: false)

        expect(described_class.send(:skip_expiration?)).to be(false)
      end
    end
  end

  describe '.authorization_header' do
    it 'returns Bearer token header' do
      header = described_class.authorization_header(
        user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST
      )

      expect(header).to start_with('Bearer ')
    end

    it 'passes source_type through to token generation' do
      allow(described_class).to receive(:generate_token).and_return('token')

      described_class.authorization_header(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST)

      expect(described_class).to have_received(:generate_token)
        .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: nil)
    end

    it 'passes session_id through to token generation' do
      allow(described_class).to receive(:generate_token).and_return('token')

      described_class.authorization_header(
        user: user,
        source_type: Analytics::KnowledgeGraph::SourceType::REST,
        session_id: 'workflow-abc-123'
      )

      expect(described_class).to have_received(:generate_token)
        .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: 'workflow-abc-123')
    end

    it 'returns nil when token generation fails' do
      header = described_class.authorization_header(user: nil, source_type: Analytics::KnowledgeGraph::SourceType::REST)

      expect(header).to be_nil
    end
  end
end
