# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Cache::Entries::CreateOrUpdateService, :aggregate_failures, feature_category: :virtual_registry do
  let_it_be(:registry) { create(:virtual_registries_container_registry) }
  let_it_be(:project) { create(:project, namespace: registry.group) }
  let_it_be(:user) { create(:user, owner_of: registry.group) }
  let_it_be(:path) { "#{path}-#{SecureRandom.hex(4)}" }
  let_it_be(:upstream, freeze: false) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:etag) { 'test' }
  let(:content_type) { 'text/xml' }
  let(:params) { { path: path, file: file, etag: etag, content_type: content_type } }
  let(:file) do
    UploadedFile.new(
      Tempfile.new('cache_entry').path,
      sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
    )
  end

  let!(:service) do
    described_class.new(upstream: upstream, current_user: user, params: params)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returning a service response success response' do
      shared_examples 'creating a new cache entry' do
        let_it_be(:path) do
          "my/image/blobs/sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd"
        end

        it 'returns a success service response', :freeze_time do
          expect_next_instance_of(::VirtualRegistries::Container::Cache::Remote::Entry) do |expected_cache_entry|
            expect(expected_cache_entry).to receive(:bump_downloads_count)
          end

          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)
          expect(execute).to be_success

          last_cache_entry = upstream.cache_remote_entries.last
          expect(execute.payload).to eq(cache_entry: last_cache_entry)

          expect(last_cache_entry).to have_attributes(
            group_id: registry.group.id,
            upstream_checked_at: Time.zone.now,
            relative_path: "/#{path}",
            upstream_etag: etag,
            content_type: content_type,
            digest: 'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
            file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
          )
        end
      end

      shared_examples 'updating an existing cache entry' do
        let_it_be(:path) { "#{path}-existing" }
        let_it_be(:cache_entry, freeze: false) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: upstream.group,
            upstream: upstream,
            relative_path: "/#{path}"
          )
        end

        it 'updates it', :freeze_time, :sidekiq_inline do
          last_cache_entry = upstream.cache_remote_entries.last

          expect { execute }.to not_change { upstream.cache_remote_entries.count }
            .and change { last_cache_entry.reset.downloads_count }.by(1)
            .and change { last_cache_entry.downloaded_at }.to(Time.current)

          is_expected.to be_success.and have_attributes(payload: { cache_entry: last_cache_entry })

          expect(last_cache_entry).to have_attributes(
            upstream_checked_at: Time.zone.now,
            upstream_etag: etag
          )
        end
      end

      it_behaves_like 'creating a new cache entry'
      it_behaves_like 'updating an existing cache entry'

      context 'with a nil content_type' do
        let(:params) { super().merge(content_type: nil) }

        it 'creates a cache entry with a default content_type' do
          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)
          expect(execute).to be_success

          expect(upstream.cache_remote_entries.last).to have_attributes(content_type: 'application/octet-stream')
        end
      end

      context 'with an error' do
        it 'returns an error response and log the error' do
          expect(::VirtualRegistries::Container::Cache::Remote::Entry)
            .to receive(:create_or_update_by!).and_raise(ActiveRecord::RecordInvalid)
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)
            .with(
              instance_of(ActiveRecord::RecordInvalid),
              upstream_id: upstream.id,
              group_id: upstream.group_id,
              class: described_class.name
            )
          expect { execute }.not_to change { upstream.cache_remote_entries.count }
        end
      end

      context 'with a manifest requested by tag' do
        let_it_be(:path) { "my/image/manifests/3.23" }
        let(:etag) { 'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd' }

        it 'extracts digest from etag when path does not contain digest' do
          expect_next_instance_of(::VirtualRegistries::Container::Cache::Remote::Entry) do |expected_cache_entry|
            expect(expected_cache_entry).to receive(:bump_downloads_count)
          end

          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)
          expect(execute).to be_success

          last_cache_entry = upstream.cache_remote_entries.last
          expect(last_cache_entry).to have_attributes(
            relative_path: "/#{path}",
            upstream_etag: etag,
            digest: 'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd'
          )
        end
      end

      context 'with blob deduplication' do
        let_it_be(:blob_digest) do
          'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd'
        end

        let_it_be(:existing_blob_entry, freeze: false) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: upstream.group,
            upstream: upstream,
            relative_path: "/library/alpine/blobs/#{blob_digest}",
            digest: blob_digest
          )
        end

        let(:path) { "library/nginx/blobs/#{blob_digest}" }

        it 'reuses existing blob entry with same digest instead of creating a new one', :sidekiq_inline do
          expect { execute }.to not_change { upstream.cache_remote_entries.count }
            .and change { existing_blob_entry.reload.downloads_count }.by(1)

          expect(execute).to be_success
          expect(execute.payload[:cache_entry]).to eq(existing_blob_entry)
        end
      end

      context 'with manifest deduplication by digest' do
        let_it_be(:manifest_digest) do
          'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd'
        end

        let_it_be(:existing_manifest_entry, freeze: false) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: upstream.group,
            upstream: upstream,
            relative_path: "/library/alpine/manifests/#{manifest_digest}",
            digest: manifest_digest
          )
        end

        let(:path) { "library/nginx/manifests/#{manifest_digest}" }

        it 'reuses existing manifest entry with same digest instead of creating a new one', :sidekiq_inline do
          expect { execute }.to not_change { upstream.cache_remote_entries.count }
            .and change { existing_manifest_entry.reload.downloads_count }.by(1)

          expect(execute).to be_success
          expect(execute.payload[:cache_entry]).to eq(existing_manifest_entry)
        end
      end

      context 'with manifest by tag (no deduplication)' do
        let_it_be(:tag_path) { "library/alpine/manifests/latest" }
        let_it_be(:existing_tag_entry, freeze: false) do
          create(
            :virtual_registries_container_cache_remote_entry,
            group: upstream.group,
            upstream: upstream,
            relative_path: "/#{tag_path}"
          )
        end

        let(:path) { "library/nginx/manifests/latest" }

        it 'creates a new entry for tag-based manifest requests' do
          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)

          expect(execute).to be_success
          expect(execute.payload[:cache_entry]).not_to eq(existing_tag_entry)
        end
      end

      context 'with a blank etag' do
        let_it_be(:path) { "my/image/manifests/3.23" }
        let(:etag) { nil }

        it 'skips digest extraction from etag and creates entry without digest' do
          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)
          expect(execute).to be_success

          expect(upstream.cache_remote_entries.last).to have_attributes(
            relative_path: "/#{path}",
            digest: nil
          )
        end
      end

      context 'with a blob path without a valid digest' do
        let(:path) { "library/nginx/blobs/not-a-digest" }

        it 'skips deduplication and creates a new entry' do
          expect { execute }.to change { upstream.cache_remote_entries.count }.by(1)
          expect(execute).to be_success

          expect(upstream.cache_remote_entries.last).to have_attributes(
            relative_path: "/#{path}",
            digest: nil
          )
        end
      end
    end

    context 'with a User' do
      it_behaves_like 'returning a service response success response'
    end

    context 'with a DeployToken' do
      let_it_be(:user) { create(:deploy_token, :group, groups: [registry.group], read_virtual_registry: true) }

      it_behaves_like 'returning a service response success response'
    end

    context 'with no path' do
      let(:path) { nil }

      it { is_expected.to eq(described_class::ERRORS[:path_not_present]) }
    end

    context 'with no file' do
      let(:file) { nil }

      it { is_expected.to eq(described_class::ERRORS[:file_not_present]) }
    end

    context 'with no upstream' do
      let_it_be(:upstream) { nil }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end

    context 'with no user' do
      let(:user) { nil }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end
  end
end
