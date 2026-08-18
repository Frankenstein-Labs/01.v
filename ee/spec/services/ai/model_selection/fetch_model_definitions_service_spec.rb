# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ModelSelection::FetchModelDefinitionsService, feature_category: :"self-hosted_models" do
  let(:endpoint_url) { "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions" }
  let(:feature_flag_enabled) { true }
  let(:cache_key) { "#{described_class::RESPONSE_CACHE_NAME}:#{feature_flag_enabled}" }
  let(:model_definitions) do
    {
      'models' => [
        { 'name' => 'Claude Sonnet', 'identifier' => 'claude_sonnet' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet],
          'beta_models' => []
        }
      ]
    }
  end

  let(:model_definitions_response) { model_definitions.to_json }

  let(:user) { nil }
  let(:initialized_class) { described_class.new(user) }

  subject(:service) { initialized_class.execute }

  before do
    allow(Gitlab::AiGateway).to receive(:public_headers).and_return({})
    allow(Gitlab::AiGateway).to receive(:push_feature_flag)
  end

  describe '#execute' do
    context 'when license is offline' do
      before do
        license = create(:license)
        allow(::License).to receive(:current).and_return(license)
        allow(license).to receive(:offline_cloud_license?).and_return(true)
      end

      it 'returns success ServiceResponse with nil payload' do
        expect(service).to be_success
        expect(service.payload).to be_nil
      end
    end

    context 'when response is cached' do
      let(:cached_data) { model_definitions }

      before do
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
        allow(Rails.cache).to receive(:fetch).with(cache_key).and_return(cached_data)
      end

      it 'returns cached response' do
        expect(service).to be_success
        expect(service.payload).to eq(cached_data)
      end

      it 'does not make an HTTP request' do
        expect(Gitlab::HTTP).not_to receive(:get)
        service
      end

      context 'when feature flag is disabled' do
        let(:feature_flag_enabled) { false }

        before do
          stub_feature_flags(ai_gateway_multi_default_models: false)
        end

        it 'uses a different cache key and returns cached response' do
          expect(service).to be_success
          expect(service.payload).to eq(cached_data)
        end

        it 'does not make an HTTP request' do
          expect(Gitlab::HTTP).not_to receive(:get)
          service
        end
      end
    end

    context 'when feature flag state changes between requests' do
      let(:cached_data) { model_definitions }

      before do
        # Cache exists only for the flag-enabled key
        allow(Rails.cache).to receive(:exist?).with("#{described_class::RESPONSE_CACHE_NAME}:true").and_return(true)
        allow(Rails.cache).to receive(:exist?).with("#{described_class::RESPONSE_CACHE_NAME}:false").and_return(false)
        flag_on_key = "#{described_class::RESPONSE_CACHE_NAME}:true"
        allow(Rails.cache).to receive(:fetch).with(flag_on_key).and_return(cached_data)
      end

      it 'serves cached response when flag is enabled' do
        expect(Gitlab::HTTP).not_to receive(:get)
        expect(service).to be_success
        expect(service.payload).to eq(cached_data)
      end

      it 'makes a new request when flag is disabled (cache miss on different key)' do
        stub_feature_flags(ai_gateway_multi_default_models: false)

        stub_request(:get, endpoint_url)
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(Rails.cache).to receive(:fetch).with(
          "#{described_class::RESPONSE_CACHE_NAME}:false",
          expires_in: described_class::RESPONSE_CACHE_EXPIRATION
        )

        expect(Gitlab::HTTP).to receive(:get).and_call_original
        expect(service).to be_success
      end
    end

    context 'when response is not cached' do
      before do
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
      end

      context 'when API call is successful' do
        before do
          stub_request(:get, endpoint_url)
            .to_return(
              status: 200,
              body: model_definitions_response,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'caches and returns the response' do
          expect(Rails.cache).to receive(:fetch).with(
            cache_key,
            expires_in: described_class::RESPONSE_CACHE_EXPIRATION
          )

          expect(service).to be_success
          expect(service.payload).to include(model_definitions)
        end

        it 'pushes the ai_gateway_multi_default_models feature flag' do
          expect(Gitlab::AiGateway).to receive(:push_feature_flag).with(:ai_gateway_multi_default_models, user)

          service
        end

        it 'sends public headers in the request' do
          expect(Gitlab::AiGateway).to receive(:public_headers).with(
            user: user,
            unit_primitive_name: :code_suggestions,
            ai_feature_name: :code_suggestions
          ).and_return({})

          service
        end

        context 'when a user is provided' do
          let(:user) { build_stubbed(:user) }

          it 'pushes the feature flag with the user' do
            expect(Gitlab::AiGateway).to receive(:push_feature_flag)
              .with(:ai_gateway_multi_default_models, user)

            service
          end

          it 'sends public headers with the user' do
            expect(Gitlab::AiGateway).to receive(:public_headers).with(
              user: user,
              unit_primitive_name: :code_suggestions,
              ai_feature_name: :code_suggestions
            ).and_return({})

            service
          end
        end
      end

      context 'when API call returns error' do
        let(:error_message) { "Received error 401 from AI gateway when fetching model definitions" }

        before do
          stub_request(:get, endpoint_url)
            .to_return(
              status: 401,
              body: "{\"error\":\"No authorization header presented\"}",
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'logs the error and returns error ServiceResponse' do
          expect(initialized_class).to receive(:log_error)

          expect(service).to be_error
          expect(service.message).to eq(error_message)
        end
      end

      context 'when API call raises network error (SocketError)' do
        before do
          allow(Gitlab::HTTP).to receive(:get).and_raise(SocketError.new('Connection failed'))
        end

        it 'handles error gracefully and returns error ServiceResponse' do
          expect(service).to be_error
          expect(service.message).to eq('Failed to fetch model definitions')
        end
      end

      context 'when API call raises timeout error (Net::OpenTimeout)' do
        before do
          allow(Gitlab::HTTP).to receive(:get).and_raise(Net::OpenTimeout.new('Request timeout'))
        end

        it 'handles timeout gracefully and returns error ServiceResponse' do
          expect(service).to be_error
          expect(service.message).to eq('Failed to fetch model definitions')
        end
      end

      context 'when API call raises unexpected StandardError' do
        before do
          allow(Gitlab::HTTP).to receive(:get).and_raise(StandardError.new('Unexpected error'))
        end

        it 'handles unexpected error gracefully and returns error ServiceResponse' do
          expect(service).to be_error
          expect(service.message).to eq('Failed to fetch model definitions')
        end
      end
    end
  end

  describe 'local development behavior with respect to cache' do
    context 'when FETCH_MODEL_SELECTION_DATA_FROM_LOCAL environment variable is set' do
      let(:local_endpoint_url) { 'http://local-gateway.com/v1/models%2Fdefinitions' }

      before do
        allow(::Gitlab::AiGateway).to receive(:url).and_return('http://local-gateway.com')
      end

      %w[1 true True TRUE].each do |truthy_value|
        context "with value set to '#{truthy_value}'" do
          before do
            stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', truthy_value)
            stub_request(:get, local_endpoint_url)
              .to_return(
                status: 200,
                body: model_definitions_response,
                headers: { 'Content-Type' => 'application/json' }
              )
          end

          it 'uses local endpoint and skips cache even when cache exists' do
            allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
            expect(Rails.cache).to receive(:fetch).with(
              cache_key,
              expires_in: described_class::RESPONSE_CACHE_EXPIRATION
            ).and_return(model_definitions)

            expect(Gitlab::HTTP).to receive(:get).with(
              local_endpoint_url,
              hash_including(allow_local_requests: true)
            ).and_call_original

            expect(service).to be_success
          end
        end
      end

      ['0', 'false', 'False', 'FALSE', '', nil].each do |falsy_value|
        context "with value set to '#{falsy_value}'" do
          before do
            stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', falsy_value)
          end

          it 'uses and respects cache' do
            allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(true)
            allow(Rails.cache).to receive(:fetch).with(cache_key).and_return(model_definitions)

            # Should not make HTTP request when cache exists
            expect(Gitlab::HTTP).not_to receive(:get)

            expect(service).to be_success
            expect(service.payload).to eq(model_definitions)
          end
        end
      end
    end
  end

  describe 'endpoint behavior' do
    context 'when not in local development' do
      before do
        stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', nil)
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
      end

      it 'uses the cloud-connected endpoint URL' do
        stub_request(:get, "https://cloud.gitlab.com/ai/v1/models%2Fdefinitions")
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        expect(service).to be_success
      end
    end

    context 'when in local development' do
      before do
        stub_env('FETCH_MODEL_SELECTION_DATA_FROM_LOCAL', '1')
        allow(::Gitlab::AiGateway).to receive(:url).and_return('http://local-gateway.com')
        allow(Rails.cache).to receive(:exist?).with(cache_key).and_return(false)
      end

      it 'uses the local endpoint URL' do
        stub_request(:get, 'http://local-gateway.com/v1/models%2Fdefinitions')
          .to_return(
            status: 200,
            body: model_definitions_response,
            headers: { 'Content-Type' => 'application/json' }
          )

        expect(service).to be_success
      end
    end
  end
end
