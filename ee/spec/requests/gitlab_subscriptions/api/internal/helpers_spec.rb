# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Helpers, feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  subject(:helper) { Class.new.include(described_class).new }

  describe '#jwt_request?' do
    context 'when the headers do not contain the subscription portal JWT token' do
      it 'returns false' do
        allow(helper).to receive(:headers).and_return({ 'Authorization' => 'Bearer test' })

        expect(helper.jwt_request?).to be(false)
      end
    end

    context 'when the headers contain the subscription portal JWT token' do
      it 'returns true' do
        allow(helper).to receive(:headers).and_return({ 'X-Customers-Dot-Internal-Token' => 'test-token' })

        expect(helper.jwt_request?).to be(true)
      end
    end
  end

  describe '#authenticate_from_jwt!' do
    let(:jwt_token_headers) { { 'X-Customers-Dot-Internal-Token' => 'test-token' } }

    before do
      allow(helper).to receive(:headers).and_return(jwt_token_headers)
    end

    context 'when the request cannot be verified with the subscription portal JWT token' do
      it 'returns an unauthorised error' do
        allow(helper).to receive(:unauthorized!).and_raise('unauthorized')

        allow(GitlabSubscriptions::API::Internal::Auth)
          .to receive(:verify_api_request)
          .with(jwt_token_headers)
          .and_return(nil)

        expect { helper.authenticate_from_jwt! }.to raise_error('unauthorized')
      end
    end

    context 'when the request can be verified with the subscription portal JWT token' do
      it 'does not return an error' do
        allow(GitlabSubscriptions::API::Internal::Auth)
          .to receive(:verify_api_request)
          .with(jwt_token_headers)
          .and_return(['decoded-token'])

        expect(helper.authenticate_from_jwt!).to be_nil
      end
    end
  end
end
