# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Client, :zoekt_settings_enabled, :zoekt_cache_disabled, :clean_gitlab_redis_cache, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project_1) { create(:project, :public, :small_repo, namespace: namespace) }
  let_it_be(:project_2) { create(:project, :public, :small_repo, namespace: namespace) }
  let_it_be(:project_3) { create(:project, :public, :small_repo, namespace: namespace) }
  let(:client) { described_class.new }

  before_all do
    zoekt_ensure_project_indexed!(project_1)
    zoekt_ensure_project_indexed!(project_2)
    zoekt_ensure_project_indexed!(project_3)
  end

  shared_examples 'an authenticated zoekt request' do
    context 'when JWT authentication is enabled' do
      let(:auth_token) { 'test-jwt-token' }

      before do
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_return(auth_token)
      end

      it 'includes JWT authorization header in the request' do
        headers = { described_class::JWT_HEADER => "Bearer #{auth_token}" }
        mock_response = instance_double(HTTParty::Response, code: 200, success?: true, body: '{"Files": []}')
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(headers: hash_including(headers)))
          .and_return(mock_response)

        make_request
      end
    end

    context 'when JWT token is invalid or missing' do
      it 'raises ClientConnectionError when server returns 401 Unauthorized' do
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_return('invalid-token')
        mock_response = instance_double(HTTParty::Response,
          code: 401,
          success?: false,
          body: 'Unauthorized: invalid JWT token'
        )
        allow(::Gitlab::HTTP).to receive(:post).and_return(mock_response)

        expect { make_request }.to raise_error(Search::Zoekt::Errors::ClientConnectionError)
      end

      it 'raises ClientConnectionError when JWT generation fails' do
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_raise(StandardError.new('JWT generation failed'))

        expect { make_request }.to raise_error(StandardError, 'JWT generation failed')
      end

      it 'still includes JWT header even if token is nil' do
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_return(nil)
        headers = { described_class::JWT_HEADER => "Bearer " }
        mock_response = instance_double(HTTParty::Response, code: 401, success?: false, body: 'Unauthorized')
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(headers: hash_including(headers)))
          .and_return(mock_response)

        expect { make_request }.to raise_error(Search::Zoekt::Errors::ClientConnectionError)
      end

      it 'handles server rejection when JWT header is missing entirely' do
        # Simulate what would happen if JWT header was not included
        allow(Search::Zoekt::JwtAuth).to receive(:authorization_header).and_return(nil)
        mock_response = instance_double(HTTParty::Response,
          code: 401,
          success?: false,
          body: 'Unauthorized: missing JWT token'
        )
        allow(::Gitlab::HTTP).to receive(:post).and_return(mock_response)

        expect { make_request }.to raise_error(Search::Zoekt::Errors::ClientConnectionError, /missing JWT token/)
      end
    end
  end

  shared_examples 'with relative base_url' do |method|
    let(:base_url) { [zoekt_node.index_base_url, 'nodes', 'zoekt-2'].join('/') }
    let(:custom_node) { create(:zoekt_node, index_base_url: base_url, search_base_url: base_url) }
    let(:body) { {} }
    let(:response) { instance_double(Net::HTTPResponse, body: body.to_json) }
    let(:success) do
      instance_double(HTTParty::Response,
        code: 200, success?: true, parsed_response: body, response: response, body: response.body
      )
    end

    it 'send request to the correct URL' do
      raise 'Unknown method' if %i[delete post].exclude?(method)

      requested_url = custom_node.index_base_url + expected_path
      expect(Gitlab::HTTP).to receive(method).with(requested_url, anything).and_return(success)
      make_request
    end
  end

  shared_examples 'with connection errors' do |method|
    Gitlab::HTTP::HTTP_ERRORS.each do |error|
      context "when an `#{error}` is raised while trying to connect to zoekt" do
        before do
          allow(::Gitlab::HTTP).to receive(method).and_raise(error)
        end

        it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
      end
    end

    context 'when an exception is raised during json parsing' do
      let(:invalid_json_body) { '' }
      let(:response) { instance_double(HTTParty::Response, code: 200, success?: true, body: invalid_json_body) }

      before do
        allow(::Gitlab::HTTP).to receive(method).and_return response
      end

      it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
    end
  end

  describe '#search' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:search_mode) { 'regex' }
    let(:targets) { { node_id => project_ids } }
    let(:options) { {} }

    subject(:search) do
      client.search(query, num: 10, targets: targets, search_mode: search_mode, **options)
    end

    context 'when user does not have permission to read across the projects' do
      before do
        allow(Ability).to receive(:allowed?).with(anything, :read_cross_project).and_return(false)
      end

      it 'returns an empty array', :aggregate_failures do
        expect(search.file_count).to eq 0
      end
    end

    context 'when zoekt traversal ID search is unavailable' do
      before do
        stub_zoekt_features(traversal_id_search: false)
      end

      context 'and no targets are provided' do
        let(:targets) { {} }

        it 'returns an empty response' do
          expect(search.file_count).to eq 0
          expect(search.match_count).to eq 0
          expect(search.result[:Files]).to be_nil
        end
      end
    end

    context 'with load balancer' do
      context 'with global search' do
        it 'tracks correct load for node via load balancer' do
          load_balancer = ::Search::Zoekt::LoadBalancer.new([node])
          allow(::Search::Zoekt::LoadBalancer).to receive(:new).and_return(load_balancer)
          expect(load_balancer).to receive(:increase_load).with(node, weight: 5)
          expect(load_balancer).to receive(:decrease_load).with(node, weight: 5)

          search

          distribution = load_balancer.distribution
          expect(distribution.find { |h| h[:node_id] == node.id }[:current_load]).to eq(0.0)
        end
      end

      context 'with group search' do
        let(:options) { { group_id: project_1.namespace.id } }

        it 'tracks load for node via load balancer' do
          load_balancer = ::Search::Zoekt::LoadBalancer.new([node])
          expect(::Search::Zoekt::LoadBalancer).to receive(:new).and_return(load_balancer)
          expect(load_balancer).to receive(:increase_load).with(node, weight: 3)
          expect(load_balancer).to receive(:decrease_load).with(node, weight: 3)

          search

          distribution = load_balancer.distribution
          expect(distribution.find { |h| h[:node_id] == node.id }[:current_load]).to eq(0.0)
        end
      end

      context 'with project search' do
        let(:options) { { project_id: project_1.id } }

        it 'tracks correct load for node via load balancer' do
          load_balancer = ::Search::Zoekt::LoadBalancer.new([node])
          expect(::Search::Zoekt::LoadBalancer).to receive(:new).and_return(load_balancer)
          expect(load_balancer).to receive(:increase_load).with(node, weight: 1)
          expect(load_balancer).to receive(:decrease_load).with(node, weight: 1)

          search

          distribution = load_balancer.distribution
          expect(distribution.find { |h| h[:node_id] == node.id }[:current_load]).to eq(0.0)
        end
      end

      context 'when using traversal id search' do
        let(:targets) { {} }

        it 'calls #pick on the load balancer to select the appropriate node' do
          load_balancer = ::Search::Zoekt::LoadBalancer.new([node])
          expect(::Search::Zoekt::LoadBalancer).to receive(:new).and_return(load_balancer)
          expect(load_balancer).to receive(:pick).and_return(node)

          search
        end
      end
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { search }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { search }
      let(:expected_path) { '/webserver/api/v2/search' }
    end
  end

  describe 'JWT authentication enforcement', :aggregate_failures do
    let(:client) { described_class.new }
    let(:query) { 'test' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }

    context 'when making requests without JWT authentication' do
      let(:missing_jwt_error_pattern) { /Unauthorized.*missing.*Gitlab-Zoekt-Api-Request/ }

      before do
        # Stub the JWT auth to return no header, simulating missing JWT
        allow_next_instance_of(described_class) do |client_instance|
          allow(client_instance).to receive(:request_headers).and_return({
            'Content-Type' => 'application/json'
          })
        end
      end

      it 'search method is rejected by server without JWT' do
        expect do
          client.search(query, num: 10, project_ids: [project_1.id], node_id: node_id, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, missing_jwt_error_pattern)
      end

      it 'search method is rejected by server without JWT' do
        targets = { node_id => [project_1.id] }
        expect do
          client.search(query, num: 10, targets: targets, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, missing_jwt_error_pattern)
      end
    end

    context 'when making requests with invalid JWT token' do
      before do
        # Stub JWT auth to return an invalid token
        allow(Search::Zoekt::JwtAuth).to receive(:jwt_token).and_return('invalid.jwt.token')
      end

      it 'search method is rejected by server with invalid JWT' do
        expect do
          client.search(query, num: 10, project_ids: [project_1.id], node_id: node_id, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, /Unauthorized.*invalid JWT token/)
      end

      it 'search method is rejected by server with invalid JWT' do
        targets = { node_id => [project_1.id] }
        expect do
          client.search(query, num: 10, targets: targets, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, /Unauthorized.*invalid JWT token/)
      end
    end

    context 'when making requests with malformed JWT authorization header' do
      before do
        # Stub the request headers to include a malformed JWT header
        allow_next_instance_of(described_class) do |client_instance|
          allow(client_instance).to receive(:request_headers).and_return({
            'Content-Type' => 'application/json',
            described_class::JWT_HEADER => 'Malformed header without Bearer prefix'
          })
        end
      end

      it 'search method is rejected by server with malformed JWT header' do
        expect do
          client.search(query, num: 10, project_ids: [project_1.id], node_id: node_id, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, /Unauthorized.*invalid JWT token/)
      end

      it 'search method is rejected by server with malformed JWT header' do
        targets = { node_id => [project_1.id] }
        expect do
          client.search(query, num: 10, targets: targets, search_mode: 'regex')
        end.to raise_error(Search::Zoekt::Errors::ClientConnectionError, /Unauthorized.*invalid JWT token/)
      end
    end
  end
end
