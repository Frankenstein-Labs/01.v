# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::Replication::BlobDownloader, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  # freeze: true catches accidental mutation causing state leakage across tests.
  # primary uses with_reload instead because tests intentionally mutate its attributes.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/590041
  let_it_be_with_reload(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: true) { create(:geo_node) }

  let(:model_record) { create(:package_file, :npm) }
  let(:replicator) { model_record.replicator }

  subject(:downloader) { described_class.new(replicator: replicator) }

  describe '#execute' do
    before do
      stub_current_geo_node(secondary)
    end

    describe 'preconditions' do
      context 'when not a Geo secondary' do
        it 'returns failure' do
          stub_current_geo_node(primary)
          stub_primary_node

          result = downloader.execute

          expect(result.success).to be_falsey
        end
      end

      context 'when an org migration target' do
        before do
          stub_feature_flags(org_migration_target_cell: true)
        end

        it 'does not fail the secondary node precondition check' do
          result = downloader.execute

          expect(result.success).to be true
        end
      end

      context 'when no Geo primary exists' do
        it 'returns failure' do
          primary.update!(primary: false)

          result = downloader.execute

          expect(result.success).to be_falsey
        end
      end

      context 'when the file is locally stored' do
        context 'when the file destination is already taken by a directory' do
          it 'returns failure' do
            path = replicator.carrierwave_uploader.path
            expect(File).to receive(:directory?).with(path).and_return(true)

            result = downloader.execute

            expect(result.success).to be_falsey
          end
        end

        # Not worth testing here as-is. Extract the functionality first.
        xit 'ensures the file destination directory exists'

        context 'when the destination directory cannot be created' do
          it 'logs an error and returns failure' do
            path = replicator.carrierwave_uploader.path
            dir = Pathname.new(path).dirname

            allow(File).to receive(:directory?).with(path).and_return(false)
            allow(File).to receive(:directory?).with(dir).and_return(false)
            allow(FileUtils).to receive(:mkdir_p).and_raise(StandardError, 'Permission denied')

            expect(downloader).to receive(:log_error)
              .with("Unable to create directory #{dir}: Permission denied")

            result = downloader.execute

            expect(result.success).to be_falsey
            expect(result.reason).to eq('Skipping transfer as we cannot create the destination directory')
          end
        end
      end

      context 'when the file is on Object Storage' do
        let!(:secondary_object_storage) { create(:geo_node, sync_object_storage: sync_object_storage) }

        before do
          stub_package_file_object_storage(enabled: true, direct_upload: true)
          stub_current_geo_node(secondary_object_storage)
        end

        let!(:model_record) { create(:package_file, :npm, :object_storage) } # rubocop:disable RSpec/ScatteredLet -- due to creation on primary then test on secondary

        subject(:downloader) { described_class.new(replicator: model_record.replicator) }

        context 'with object storage sync enabled' do
          let(:sync_object_storage) { true }

          context 'with object storage disabled' do
            before do
              stub_package_file_object_storage(enabled: false)
            end

            it 'returns failure' do
              result = downloader.execute

              expect(result.success).to be_falsey
            end
          end
        end

        context 'with object storage sync disabled' do
          let(:sync_object_storage) { false }

          it 'returns failure' do
            result = downloader.execute

            expect(result.success).to be_falsey
          end
        end
      end

      context 'when the file already exists and it is ok to skip download' do
        it 'returns success' do
          allow(replicator).to receive(:ok_to_skip_download?).and_return(true)

          result = downloader.execute

          expect(result.success).to be_truthy
          expect(result.bytes_downloaded).to eq(0)
          expect(result.extra_details).to eq({ skipped: true })
        end
      end
    end

    describe 'download file' do
      before do
        allow(downloader).to receive(:check_preconditions)
      end

      context 'when an error occurs while getting a Tempfile' do
        it 'returns failure' do
          downloader

          expect(Tempfile).to receive(:new).and_raise('boom')

          result = downloader.execute

          expect(result.success).to be_falsey
          expect(result.extra_details).to have_key(:error)
        end
      end

      context 'when an exception occurs during HTTP transfer' do
        it 'returns failure with bytes_downloaded: 0' do
          stub_request(:get, downloader.resource_url)
            .to_raise(StandardError.new('Connection reset'))

          result = downloader.execute

          expect(result.success).to be_falsey
          expect(result.bytes_downloaded).to eq(0)
          expect(result.reason).to eq('Error downloading file')
          expect(result.extra_details).to include(error: an_instance_of(StandardError))
        end
      end

      context 'when the HTTP response is unsuccessful' do
        context 'when the HTTP response indicates a missing file on the primary' do
          it 'returns a failed result indicating primary_missing_file' do
            stub_request(:get, downloader.resource_url)
              .to_return(
                status: 404,
                headers: { content_type: 'application/json' },
                body: { geo_code: Gitlab::Geo::Replication::FILE_NOT_FOUND_GEO_CODE }.to_json
              )

            result = downloader.execute

            expect_blob_downloader_result(result, success: false, bytes_downloaded: 0, primary_missing_file: true,
              reason: 'The file is missing on the Geo primary site')
          end
        end

        context 'when the HTTP response does not indicate a missing file on the primary' do
          it 'returns a failed result' do
            stub_request(:get, downloader.resource_url)
              .to_return(
                status: 404,
                headers: { content_type: 'application/json' },
                body: 'Not found'
              )

            result = downloader.execute

            expect_blob_downloader_result(result, success: false, bytes_downloaded: 0, primary_missing_file: false,
              reason: 'Non-success HTTP response status code 404')
          end
        end

        context 'when the HTTP response is a server error' do
          it 'returns a failed result' do
            stub_request(:get, downloader.resource_url)
              .to_return(status: 500, body: 'Internal Server Error')

            result = downloader.execute

            expect_blob_downloader_result(result, success: false, bytes_downloaded: 0, primary_missing_file: false,
              reason: 'Non-success HTTP response status code 500')
          end
        end

        context 'when the HTTP response is 404 with non-JSON content type' do
          it 'returns a failed result without primary_missing_file' do
            stub_request(:get, downloader.resource_url)
              .to_return(
                status: 404,
                headers: { content_type: 'text/html' },
                body: '<h1>Not Found</h1>'
              )

            result = downloader.execute

            expect_blob_downloader_result(result, success: false, bytes_downloaded: 0, primary_missing_file: false,
              reason: 'Non-success HTTP response status code 404')
          end
        end
      end

      context 'when the HTTP response is successful' do
        it 'returns success' do
          path = replicator.carrierwave_uploader.path
          content = replicator.carrierwave_uploader.file.read
          size = content.bytesize
          stub_request(:get, downloader.resource_url).to_return(status: 200, body: content)

          result = downloader.execute
          stat = File.stat(path)

          expect_blob_downloader_result(result, success: true, bytes_downloaded: size, primary_missing_file: false)
          expect(stat.size).to eq(size)
          expect(stat.mode & 0o0777).to eq(0o0666 - File.umask)
          expect(File.binread(path)).to eq(content)
        end

        context 'when the checksum of the downloaded file does not match' do
          it 'returns a failed result' do
            allow(replicator).to receive(:primary_checksum).and_return('something')
            bad_content = 'corrupted!!!'
            stub_request(:get, downloader.resource_url)
              .to_return(status: 200, body: bad_content)

            result = downloader.execute

            expect_blob_downloader_result(result,
              success: false, bytes_downloaded: bad_content.bytesize, primary_missing_file: false)
          end
        end

        context 'when the primary has not stored a checksum for the file' do
          it 'returns a successful result' do
            expect(replicator).to receive(:primary_checksum).and_return(nil)
            content = 'foo'
            stub_request(:get, downloader.resource_url)
              .to_return(status: 200, body: content)

            result = downloader.execute

            expect_blob_downloader_result(result,
              success: true, bytes_downloaded: content.bytesize, primary_missing_file: false)
          end
        end

        context 'when file is in object storage and has the filesize as a checksum on primary' do
          let!(:secondary_object_storage) { create(:geo_node, sync_object_storage: true) }

          before do
            stub_package_file_object_storage(enabled: true, direct_upload: true)
            stub_current_geo_node(secondary_object_storage)
            model_record.update!(file_store: ObjectStorage::Store::REMOTE)
          end

          it 'returns a successful result' do
            allow(replicator).to receive(:primary_checksum).and_return("03")

            content = 'foo' # 3 bytes
            stub_request(:get, downloader.resource_url)
              .to_return(status: 200, body: content)

            result = downloader.execute

            expect_blob_downloader_result(result,
              success: true, bytes_downloaded: content.bytesize, primary_missing_file: false)
          end

          context 'when the primary site redirects to remote storage' do
            let(:geo_internal_headers) { { 'Authorization' => 'Gl-Geo: abc123' } }
            let(:content) { 'foo' }
            let(:remote_url) { 'https://example.com/foo' }

            before do
              allow(replicator).to receive(:primary_checksum).and_return("03")

              allow_next_instance_of(Gitlab::Geo::TransferRequest) do |request|
                allow(request).to receive(:headers).and_return(geo_internal_headers)
              end

              stub_request(:get, downloader.resource_url)
                .to_return(status: 302, headers: { 'Location' => remote_url })

              stub_request(:get, remote_url)
                .to_return(status: 400, body: content, headers: geo_internal_headers)

              stub_request(:get, remote_url)
                .to_return(status: 200, body: content)
            end

            it 'returns success', :aggregate_failures do
              result = downloader.execute

              expect_blob_downloader_result(result,
                success: true, bytes_downloaded: content.bytesize, primary_missing_file: false)

              expect(WebMock).to have_requested(:get, remote_url)
            end
          end

          context 'when the primary site redirects to a S3 presigned URLs containing special characters' do
            let(:remote_url) { 'https://s3.amazonaws.com/bucket/file%2Bwith+plus.txt?X-Amz-Signature=abc123' }
            let(:content) { 'foo' }

            before do
              allow(replicator).to receive(:primary_checksum).and_return("03")

              stub_request(:get, downloader.resource_url)
                .to_return(status: 302, headers: { 'Location' => remote_url })

              stub_request(:get, remote_url)
                .to_return(status: 200, body: content)
            end

            it 'preserves special characters in URLs during redirect' do
              result = downloader.execute

              expect_blob_downloader_result(result,
                success: true, bytes_downloaded: content.bytesize, primary_missing_file: false)

              expect(WebMock).to have_requested(:get, remote_url)
            end
          end
        end
      end
    end
  end

  def expect_blob_downloader_result(result, success:, bytes_downloaded:, primary_missing_file:, reason: nil)
    expect(result.success).to eq(success)
    expect(result.bytes_downloaded).to eq(bytes_downloaded)
    expect(result.primary_missing_file).to eq(primary_missing_file)
    expect(result.reason).to eq(reason) if reason

    # Sanity check to help ensure a valid test
    expect(success).not_to be_nil
    expect(primary_missing_file).not_to be_nil
  end
end
