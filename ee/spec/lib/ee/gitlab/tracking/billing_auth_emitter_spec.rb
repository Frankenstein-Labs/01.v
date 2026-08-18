# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::BillingAuthEmitter, feature_category: :application_instrumentation do
  subject(:emitter) do
    described_class.new(
      endpoint: 'billing.stgsub.gitlab.net',
      options: { protocol: 'https', method: 'post', buffer_size: 1, path: path }
    )
  end

  let(:path) { '/com.snowplowanalytics.snowplow.auth/tp2' }
  let(:collector_uri) { "https://billing.stgsub.gitlab.net#{path}" }
  let(:payload) { { 'key' => 'value' } }

  before do
    stub_request(:post, collector_uri).to_return(status: 200, body: '')
  end

  describe '#http_post' do
    context 'when on SaaS' do
      let(:token_source) { instance_double(Gitlab::Tracking::Destinations::BillingOidcTokenSource) }

      before do
        allow(CloudConnector).to receive(:gitlab_realm).and_return(CloudConnector::GITLAB_REALM_SAAS)
        allow(Gitlab::Tracking::Destinations::BillingOidcTokenSource)
          .to receive(:new).with('billing.stgsub.gitlab.net').and_return(token_source)
        allow(token_source).to receive(:token).and_return('oidc-id-token')
      end

      it 'authenticates with the GCP IAM OIDC token' do
        emitter.send(:http_post, payload)

        expect(
          a_request(:post, collector_uri).with(
            headers: { 'Authorization' => 'Bearer oidc-id-token' },
            body: payload.to_json
          )
        ).to have_been_made.once
      end
    end

    context 'when not on SaaS' do
      before do
        allow(CloudConnector).to receive(:gitlab_realm).and_return(CloudConnector::GITLAB_REALM_SELF_MANAGED)
      end

      context 'when a Cloud Connector token is available' do
        let(:cc_token) { JWT.encode({ 'exp' => 1.hour.from_now.to_i }, nil, 'none') }

        before do
          allow(CloudConnector::Tokens).to receive(:cloud_connector_token).and_return(cc_token)
        end

        it 'authenticates with the Cloud Connector token' do
          emitter.send(:http_post, payload)

          expect(
            a_request(:post, collector_uri).with(
              headers: { 'Authorization' => "Bearer #{cc_token}" },
              body: payload.to_json
            )
          ).to have_been_made.once
        end

        it 'does not use the OIDC token source' do
          expect(Gitlab::Tracking::Destinations::BillingOidcTokenSource).not_to receive(:new)

          emitter.send(:http_post, payload)
        end

        it 'caches the token across requests until it is about to expire' do
          3.times { emitter.send(:http_post, payload) }

          expect(CloudConnector::Tokens).to have_received(:cloud_connector_token).once
        end

        it 'refetches the token once the cached one has expired' do
          emitter.send(:http_post, payload)

          travel_to(2.hours.from_now) { emitter.send(:http_post, payload) }

          expect(CloudConnector::Tokens).to have_received(:cloud_connector_token).twice
        end
      end

      context 'when no Cloud Connector token is available' do
        before do
          allow(CloudConnector::Tokens).to receive(:cloud_connector_token).and_return(nil)
        end

        it 'sends the request without an Authorization header and logs a warning' do
          expect(emitter.logger).to receive(:warn).with(/no auth token available/)

          emitter.send(:http_post, payload)

          expect(
            a_request(:post, collector_uri)
              .with { |req| !req.headers.key?('Authorization') }
          ).to have_been_made.once
        end
      end

      context 'when the Cloud Connector token has expired' do
        before do
          create(:service_access_token, :expired)
        end

        it 'sends the request without an Authorization header and logs a warning' do
          expect(emitter.logger).to receive(:warn).with(/no auth token available/)

          emitter.send(:http_post, payload)

          expect(
            a_request(:post, collector_uri)
              .with { |req| !req.headers.key?('Authorization') }
          ).to have_been_made.once
        end
      end

      context 'when reading the Cloud Connector token fails' do
        let(:error) { StandardError.new('boom') }

        before do
          allow(CloudConnector::Tokens).to receive(:cloud_connector_token).and_raise(error)
        end

        it 'tracks the exception and sends the request without an Authorization header' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(error)
          expect(emitter.logger).to receive(:warn).with(/no auth token available/)

          emitter.send(:http_post, payload)

          expect(
            a_request(:post, collector_uri)
              .with { |req| !req.headers.key?('Authorization') }
          ).to have_been_made.once
        end
      end
    end
  end
end
