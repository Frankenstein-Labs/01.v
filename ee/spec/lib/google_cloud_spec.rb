# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GoogleCloud, feature_category: :system_access do
  describe '.credentials' do
    subject(:credentials) do
      described_class.credentials(
        identity_provider_resource_name: audience,
        encoded_jwt: encoded_jwt
      )
    end

    let(:audience) { 'example_audience' }
    let(:encoded_jwt) { 'not_a_real_jwt' }

    it 'returns a hash with the provided info' do
      expect(credentials).to match(
        a_hash_including(
          audience: audience,
          credential_source: a_hash_including(
            headers: a_hash_including(
              'Authorization' => "Bearer #{encoded_jwt}"
            )
          )
        )
      )
    end
  end

  describe '.glgo_base_url' do
    subject { described_class.glgo_base_url }

    it { is_expected.to include('https://') }
  end
end
