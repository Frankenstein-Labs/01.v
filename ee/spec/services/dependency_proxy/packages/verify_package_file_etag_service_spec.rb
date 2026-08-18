# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Packages::VerifyPackageFileEtagService, :aggregate_failures, feature_category: :package_registry do
  let_it_be(:setting) { create(:dependency_proxy_packages_setting, :maven) }
  let_it_be(:package_file) { create(:package_file, :jar) }

  let(:remote_url) { 'http://test/package.file' }

  let(:authorization_header) do
    ActionController::HttpAuthentication::Basic.encode_credentials(
      setting.maven_external_registry_username,
      setting.maven_external_registry_password
    )
  end

  let(:request_headers) { { 'Authorization' => authorization_header } }

  let(:service) do
    described_class.new(remote_url: remote_url, package_file: package_file, headers: request_headers)
  end

  describe '#execute' do
    subject(:result) { service.execute }

    shared_examples 'expecting a service response error with' do |message:, reason:|
      it 'returns an error' do
        if message.start_with?('Received')
          expect(Gitlab::AppLogger).to receive(:error).with(
            service_class: described_class.to_s,
            project_id: package_file.project_id,
            message: message
          )
        end

        expect(result).to be_a(ServiceResponse)
        expect(result).to be_error
        expect(result.message).to eq(message)
        expect(result.reason).to eq(reason)
      end
    end

    context 'with valid arguments' do
      context 'with a successful head request' do
        let(:etag) { package_file.file_md5 }

        before do
          stub_external_registry_request(status: 200, etag: etag)
        end

        it_behaves_like 'returning a success service response'

        context 'with an etag that contains a digest' do
          let(:etag) { "\"{SHA1{#{package_file.file_sha1}\"}" }

          it_behaves_like 'returning a success service response'
        end

        context 'with an unmatched etag' do
          let(:etag) { 'wrong_etag' }

          it_behaves_like 'expecting a service response error with',
            message: "etag from external registry doesn't match any known digests",
            reason: :wrong_etag
        end

        context 'with an absent etag' do
          let(:etag) { nil }

          it_behaves_like 'expecting a service response error with',
            message: 'no etag from external registry',
            reason: :no_etag
        end

        context 'with a redirect' do
          let(:redirect_location) { 'http://redirect' }

          it 'follows it' do
            stub_external_registry_request(status: 307, response_headers: { Location: redirect_location })
            stub_request(:head, redirect_location)
              .to_return(status: 200, body: '', headers: { etag: "\"#{package_file.file_md5}\"" })

            expect(result).to be_a(ServiceResponse)
            expect(result).to be_success
          end
        end

        context 'with an inline basic auth' do
          let(:remote_url) { "http://#{setting.maven_external_registry_username}:#{setting.maven_external_registry_password}@test/package.file" }

          let(:service) do
            described_class.new(remote_url: remote_url, package_file: package_file)
          end

          it_behaves_like 'returning a success service response'
        end

        context 'with custom headers' do
          let(:request_headers) { { 'Authorization' => 'Bearer test' } }

          it_behaves_like 'returning a success service response'
        end
      end

      context 'with a unsuccessful head request' do
        before do
          stub_external_registry_request(status: 404)
        end

        it_behaves_like 'expecting a service response error with',
          message: 'Received 404 from external registry',
          reason: :response_error_code
      end

      context 'with a timeout' do
        before do
          allow(::Gitlab::HTTP).to receive(:head).and_raise(::Net::OpenTimeout)
        end

        it_behaves_like 'expecting a service response error with',
          message: 'External registry is not available',
          reason: :response_error_code
      end
    end

    context 'with invalid arguments' do
      %i[remote_url package_file].each do |field|
        context "with a nil #{field}" do
          let(field) { nil }

          it_behaves_like 'expecting a service response error with',
            message: 'invalid arguments',
            reason: :invalid_arguments
        end
      end
    end

    def stub_external_registry_request(status: 200, etag: 'etag', response_headers: {})
      response_headers[:etag] = "\"#{etag}\"" if etag

      stub_request(:head, 'http://test/package.file')
        .with(headers: request_headers)
        .to_return(status: status, body: '', headers: response_headers)
    end
  end
end
