# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Telesign::TransactionCallback, feature_category: :instance_resiliency do
  using RSpec::Parameterized::TableSyntax

  describe '#new' do
    let(:request) { instance_double(ActionDispatch::Request) }
    let(:request_params) { {} }

    subject { described_class.new(request, request_params) }

    it 'initializes the request and payload' do
      payload = instance_double(Telesign::TransactionCallbackPayload)
      expect(Telesign::TransactionCallbackPayload).to receive(:new).with(request_params).and_return(payload)

      expect(subject.request).to eq request
      expect(subject.payload).to eq payload
    end
  end

  describe '#valid?' do
    let(:request_params) { {} }

    subject { described_class.new(request, request_params).valid? }

    context 'when signature is not present in the headers' do
      let(:request) { instance_double(ActionDispatch::Request, headers: {}) }

      it { is_expected.to be false }
    end

    context 'when signature is present in the headers' do
      let(:payload_string) { '{:ref_id=>"ref_id"}' }
      let(:request_params) { payload_string }
      let(:scheme) { described_class::AUTHORIZATION_SCHEME }
      let(:encoded_api_key) { Base64.encode64('secret_api_key') }
      let(:customer_id) { 'secret_customer_id' }
      # Base64.encode64(OpenSSL::HMAC.digest('SHA256', 'secret_api_key', '{:ref_id=>"ref_id"}'))
      let(:signature) { 'PJRdTwXX+/+nksJwXkEDLslxkX2rwUyyCHnlGslCsto=' }
      let(:authorization) { "#{scheme} #{customer_id}:#{signature}" }

      let(:request) do
        instance_double(
          ActionDispatch::Request,
          headers: { 'Authorization' => authorization },
          raw_post: request_params
        )
      end

      before do
        stub_ee_application_setting(
          telesign_customer_xid: customer_id,
          telesign_api_key: encoded_api_key
        )
      end

      it { is_expected.to be true }

      context 'when Authorization header does not have the correct format' do
        where(:authorization, :payload) do
          ''                                                        | ref(:payload_string)
          'wrong auth'                                              | ref(:payload_string)
          "XYZ #{ref(:customer_id)}:#{ref(:signature)}"             | ref(:payload_string)
          "#{ref(:scheme)} wrong_customer_id:#{ref(:signature)}"    | ref(:payload_string)
          "#{ref(:scheme)} #{ref(:customer_id)}:wrong_signature"    | ref(:payload_string)
          "#{ref(:scheme)} #{ref(:customer_id)}:#{ref(:signature)}" | 'wrong payload'
        end

        with_them do
          let(:request_params) { payload }

          it { is_expected.to be false }
        end
      end
    end
  end

  describe '#log' do
    let_it_be(:phone_number_validation) { create(:phone_number_validation, telesign_reference_xid: 'ref_id') }

    let(:callback_valid) { true }
    let(:request_params) { {} }
    let(:reference_id) { phone_number_validation.telesign_reference_xid }
    let(:status) { '200 - Sent' }
    let(:status_updated_on) { 'today' }
    let(:errors) { 'errors' }

    subject(:log) { described_class.new(instance_double(ActionDispatch::Request), request_params).log }

    before do
      allow_next_instance_of(described_class) do |callback|
        allow(callback).to receive(:valid?).and_return(callback_valid)
      end
    end

    it 'logs with the correct payload and tracks the event', :aggregate_failures do
      expect_next_instance_of(Telesign::TransactionCallbackPayload, request_params) do |response|
        expect(response).to receive(:reference_id).and_return(reference_id, reference_id)
        expect(response).to receive(:status).and_return(status, status)
        expect(response).to receive(:status_updated_on).and_return(status_updated_on)
        expect(response).to receive(:errors).and_return(errors)
        expect(response).to receive(:failed_delivery?).and_return(false)
      end

      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          class: 'Telesign::TransactionCallback',
          username: phone_number_validation.user.username,
          message: 'IdentityVerification::Phone',
          event: 'Telesign transaction status update',
          telesign_reference_id: reference_id,
          telesign_status: status,
          telesign_status_updated_on: status_updated_on,
          telesign_errors: errors
        )
      )

      log

      expect_snowplow_event(
        category: 'IdentityVerification::Phone',
        action: 'telesign_sms_delivery_success',
        user: phone_number_validation.user,
        extra: { country_code: phone_number_validation.country, status: status }
      )
    end

    context 'when status is not 200' do
      let(:status) { '207 - Error delivering SMS to handset (reason unknown)' }

      it 'tracks the event with the correct payload' do
        expect_next_instance_of(Telesign::TransactionCallbackPayload, request_params) do |response|
          expect(response).to receive(:reference_id).and_return(reference_id, reference_id)
          expect(response).to receive(:status).and_return(status, status)
          expect(response).to receive(:status_updated_on).and_return(status_updated_on)
          expect(response).to receive(:errors).and_return(errors)
          expect(response).to receive(:failed_delivery?).and_return(true)
        end

        log

        expect_snowplow_event(
          category: 'IdentityVerification::Phone',
          action: 'telesign_sms_delivery_failed',
          user: phone_number_validation.user,
          extra: { country_code: phone_number_validation.country, status: status }
        )
      end
    end

    context 'when there is no matching record for the received reference_id' do
      let(:reference_id) { 'non-existing-ref-id' }

      it 'does not track any event' do
        expect_next_instance_of(Telesign::TransactionCallbackPayload, request_params) do |response|
          expect(response).to receive(:reference_id).and_return(reference_id, reference_id)
          expect(response).to receive(:status).and_return(status)
          expect(response).to receive(:status_updated_on).and_return(status_updated_on)
          expect(response).to receive(:errors).and_return(errors)
        end

        log

        expect_no_snowplow_event
      end
    end

    context 'when callback is not valid' do
      let(:callback_valid) { false }

      it 'does not log' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        log

        expect_no_snowplow_event
      end
    end
  end

  describe '#user' do
    let(:callback_valid) { true }

    subject(:user) { described_class.new(instance_double(ActionDispatch::Request), {}).user }

    before do
      allow_next_instance_of(described_class) do |callback|
        allow(callback).to receive(:valid?).and_return(callback_valid)
      end
    end

    context 'when callback is not valid' do
      let(:callback_valid) { false }

      it { is_expected.to be_nil }
    end

    context 'when no matching phone number validation record is found' do
      it 'returns nil' do
        expect_next_instance_of(Telesign::TransactionCallbackPayload, {}) do |response|
          expect(response).to receive(:reference_id).and_return('fake-ref-id')
        end

        expect(user).to be_nil
      end
    end

    it 'returns user associated with the matching phone number validation record' do
      ref_id = 'abc123'
      record = create(:phone_number_validation, telesign_reference_xid: ref_id)

      expect_next_instance_of(Telesign::TransactionCallbackPayload, {}) do |response|
        expect(response).to receive(:reference_id).and_return(ref_id)
      end

      expect(user).to eq record.user
    end
  end
end
