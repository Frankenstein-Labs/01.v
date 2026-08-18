# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe Gitlab::Checks::SecretPushProtection::SecretDetectionServiceClient, feature_category: :secret_detection do
  include_context 'secrets check context'

  let(:audit_logger) { instance_double(Gitlab::Checks::SecretPushProtection::AuditLogger) }
  let(:client) { described_class.new(project: project) }
  let(:log_messages) { described_class::LOG_MESSAGES }

  let(:payload) do
    ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
      id: blob_2_reference,
      data: "BASE_URL=https://foo.bar",
      offset: 1
    )
  end

  describe '#use_secret_detection_service?' do
    before do
      stub_feature_flags(use_secret_detection_service: sds_ff_enabled)
      stub_saas_features(secret_detection_service: saas_feature_enabled)
      stub_application_setting(gitlab_dedicated_instance: dedicated_instance)
      allow(::Gitlab::CurrentSettings.current_application_settings)
        .to receive(:secret_detection_service_url).and_return('https://foo.bar')
    end

    subject(:use_service) { client.use_secret_detection_service? }

    context 'when feature flag enabled, SaaS available, and not dedicated' do
      let(:sds_ff_enabled) { true }
      let(:saas_feature_enabled) { true }
      let(:dedicated_instance) { false }

      it { is_expected.to be(true) }
    end

    where(:desc, :sds_ff_enabled, :saas_feature_enabled, :dedicated_instance) do
      [
        ['feature flag disabled', false, true, false],
        ['instance is not SaaS', true, false, false],
        ['instance is dedicated', true, true, true]
      ]
    end

    with_them do
      it 'logs disabled message and returns false' do
        msg = format(
          log_messages[:sds_disabled],
          sds_ff_enabled: sds_ff_enabled,
          saas_feature_enabled: saas_feature_enabled,
          is_not_dedicated: !dedicated_instance
        )

        expect(client.use_secret_detection_service?).to be false
        expect(logged_messages[:info]).to include(
          hash_including("message" => msg, "class" => described_class.name)
        )
      end
    end
  end

  describe '#setup_sds_client' do
    let(:sds_host) { 'https://foo.bar' }
    let(:auth_token) { 'token123' }

    before do
      allow(::Gitlab::CurrentSettings.current_application_settings)
        .to receive_messages(secret_detection_service_url: sds_host, secret_detection_service_auth_token: auth_token)

      allow(client).to receive(:use_secret_detection_service?).and_return(use_sds)
    end

    subject(:setup_client) { client.setup_sds_client }

    context 'when SDS should not be used' do
      let(:use_sds) { false }

      it 'does not create GRPC client' do
        expect(::Gitlab::SecretDetection::GRPC::Client).not_to receive(:new)
        setup_client
        expect(client.sds_client).to be_nil
      end
    end

    context 'when SDS host is blank' do
      let(:use_sds) { false }
      let(:sds_host) { '' }

      it 'does not create GRPC client' do
        expect(::Gitlab::SecretDetection::GRPC::Client).not_to receive(:new)
        setup_client
        expect(client.sds_client).to be_nil
      end
    end

    context 'when client creation raises an error' do
      let(:use_sds) { true }

      it 'catches the error and tracks it' do
        expect(::Gitlab::SecretDetection::GRPC::Client)
          .to receive(:new)
          .and_raise(StandardError.new("Expected error"))

        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
        setup_client
        expect(client.sds_client).to be_nil
      end
    end

    context 'when parameters are valid' do
      let(:use_sds) { true }
      let(:grpc_client) { instance_double(::Gitlab::SecretDetection::GRPC::Client) }

      it 'creates GRPC client with correct parameters' do
        expect(::Gitlab::SecretDetection::GRPC::Client)
          .to receive(:new)
          .with(sds_host, secure: true, logger: secret_detection_logger)
          .and_return(grpc_client)

        setup_client
        expect(client.sds_client).to eq(grpc_client)
        expect(client.sds_auth_token).to eq(auth_token)
      end
    end
  end

  describe '#send_request_to_sds' do
    let(:grpc_client) { instance_double(::Gitlab::SecretDetection::GRPC::Client) }
    let!(:exclusion) do
      create(:project_security_exclusion, :active, :with_path, project: project, value: 'file-exclusion-1.rb')
    end

    before do
      allow(client).to receive(:setup_sds_client)
      allow(client).to receive_messages(sds_client: grpc_client, sds_auth_token: 'token123')
    end

    it 'invokes run_scan with request and token' do
      expect(grpc_client).to receive(:run_scan).with(
        hash_including(
          request: kind_of(::Gitlab::SecretDetection::GRPC::ScanRequest),
          auth_token: 'token123'
        )
      )
      client.send_request_to_sds([payload], exclusions: { path: [exclusion] })
    end

    it 'sets timeout_secs to REQUEST_TIMEOUT_SECONDS in the request' do
      expect(grpc_client).to receive(:run_scan) do |args|
        expect(args[:request].timeout_secs).to eq(::Gitlab::SecretDetection::GRPC::Client::REQUEST_TIMEOUT_SECONDS)
      end
      client.send_request_to_sds([payload])
    end

    it 'logs the request and response' do
      allow(grpc_client).to receive(:run_scan)

      client.send_request_to_sds([payload], exclusions: { path: [exclusion] },
        extra_headers: { 'x-correlation-id': "ABC123", 'x-request-type': 'dark-launch' })

      expect(logged_messages[:info]).to include("Sending request to SDS with type: dark-launch")
    end

    it 'rescues and tracks on error' do
      allow(grpc_client).to receive(:run_scan).and_raise(StandardError)
      expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(kind_of(StandardError))
      expect { client.send_request_to_sds([payload]) }.not_to raise_error
    end

    it 'returns nil on error' do
      allow(grpc_client).to receive(:run_scan).and_raise(StandardError)
      expect(client.send_request_to_sds([payload])).to be_nil
    end
  end

  describe '#build_exclusions' do
    let(:e1) { build_stubbed(:project_security_exclusion, :active, :with_path, project: project, value: 'foo.rb') }
    let(:e2) do
      build_stubbed(:project_security_exclusion, :active, :with_raw_value, project: project, value: 'secret123')
    end

    it 'builds GRPC Exclusion messages from a hash of exclusion lists' do
      input = { 'path' => [e1], 'raw_value' => [e2] }
      grpc_exclusions = client.send(:build_exclusions, exclusions: input)

      expect(grpc_exclusions).to contain_exactly(
        have_attributes(
          exclusion_type: :EXCLUSION_TYPE_PATH,
          value: 'foo.rb'
        ),
        have_attributes(
          exclusion_type: :EXCLUSION_TYPE_RAW_VALUE,
          value: 'secret123'
        )
      )
    end
  end
end
