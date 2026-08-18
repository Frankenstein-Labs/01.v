# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArkoseHelper, feature_category: :instance_resiliency do
  describe '.arkose_data_exchange_payload' do
    let(:request_double) { instance_double(ActionDispatch::Request) }
    let(:email) { "test@example.com" }

    subject(:call_method) { helper.arkose_data_exchange_payload(use_case, email: email) }

    before do
      allow(helper).to receive_messages(request: request_double)
    end

    shared_examples 'builds the payload with the correct options' do
      specify do
        options = { use_case: use_case, require_challenge: require_challenge, email: email }
        expect_next_instance_of(Arkose::DataExchangePayload, request_double, options) do |instance|
          expect(instance).to receive(:build).and_return('payload')
        end

        expect(call_method).to eq 'payload'
      end
    end

    it_behaves_like 'builds the payload with the correct options' do
      let(:use_case) { Arkose::DataExchangePayload::USE_CASE_IDENTITY_VERIFICATION }
      let(:require_challenge) { true }
    end

    context "when use_case is 'SIGN_UP'" do
      it_behaves_like 'builds the payload with the correct options' do
        let(:use_case) { Arkose::DataExchangePayload::USE_CASE_SIGN_UP }
        let(:require_challenge) { false }
        let(:email) { nil }
      end

      context 'and phone verifications hard limit has been exceeded' do
        before do
          allow(::Gitlab::ApplicationRateLimiter).to receive(:peek)
            .with(:hard_phone_verification_transactions_limit, scope: :global).and_return(true)
        end

        it_behaves_like 'builds the payload with the correct options' do
          let(:use_case) { Arkose::DataExchangePayload::USE_CASE_SIGN_UP }
          let(:require_challenge) { true }
        end
      end
    end
  end
end
