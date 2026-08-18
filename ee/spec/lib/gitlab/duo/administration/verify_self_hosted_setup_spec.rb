# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Administration::VerifySelfHostedSetup, :gitlab_duo, :silence_stdout, feature_category: :"self-hosted_models" do
  include RakeHelpers

  let_it_be(:user) { create(:user, :admin, id: 1, username: 'root') }
  let_it_be(:user1) { create(:user, :admin, id: 2) }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }
  let(:ai_gateway_url) { 'http://ai-gateway.local' }
  let(:use_self_signed_token) { "1" }
  let(:license_provides_code_suggestions) { true }
  let(:can_user_access_code_suggestions) { true }
  let(:status_code) { 200 }
  let(:health_response_body) { '{"status": "healthy"}' }
  let(:http_response) do
    instance_double(HTTParty::Response, body: health_response_body, code: status_code, headers: {})
  end

  let(:websocket_check) { instance_double(Gitlab::Duo::Administration::AgentPlatformWebsocketCheck) }
  let(:websocket_result) do
    Gitlab::Duo::Administration::AgentPlatformWebsocketCheck::Result.new(
      status: :ok,
      http_status: 101,
      headers: { 'Upgrade' => 'websocket' },
      url: 'http://gitlab.example.com/api/v4/ai/duo_workflows/ws',
      response_time_ms: 12.3
    )
  end

  let(:transport_check) { instance_double(Gitlab::Duo::Administration::TransportConnectivityCheck) }

  let(:username) { user1.username }
  let(:task) { described_class.new(username) }

  subject(:verify_setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)
    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
    stub_application_setting(ai_gateway_url: ai_gateway_url)
    stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', use_self_signed_token)
    stub_licensed_features(code_suggestions: license_provides_code_suggestions)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :access_code_suggestions)
                                        .and_return(can_user_access_code_suggestions)
    allow(Ability).to receive(:allowed?).with(user1, :access_code_suggestions)
                                        .and_return(can_user_access_code_suggestions)

    # Mock AI Gateway health check
    allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
      headers: { "accept" => "application/json" }, allow_local_requests: true, timeout: 10)
                                        .and_return(http_response)

    allow(Gitlab::Duo::Administration::AgentPlatformWebsocketCheck).to receive(:new).and_return(websocket_check)
    allow(websocket_check).to receive(:execute).and_return(websocket_result)

    allow(Gitlab::Duo::Administration::TransportConnectivityCheck).to receive(:new).and_return(transport_check)
    allow(transport_check).to receive_messages(execute: [], proxy_environment: {})

    allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
  end

  describe '#execute' do
    context 'when everything is set properly' do
      it 'completes without error' do
        expect { verify_setup }.not_to raise_error
      end

      it 'fetches the correct user' do
        expect(User).to receive(:find_by_username!).with(username).and_call_original
        verify_setup
      end

      it 'collects system information' do
        verify_setup
        expect(task.diagnostics[:system]).to include(
          gitlab_version: Gitlab::VERSION,
          user: user1.username,
          user_id: user1.id
        )
      end

      context 'when not passing user' do
        let(:username) { nil }

        it 'uses root user' do
          expect(User).to receive(:find_by_username!).with('root').and_call_original
          verify_setup
        end
      end
    end

    context 'when ai_gateway_url is not set' do
      let(:ai_gateway_url) { nil }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Set the 'ai_gateway_url' application setting/)
        expect(task.diagnostics[:ai_gateway_url][:status]).to eq('ERROR')
      end
    end

    context 'when ai_gateway_url has invalid format' do
      let(:ai_gateway_url) { 'invalid-url' }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Invalid AI Gateway URL format/)
        expect(task.diagnostics[:ai_gateway_url][:status]).to eq('ERROR')
      end
    end

    context 'when user does not have :code_suggestions permission' do
      let(:can_user_access_code_suggestions) { false }

      context 'and license provides code suggestions' do
        it 'raises error with diagnostic info' do
          expect { verify_setup }.to raise_error(
            RuntimeError,
            /License is correct, but user does not have access to code suggestions/
          )
          expect(task.diagnostics[:license]).to include(
            feature_available: true,
            user_has_access: false,
            error: "License valid but user lacks access"
          )
        end
      end

      context 'and license does not provide code suggestions' do
        let(:license_provides_code_suggestions) { false }

        it 'raises error with diagnostic info' do
          expect { verify_setup }.to raise_error(
            RuntimeError,
            /License does not provide access to code suggestions, verify your license/
          )
          expect(task.diagnostics[:license]).to include(
            feature_available: false,
            user_has_access: false,
            error: "License does not provide code suggestions feature"
          )
        end
      end
    end

    context 'when connection to ai_gateway fails' do
      before do
        allow(Gitlab::HTTP).to receive(:get).with("#{ai_gateway_url}/monitoring/healthz",
          headers: { "accept" => "application/json" }, allow_local_requests: true, timeout: 10)
                                            .and_raise(Errno::ECONNREFUSED)
      end

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Cannot access AI Gateway/)
        expect(task.diagnostics[:ai_gateway_health]).to include(
          status: 'ERROR',
          error: 'Errno::ECONNREFUSED'
        )
      end
    end

    context 'when response from ai_gateway is not 200' do
      let(:status_code) { 500 }

      it 'raises error with diagnostic info' do
        expect { verify_setup }.to raise_error(RuntimeError, /Cannot access AI Gateway/)
        expect(task.diagnostics[:ai_gateway_health]).to include(
          status: 'ERROR',
          http_code: 500
        )
      end
    end

    context 'when response from ai_gateway contains malformed json' do
      let(:health_response_body) { 'malformed json' }

      it 'ignores the malformed json and does not crash', :aggregate_failures do
        expect { verify_setup }.not_to raise_error
        expect(task.diagnostics[:ai_gateway_health]).to include(
          status: 'OK',
          http_code: 200,
          response_body: 'malformed json'
        )
      end
    end
  end

  describe '#verify_model_endpoints!' do
    context 'when no models are configured' do
      it 'records warning in diagnostics' do
        task.send(:verify_model_endpoints!)
        expect(task.diagnostics[:self_hosted_models]).to include(
          status: 'WARNING',
          count: 0,
          error: 'No self-hosted models configured'
        )
      end
    end

    context 'when models are configured' do
      let_it_be(:model1) { create(:ai_self_hosted_model, name: 'Code Model', model: :codestral) }
      let_it_be(:model2) { create(:ai_self_hosted_model, name: 'Chat Model', model: :mistral) }

      it 'records model information in diagnostics' do
        task.send(:verify_model_endpoints!)
        expect(task.diagnostics[:self_hosted_models]).to include(
          status: 'OK',
          count: 2
        )

        model_data = task.diagnostics[:self_hosted_models][:models]
        expect(model_data).to include(
          hash_including(
            name: 'Code Model',
            model_type: 'codestral',
            release_state: 'GA',
            ga: true
          )
        )
      end
    end
  end

  describe '#verify_feature_settings!' do
    context 'when no feature settings are configured' do
      let_it_be(:model) { create(:ai_self_hosted_model) }

      it 'records warning in diagnostics' do
        task.send(:verify_feature_settings!)
        expect(task.diagnostics[:feature_settings]).to include(
          status: 'WARNING',
          total_features: 0,
          warning: 'No feature settings configured for any models'
        )
      end
    end

    context 'when feature settings are configured' do
      let!(:model1) { create(:ai_self_hosted_model, name: 'Code Model') }
      let!(:model2) { create(:ai_self_hosted_model, name: 'Chat Model') }
      let!(:feature_setting1) { create(:ai_feature_setting, feature: :code_generations, self_hosted_model: model1) }
      let!(:feature_setting2) do
        create(:ai_feature_setting, feature: :duo_chat_troubleshoot_job, self_hosted_model: model1)
      end

      let!(:feature_setting3) do
        create(:ai_feature_setting, feature: :generate_commit_message, self_hosted_model: model2)
      end

      it 'records feature settings in diagnostics' do
        task.send(:verify_feature_settings!)
        expect(task.diagnostics[:feature_settings][:status]).to eq('OK')
        expect(task.diagnostics[:feature_settings][:total_features]).to eq(3)
        expect(task.diagnostics[:feature_settings][:features]).to be_an(Array)
        expect(task.diagnostics[:feature_settings][:features].length).to eq(3)

        model_names = task.diagnostics[:feature_settings][:features].pluck(:model_name)
        expect(model_names).to include('Code Model', 'Chat Model')
      end

      it 'shows code model has 2 features assigned' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Code Model: 2 feature\(s\) assigned/
        ).to_stdout
      end

      it 'shows chat model has 1 feature assigned' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Chat Model: 1 feature\(s\) assigned/
        ).to_stdout
      end

      it 'shows correct feature count summary' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /3 feature settings configured/
        ).to_stdout
      end
    end

    context 'when models exist but no features are assigned' do
      let_it_be(:model1) { create(:ai_self_hosted_model, name: 'Unused Model') }
      let_it_be(:model2) { create(:ai_self_hosted_model, name: 'Another Unused Model') }

      it 'shows warning about unassigned models' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /No feature settings configured ⚠/
        ).to_stdout
      end

      it 'includes helpful message about model availability' do
        expect { task.send(:verify_feature_settings!) }.to output(
          /Models may not be available for any GitLab Duo features/
        ).to_stdout
      end
    end
  end

  describe '#test_request_flow!' do
    context 'when no models are configured' do
      it 'skips testing and records in diagnostics' do
        task.send(:test_request_flow!)
        expect(task.diagnostics[:request_flow]).to include(
          status: 'SKIPPED',
          reason: 'No models configured to test'
        )
      end
    end

    context 'when models are configured' do
      let_it_be(:model1) do
        create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://model1.local',
          identifier: 'custom_openai/model-1')
      end

      let_it_be(:model2) do
        create(:ai_self_hosted_model, name: 'Test Model 2', endpoint: 'http://model2.local',
          identifier: 'custom_openai/model-2')
      end

      let(:model_response) { instance_double(HTTParty::Response, body: '{"data": []}', code: 200, headers: {}) }

      before do
        allow(Gitlab::HTTP).to receive(:get).with(
          "http://model1.local/v1/models",
          hash_including(headers: hash_including('accept' => 'application/json'))
        ).and_return(model_response)

        allow(Gitlab::HTTP).to receive(:get).with(
          "http://model2.local/v1/models",
          hash_including(headers: hash_including('accept' => 'application/json'))
        ).and_return(model_response)
      end

      it 'tests model endpoints and records results' do
        task.send(:test_request_flow!)
        expect(task.diagnostics[:request_flow]).to include(
          status: 'OK',
          models_tested: 2
        )

        model_tests = task.diagnostics[:request_flow][:model_tests]
        expect(model_tests).to all(include(status: 'OK'))
      end

      context 'when model endpoint fails' do
        before do
          allow(Gitlab::HTTP).to receive(:get).with(
            "http://model1.local/v1/models",
            hash_including(headers: hash_including('accept' => 'application/json'))
          ).and_raise(Errno::ECONNREFUSED)
        end

        it 'records the failure in diagnostics' do
          task.send(:test_request_flow!)

          failed_test = task.diagnostics[:request_flow][:model_tests].find { |t| t[:model_name] == 'Test Model' }
          expect(failed_test).to include(
            status: 'ERROR',
            error: 'Errno::ECONNREFUSED'
          )
        end
      end
    end

    context 'when no configured model has a custom_openai identifier' do
      let_it_be(:bedrock_model) do
        create(:ai_self_hosted_model, name: 'Bedrock Model', endpoint: 'http://bedrock.local',
          identifier: 'bedrock/some-model')
      end

      let_it_be(:vertex_model) do
        create(:ai_self_hosted_model, name: 'Vertex Model', endpoint: 'http://vertex.local',
          identifier: 'vertex_ai/some-model')
      end

      it 'does not make any HTTP requests' do
        expect(Gitlab::HTTP).not_to receive(:get)

        task.send(:test_request_flow!)
      end

      it 'records SKIPPED status with zero models tested' do
        task.send(:test_request_flow!)

        expect(task.diagnostics[:request_flow]).to include(
          status: 'SKIPPED',
          models_tested: 0,
          model_tests: []
        )
      end

      it 'logs a skip message for each non-custom_openai model' do
        expect { task.send(:test_request_flow!) }.to output(
          /Skipping model: Bedrock Model.*Skipping model: Vertex Model/m
        ).to_stdout
      end
    end

    context 'when models have mixed identifiers' do
      let_it_be(:openai_model) do
        create(:ai_self_hosted_model, name: 'OpenAI Model', endpoint: 'http://openai.local',
          identifier: 'custom_openai/model-a')
      end

      let_it_be(:bedrock_model) do
        create(:ai_self_hosted_model, name: 'Bedrock Model', endpoint: 'http://bedrock.local',
          identifier: 'bedrock/some-model')
      end

      let(:model_response) { instance_double(HTTParty::Response, body: '{"data": []}', code: 200, headers: {}) }

      it 'only tests the custom_openai model' do
        expect(Gitlab::HTTP).to receive(:get).with(
          "http://openai.local/v1/models",
          hash_including(headers: hash_including('accept' => 'application/json'))
        ).and_return(model_response)
        expect(Gitlab::HTTP).not_to receive(:get).with("http://bedrock.local/v1/models", anything)

        task.send(:test_request_flow!)

        expect(task.diagnostics[:request_flow]).to include(
          status: 'OK',
          models_tested: 1
        )
        expect(task.diagnostics[:request_flow][:model_tests].map { |t| t[:model_name] }).to eq(['OpenAI Model'])
      end
    end
  end

  describe '#test_model_endpoint' do
    let(:model) { create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://test.local', api_token: 'secret') }
    let(:model_response) { instance_double(HTTParty::Response, body: '{"data": []}', code: 200, headers: {}) }

    it 'includes authorization header when api_token is present' do
      expect(Gitlab::HTTP).to receive(:get).with(
        "http://test.local/v1/models",
        hash_including(
          headers: hash_including('authorization' => 'Bearer secret')
        )
      ).and_return(model_response)

      result = task.send(:test_model_endpoint, model)
      expect(result[:has_auth]).to be true
      expect(result[:status]).to eq('OK')
    end

    context 'when model has no api_token' do
      let(:model) { create(:ai_self_hosted_model, name: 'Test Model', endpoint: 'http://test.local', api_token: nil) }

      it 'does not include authorization header' do
        expect(Gitlab::HTTP).to receive(:get).with(
          "http://test.local/v1/models",
          hash_including(
            headers: hash_not_including('authorization')
          )
        ).and_return(model_response)

        result = task.send(:test_model_endpoint, model)
        expect(result[:has_auth]).to be false
      end
    end
  end

  describe '#sanitize_headers' do
    it 'removes sensitive headers' do
      headers = {
        'content-type' => 'application/json',
        'authorization' => 'Bearer secret-token',
        'x-api-key' => 'api-key',
        'cookie' => 'session=abc123'
      }

      result = task.send(:sanitize_headers, headers)

      expect(result).to include('content-type' => 'application/json')
      expect(result).not_to include('authorization', 'x-api-key', 'cookie')
    end

    it 'truncates long header values' do
      long_value = 'x' * 200
      headers = { 'custom-header' => long_value }

      result = task.send(:sanitize_headers, headers)
      expect(result['custom-header'].length).to eq(100)
    end

    it 'handles nil input' do
      expect(task.send(:sanitize_headers, nil)).to eq({})
    end
  end

  describe '#output_diagnostics' do
    it 'outputs JSON formatted diagnostics' do
      task.instance_variable_set(:@diagnostics, { test: 'data' })

      expect(Gitlab::Json).to receive(:pretty_generate).with({ test: 'data' })
      expect { task.send(:output_diagnostics) }.to output(/NOTE: Review the above output/).to_stdout
    end
  end

  describe 'diagnostics structure' do
    it 'includes all expected diagnostic sections when successful' do
      verify_setup

      expect(task.diagnostics).to include(
        :system,
        :ai_gateway_url,
        :transport_connectivity,
        :license,
        :ai_gateway_health,
        :self_hosted_models,
        :feature_settings,
        :request_flow,
        :agent_platform_websocket,
        :duo_workflow_service
      )
    end

    it 'includes system information with required fields' do
      verify_setup

      system_info = task.diagnostics[:system]
      expect(system_info).to include(
        :gitlab_version,
        :gitlab_revision,
        :rails_env,
        :timestamp,
        :user,
        :user_id,
        :instance_url
      )
    end
  end

  describe '#verify_transport_connectivity!' do
    subject(:verify_transport) { task.send(:verify_transport_connectivity!) }

    let(:trusted_result) do
      Gitlab::Duo::Administration::TransportConnectivityCheck::Result.new(
        name: 'AI Gateway', host: 'ai-gw.example.com', port: 443, tls: true, status: :ok,
        tls_verified: true, cert_subject: 'CN=ai-gw', cert_issuer: 'CN=Internal CA',
        proxy: 'http://proxy.example.com:8080', response_time_ms: 12.3
      )
    end

    context 'when no endpoints are configured' do
      before do
        allow(transport_check).to receive_messages(execute: [], proxy_environment: {})
      end

      it 'records a skipped result' do
        verify_transport

        expect(task.diagnostics[:transport_connectivity]).to include(status: 'SKIPPED')
      end
    end

    context 'when an endpoint is reachable with a trusted certificate' do
      before do
        allow(transport_check).to receive_messages(
          execute: [trusted_result], proxy_environment: { 'HTTPS_PROXY' => 'http://proxy.example.com:8080' }
        )
      end

      it 'records the certificate and proxy details', :aggregate_failures do
        verify_transport

        endpoint = task.diagnostics[:transport_connectivity][:endpoints].first
        expect(endpoint).to include(status: 'OK', tls_verified: true, cert_subject: 'CN=ai-gw', proxy: anything)
        expect(task.diagnostics[:transport_connectivity][:proxy_environment]).to include('HTTPS_PROXY')
      end
    end

    context 'when the certificate is untrusted' do
      let(:untrusted_result) do
        Gitlab::Duo::Administration::TransportConnectivityCheck::Result.new(
          name: 'AI Gateway', host: 'ai-gw.example.com', port: 443, tls: true, status: :ok,
          tls_verified: false, cert_subject: 'CN=proxy', cert_issuer: 'CN=Zscaler', response_time_ms: 8.0
        )
      end

      before do
        allow(transport_check).to receive_messages(execute: [untrusted_result], proxy_environment: {})
      end

      it 'flags the endpoint as a warning and prints proxy CA guidance', :aggregate_failures do
        expect { verify_transport }.to output(/TLS-inspecting proxy/).to_stdout

        expect(task.diagnostics[:transport_connectivity][:endpoints].first).to include(status: 'WARNING')
      end
    end

    context 'when the endpoint is unreachable with a TLS mismatch' do
      let(:error_result) do
        Gitlab::Duo::Administration::TransportConnectivityCheck::Result.new(
          name: 'AI Gateway', host: 'ai-gw.example.com', port: 443, tls: true, status: :error,
          error: OpenSSL::SSL::SSLError.new('WRONG_VERSION_NUMBER'), response_time_ms: 3.0
        )
      end

      before do
        allow(transport_check).to receive_messages(execute: [error_result], proxy_environment: {})
      end

      it 'records the error and prints TLS handshake guidance', :aggregate_failures do
        expect { verify_transport }.to output(/TLS handshake failed/).to_stdout

        expect(task.diagnostics[:transport_connectivity][:endpoints].first).to include(
          status: 'ERROR', error: 'OpenSSL::SSL::SSLError'
        )
      end
    end
  end

  describe '#verify_agent_platform_websocket!' do
    subject(:verify_websocket) { task.send(:verify_agent_platform_websocket!) }

    context 'when the upgrade succeeds' do
      it 'records a successful result in diagnostics' do
        verify_websocket

        expect(task.diagnostics[:agent_platform_websocket]).to include(
          status: 'OK',
          http_status: 101,
          response_headers: { 'Upgrade' => 'websocket' }
        )
      end
    end

    context 'when the upgrade does not complete' do
      let(:websocket_result) do
        Gitlab::Duo::Administration::AgentPlatformWebsocketCheck::Result.new(
          status: :not_upgraded, http_status: 400, headers: {}, url: 'http://gitlab.example.com', response_time_ms: 5.0
        )
      end

      it 'records an error result with the HTTP status' do
        verify_websocket

        expect(task.diagnostics[:agent_platform_websocket]).to include(status: 'ERROR', http_status: 400)
      end
    end

    context 'when the endpoint is unreachable' do
      let(:websocket_result) do
        Gitlab::Duo::Administration::AgentPlatformWebsocketCheck::Result.new(
          status: :error, error: Errno::ECONNREFUSED.new('Connection refused'),
          url: 'http://gitlab.example.com', response_time_ms: 1.0
        )
      end

      it 'records the error class and message' do
        verify_websocket

        expect(task.diagnostics[:agent_platform_websocket]).to include(
          status: 'ERROR',
          error: 'Errno::ECONNREFUSED',
          error_message: 'Connection refused - Connection refused'
        )
      end
    end
  end

  describe '#verify_duo_workflow_service!' do
    subject(:verify_dws) { task.send(:verify_duo_workflow_service!) }

    context 'when the self-hosted service URL is not configured' do
      before do
        allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(nil)
      end

      it 'records a warning and does not run the probe' do
        expect(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe).not_to receive(:new)

        verify_dws

        expect(task.diagnostics[:duo_workflow_service]).to include(status: 'WARNING', url: nil)
      end
    end

    context 'when the service URL is configured' do
      let(:service_url) { 'grpc.duo-workflow.local:443' }
      let(:probe) do
        instance_double(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe, execute: probe_result)
      end

      before do
        allow(::Gitlab::DuoWorkflow::Client).to receive(:self_hosted_url).and_return(service_url)
        allow(CloudConnector::StatusChecks::Probes::DuoAgentPlatformProbe).to receive(:new)
          .with(user1, deployment: :self_hosted).and_return(probe)
      end

      context 'when the service is reachable' do
        let(:probe_result) do
          CloudConnector::StatusChecks::Probes::ProbeResult.new(
            :duo_agent_platform_probe, true, 'The self-hosted service is operational.'
          )
        end

        it 'records a successful result in diagnostics' do
          verify_dws

          expect(task.diagnostics[:duo_workflow_service]).to include(
            status: 'OK',
            url: service_url,
            message: 'The self-hosted service is operational.'
          )
        end
      end

      context 'when the service is not reachable' do
        let(:probe_errors) do
          instance_double(ActiveModel::Errors, full_messages: ['14:failed to connect to all addresses'])
        end

        let(:probe_result) do
          CloudConnector::StatusChecks::Probes::ProbeResult.new(
            :duo_agent_platform_probe, false, 'The self-hosted service is not reachable.', [], probe_errors
          )
        end

        it 'records an error result and surfaces the underlying errors' do
          verify_dws

          expect(task.diagnostics[:duo_workflow_service]).to include(
            status: 'ERROR',
            url: service_url,
            message: 'The self-hosted service is not reachable.',
            errors: ['14:failed to connect to all addresses']
          )
        end
      end
    end
  end
end
