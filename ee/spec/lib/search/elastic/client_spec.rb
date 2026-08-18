# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Client, feature_category: :global_search do
  describe '.build' do
    let(:client) { described_class.build(params) }

    context 'when params are nil' do
      let(:params) { nil }

      it 'client returns nil' do
        expect(client).to be_nil
      end
    end

    context 'without credentials' do
      let(:params) { { url: 'http://dummy-elastic:9200' } }

      it 'makes unsigned requests' do
        stub_request(:get, 'http://dummy-elastic:9200/foo/_doc/1')
          .with(headers: { 'Content-Type' => 'application/json' })
          .to_return(status: 200, body: 'fake_response')

        expect(client.get(index: 'foo', id: 1)).to eq('fake_response')
      end

      it 'does not set request timeout in transport' do
        options = client.transport.transport.options.dig(:transport_options, :request)

        expect(options).to include(open_timeout: described_class::OPEN_TIMEOUT, timeout: nil)
      end

      it 'does not set log & debug flags by default' do
        expect(client.transport.transport.options).not_to include(debug: true, log: true)
      end

      it 'sets log & debug flags if .debug? is true' do
        allow(described_class).to receive(:debug?).and_return(true)

        expect(client.transport.transport.options).to include(debug: true, log: true)
      end

      describe 'client adapter' do
        it 'uses typhoeus as the adapter by default' do
          options = client.transport.transport.options

          expect(options).to include(adapter: :typhoeus)
        end

        context 'when adapter in config' do
          let(:params) { { client_adapter: 'net_http' } }

          it 'uses the adapter from application settings' do
            options = client.transport.transport.options

            expect(options).to include(adapter: :net_http)
          end
        end

        context 'when client_adapter in config is null' do
          let(:params) { { client_adapter: nil } }

          it 'falls back to the DEFAULT_ADAPTER' do
            options = client.transport.transport.options

            expect(options).to include(adapter: described_class::DEFAULT_ADAPTER)
          end
        end
      end

      context 'with client_request_timeout in config' do
        let(:params) { { url: 'http://dummy-elastic:9200', client_request_timeout: 30 } }

        it 'sets request timeout in transport' do
          options = client.transport.transport.options.dig(:transport_options, :request)

          expect(options).to include(open_timeout: described_class::OPEN_TIMEOUT, timeout: 30)
        end
      end

      context 'with retry_on_failure' do
        using RSpec::Parameterized::TableSyntax

        where(:retry_on_failure, :client_retry) do
          nil   | 0    # not set or nil, no retry
          false | 0    # with false, no retry
          true  | true # with true, retry with default times
          10    | 10   # with a number N, retry N times
        end

        with_them do
          let(:params) { { url: 'http://dummy-elastic:9200', retry_on_failure: retry_on_failure } }

          it 'sets retry in transport' do
            expect(client.transport.transport.options[:retry_on_failure]).to eq(client_retry)
          end
        end
      end
    end

    context 'with AWS IAM static credentials' do
      let(:params) do
        {
          url: 'http://example-elastic:9200',
          aws: true,
          aws_region: 'us-east-1',
          aws_access_key: '0',
          aws_secret_access_key: '0'
        }
      end

      let(:meta_string) do
        "es=#{Elasticsearch::VERSION},rb=#{RUBY_VERSION},t=#{Elasticsearch::Transport::VERSION}," \
          "fd=#{Faraday::VERSION},ty=#{Typhoeus::VERSION}"
      end

      it 'signs_requests' do
        # Mock the correlation ID (passed as header) to have deterministic signature
        allow(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id).and_return('new-correlation-id')

        travel_to(Time.parse('20170303T133952Z')) do
          stub_request(:get, 'http://example-elastic:9200/foo/_doc/1')
            .with(
              headers: {
                'Authorization' => /^AWS4-HMAC-SHA256 Credential=0/,
                'Content-Type' => 'application/json',
                'Expect' => '',
                'Host' => 'example-elastic:9200',
                'User-Agent' => /^elasticsearch-ruby/,
                'X-Amz-Content-Sha256' => 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                'X-Amz-Date' => '20170303T133952Z',
                'X-Elastic-Client-Meta' => meta_string
              }
            ).to_return(status: 200, body: 'fake_response')

          expect(client.get(index: 'foo', id: 1)).to eq('fake_response')
        end
      end
    end
  end

  describe '.resolve_aws_credentials' do
    subject(:creds) { described_class.resolve_aws_credentials(params) }

    context 'when the AWS IAM static credentials are valid' do
      let(:params) do
        {
          url: 'http://example-elastic:9200',
          aws: true,
          aws_region: 'us-east-1',
          aws_access_key: '0',
          aws_secret_access_key: '0'
        }
      end

      let(:mock_static_credentials) { instance_double(Aws::Credentials, set?: true) }

      before do
        allow(Aws::Credentials).to receive(:new).with('0', '0').and_return(mock_static_credentials)
      end

      it 'returns credentials from static credentials without making an HTTP request' do
        expect(Aws::Credentials).to receive(:new).with('0', '0')
        expect(creds).to eq(mock_static_credentials)
      end

      context 'when AWS IAM role ARN is provided' do
        let(:params) do
          {
            url: 'http://example-elastic:9200',
            aws: true,
            aws_region: 'us-east-1',
            aws_role_arn: 'arn:aws:iam::123456789012:role/elasticsearch-role'
          }
        end

        let(:mock_sts_client) { instance_double(Aws::STS::Client) }
        let(:mock_assume_role_credentials) do
          instance_double(Aws::AssumeRoleCredentials, set?: true)
        end

        it 'returns credentials from the assumed role' do
          expect(Aws::STS::Client).to receive(:new).with(region: 'us-east-1').and_return(mock_sts_client)
          expect(Aws::AssumeRoleCredentials).to receive(:new)
            .with(
              client: mock_sts_client,
              role_arn: 'arn:aws:iam::123456789012:role/elasticsearch-role',
              role_session_name: described_class::AWS_ROLE_SESSION_NAME
            ).and_return(mock_assume_role_credentials)

          expect(creds).to eq(mock_assume_role_credentials)
        end
      end

      context 'when both AWS IAM role ARN and static credentials are provided' do
        let(:params) do
          {
            url: 'http://example-elastic:9200',
            aws: true,
            aws_region: 'us-east-1',
            aws_role_arn: 'arn:aws:iam::123456789012:role/elasticsearch-role',
            aws_access_key: 'static-access-key',
            aws_secret_access_key: 'static-secret-key'
          }
        end

        let(:mock_sts_client) { instance_double(Aws::STS::Client) }
        let(:mock_assume_role_credentials) do
          instance_double(Aws::AssumeRoleCredentials, set?: true)
        end

        before do
          allow(Aws::STS::Client).to receive(:new).with(region: 'us-east-1').and_return(mock_sts_client)
          allow(Aws::AssumeRoleCredentials).to receive(:new)
            .with(
              client: mock_sts_client,
              role_arn: 'arn:aws:iam::123456789012:role/elasticsearch-role',
              role_session_name: described_class::AWS_ROLE_SESSION_NAME
            )
            .and_return(mock_assume_role_credentials)
        end

        it 'prioritizes role ARN over static credentials' do
          # The test should not try to create static credentials when role ARN is provided
          expect(Aws::Credentials).not_to receive(:new).with('static-access-key', 'static-secret-key')

          expect(creds).to eq(mock_assume_role_credentials)
        end
      end
    end

    context 'when the AWS IAM static credentials are invalid' do
      let(:params) do
        {
          url: 'http://example-elastic:9200',
          aws: true,
          aws_region: 'us-east-1'
        }
      end

      let(:mock_static_credentials) { instance_double(Aws::Credentials, set?: false) }

      before do
        allow(Aws::Credentials).to receive(:new).with(nil, nil).and_return(mock_static_credentials)
        Gitlab::Aws::CredentialsResolver.clear_memoization(:credential_provider_chain)
        allow_next_instance_of(Aws::CredentialProviderChain) do |instance|
          allow(instance).to receive(:resolve).and_return(provider_credentials)
        end
      end

      context 'when aws sdk provides credentials through provider chain' do
        let(:provider_credentials) { instance_double(Aws::Credentials, set?: true) }

        it 'returns the credentials from provider chain' do
          expect(creds).to eq(provider_credentials)
        end
      end

      context 'when aws sdk does not provide credentials through provider chain' do
        let(:provider_credentials) { nil }

        it 'returns nil' do
          expect(creds).to be_nil
        end
      end
    end
  end

  describe '.debug?' do
    using RSpec::Parameterized::TableSyntax

    where(:dev_or_test_env, :env_variable, :expected_result) do
      false | 'true'  | false
      false | 'false' | false
      true  | 'false' | false
      true  | 'true'  | true
    end

    with_them do
      before do
        allow(Gitlab).to receive(:dev_or_test_env?).and_return(dev_or_test_env)
        stub_env('ELASTIC_CLIENT_DEBUG', env_variable)
      end

      it 'returns expected result' do
        expect(described_class.debug?).to eq(expected_result)
      end
    end
  end
end
