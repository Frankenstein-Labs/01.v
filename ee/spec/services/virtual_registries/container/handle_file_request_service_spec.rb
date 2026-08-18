# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::HandleFileRequestService, :aggregate_failures, :clean_gitlab_redis_shared_state, feature_category: :virtual_registry do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:user) { create(:user, owner_of: group) }

  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let_it_be_with_reload(:registry) do
    create(:virtual_registries_container_registry, group: group, upstreams: [upstream])
  end

  let(:etag_returned_by_upstream) { nil }
  let(:service) { described_class.new(registry: registry, current_user: user, params: { path: path }) }

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returning a service response success response' do |action:|
      before do
        stub_external_registry_request(etag: etag_returned_by_upstream)
      end

      it 'returns a success service response' do
        event_data = event_data_from(action)
        expect(service).to receive(:can?).and_call_original

        if action == :download_file
          expect_next_found_instance_of(::VirtualRegistries::Container::Cache::Remote::Entry) do |expected_cache_entry|
            expect(expected_cache_entry).to receive(:bump_downloads_count)
          end
        end

        expect { execute }
          .to trigger_internal_events('pull_container_file_through_virtual_registry')
          .with(**event_data[:args])
          .and increment_usage_metrics(event_data[:metric_key])

        is_expected.to be_success.and have_attributes(payload: a_hash_including(action:))

        case action
        when :workhorse_upload_url
          expect(execute[:action_params]).to eq(
            url: upstream_resource_url,
            upstream: upstream
          )
        when :download_file
          expect(execute[:action_params]).to include(
            file: an_instance_of(VirtualRegistries::Cache::EntryUploader),
            content_type: an_instance_of(String),
            file_sha1: an_instance_of(String)
          )
        end
      end

      def event_data_from(action)
        event_label = action == :workhorse_upload_url ? 'from_upstream' : 'from_cache'
        metric_key = "counts.count_total_pull_container_file_through_virtual_registry_#{event_label}"

        args = { namespace: registry.group, additional_properties: { label: event_label } }
        args[:user] = user if user.is_a?(User)

        { args:, metric_key: }
      end
    end

    context 'with an existing cache entry' do
      let_it_be(:upstream_etag) { 'sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd' }
      let_it_be(:expected_relative_path) { '/my/image/manifests/latest' }
      let_it_be(:upstream_resource_url) { upstream.url_for(path) }
      let_it_be(:path) { "my/image/manifests/#{upstream_etag}" }
      let_it_be(:cache_entry) do
        create(:virtual_registries_container_cache_remote_entry,
          :upstream_checked,
          upstream: upstream,
          relative_path: '/my/image/manifests/latest',
          upstream_etag: upstream_etag,
          digest: upstream_etag
        )
      end

      context 'when requesting manifest by digest' do
        it_behaves_like 'returning a service response success response', action: :download_file
      end

      context 'when requesting a blob by digest' do
        let_it_be(:path) { "my/image/blobs/#{upstream_etag}" }

        it_behaves_like 'returning a service response success response', action: :download_file
      end
    end

    context 'with cross-image deduplication' do
      let_it_be(:shared_digest) { 'sha256:aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344' }
      let_it_be(:cache_entry) do
        create(:virtual_registries_container_cache_remote_entry,
          :upstream_checked,
          upstream: upstream,
          relative_path: "/library/alpine/blobs/#{shared_digest}",
          upstream_etag: shared_digest,
          digest: shared_digest
        )
      end

      let(:path) { "library/python/blobs/#{shared_digest}" }
      let(:upstream_resource_url) { upstream.url_for(path) }

      before do
        stub_external_registry_request
      end

      it 'finds the cache entry by digest regardless of image path' do
        expect_next_found_instance_of(::VirtualRegistries::Container::Cache::Remote::Entry) do |expected_cache_entry|
          expect(expected_cache_entry).to receive(:bump_downloads_count)
        end

        expect(execute).to be_success.and have_attributes(payload: a_hash_including(action: :download_file))
      end
    end

    context 'with digest-addressed request skipping etag revalidation' do
      let_it_be(:digest) { 'sha256:aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344' }
      let(:path) { "my/image/manifests/#{digest}" }
      let(:upstream_resource_url) { upstream.url_for(path) }

      context 'with a stale cache entry' do
        let!(:cache_entry) do
          create(:virtual_registries_container_cache_remote_entry,
            upstream: upstream,
            relative_path: "/library/alpine/manifests/#{digest}",
            upstream_etag: 'some-etag',
            digest: digest,
            upstream_checked_at: 1.year.ago
          )
        end

        it 'does not make a HEAD request and re-fetches from upstream' do
          stub_external_registry_request

          expect(execute).to be_success.and have_attributes(
            payload: a_hash_including(action: :workhorse_upload_url)
          )
        end
      end

      context 'with a fresh cache entry' do
        let!(:cache_entry) do
          create(:virtual_registries_container_cache_remote_entry,
            :upstream_checked,
            upstream: upstream,
            relative_path: "/library/alpine/manifests/#{digest}",
            upstream_etag: 'some-etag',
            digest: digest
          )
        end

        it 'serves from cache without making a HEAD request to upstream' do
          expect(::Gitlab::HTTP).not_to receive(:head)

          expect_next_found_instance_of(::VirtualRegistries::Container::Cache::Remote::Entry) do |entry|
            expect(entry).to receive(:bump_downloads_count)
          end

          expect(execute).to be_success.and have_attributes(
            payload: a_hash_including(action: :download_file)
          )
        end
      end
    end

    context 'with a User' do
      shared_examples 'container request tests' do
        let(:processing_cache_entry) do
          create(
            :virtual_registries_container_cache_remote_entry,
            :upstream_checked,
            :processing,
            relative_path: expected_relative_path,
            upstream: upstream
          )
        end

        context 'with no cache entry' do
          it_behaves_like 'returning a service response success response', action: :workhorse_upload_url

          context 'with upstream returning an error' do
            let(:expected_response) do
              ::VirtualRegistries::Upstreams::CheckBaseService::ERRORS[:file_not_found_on_upstreams]
            end

            before do
              stub_external_registry_request(status: 404)
            end

            it { is_expected.to eq(expected_response) }
          end

          context 'with upstream head raising an error' do
            before do
              stub_external_registry_request(raise_error: true)
            end

            it { is_expected.to eq(described_class::ERRORS[:upstream_not_available]) }
          end
        end

        context 'with a cache entry' do
          let!(:cache_entry) do
            create(:virtual_registries_container_cache_remote_entry,
              :upstream_checked,
              upstream: upstream,
              relative_path: expected_relative_path
            )
          end

          it_behaves_like 'returning a service response success response', action: :download_file

          context 'and is too old' do
            before do
              cache_entry.update!(upstream_checked_at: 1.year.ago)
            end

            context 'with the same etag as upstream' do
              let(:etag_returned_by_upstream) { cache_entry.upstream_etag }

              it_behaves_like 'returning a service response success response', action: :download_file

              it 'bumps the statistics', :freeze_time do
                stub_external_registry_request(etag: etag_returned_by_upstream)

                expect { execute }.to change { cache_entry.reload.upstream_checked_at }.to(Time.zone.now)
              end
            end

            context 'with a different etag as upstream' do
              let(:etag_returned_by_upstream) { "#{cache_entry.upstream_etag}_test" }

              it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
            end

            context 'with a stored blank etag' do
              before do
                cache_entry.update!(upstream_etag: nil)
              end

              it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
            end

            context 'when the revalidation head hits a redirect loop' do
              before do
                stub_request(:head, upstream_resource_url)
                  .to_return(status: 307, headers: { 'Location' => upstream_resource_url })
              end

              it 'serves the stale cache entry rather than turning the loop into a miss' do
                expect(execute).to be_success.and have_attributes(
                  payload: a_hash_including(action: :download_file)
                )
              end
            end
          end

          context 'with upstream head raising an error' do
            before do
              stub_external_registry_request(raise_error: true)
            end

            it_behaves_like 'returning a service response success response', action: :download_file
          end

          context 'with a cached permissions evaluation' do
            before do
              stub_external_registry_request
              Rails.cache.fetch(service.send(:permissions_cache_key)) do
                can?(user, :read_virtual_registry, registry)
              end
            end

            it 'does not call the permissions evaluation again', :aggregate_failures do
              expect(service).not_to receive(:can)
              expect(execute).to be_success
            end
          end
        end
      end

      context 'when requesting a manifest' do
        let(:path) { 'my/image/manifests/latest' }
        let(:expected_image_name) { 'my/image' }
        let(:expected_relative_path) { '/my/image/manifests/latest' }
        let(:upstream_resource_url) { upstream.url_for(path) }

        it_behaves_like 'container request tests'

        context 'when requesting by digest' do
          let(:path) { 'my/image/manifests/sha256:abc123' }
          let(:expected_relative_path) { '/my/image/manifests/sha256:abc123' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end

        context 'with nested image name' do
          let(:path) { 'library/nginx/app/manifests/v1.0' }
          let(:expected_image_name) { 'library/nginx/app' }
          let(:expected_relative_path) { '/library/nginx/app/manifests/v1.0' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end
      end

      context 'when requesting a blob' do
        let(:path) { 'my/image/blobs/sha256:def456' }
        let(:expected_image_name) { 'my/image' }
        let(:expected_relative_path) { '/my/image/blobs/sha256:def456' }
        let(:upstream_resource_url) { upstream.url_for(path) }

        it_behaves_like 'container request tests'

        context 'with nested image name' do
          let(:path) { 'library/nginx/app/blobs/sha256:ghi789' }
          let(:expected_image_name) { 'library/nginx/app' }
          let(:expected_relative_path) { '/library/nginx/app/blobs/sha256:ghi789' }
          let(:upstream_resource_url) { upstream.url_for(path) }

          it_behaves_like 'container request tests'
        end
      end
    end

    context 'when a stale cache entry revalidation redirects to a different host' do
      let(:path) { 'my/image/manifests/latest' }
      let(:upstream_resource_url) { upstream.url_for(path) }
      let(:redirect_url) { 'https://blobs.example.org/signed/path?sig=xyz' }

      let_it_be_with_reload(:cache_entry) do
        create(:virtual_registries_container_cache_remote_entry,
          :upstream_checked,
          upstream: upstream,
          relative_path: '/my/image/manifests/latest',
          upstream_checked_at: 1.year.ago
        )
      end

      before do
        stub_request(:head, upstream_resource_url).to_return(
          status: 401,
          headers: {
            'www-authenticate' =>
              'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:my/image:pull"'
          }
        ).times(1)

        stub_request(:get, %r{auth\.example\.com/token}).to_return(
          status: 200,
          body: { token: 'fake-bearer-token' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

        stub_request(:head, upstream_resource_url)
          .with(headers: { 'Authorization' => 'Bearer fake-bearer-token' }
            .merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS))
          .to_return(status: 307, headers: { 'Location' => redirect_url })

        stub_request(:head, redirect_url).to_return(status: 200, headers: { 'etag' => cache_entry.upstream_etag })
      end

      it_behaves_like 'a credential-safe cross-host redirect'
    end

    context 'with a DeployToken' do
      let_it_be(:user) { create(:deploy_token, :group, groups: [registry.group], read_virtual_registry: true) }

      let(:path) { 'my/image/manifests/latest' }
      let(:expected_image_name) { 'my/image' }
      let(:expected_relative_path) { '/my/image/manifests/latest' }
      let(:upstream_resource_url) { upstream.url_for(path) }

      it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
    end

    context 'with no path' do
      let(:path) { nil }

      it { is_expected.to eq(described_class::ERRORS[:path_not_present]) }
    end

    context 'with no user' do
      let(:user) { nil }
      let(:path) { 'my/image/manifests/latest' }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end

    context 'with registry with no upstreams' do
      let(:path) { 'my/image/manifests/latest' }

      before do
        registry.upstreams = []
      end

      it { is_expected.to eq(described_class::ERRORS[:no_upstreams]) }
    end

    def stub_external_registry_request(status: 200, raise_error: false, etag: nil)
      if raise_error
        stub_request(:head, upstream_resource_url).to_raise(Gitlab::HTTP::BlockedUrlError)
        return
      end

      stub_request(:head, upstream_resource_url).to_return(
        status: 401,
        body: '',
        headers: {
          'www-authenticate' => 'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:library/nginx:pull"'
        }
      ).times(1)

      # Second, stub the token exchange request
      stub_request(:get, %r{auth\.example\.com/token})
        .to_return(
          status: 200,
          body: { token: 'fake-bearer-token' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Finally, stub the actual HEAD request with bearer token
      stub_request(:head, upstream_resource_url)
        .with(
          headers: { 'Authorization' => 'Bearer fake-bearer-token' }
          .merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS)
        ).to_return(status: status, body: '', headers: { 'etag' => etag }.compact)
    end
  end
end
