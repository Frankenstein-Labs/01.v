# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::HandleFileRequestService, :aggregate_failures, :clean_gitlab_redis_shared_state, feature_category: :virtual_registry do
  let_it_be(:registry) { create(:virtual_registries_packages_npm_registry, :with_upstreams) }
  let_it_be(:project) { create(:project, namespace: registry.group) }
  let_it_be(:user) { create(:user, owner_of: registry.group) }
  let_it_be(:path) { 'pkg/-/pkg-1.0.0.tgz' }
  let_it_be(:upstream) { registry.upstreams.first }
  let_it_be(:upstream_resource_url) { upstream.url_for(path) }

  let(:etag_returned_by_upstream) { nil }
  let(:if_none_match) { nil }
  let(:service) { described_class.new(registry: registry, current_user: user, params: { path: path }) }

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returning a service response success response' do |action:|
      before do
        stub_external_registry_request(
          etag: etag_returned_by_upstream,
          if_none_match: if_none_match
        )
      end

      it 'returns a success service response' do
        event_data = event_data_from(action)
        expect(service).to receive(:can?).and_call_original

        if action == :download_file
          expect_next_found_instance_of(::VirtualRegistries::Packages::Npm::Cache::Remote::Entry) do |entry|
            expect(entry).to receive(:bump_downloads_count)
          end
        end

        expect { execute }
          .to trigger_internal_events('pull_npm_package_file_through_virtual_registry')
          .with(**event_data[:args])
          .and increment_usage_metrics(event_data[:metric_key])

        expect(execute).to be_success
        expect(execute.payload[:action]).to eq(action)

        case action
        when :workhorse_upload_url
          expect(execute.payload[:action_params]).to eq(url: upstream_resource_url, upstream: upstream)
        when :download_file
          action_params = execute.payload[:action_params]
          expect(action_params[:file]).to be_instance_of(VirtualRegistries::Cache::EntryUploader)
          expect(action_params[:content_type]).to eq(cache_entry.content_type)
          expect(action_params[:file_sha1]).to be_instance_of(String)
          expect(action_params[:file_md5]).to be_instance_of(String)
        end
      end

      def event_data_from(action)
        if action == :workhorse_upload_url
          event_label = 'from_upstream'
          metric_key = 'counts.count_total_pull_npm_package_file_through_virtual_registry_from_upstream'
        else
          event_label = 'from_cache'
          metric_key = 'counts.count_total_pull_npm_package_file_through_virtual_registry_from_cache'
        end

        args = { namespace: registry.group, additional_properties: { label: event_label } }
        args[:user] = user if user.is_a?(User)

        { args:, metric_key: }
      end
    end

    context 'with a User' do
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

        context 'with check_registry_upstreams raising an HTTP error' do
          before do
            allow(service).to receive(:check_registry_upstreams).and_raise(Gitlab::HTTP::BlockedUrlError)
          end

          it { is_expected.to eq(described_class::ERRORS[:upstream_not_available]) }
        end
      end

      context 'with a cache entry' do
        let(:fresh_cache_entry) do
          create(:virtual_registries_packages_npm_cache_remote_entry,
            :upstream_checked,
            upstream: upstream,
            relative_path: "/#{path}",
            group: registry.group
          )
        end

        let(:cache_entry) { fresh_cache_entry }

        before do
          cache_entry
        end

        it_behaves_like 'returning a service response success response', action: :download_file

        context 'and is too old' do
          let(:stale_cache_entry) do
            create(:virtual_registries_packages_npm_cache_remote_entry,
              :upstream_checked,
              upstream: upstream,
              relative_path: "/#{path}",
              upstream_checked_at: 1.year.ago,
              group: registry.group
            )
          end

          let(:cache_entry) { stale_cache_entry }

          context 'with HEAD returning 304 Not Modified' do
            let(:etag_returned_by_upstream) { cache_entry.upstream_etag }
            let(:if_none_match) { cache_entry.upstream_etag }

            before do
              stub_external_registry_request(
                status: 304,
                etag: etag_returned_by_upstream,
                if_none_match: if_none_match
              )
            end

            it 'returns a download_file response' do
              expect(execute).to be_success
              expect(execute.payload[:action]).to eq(:download_file)
            end

            it 'bumps the statistics', :freeze_time do
              expect { execute }.to change { cache_entry.reload.upstream_checked_at }.to(Time.zone.now)
            end
          end

          context 'with the same etag as upstream' do
            let(:etag_returned_by_upstream) { cache_entry.upstream_etag }
            let(:if_none_match) { cache_entry.upstream_etag }

            it_behaves_like 'returning a service response success response', action: :download_file

            it 'bumps the statistics', :freeze_time do
              stub_external_registry_request(
                etag: etag_returned_by_upstream,
                if_none_match: if_none_match
              )

              expect { execute }.to change { cache_entry.reload.upstream_checked_at }.to(Time.zone.now)
            end
          end

          context 'with a different etag as upstream' do
            let(:etag_returned_by_upstream) { "#{cache_entry.upstream_etag}_test" }
            let(:if_none_match) { cache_entry.upstream_etag }

            it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
          end

          context 'with HEAD returning an error status' do
            before do
              stub_request(:head, upstream_resource_url)
                .to_return(
                  { status: 500, body: '', headers: {} },
                  { status: 200, body: '', headers: {} }
                )
            end

            it 'falls through to check registry upstreams' do
              expect(execute).to be_success
              expect(execute.payload[:action]).to eq(:workhorse_upload_url)
            end
          end

          context 'with HEAD raising an HTTP error' do
            before do
              stub_external_registry_request(raise_error: true)
            end

            it 'falls back to the cached file' do
              expect(execute).to be_success
              expect(execute.payload[:action]).to eq(:download_file)
            end
          end

          context 'with a stored blank etag' do
            let(:stale_cache_entry_without_etag) do
              create(:virtual_registries_packages_npm_cache_remote_entry,
                :upstream_checked,
                upstream: upstream,
                relative_path: "/#{path}",
                upstream_checked_at: 1.year.ago,
                upstream_etag: nil,
                group: registry.group
              )
            end

            let(:cache_entry) { stale_cache_entry_without_etag }

            it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
          end

          context 'when the upstream redirects to a different host' do
            let(:redirect_url) { 'https://blobs.example.org/signed/path?sig=xyz' }

            before do
              stub_request(:head, upstream_resource_url)
                .to_return(status: 307, headers: { 'Location' => redirect_url })

              stub_request(:head, redirect_url)
                .to_return(status: 200, headers: { 'etag' => cache_entry.upstream_etag })
            end

            it_behaves_like 'a credential-safe cross-host redirect'
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
            Rails.cache.fetch(service.send(:permissions_cache_key)) do
              can?(user, :read_virtual_registry, registry)
            end
          end

          it 'does not call the permissions evaluation again' do
            expect(service).not_to receive(:can).and_call_original
            expect(execute).to be_success
          end
        end
      end
    end

    context 'with a DeployToken' do
      let_it_be(:user) { create(:deploy_token, :group, groups: [registry.group], read_virtual_registry: true) }

      it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
    end

    context 'with no path' do
      let(:path) { nil }

      it { is_expected.to eq(described_class::ERRORS[:path_not_present]) }
    end

    context 'with no user' do
      let(:user) { nil }

      it { is_expected.to eq(described_class::ERRORS[:unauthorized]) }
    end

    context 'with registry with no upstreams' do
      let_it_be(:registry_without_upstreams) do
        create(:virtual_registries_packages_npm_registry, group: registry.group)
      end

      let(:service) do
        described_class.new(registry: registry_without_upstreams, current_user: user, params: { path: path })
      end

      it { is_expected.to eq(described_class::ERRORS[:no_upstreams]) }
    end

    def stub_external_registry_request(status: 200, raise_error: false, etag: nil, if_none_match: nil)
      headers = upstream.headers

      if raise_error
        stub_request(:head, upstream_resource_url)
          .to_raise(Gitlab::HTTP::BlockedUrlError)
        return
      end

      response = { status: status, body: '', headers: { 'etag' => etag }.compact }

      # Always register a base stub matching auth headers only.
      # This covers CheckService requests (which don't send If-None-Match).
      stub_request(:head, upstream_resource_url)
        .with(headers: headers.compact)
        .to_return(response)

      # When if_none_match is set, register a more specific stub that also
      # requires the If-None-Match header. WebMock checks stubs in reverse
      # order, so this (registered last) is checked first for head_upstream
      # requests that include the header.
      return unless if_none_match.present?

      stub_request(:head, upstream_resource_url)
        .with(headers: headers.merge('If-None-Match' => if_none_match).compact)
        .to_return(response)
    end
  end
end
