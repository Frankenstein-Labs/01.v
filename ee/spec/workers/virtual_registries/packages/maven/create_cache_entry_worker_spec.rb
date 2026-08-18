# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::CreateCacheEntryWorker, feature_category: :virtual_registry do
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

  let(:worker) { described_class.new }
  let(:path) { 'maven/package-name.pom' }
  let(:upstream_resource_url) { upstream.url_for(path) }
  let(:etag) { 'W/"51f828b51a27ae904e020f679d8f8ce0"' }
  let(:content_type) { 'application/octet-stream' }
  let(:mock_response) do
    {
      status: 200,
      body: 'file-content',
      headers: {
        'etag' => etag,
        'content-type' => content_type
      }
    }
  end

  subject(:perform) { worker.perform(upstream_id, path) }

  before do
    stub_request(:get, upstream_resource_url).with(headers: upstream.headers).and_return(mock_response)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [upstream.id, path] }
  end

  it 'has an until_executed deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    context 'when the upstream is found' do
      let(:upstream_id) { upstream.id }
      let(:expected_file_attrs) do
        {
          sha1: OpenSSL::Digest.new('SHA1').hexdigest(mock_response[:body]),
          md5: OpenSSL::Digest.new('MD5').hexdigest(mock_response[:body]),
          content_type: content_type
        }
      end

      it 'creates cache entry' do
        expect(VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService).to receive(:new)
          .with(
            upstream: upstream,
            params: {
              path: path,
              file: be_an(UploadedFile).and(have_attributes(expected_file_attrs)),
              etag: etag,
              content_type: content_type,
              skip_permission_check: true
            }
          ).and_call_original

        perform
      end

      it 'does not have md5 digest in fips mode', :fips_mode do
        expect(VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService).to receive(:new)
          .with(
            upstream: upstream,
            params: {
              path: path,
              file: be_an(UploadedFile).and(have_attributes(md5: nil)),
              etag: etag,
              content_type: content_type,
              skip_permission_check: true
            }
          ).and_call_original

        perform
      end

      it 'downloads file from upstream' do
        perform

        assert_requested(:get, upstream_resource_url) do |req|
          expect(req.headers).to include(upstream.headers(path).deep_stringify_keys)
        end
      end

      context 'when sha1 checksum exist in response.header' do
        using RSpec::Parameterized::TableSyntax

        let(:digest_checksum) { 'abcdef1234567890abcdef1234567890abcdef12' }

        where(:digest_type, :header_key) do
          :sha1 | 'x-checksum-sha1'
          :sha1 | 'x-goog-meta-checksum-sha1'
          :md5  | 'x-checksum-md5'
          :md5  | 'x-goog-meta-checksum-md5'
        end

        with_them do
          let(:mock_response) do
            super().merge(headers: { header_key.to_s => digest_checksum })
          end

          let(:mock_digest) { instance_double(OpenSSL::Digest) }

          before do
            allow(OpenSSL::Digest).to receive(:new).and_call_original
          end

          it "does not compute #{params[:digest_type]} digest", :aggregate_failures do
            expect(OpenSSL::Digest).to receive(:new).with(digest_type.to_s.upcase).and_return(mock_digest)
            expect(mock_digest).not_to receive(:update)

            perform
          end

          it "uses #{params[:digest_type]} digest from response header" do
            expect(VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService).to receive(:new)
              .with(
                upstream: upstream,
                params: hash_including(
                  file: be_an(UploadedFile).and(have_attributes({ digest_type.to_sym => digest_checksum }))
                )
              ).and_call_original

            perform
          end
        end

        context 'when in fips mode', :fips_mode do
          let(:md5) { 'md51234567890abcdef1234567890abcdef12' }
          let(:mock_response) do
            super().merge(headers: { 'x-checksum-md5' => md5 })
          end

          it 'does not have md5 digest' do
            expect(VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService).to receive(:new)
              .with(
                upstream: upstream,
                params: hash_including(
                  file: be_an(UploadedFile).and(have_attributes(md5: nil))
                )
              ).and_call_original

            perform
          end
        end
      end

      context 'when upstream returns error' do
        let(:mock_response) { { status: 400 } }

        it 'logs errors' do
          expect(Gitlab::ErrorTracking).to receive(:log_exception)
            .with(
              instance_of(described_class::ResponseError),
              upstream_id: upstream.id, path: path
            )

          perform
        end
      end

      context 'when http request failed' do
        let(:error) { Errno::ECONNREFUSED.new('Network timeout') }

        before do
          stub_request(:get, upstream_resource_url).to_raise(error)
        end

        it 'logs errors' do
          expect(Gitlab::ErrorTracking).to receive(:log_exception)
            .with(error, upstream_id: upstream.id, path: path)

          perform
        end
      end
    end

    context 'when the upstream is not found' do
      let(:upstream_id) { non_existing_record_id }

      it 'does not create cache entry' do
        expect(VirtualRegistries::Packages::Maven::Cache::Entries::CreateOrUpdateService).not_to receive(:new)

        perform
      end
    end
  end
end
