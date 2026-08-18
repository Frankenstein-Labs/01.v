# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arkose::DataExchangePayload, feature_category: :instance_resiliency do
  let(:headers) do
    {
      "HTTP_ACCEPT_LANGUAGE" => "http accept lang",
      "HTTP_SEC_FETCH_SITE" => "sec fetch site"
    }
  end

  let(:request) do
    instance_double(
      ActionDispatch::Request,
      headers: headers,
      origin: 'origin',
      referer: 'referer',
      user_agent: 'ua',
      ip: 'ip'
    )
  end

  let(:one_sec_since_unix_epoch) { Time.zone.at(1) }
  let(:one_sec_since_unix_epoch_in_ms) { 1000 }

  let(:json_data) do
    {
      timestamp: one_sec_since_unix_epoch_in_ms.to_s,
      "HEADER_user-agent" => request.user_agent,
      "HEADER_origin" => request.origin,
      "HEADER_referer" => request.referer,
      "HEADER_accept-language" => request.headers['HTTP_ACCEPT_LANGUAGE'],
      "HEADER_sec-fetch-site" => request.headers['HTTP_SEC_FETCH_SITE'],
      ip_address: request.ip,
      use_case: described_class::USE_CASE_SIGN_UP,
      api_source_validation: {
        timestamp: one_sec_since_unix_epoch_in_ms,
        token: SecureRandom.uuid
      }.stringify_keys
    }.stringify_keys
  end

  subject(:result) { described_class.new(request, use_case: described_class::USE_CASE_SIGN_UP).build }

  before do
    allow(SecureRandom).to receive(:uuid).and_return('uuid')
  end

  describe '#build' do
    let(:key) { "2nk39IVINZiK5OHO5TfRTrJ8kWhZVtjRAMeXLerxDlU=\n" }

    before do
      stub_application_setting(arkose_labs_data_exchange_key: key)
    end

    def decrypt(encrypted_payload, key)
      encoded_initialization_vector, encoded_encrypted_text_and_tag = encrypted_payload.split('.')

      initialization_vector = Base64.decode64(encoded_initialization_vector)
      encrypted_text_and_tag = Base64.decode64(encoded_encrypted_text_and_tag)

      tag = encrypted_text_and_tag[-16..] # last 16 bytes
      encrypted_text = encrypted_text_and_tag[0..-17]

      decipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
      decipher.key = Base64.decode64(key)
      decipher.iv = initialization_vector
      decipher.auth_tag = tag
      decipher.auth_data = ""
      decipher.update(encrypted_text) + decipher.final # rubocop:disable Rails/SaveBang -- Not an ActiveRecord::Base#update call
    end

    it 'can be decrypted with the right key' do
      travel_to one_sec_since_unix_epoch do
        decrypted_payload = decrypt(result, key)
        json_payload = Gitlab::Json.parse(decrypted_payload)

        expect(json_payload).to include(json_data)
      end
    end

    context 'with an invalid use_case' do
      subject(:result) { described_class.new(request, use_case: 'invalid').build }

      it { is_expected.to be_nil }
    end

    context 'when arkose_labs_data_exchange_enabled application setting is disabled' do
      before do
        stub_application_setting(arkose_labs_data_exchange_enabled: false)
      end

      it { is_expected.to be_nil }
    end

    context 'when arkose_labs_data_exchange_key application setting is not set' do
      before do
        stub_application_setting(arkose_labs_data_exchange_key: nil)
      end

      it { is_expected.to be_nil }
    end

    context 'when email is present' do
      let(:email) { "test@example.com" }

      subject(:result) do
        described_class.new(
          request,
          use_case: described_class::USE_CASE_IDENTITY_VERIFICATION,
          email: email
        ).build
      end

      it "includes the email address" do
        decrypted_payload = decrypt(result, key)
        json_payload = Gitlab::Json.parse(decrypted_payload)

        expect(json_payload['email_address']).to eq email
      end
    end

    context 'when require_challenge is true' do
      subject(:result) do
        described_class.new(
          request,
          use_case: described_class::USE_CASE_SIGN_UP,
          require_challenge: true
        ).build
      end

      it "includes { 'interactive' => 'true' }" do
        decrypted_payload = decrypt(result, key)
        json_payload = Gitlab::Json.parse(decrypted_payload)

        expect(json_payload['interactive']).to eq 'true'
      end
    end
  end
end
