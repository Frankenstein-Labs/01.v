# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::HandleFileRequestService, :aggregate_failures, :clean_gitlab_redis_shared_state, feature_category: :virtual_registry do
  let_it_be_with_reload(:registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams) }
  let_it_be(:project) { create(:project, namespace: registry.group) }
  let_it_be(:user) { create(:user, owner_of: registry.group) }
  let_it_be(:upstream) { registry.upstreams.first }
  let_it_be(:path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
  let_it_be(:upstream_resource_url) { upstream.url_for(path) }

  let(:etag_returned_by_upstream) { nil }
  let(:service) { described_class.new(registry: registry, current_user: user, params: { path: }) }

  before do
    registry.clear_memoization(:all_upstreams)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_context 'for local upstreams' do
      let_it_be(:package_name) { 'my/company/app/my-app' }
      let_it_be(:package_version) { '1.2.3' }
      let_it_be(:filename) { 'maven-metadata.xml' }
      let_it_be(:path) { "#{package_name}/#{package_version}/#{filename}" }
      let_it_be(:upstream_resource_url) { upstream.url_for(path) }

      let_it_be(:package_project) { create(:project, namespace: registry.group) }
      let_it_be(:package_file) do
        create(:maven_package, name: package_name, version: package_version, project: package_project)
          .package_files.find { |pf| pf.file_name == filename }
      end

      before do
        stub_external_registry_request(status: 404)
      end
    end

    shared_examples 'returning a FIPS unsupported md5 error' do
      context 'in FIPS mode', :fips_mode do
        it { is_expected.to eq(described_class::ERRORS[:fips_unsupported_md5]) }
      end
    end

    shared_examples 'returning a service response success response' do |action:, remote: true|
      if remote && action.in?(%i[download_file download_digest])
        it 'bumps the download count' do
          cache_entry_class = ::VirtualRegistries::Packages::Maven::Cache::Remote::Entry
          expect_next_found_instance_of(cache_entry_class) do |expected_cache_entry|
            expect(expected_cache_entry).to receive(:bump_downloads_count)
          end

          execute
        end
      end

      it 'returns a success service response' do
        event_data = event_data_from(action)
        expect(service).to receive(:can?).and_call_original

        expect { execute }
          .to trigger_internal_events('pull_maven_package_file_through_virtual_registry')
          .with(**event_data[:args])
          .and increment_usage_metrics(event_data[:metric_key])

        expect(execute).to be_success
        expect(execute.payload[:action]).to eq(action)

        case action
        when :workhorse_upload_url
          expect(execute.payload[:action_params]).to eq(url: upstream_resource_url, upstream: upstream)
        when :download_file
          action_params = execute.payload[:action_params]
          if remote
            expect(action_params[:file]).to be_instance_of(VirtualRegistries::Cache::EntryUploader)
            expect(action_params[:content_type]).to eq(cache_entry.content_type)
          else
            expect(action_params[:file]).to be_instance_of(Packages::PackageFileUploader)
            expect(action_params[:content_type]).to be_present
          end

          expect(action_params[:file_sha1]).to be_instance_of(String)
          expect(action_params[:file_md5]).to be_instance_of(String)
        when :download_digest
          expect(execute.payload[:action_params]).to eq(digest: expected_digest)
        when :workhorse_send_url
          expect(execute.payload[:action_params]).to eq(url: upstream_digest_url)
        end
      end

      def event_data_from(action)
        if action == :workhorse_upload_url || action == :workhorse_send_url
          event_label = 'from_upstream'
          metric_key = 'counts.count_total_pull_maven_package_file_through_virtual_registry_from_upstream'
        else
          event_label = 'from_cache'
          metric_key = 'counts.count_total_pull_maven_package_file_through_virtual_registry_from_cache'
        end

        args = { namespace: registry.group, additional_properties: { label: event_label } }
        args[:user] = user if user.is_a?(User)

        { args:, metric_key: }
      end
    end

    before do
      stub_external_registry_request(etag: etag_returned_by_upstream)
    end

    context 'with a User' do
      let_it_be(:processing_cache_entry) do
        create(
          :virtual_registries_packages_maven_cache_remote_entry,
          :upstream_checked,
          :processing,
          relative_path: "/#{path}",
          upstream: upstream,
          group: registry.group
        )
      end

      context 'with no cache entry' do
        context 'when remote upstream matches' do
          it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
        end

        context 'for upstream filtering' do
          let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

          before do
            allow(::VirtualRegistries::Upstreams::CheckService).to receive(:new).and_call_original
          end

          context 'when no upstreams are filtered out' do
            before do
              stub_external_registry_request
            end

            it 'does not log any filtration audit events' do
              expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
                hash_including(name: 'virtual_registries_packages_maven_upstream_artifact_denied')
              )

              execute
            end
          end

          context 'when the filtration service returns an error' do
            before do
              allow_next_instance_of(
                VirtualRegistries::Packages::Maven::Upstreams::FiltrationService
              ) do |svc|
                allow(svc).to receive(:execute)
                  .and_return(ServiceResponse.error(message: 'filtration error'))
              end
            end

            it 'returns the filtration error' do
              expect(execute).to be_error
              expect(execute.message).to eq('filtration error')
            end
          end

          context 'when all upstreams are filtered out' do
            before do
              [upstream, other_upstream].each do |u|
                create(:virtual_registries_packages_maven_upstream_rule,
                  :group_id,
                  :wildcard,
                  :deny,
                  pattern: 'com.test',
                  remote_upstream: u)
              end
            end

            it 'checks no upstreams' do
              is_expected.to eq(described_class::ERRORS[:all_upstreams_denied])
              expect(::VirtualRegistries::Upstreams::CheckService).not_to have_received(:new)
            end

            it 'logs an audit event for each denied upstream' do
              expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
                hash_including(
                  name: 'virtual_registries_packages_maven_upstream_artifact_denied',
                  author: user,
                  scope: registry.group,
                  target: upstream,
                  target_details: upstream.url_for(path),
                  message: 'Blocked package request - View matching patterns'
                )
              )

              expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
                hash_including(
                  name: 'virtual_registries_packages_maven_upstream_artifact_denied',
                  author: user,
                  scope: registry.group,
                  target: other_upstream,
                  target_details: other_upstream.url_for(path),
                  message: 'Blocked package request - View matching patterns'
                )
              )

              execute
            end

            context 'when audit raises an error' do
              before do
                allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(StandardError, 'audit error')
              end

              it 'tracks the exception and does not halt the service' do
                expect(Gitlab::ErrorTracking).to receive(:track_exception)
                  .with(instance_of(StandardError), hash_including(:name, :scope, :target))
                  .twice

                expect(execute).to eq(described_class::ERRORS[:all_upstreams_denied])
              end
            end
          end

          context 'when some upstreams are filtered out' do
            let(:upstream_resource_url) { other_upstream.url_for(path) }

            before do
              stub_external_registry_request

              create(:virtual_registries_packages_maven_upstream_rule,
                :group_id,
                :wildcard,
                :deny,
                pattern: 'com.test',
                remote_upstream: upstream)
            end

            it 'only checks allowed upstreams' do
              expect(execute).to be_success
              expect(execute[:action]).to eq(:workhorse_upload_url)
              expect(execute[:action_params][:upstream]).to eq(other_upstream)

              expect(::VirtualRegistries::Upstreams::CheckService).to have_received(:new)
                .with(upstreams: [other_upstream], params: { path: path })
            end

            it 'logs an audit event only for the denied upstream' do
              expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
                hash_including(
                  name: 'virtual_registries_packages_maven_upstream_artifact_denied',
                  author: user,
                  scope: registry.group,
                  target: upstream,
                  target_details: upstream.url_for(path),
                  message: 'Blocked package request - View matching patterns'
                )
              )

              execute
            end

            context 'when filtered upstreams do not have the file' do
              let(:expected_response) do
                ::VirtualRegistries::Upstreams::CheckBaseService::ERRORS[:file_not_found_on_upstreams]
              end

              before do
                stub_external_registry_request(status: 404)
              end

              it 'returns file not found error' do
                is_expected.to eq(expected_response)
                expect(::VirtualRegistries::Upstreams::CheckService).to have_received(:new)
                  .with(upstreams: [other_upstream], params: { path: path })
              end
            end
          end
        end

        context 'with remote upstream returning an error' do
          let(:expected_response) do
            ::VirtualRegistries::Upstreams::CheckBaseService::ERRORS[:file_not_found_on_upstreams]
          end

          before do
            stub_external_registry_request(status: 404)
          end

          it { is_expected.to eq(expected_response) }
        end

        context 'with remote upstream head raising an error' do
          before do
            stub_external_registry_request(raise_error: true)
          end

          it { is_expected.to eq(described_class::ERRORS[:upstream_not_available]) }
        end

        context 'for local upstreams' do
          include_context 'for local upstreams'

          context 'when a local project upstream matches' do
            let_it_be(:local_upstream) do
              create(
                :virtual_registries_packages_maven_local_upstream,
                registries: [registry],
                local_project: package_project,
                group: registry.group
              )
            end

            it_behaves_like 'returning a service response success response', action: :download_file, remote: false

            it 'queues background job to create cache local entry' do
              expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
                .to receive(:perform_async).with(local_upstream.id, package_file.id.to_s, "/#{path}")

              execute
            end
          end

          context 'when a local group upstream matches' do
            let_it_be(:local_upstream) do
              create(
                :virtual_registries_packages_maven_local_upstream,
                :local_group,
                registries: [registry],
                local_group: package_project.namespace,
                group: registry.group
              )
            end

            it_behaves_like 'returning a service response success response', action: :download_file, remote: false

            it 'queues background job to create cache local entry' do
              expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
                .to receive(:perform_async).with(local_upstream.id, package_file.id.to_s, "/#{path}")

              execute
            end
          end
        end

        context 'with only local upstreams' do
          let_it_be(:local_only_registry) do
            create(:virtual_registries_packages_maven_registry, group: registry.group)
          end

          let_it_be(:package_project) { create(:project, namespace: registry.group) }
          let_it_be(:local_upstream) do
            create(
              :virtual_registries_packages_maven_local_upstream,
              registries: [local_only_registry],
              local_project: package_project,
              group: registry.group
            )
          end

          let_it_be(:package_name) { 'my/company/app/my-app' }
          let_it_be(:package_version) { '1.2.3' }
          let_it_be(:filename) { 'maven-metadata.xml' }
          let_it_be(:path) { "#{package_name}/#{package_version}/#{filename}" }

          let_it_be(:package_file) do
            create(:maven_package, name: package_name, version: package_version, project: package_project)
              .package_files.find { |pf| pf.file_name == filename }
          end

          let(:service) do
            described_class.new(registry: local_only_registry, current_user: user, params: { path: })
          end

          it 'skips filtration, returns success and queues a cache local entry job' do
            expect(VirtualRegistries::Packages::Maven::Upstreams::FiltrationService).not_to receive(:new)
            expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
              .to receive(:perform_async).with(local_upstream.id, package_file.id.to_s, "/#{path}")

            expect(execute).to be_success
            expect(execute.payload[:action]).to eq(:download_file)
          end
        end

        %i[md5 sha1].each do |digest_format|
          context "when accessing the #{digest_format} digest" do
            context 'when remote upstream matches' do
              let(:non_digest_path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
              let(:path) { "#{non_digest_path}.#{digest_format}" }
              let(:upstream_digest_url) { "#{upstream_resource_url}.#{digest_format}" }
              let(:expected_digest) { cache_entry["file_#{digest_format}"] }

              it_behaves_like 'returning a service response success response', action: :workhorse_send_url

              it 'queues background job to create cache entry' do
                expect(VirtualRegistries::Packages::Maven::CreateCacheEntryWorker).to receive(:perform_async)
                  .with(upstream.id, non_digest_path)

                execute
              end

              it_behaves_like 'returning a FIPS unsupported md5 error' if digest_format == :md5
            end

            context 'when no upstream has the file' do
              let(:non_digest_path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
              let(:path) { "#{non_digest_path}.#{digest_format}" }
              let(:expected_response) do
                ::VirtualRegistries::Upstreams::CheckBaseService::ERRORS[:file_not_found_on_upstreams]
              end

              before do
                stub_external_registry_request(status: 404)
              end

              it { is_expected.to eq(expected_response) }
            end

            context 'for local upstreams' do
              include_context 'for local upstreams'

              let(:non_digest_path) { "#{package_name}/#{package_version}/#{filename}" }
              let(:path) { "#{non_digest_path}.#{digest_format}" }
              let(:upstream_resource_url) { upstream.url_for(non_digest_path) }
              let(:expected_digest) { package_file["file_#{digest_format}"] }

              context 'when a local project upstream matches' do
                let_it_be(:local_upstream) do
                  create(
                    :virtual_registries_packages_maven_local_upstream,
                    registries: [registry],
                    local_project: package_project,
                    group: registry.group
                  )
                end

                it_behaves_like 'returning a service response success response', action: :download_digest, remote: false

                it 'queues background job to create cache local entry' do
                  expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
                    .to receive(:perform_async).with(local_upstream.id, package_file.id.to_s, "/#{non_digest_path}")

                  execute
                end

                it_behaves_like 'returning a FIPS unsupported md5 error' if digest_format == :md5
              end

              context 'when a local group upstream matches' do
                let_it_be(:local_upstream) do
                  create(
                    :virtual_registries_packages_maven_local_upstream,
                    :local_group,
                    registries: [registry],
                    local_group: package_project.namespace,
                    group: registry.group
                  )
                end

                it_behaves_like 'returning a service response success response', action: :download_digest, remote: false

                it 'queues background job to create cache entry' do
                  expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
                    .to receive(:perform_async).with(local_upstream.id, package_file.id.to_s, "/#{non_digest_path}")

                  execute
                end

                it_behaves_like 'returning a FIPS unsupported md5 error' if digest_format == :md5
              end
            end
          end
        end
      end

      context 'with a cache entry' do
        let_it_be_with_reload(:cache_entry) do
          create(:virtual_registries_packages_maven_cache_remote_entry,
            :upstream_checked,
            upstream: upstream,
            relative_path: "/#{path}",
            group: registry.group
          )
        end

        context 'when remote' do
          it_behaves_like 'returning a service response success response', action: :download_file

          it 'does not invoke filtration service' do
            expect(VirtualRegistries::Packages::Maven::Upstreams::FiltrationService).not_to receive(:new)

            execute
          end

          context 'and is too old' do
            before do
              cache_entry.update!(upstream_checked_at: 1.year.ago)
            end

            context 'with the same etag as upstream' do
              let(:etag_returned_by_upstream) { cache_entry.upstream_etag }

              it_behaves_like 'returning a service response success response', action: :download_file

              it 'bumps the statistics', :freeze_time do
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

            context 'when the upstream redirects to a different host' do
              let(:redirect_url) { 'https://blobs.example.org/signed/path?sig=xyz' }
              let(:etag_returned_by_upstream) { cache_entry.upstream_etag }

              before do
                stub_request(:head, upstream_resource_url)
                  .with(headers: upstream.headers)
                  .to_return(status: 307, headers: { 'Location' => redirect_url })

                stub_request(:head, redirect_url)
                  .to_return(status: 200, headers: { 'etag' => etag_returned_by_upstream })
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
        end

        context 'when local' do
          include_context 'for local upstreams'

          let_it_be(:local_upstream) do
            create(
              :virtual_registries_packages_maven_local_upstream,
              registries: [registry],
              local_project: package_project,
              group: registry.group
            )
          end

          let_it_be_with_reload(:cache_entry) do
            create(:virtual_registries_packages_maven_cache_local_entry,
              group: registry.group,
              upstream: local_upstream,
              relative_path: "/#{path}",
              package_file: package_file
            )
          end

          it_behaves_like 'returning a service response success response', action: :download_file, remote: false

          context 'and is too old' do
            before do
              cache_entry.update!(upstream_checked_at: 1.year.ago)
            end

            context 'with the same package file' do
              it_behaves_like 'returning a service response success response', action: :download_file, remote: false

              it 'updates upstream_checked_at', :freeze_time do
                expect { execute }.to change { cache_entry.reload.upstream_checked_at }.to(Time.zone.now)
              end
            end

            context 'when the local upstream check fails' do
              before do
                allow(service).to receive(:check_local_upstream)
                  .and_return(ServiceResponse.error(message: 'file not found'))
                stub_external_registry_request
              end

              it_behaves_like 'returning a service response success response', action: :workhorse_upload_url
            end

            context 'with a newer package file' do
              let_it_be(:other_package_file) do
                create(:package_file, :xml, package: package_file.package, project: package_file.project)
              end

              it_behaves_like 'returning a service response success response', action: :download_file, remote: false

              it 'queues background job to create cache local entry' do
                expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker)
                  .to receive(:perform_async).with(local_upstream.id, other_package_file.id.to_s, "/#{path}")

                execute
              end
            end
          end
        end

        %i[md5 sha1].each do |digest_format|
          context "when accessing the #{digest_format} digest" do
            context 'when remote cache entry matches' do
              let(:non_digest_path) { 'com/test/package/1.2.3/package-1.2.3.pom' }
              let(:path) { "#{non_digest_path}.#{digest_format}" }
              let(:upstream_digest_url) { "#{upstream_resource_url}.#{digest_format}" }
              let(:expected_digest) { cache_entry["file_#{digest_format}"] }

              it_behaves_like 'returning a service response success response', action: :download_digest

              it_behaves_like 'returning a FIPS unsupported md5 error' if digest_format == :md5
            end

            context 'for local upstreams' do
              include_context 'for local upstreams'

              let_it_be(:non_digest_path) { "#{package_name}/#{package_version}/#{filename}" }
              let_it_be(:path) { "#{non_digest_path}.#{digest_format}" }
              let_it_be(:local_upstream) do
                create(
                  :virtual_registries_packages_maven_local_upstream,
                  registries: [registry],
                  local_project: package_project,
                  group: registry.group
                )
              end

              let_it_be(:local_cache_entry) do
                create(:virtual_registries_packages_maven_cache_local_entry,
                  group: registry.group,
                  upstream: local_upstream,
                  relative_path: "/#{non_digest_path}",
                  package_file: package_file
                )
              end

              let(:upstream_resource_url) { upstream.url_for(non_digest_path) }
              let(:expected_digest) { package_file["file_#{digest_format}"] }

              it_behaves_like 'returning a service response success response', action: :download_digest, remote: false

              it_behaves_like 'returning a FIPS unsupported md5 error' if digest_format == :md5
            end
          end
        end
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
        create(:virtual_registries_packages_maven_registry, group: registry.group)
      end

      let(:service) do
        described_class.new(registry: registry_without_upstreams, current_user: user, params: { path: })
      end

      it { is_expected.to eq(described_class::ERRORS[:no_upstreams]) }
    end

    def stub_external_registry_request(status: 200, raise_error: false, etag: nil)
      request = stub_request(:head, upstream_resource_url)
        .with(headers: upstream.headers)

      if raise_error
        request.to_raise(Gitlab::HTTP::BlockedUrlError)
      else
        request.to_return(status: status, body: '', headers: { 'etag' => etag }.compact)
      end
    end
  end

  describe '#enqueue_create_cache_local_entry_job' do
    let(:service) { described_class.new(registry: registry, current_user: user, params: { path: }) }

    subject(:enqueue) { service.send(:enqueue_create_cache_local_entry_job, global_id) }

    before do
      allow(service).to receive_messages(upstream: upstream, relative_path: "/#{path}")
    end

    context 'with an invalid global id' do
      let(:global_id) { 'not-a-valid-global-id' }

      it 'does not enqueue the worker' do
        expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker).not_to receive(:perform_async)

        enqueue
      end
    end

    context 'with a global id for a different model' do
      let(:global_id) { create(:project).to_global_id.to_s }

      it 'does not enqueue the worker' do
        expect(::VirtualRegistries::Packages::Maven::Local::CreateCacheEntryWorker).not_to receive(:perform_async)

        enqueue
      end
    end
  end
end
