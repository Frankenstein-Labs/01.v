# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::IdentityProviderPayloadFactory, feature_category: :ai_agents do
  using RSpec::Parameterized::TableSyntax

  let(:signing_key) { OpenSSL::PKey::RSA.new(Rails.application.credentials.openid_connect_signing_key) }

  let(:token_invalid) { 'NOT_A_REAL_TOKEN' }
  let(:token_no_uid) { JWT.encode({ foo: 'bar' }, signing_key, 'RS256', { typ: 'JWT' }) }
  let(:token_with_sub) { JWT.encode({ sub: 'test-subject' }, signing_key, 'RS256', { typ: 'JWT' }) }
  let(:token_with_uid) do
    JWT.encode({ sub: 'test-subject', gitlab_instance_uid: 'test-gitlab-uid' }, signing_key, 'RS256', { typ: 'JWT' })
  end

  describe '#execute' do
    subject(:execution) { described_class.new.execute }

    where(:token, :expectation) do
      nil                     | { err: hash_including(reason: :cc_token_not_found) }
      ref(:token_invalid)     | { err: hash_including(reason: :cc_token_jwt_decode) }
      ref(:token_no_uid)      | { err: hash_including(reason: :cc_token_no_uid) }
      ref(:token_with_uid)    | { ok: { aws_audience: 'gitlab-cc-test-gitlab-uid',
                                        aws_provider_url: 'https://auth.token.gitlab.com/cc/oidc/test-gitlab-uid',
                                        instance_uid: 'test-gitlab-uid' } }
      ref(:token_with_sub)    | { ok: { aws_audience: 'gitlab-cc-test-subject',
                                        aws_provider_url: 'https://auth.token.gitlab.com/cc/oidc/test-subject',
                                        instance_uid: 'test-subject' } }
    end

    with_them do
      before do
        allow(::CloudConnector::Tokens).to receive(:get).with(
          unit_primitive: :amazon_q_integration,
          resource: :instance).and_return(token)
      end

      it { expect(execution.to_h).to include(expectation) }
    end
  end
end
