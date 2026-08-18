# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Embeddings::Client, :aggregate_failures, feature_category: :code_suggestions do
  let(:model_definition) do
    Gitlab::Llm::Embeddings::ModelDefinition.for_gitlab_provided_code_embeddings(
      identifier: 'text_embedding_005_vertex',
      use_cloud_aigw: false
    )
  end

  let(:aigw_url) { 'https://aigw.example.com' }
  let(:endpoint) { "#{aigw_url}/v1/embeddings/code_embeddings" }
  let(:index_endpoint) { "#{aigw_url}/v1/embeddings/code_embeddings/index" }
  let(:contents) { ['content one', 'content two'] }

  let(:response_status) { 200 }
  let(:response_body) do
    {
      'predictions' => [
        { 'embedding' => [0.1, 0.2, 0.3], 'index' => 0 },
        { 'embedding' => [0.4, 0.5, 0.6], 'index' => 1 }
      ],
      'model' => { 'engine' => 'litellm_embedding', 'name' => 'text-embedding-005' }
    }.to_json
  end

  subject(:client) { described_class.new }

  before do
    allow(model_definition).to receive(:litellm_drop_params?).and_call_original
    allow(client).to receive(:log_info)

    allow(Gitlab::AiGateway).to receive_messages(url: aigw_url, headers: { 'Authorization' => 'Bearer test-token' })
    allow(Gitlab::Metrics::Sli::ErrorRate[:llm_client_request]).to receive(:increment)
    allow(Gitlab::CircuitBreaker).to receive(:run_with_circuit).and_yield
    stub_request(:post, endpoint).to_return(status: response_status, body: response_body,
      headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, index_endpoint).to_return(status: response_status, body: response_body,
      headers: { 'Content-Type' => 'application/json' })
  end

  describe '#code_embeddings' do
    subject(:result) { client.code_embeddings(contents: contents, model_definition: model_definition) }

    it 'posts to the AIGW code_embeddings/index endpoint' do
      result

      expect(WebMock).not_to have_requested(:post, endpoint)
      expect(WebMock).to have_requested(:post, index_endpoint).with(
        body: {
          model_metadata: model_definition.model_params,
          litellm_drop_params: false,
          contents: contents
        }.to_json
      ).once
    end

    it 'returns a Gitlab::Llm::Embeddings::Response' do
      expect(result).to be_a(Gitlab::Llm::Embeddings::Response)
      expect(result.success?).to be(true)
      expect(result.embeddings).to eq([[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]])
    end

    it 'logs the request and response' do
      expect(client).to receive(:log_info).with(
        message: 'Performing embeddings request',
        event_name: 'performing_request',
        ai_component: 'code_embeddings_index',
        unit_primitive: model_definition.unit_primitive,
        url: index_endpoint,
        user_id: nil,
        root_namespace_id: nil,
        params: { model_metadata: model_definition.model_params }.to_json
      ).once.ordered
      expect(client).to receive(:log_info).with(
        message: 'Received embeddings response',
        event_name: 'response_received',
        ai_component: 'code_embeddings_index',
        unit_primitive: model_definition.unit_primitive,
        url: index_endpoint
      ).once.ordered

      result
    end

    context 'for search operations' do
      let(:search_endpoint) { "#{aigw_url}/v1/embeddings/code_embeddings/search" }

      subject(:result) { client.code_embeddings(contents: contents, model_definition: model_definition, search: true) }

      before do
        stub_request(:post, search_endpoint).to_return(status: response_status, body: response_body,
          headers: { 'Content-Type' => 'application/json' })
      end

      it 'posts to the AIGW code_embeddings/search endpoint' do
        result

        expect(WebMock).not_to have_requested(:post, endpoint)
        expect(WebMock).to have_requested(:post, search_endpoint).with(
          body: {
            model_metadata: model_definition.model_params,
            litellm_drop_params: false,
            contents: contents
          }.to_json
        ).once
      end

      it 'logs the correct information' do
        expect(client).to receive(:log_info).with(
          message: 'Performing embeddings request',
          event_name: 'performing_request',
          ai_component: 'code_embeddings_search',
          unit_primitive: model_definition.unit_primitive,
          url: search_endpoint,
          user_id: nil,
          root_namespace_id: nil,
          params: { model_metadata: model_definition.model_params }.to_json
        ).once.ordered
        expect(client).to receive(:log_info).with(
          message: 'Received embeddings response',
          event_name: 'response_received',
          ai_component: 'code_embeddings_search',
          unit_primitive: model_definition.unit_primitive,
          url: search_endpoint
        ).once.ordered

        result
      end
    end

    context 'with dimensions parameter' do
      subject(:result) do
        client.code_embeddings(
          model_definition: model_definition,
          contents: contents,
          dimensions: 32
        )
      end

      it 'includes the dimensions in the request parameter' do
        result

        expect(WebMock).to have_requested(:post, index_endpoint).with(
          body: {
            model_metadata: model_definition.model_params,
            litellm_drop_params: false,
            contents: contents,
            dimensions: 32
          }.to_json
        ).once
      end
    end

    context 'when model_definition sets litellm_drop_params=true' do
      before do
        allow(model_definition).to receive(:litellm_drop_params?).and_return(true)
      end

      it 'sets litellm_drop_params=true in the request args' do
        result

        expect(WebMock).to have_requested(:post, index_endpoint).with(
          body: {
            model_metadata: model_definition.model_params,
            litellm_drop_params: true,
            contents: contents
          }.to_json
        ).once
      end
    end

    context 'when there is a non-server error' do
      let(:response_status) { 400 }
      let(:response_body) do
        {
          'detail' => "This is a bad request error with more than fifty characters. " \
            "This is the second sentence of the bad request error."
        }.to_json
      end

      it 'logs response with error information' do
        expect(client).to receive(:log_info).with(
          message: 'Received embeddings response',
          event_name: 'response_received',
          ai_component: 'code_embeddings_index',
          unit_primitive: model_definition.unit_primitive,
          url: index_endpoint,
          error: "could not generate embeddings: This is a bad request error with more than fifty characters. This ..."
        ).once

        result
      end
    end

    # AIGW returns an empty response on 500 errors
    context 'when the response is empty' do
      before do
        allow(Gitlab::HTTP).to receive(:post).with(
          index_endpoint, any_args
        ).and_return(nil)
      end

      it 'logs response with error information' do
        expect(client).to receive(:log_info).with(
          message: 'Received embeddings response',
          event_name: 'response_received',
          ai_component: 'code_embeddings_index',
          unit_primitive: model_definition.unit_primitive,
          url: index_endpoint,
          error: "embeddings generation had no response"
        ).once

        result
      end
    end

    context 'when there is a server error' do
      let(:response_status) { 500 }
      let(:response_body) { nil }

      it 'raises a circuit breaker error' do
        expect { result }.to raise_error(Gitlab::CircuitBreaker::InternalServerError)
      end
    end

    describe 'headers' do
      let_it_be(:group) { create(:group) }
      let(:user) { build(:user, id: 246) }

      it 'sets the correct unit_primitive and feature_name headers' do
        expect(Gitlab::AiGateway).to receive(:headers).with(
          user: nil,
          unit_primitive_name: 'generate_embeddings_codebase',
          ai_feature_name: :embeddings_code,
          organization_id: nil,
          governing_namespace_id: nil
        )

        result
      end

      context 'when user is given' do
        let(:client) { described_class.new(user: user) }

        context 'when user governing namespace is nil' do
          before do
            allow(user).to receive(:governing_namespace).and_return(nil)
          end

          it 'sets the user info header' do
            expect(client).to receive(:log_info).with(
              hash_including(
                event_name: 'performing_request',
                user_id: 246,
                root_namespace_id: nil
              )
            )

            expect(Gitlab::AiGateway).to receive(:headers).with(
              user: user,
              unit_primitive_name: 'generate_embeddings_codebase',
              ai_feature_name: :embeddings_code,
              organization_id: nil,
              governing_namespace_id: nil
            ).and_return({ 'Authorization' => 'Bearer test-token' })

            result
          end
        end

        context 'when user governing namespace is present' do
          before do
            allow(user).to receive(:governing_namespace).and_return(group)
          end

          it 'sets the user and namespace headers' do
            expect(client).to receive(:log_info).with(
              hash_including(
                event_name: 'performing_request',
                user_id: 246,
                root_namespace_id: group.id
              )
            )

            expect(Gitlab::AiGateway).to receive(:headers).with(
              user: user,
              unit_primitive_name: 'generate_embeddings_codebase',
              ai_feature_name: :embeddings_code,
              organization_id: group.organization_id,
              governing_namespace_id: group.id
            ).and_return({ 'Authorization' => 'Bearer test-token' })

            result
          end
        end
      end

      context 'when root_namespace_id is given' do
        let(:client) { described_class.new(root_namespace_id: 123) }

        it 'sets namespace headers from the root_namespace_id' do
          expect(client).to receive(:log_info).with(
            hash_including(
              event_name: 'performing_request',
              user_id: nil,
              root_namespace_id: 123
            )
          )

          expect(Gitlab::AiGateway).to receive(:headers).with(
            user: nil,
            unit_primitive_name: 'generate_embeddings_codebase',
            ai_feature_name: :embeddings_code,
            organization_id: nil,
            governing_namespace_id: 123
          ).and_return({ 'Authorization' => 'Bearer test-token' })

          result
        end
      end

      context 'when user and root_namespace_id are given' do
        let(:client) { described_class.new(user: user, root_namespace_id: 123) }

        it 'sets namespace headers from the root_namespace_id' do
          allow(user).to receive(:governing_namespace).and_return(group)

          expect(client).to receive(:log_info).with(
            hash_including(
              event_name: 'performing_request',
              user_id: user.id,
              root_namespace_id: 123
            )
          )

          expect(Gitlab::AiGateway).to receive(:headers).with(
            user: user,
            unit_primitive_name: 'generate_embeddings_codebase',
            ai_feature_name: :embeddings_code,
            organization_id: nil,
            governing_namespace_id: 123
          ).and_return({ 'Authorization' => 'Bearer test-token' })

          result
        end
      end
    end
  end
end
