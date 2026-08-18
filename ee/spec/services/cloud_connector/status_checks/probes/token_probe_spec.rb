# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::StatusChecks::Probes::TokenProbe, :freeze_time, feature_category: :duo_setting do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    subject(:probe) { described_class.new }

    let(:decoded_token) do
      {
        exp: exp.to_i,
        aud: ['example_audience'],
        iss: 'example_issuer',
        gitlab_realm: 'example_realm',
        scopes: ['example_scope']
      }.stringify_keys
    end

    # nil trait means record is missing
    where(:token_trait, :decoded?, :expired?, :success?, :message) do
      :active    | true  | false | true  | 'Access credentials are valid'
      nil        | false | false | false | 'Access credentials not found'
      :expired   | true  | true  | false | 'Access credentials expired'
      :invalid   | false | false | false | 'Invalid access credentials'
    end

    with_them do
      let!(:token) { create(:service_access_token, token_trait) if token_trait }
      let(:exp) { expired? ? 1.day.ago : 1.day.from_now }

      it 'returns the expected result' do
        result = probe.execute

        expect(result).to be_a(CloudConnector::StatusChecks::Probes::ProbeResult)
        expect(result.success?).to be success?
        expect(result.message).to match(message)

        if decoded?
          expect(result.details).to include(
            decode: 'Successful',
            expired: expired?,
            expires_at: Time.at(exp).utc,
            token: hash_including(decoded_token),
            created_at: token.created_at
          )
        elsif token
          expect(result.details).to include(decode: 'Failed with message: Not enough or too many segments')
        end
      end
    end
  end
end
