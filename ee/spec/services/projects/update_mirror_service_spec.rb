# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdateMirrorService, feature_category: :source_code_management do
  let(:lfs_enabled) { false }
  let(:project) do
    create(:project, :repository, :mirror, import_url: Project::UNKNOWN_IMPORT_URL, only_mirror_protected_branches: false)
  end

  let(:current_user) { project.first_owner }

  subject(:service) { described_class.new(project, current_user) }

  before do
    allow(project).to receive(:lfs_enabled?).and_return(lfs_enabled)
    stub_feature_flags(async_mirror_branch_creation: false)
  end

  describe "#execute" do
    context 'unlicensed' do
      before do
        stub_licensed_features(repository_mirrors: false)
      end

      it 'does nothing' do
        expect(project).not_to receive(:fetch_mirror)

        result = service.execute

        expect(result[:status]).to eq(:success)
      end
    end

    it "fetches the upstream repository" do
      stub_fetch_mirror(project)

      expect(project).to receive(:fetch_mirror)

      service.execute
    end

    it 'injects "pull-mirror-update" => true into the gitaly_context of every Gitaly call', :request_store, :aggregate_failures do
      service

      expect(Gitlab::GitalyClient).to receive(:request_kwargs).at_least(:once).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap do |result|
          expect(Gitlab::Json.parse(result.dig(:metadata, 'gitaly-client-context-bin'))).to include('pull-mirror-update' => true)
        end
      end

      service.execute
    end

    it 'runs project housekeeping' do
      stub_fetch_mirror(project)

      expect_next_instance_of(::Repositories::HousekeepingService) do |svc|
        expect(svc).to receive(:increment!)
        expect(svc).to receive(:needed?).and_return(true)
        expect(svc).to receive(:execute)
      end

      service.execute
    end

    it 'rescues exceptions from Repository#ff_merge' do
      stub_fetch_mirror(project)

      expect(project.repository).to receive(:ff_merge).and_raise(Gitlab::Git::PreReceiveError)

      expect { service.execute }.not_to raise_error
    end

    it "returns success when updated succeeds" do
      stub_fetch_mirror(project)

      result = service.execute

      expect(result[:status]).to eq(:success)
    end

    it "disables mirroring protected branches only by default" do
      new_project = create(:project, :repository, :mirror, import_url: Project::UNKNOWN_IMPORT_URL)

      expect(new_project.only_mirror_protected_branches).to be_falsey
    end

    context 'when mirror user is blocked' do
      before do
        project.mirror_user.block
      end

      it 'fails and returns error status' do
        expect(service.execute[:status]).to eq(:error)
      end
    end

    context "when the URL is blocked" do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'URL is blocked')

        stub_fetch_mirror(project)
      end

      it "fails and returns error status", :aggregate_failures do
        result = service.execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('The import URL is invalid')
      end
    end

    context 'when passing resolved_address to fetch_mirror' do
      let(:resolved_ip) { '93.184.216.34' }
      let(:import_url) { 'https://example.com/repo.git' }

      before do
        project.import_url = import_url

        # Mock validate! to return the validated URI with hostname replaced by IP.
        # In production, UrlBlocker.validate! replaces the hostname with the resolved IP
        # when dns_rebind_protection is enabled, and returns the original hostname
        # as the second element for SSL verification purposes.
        #
        validated_uri = Addressable::URI.parse(import_url)
        validated_uri.hostname = resolved_ip
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .and_return([validated_uri, 'example.com'])
      end

      it 'passes resolved_address to project.fetch_mirror' do
        expect(project).to receive(:fetch_mirror)
          .with(forced: true, resolved_address: resolved_ip)
          .and_return(Gitaly::FetchRemoteResponse.new)

        service.execute
      end

      context 'when import_url uses git protocol' do
        let(:import_url) { 'git://example.com/repo.git' }

        before do
          validated_uri = Addressable::URI.parse(import_url)
          validated_uri.hostname = resolved_ip
          allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
            .and_return([validated_uri, 'example.com'])
        end

        it 'passes resolved_address for git:// URLs' do
          expect(project).to receive(:fetch_mirror)
            .with(forced: true, resolved_address: resolved_ip)
            .and_return(Gitaly::FetchRemoteResponse.new)

          service.execute
        end
      end

      context 'when import_url uses SSH protocol' do
        let(:import_url) { 'ssh://git@example.com/repo.git' }

        before do
          validated_uri = Addressable::URI.parse(import_url)
          allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
            .and_return([validated_uri, resolved_ip])
        end

        it 'passes empty resolved_address for SSH URLs' do
          expect(project).to receive(:fetch_mirror)
            .with(forced: true, resolved_address: '')
            .and_return(Gitaly::FetchRemoteResponse.new)

          service.execute
        end
      end

      context 'when resolved_host is nil' do
        before do
          validated_uri = Addressable::URI.parse(import_url)
          allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
            .and_return([validated_uri, nil])
        end

        it 'passes empty resolved_address' do
          expect(project).to receive(:fetch_mirror)
            .with(forced: true, resolved_address: '')
            .and_return(Gitaly::FetchRemoteResponse.new)

          service.execute
        end
      end
    end

    context "when the URL local" do
      before do
        project.import_url = 'https://localhost:3000'

        stub_fetch_mirror(project)
      end

      context "when local requests are allowed" do
        before do
          stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)
        end

        it "succeeds" do
          result = service.execute

          expect(result[:status]).to eq(:success)
          expect(result[:message]).to be_nil
        end
      end

      context "when local requests are not allowed" do
        before do
          stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)
        end

        it "fails and returns error status" do
          result = service.execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to include('The import URL is invalid')
        end
      end
    end

    context "when given URLs contain escaped elements" do
      it_behaves_like "URLs containing escaped elements return expected status" do
        let(:result) { service.execute }

        before do
          project.import_url = url

          stub_fetch_mirror(project)
        end
      end
    end

    context 'updating tags', :aggregate_failures do
      it 'creates new tags, expiring cache if there are tag changes' do
        stub_fetch_mirror(project)

        expect(project.repository).to receive(:expire_tags_cache).and_call_original

        expect(service.execute).to eq(status: :success)

        expect(project.repository.tag_names).to include('new-tag')
      end

      it 'does not expire cache if there are no tag changes' do
        stub_fetch_mirror(project, tags_changed: false)

        expect(project.repository).not_to receive(:expire_tags_cache)

        expect(service.execute).to eq(status: :success)
      end

      it 'only invokes Git::TagPushService for tags pointing to commits' do
        stub_fetch_mirror(project)

        allow(Git::TagPushService).to receive(:new).and_call_original
        expect(Git::TagPushService).to receive(:new)
          .with(
            project,
            project.first_owner,
            hash_including(change: hash_including(ref: 'refs/tags/new-tag'), mirror_update: true)
          )
          .and_return(double(execute: true))

        expect(service.execute).to eq(status: :success)
      end

      describe 'Protected tags mirroring' do
        context 'when user has permissions to create a protected tag' do
          let!(:protected_tag) { create(:protected_tag, project: project, name: 'protected-tag') }

          it 'creates the protected tag' do
            stub_fetch_mirror(project)

            expect(project.repository).to receive(:expire_tags_cache).and_call_original
            expect(Git::TagPushService).to receive(:new).and_call_original.twice

            expect(service.execute).to eq(status: :success)

            expect(project.repository.tag_names).to include('new-tag', 'protected-tag')
          end
        end

        context 'when user cannot create a protected tag' do
          let!(:protected_tag) { create(:protected_tag, :no_one_can_create, project: project, name: 'protected-tag') }

          it 'creates only tags that user can create' do
            stub_fetch_mirror(project)

            expect(Git::TagPushService).to receive(:new).and_call_original.once

            expect(service.execute).to eq(
              message: "You are not allowed to create tags: 'protected-tag' as they are protected.",
              status: :error
            )
            expect(project.repository.tag_names).not_to include('protected-tag')
            expect(project.repository.tag_names).to include('new-tag')
          end
        end
      end
    end

    context 'when repository is in read-only mode' do
      before do
        project.update_attribute(:repository_read_only, true)
      end

      it 'does not run if repository is set to read-only' do
        expect(service).not_to receive(:update_tags)
        expect(service).not_to receive(:update_branches)

        expect(service.execute).to be_truthy
      end
    end

    context 'updating branches' do
      context 'when the mirror has a repository' do
        let(:master) { "master" }

        before do
          stub_fetch_mirror(project)
        end

        it 'creates new branches' do
          service.execute

          expect(project.repository.branch_names).to include("new-branch")
        end

        it 'logs the number of branches created' do
          expect_next_instance_of(Gitlab::UpdateMirrorServiceJsonLogger) do |logger|
            expect(logger).to receive(:info).with(hash_including(
              message: 'Mirror update creating branches',
              branches_count: 1
            ))
          end

          service.execute
        end

        it 'does not execute N+1 redis cache commands' do
          modify_branch(project.repository, 'branch-1', remote: true)
          modify_branch(project.repository, 'branch-2', remote: true)

          control = RedisCommands::Recorder.new(pattern: ':branch_names:') { service.execute }

          expect(control).not_to exceed_redis_command_calls_limit(:sadd, 1)
        end

        it 'updates existing branches' do
          service.execute

          expect(project.repository.find_branch("existing-branch").dereferenced_target)
            .to eq(project.repository.find_branch(master).dereferenced_target)
        end

        context 'when branch cannot be created' do
          before do
            modify_branch(project.repository, 'HEAD', remote: true)
          end

          it 'returns an error' do
            result = service.execute

            expect(result).to eq(status: :error, message: 'Branch name is invalid')
          end
        end

        context 'when async_mirror_branch_creation feature flag is enabled' do
          before do
            stub_feature_flags(async_mirror_branch_creation: project)
          end

          context 'and the number of branches to create exceeds the threshold' do
            let(:num_new_branches) { 5 }

            before do
              stub_const('Projects::UpdateMirrorService::ASYNC_BRANCH_THRESHOLD', 1)

              # The original project includes 1 new branch
              (1..(num_new_branches - 1)).each do |i|
                modify_branch(project.repository, "batch-branch-#{i}", remote: true)
              end
            end

            context 'and there are errors before creating branches' do
              before do
                allow(project.repository).to receive(:ff_merge).and_raise(Gitlab::Git::PreReceiveError)
              end

              it 'does sets the status to failed and does not enqueue jobs for creating branches' do
                expect(service.execute[:status]).to eq :error
                expect(::Repositories::CreateBranchWorker.jobs.size).to eq(0)
                expect(::Repositories::CreateBranchesFinishWorker.jobs.size).to eq(0)
              end
            end

            it 'schedules Repositories::CreateBranchWorker jobs' do
              expect(::Branches::CreateService).to receive(:new).with(project, current_user).once.and_call_original
              expect(::Repositories::CreateBranchWorker).to receive(:bulk_perform_in) do |delay, args|
                expect(delay).to eq(1.second)
                expect(args.size).to eq(num_new_branches - 1)
              end

              service.execute
            end

            it 'schedules CreateBranchesFinishWorker' do
              expect(::Repositories::CreateBranchesFinishWorker).to receive(:perform_async).with(
                project.id, a_string_matching(/gitlab:job_waiter:/), num_new_branches - 1, 0
              )

              service.execute
            end

            it 'returns success' do
              result = service.execute
              expect(result[:status]).to eq(:success)
              expect(result[:async]).to be_truthy
            end

            it 'schedules jobs in batches with staggered delays' do
              # Stub the batch size so that there are two batches
              stub_const('Projects::UpdateMirrorService::ASYNC_BRANCH_BATCH_SIZE', num_new_branches - 2)

              expect(::Repositories::CreateBranchWorker).to receive(:bulk_perform_in).with(1.second, anything).once
              expect(::Repositories::CreateBranchWorker).to receive(:bulk_perform_in).with(31.seconds, anything).once

              service.execute
            end

            it 'creates branches up to the threshold synchronously and enqueues the rest' do
              expect(::Branches::CreateService).to receive(:new)
                .with(project, current_user)
                .and_call_original

              service.execute

              expect(::Repositories::CreateBranchWorker.jobs.size).to eq(num_new_branches - Projects::UpdateMirrorService::ASYNC_BRANCH_THRESHOLD)
            end

            context 'when synchronous bulk_create fails' do
              before do
                allow_next_instance_of(::Branches::CreateService) do |svc|
                  allow(svc).to receive(:bulk_create).and_return({ status: :error, message: 'sync error' })
                end
              end

              it 'does not enqueue async jobs and returns error' do
                result = service.execute

                expect(result[:status]).to eq(:error)
                expect(::Repositories::CreateBranchWorker.jobs.size).to eq(0)
                expect(::Repositories::CreateBranchesFinishWorker.jobs.size).to eq(0)
              end
            end

            context 'and the number of async jobs exceeds the limit' do
              let(:expected_excess_count) { 1 }
              let(:expected_enqueued_amount) { num_new_branches - Projects::UpdateMirrorService::ASYNC_BRANCH_THRESHOLD - expected_excess_count }

              before do
                stub_const('Projects::UpdateMirrorService::MAXIMUM_ASYNC_BRANCHES',
                  num_new_branches - Projects::UpdateMirrorService::ASYNC_BRANCH_THRESHOLD - expected_excess_count
                )
              end

              it 'only enqueues up to the limit and passes the excess count' do
                expect(::Repositories::CreateBranchesFinishWorker).to receive(:perform_async).with(
                  project.id, a_string_matching(/gitlab:job_waiter:/), expected_enqueued_amount, expected_excess_count
                )

                service.execute

                expect(Repositories::CreateBranchWorker.jobs.size).to eq(expected_enqueued_amount)
              end
            end
          end

          context 'and the number of branches does not exceed the threshold' do
            it 'does not enqueue jobs' do
              expect(::Branches::CreateService).to receive(:new).with(project, current_user).once.and_call_original

              expect(::Repositories::CreateBranchWorker).not_to receive(:bulk_perform_in)

              service.execute
            end
          end
        end

        context 'when async_mirror_branch_creation feature flag is disabled' do
          before do
            stub_feature_flags(async_mirror_branch_creation: false)
          end

          it 'creates branches synchronously via bulk_create' do
            service.execute

            expect(project.repository.branch_names).to include("new-branch")
          end
        end

        context 'when mirror only protected branches option is set' do
          let(:new_protected_branch_name) { "new-branch" }
          let(:protected_branch_name) { "existing-branch" }

          before do
            project.update!(only_mirror_protected_branches: true)
          end

          it 'creates a new protected branch' do
            create(:protected_branch, project: project, name: new_protected_branch_name)
            project.reload

            service.execute

            expect(project.repository.branch_names).to include(new_protected_branch_name)
          end

          it 'does not create an unprotected branch' do
            service.execute

            expect(project.repository.branch_names).not_to include(new_protected_branch_name)
          end

          it 'updates existing protected branches' do
            create(:protected_branch, project: project, name: protected_branch_name)
            project.reload

            service.execute

            expect(project.repository.find_branch(protected_branch_name).dereferenced_target)
              .to eq(project.repository.find_branch(master).dereferenced_target)
          end

          it 'does not update unprotected branches' do
            service.execute

            expect(project.repository.find_branch(protected_branch_name).dereferenced_target)
              .not_to eq(project.repository.find_branch(master).dereferenced_target)
          end
        end

        context 'when mirror_branch_regex is set' do
          let(:new_branch_name) { "new-branch" }
          let(:existing_branch_name) { "existing-branch" }
          let(:fake_regex) { instance_spy(Gitlab::UntrustedRegexp) }
          let!(:project_setting) { create(:project_setting, project: project, mirror_branch_regex: 'fake_regex') }

          before do
            allow(Gitlab::UntrustedRegexp).to receive(:new)
                                    .with('fake_regex')
                                    .and_return(fake_regex)

            allow(fake_regex).to receive(:match?).and_return(false)
          end

          it 'create a new matched branch' do
            allow(fake_regex).to receive(:match?).with(new_branch_name).and_return(true)

            service.execute

            expect(project.repository.branch_names).to include(new_branch_name)
          end

          it 'does not create mismatched branch' do
            service.execute

            expect(project.repository.branch_names).not_to include(new_branch_name)
          end

          it 'updates existing matched branches' do
            allow(fake_regex).to receive(:match?).with('existing-branch').and_return(true)

            service.execute

            expect(project.repository.find_branch(existing_branch_name).dereferenced_target)
              .to eq(project.repository.find_branch(master).dereferenced_target)
          end

          it 'does not update mismatched branches' do
            service.execute

            expect(project.repository.find_branch(existing_branch_name).dereferenced_target)
              .not_to eq(project.repository.find_branch(master).dereferenced_target)
          end
        end

        context 'with diverged branches' do
          let(:diverged_branch) { "markdown" }

          context 'when mirror_overwrites_diverged_branches is true' do
            it 'update diverged branches' do
              project.mirror_overwrites_diverged_branches = true

              service.execute

              expect(project.repository.find_branch(diverged_branch).dereferenced_target)
                .to eq(project.repository.find_branch(master).dereferenced_target)
            end
          end

          context 'when mirror_overwrites_diverged_branches is false' do
            it "doesn't update diverged branches" do
              project.mirror_overwrites_diverged_branches = false

              service.execute

              expect(project.repository.find_branch(diverged_branch).dereferenced_target)
                .not_to eq(project.repository.find_branch(master).dereferenced_target)
            end
          end

          context 'when mirror_overwrites_diverged_branches is nil' do
            it "doesn't update diverged branches" do
              project.mirror_overwrites_diverged_branches = nil

              service.execute

              expect(project.repository.find_branch(diverged_branch).dereferenced_target)
                .not_to eq(project.repository.find_branch(master).dereferenced_target)
            end
          end
        end
      end

      context 'when project is empty' do
        it 'does not add a default master branch' do
          project    = create(:project_empty_repo, :mirror, import_url: Project::UNKNOWN_IMPORT_URL)
          repository = project.repository

          allow(project).to receive(:fetch_mirror) { create_file(repository) }
          expect(::Branches::CreateService).not_to receive(:create_master_branch)

          service.execute

          expect(repository.branch_names).not_to include('master')
        end
      end

      def create_file(repository)
        repository.create_file(
          project.first_owner,
          '/newfile.txt',
          'hello',
          message: 'Add newfile.txt',
          branch_name: 'newbranch'
        )
      end
    end

    context 'updating LFS objects' do
      context 'when repository does not change' do
        let(:lfs_enabled) { true }

        it 'does not attempt to update LFS objects' do
          expect(Projects::LfsPointers::LfsImportService).not_to receive(:new)

          service.execute
        end
      end

      context 'when repository changes' do
        before do
          stub_fetch_mirror(project, repo_changed: true, tags_changed: false)
        end

        context 'when LFS is disabled in the project' do
          it 'does not update LFS objects' do
            expect(Projects::LfsPointers::LfsObjectDownloadListService).not_to receive(:new)

            expect(Gitlab::Metrics::Lfs).not_to receive(:update_objects_error_rate)

            service.execute
          end
        end

        context 'when LFS is enabled in the project' do
          let(:lfs_enabled) { true }

          it 'updates LFS objects' do
            expect(Projects::LfsPointers::LfsImportService).to receive(:new).and_call_original
            expect_next_instance_of(Projects::LfsPointers::LfsObjectDownloadListService) do |instance|
              expect(instance).to receive(:each_list_item)
            end

            expect(Gitlab::Metrics::Lfs).to receive_message_chain(:update_objects_error_rate, :increment).with(error: false, labels: {})

            service.execute
          end

          context 'when mirror only protected branches option is set' do
            let(:protected_branch_name) { "protected-branch" }
            let(:protected_branch_sha) { 'protected_sha_123' }
            let(:protected_branch_commit) { RepoHelpers.sample_commit }

            let(:unprotected_branch_name) { "unprotected-branch" }
            let(:unprotected_branch_sha) { 'unprotected_sha_456' }
            let(:unprotected_branch_commit) { RepoHelpers.another_sample_commit }

            let(:remote_protected_branch) do
              Gitlab::Git::Branch.new(project.repository, protected_branch_name, protected_branch_sha, protected_branch_commit)
            end

            let(:remote_unprotected_branch) do
              Gitlab::Git::Branch.new(project.repository, unprotected_branch_name, unprotected_branch_sha, unprotected_branch_commit)
            end

            let(:remote_branches) { [remote_protected_branch, remote_unprotected_branch] }

            before do
              project.update!(only_mirror_protected_branches: true)

              allow(project.repository).to receive_messages(
                remote_branches: remote_branches
              )
            end

            it 'only processes LFS objects from protected branches' do
              create(:protected_branch, project: project, name: protected_branch_name)
              project.reload

              expect(Projects::LfsPointers::LfsImportService).to receive(:new).with(
                project,
                current_user,
                { updated_revisions: ["refs/remotes/upstream/#{protected_branch_name}"] }
              ).and_call_original

              service.execute
            end
          end

          context 'when LFS import fails' do
            let(:error_message) { 'error_message' }

            before do
              expect_next_instance_of(Projects::LfsPointers::LfsImportService) do |instance|
                expect(instance).to receive(:execute).and_return(status: :error, message: error_message)
              end
            end

            # Uncomment once https://gitlab.com/gitlab-org/gitlab-foss/issues/61834 is closed
            # it 'fails mirror operation' do
            #   expect_any_instance_of(Projects::LfsPointers::LfsImportService).to receive(:execute).and_return(status: :error, message: 'error message')

            #   result = subject.execute

            #   expect(result[:status]).to eq :error
            #   expect(result[:message]).to eq 'error message'
            # end

            # Remove once https://gitlab.com/gitlab-org/gitlab-foss/issues/61834 is closed
            it 'does not fail mirror operation' do
              expect(Gitlab::Metrics::Lfs).to receive_message_chain(:update_objects_error_rate, :increment).with(error: true, labels: {})

              result = subject.execute

              expect(result[:status]).to eq :success
            end

            it 'logs the error' do
              expect_next_instance_of(Gitlab::UpdateMirrorServiceJsonLogger) do |instance|
                expect(instance).to receive(:error).with(hash_including(error_message: error_message))
              end

              expect(Gitlab::Metrics::Lfs).to receive_message_chain(:update_objects_error_rate, :increment).with(error: true, labels: {})

              subject.execute
            end
          end

          context 'LFS selective revision processing' do
            context 'initial mirroring (empty repository)' do
              let_it_be(:empty_project) { create(:project_empty_repo, :mirror, import_url: Project::UNKNOWN_IMPORT_URL) }
              let(:empty_project_current_user) { empty_project.first_owner }
              let(:empty_service) { described_class.new(empty_project, empty_project_current_user) }

              before do
                allow(empty_project).to receive(:lfs_enabled?).and_return(true)
                allow(empty_project).to receive(:fetch_mirror) do
                  Gitaly::FetchRemoteResponse.new(tags_changed: false, repo_changed: true)
                end
              end

              it 'passes ["--all"] to LfsImportService for initial mirroring' do
                expect(Projects::LfsPointers::LfsImportService).to receive(:new).with(
                  empty_project,
                  empty_project_current_user,
                  { updated_revisions: ['--all'] }
                ).and_call_original

                empty_service.execute
              end
            end

            context 'when no branches changed' do
              before do
                allow(project.repository).to receive(:remote_branches).and_return(project.repository.branches)
              end

              it 'does not call LfsImportService' do
                expect(Projects::LfsPointers::LfsImportService).not_to receive(:new)

                service.execute
              end
            end

            context 'when branches with changes' do
              let(:old_commit_sha) { '48f365f4fef7f4f2eabac6a57e655396f527a1e1' }
              let(:new_commit_sha) { '4c44e9f2a8b0f8c6cf90ec33034ce04c4a5a11c4' }
              let(:old_commit) { RepoHelpers.sample_commit }
              let(:new_commit) { RepoHelpers.another_sample_commit }

              let(:local_main_branch) { Gitlab::Git::Branch.new(project.repository, 'main', old_commit_sha, old_commit) }
              let(:remote_main_branch) { Gitlab::Git::Branch.new(project.repository, 'main', new_commit_sha, new_commit) }

              let(:remote_branches) { [remote_main_branch] }

              before do
                allow(project.repository).to receive_messages(
                  branches: [local_main_branch],
                  remote_branches: remote_branches,
                  upstream_branches: remote_branches,
                  ff_merge: true
                )
              end

              context 'when existing branches are updated' do
                it 'passes commit SHA ranges to LfsImportService for updated branches' do
                  expect(Projects::LfsPointers::LfsImportService).to receive(:new).with(
                    project,
                    current_user,
                    { updated_revisions: ["#{old_commit_sha}..#{new_commit_sha}"] }
                  ).and_call_original

                  service.execute
                end
              end

              context 'when mixing updated and new branches' do
                let(:feature_commit_sha) { '0a358369b3d68f5d4e7cf2507d515364f8a1c4ec' }
                let(:feature_commit) { RepoHelpers.sample_big_commit }
                let(:remote_feature_branch) { Gitlab::Git::Branch.new(project.repository, 'feature', feature_commit_sha, feature_commit) }
                let(:remote_branches) { [remote_main_branch, remote_feature_branch] }

                it 'passes SHA ranges for updated branches and full refs for new branches' do
                  expect(Projects::LfsPointers::LfsImportService).to receive(:new).with(
                    project,
                    current_user,
                    { updated_revisions: [
                      "#{old_commit_sha}..#{new_commit_sha}",
                      "refs/remotes/upstream/feature"
                    ] }
                  ).and_call_original

                  service.execute
                end

                context 'with threshold' do
                  before do
                    stub_const('Gitlab::Repositories::Mirror::LocalRemoteBranchComparator::MAX_NUMBER_TO_PROCESS_SPECIFIC_REVISIONS', 1)
                  end

                  context 'when the changes are over threshold' do
                    it 'passes --all to LfsImportService' do
                      expect(Projects::LfsPointers::LfsImportService).to receive(:new).with(
                        project,
                        current_user,
                        { updated_revisions: ['--all'] }
                      ).and_call_original

                      service.execute
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    it "fails when the mirror user doesn't have access" do
      stub_fetch_mirror(project)

      result = described_class.new(project, create(:user)).execute

      expect(result[:status]).to eq(:error)
    end

    it "fails when no user is present" do
      result = described_class.new(project, nil).execute

      expect(result[:status]).to eq(:error)
    end

    it "returns success when there is no mirror" do
      project = build_stubbed(:project)
      user    = create(:user)

      result = described_class.new(project, user).execute

      expect(result[:status]).to eq(:success)
    end
  end

  describe "#update_lfs_objects_and_branches" do
    let(:fetch_result) { double('Gitaly::FetchRemoteResponse', repo_changed: repo_changed) }

    context "and fetch_result.repo_changed is false" do
      let(:repo_changed) { false }

      it 'does not call #update_lfs_objects' do
        expect(service).not_to receive(:update_lfs_objects)

        service.update_lfs_objects_and_branches(fetch_result)
      end
    end

    context "and fetch_result.repo_changed is true" do
      let(:repo_changed) { true }

      it 'calls #update_lfs_objects before #update_branches' do
        expect(service).to receive(:update_lfs_objects).ordered
        expect(service).to receive(:update_branches).ordered

        service.update_lfs_objects_and_branches(fetch_result)
      end
    end
  end

  describe 'first sync pipeline skipping' do
    let(:default_branch) { 'master' }

    before do
      stub_fetch_mirror(project)
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    describe '#first_sync?' do
      context 'when project has never been successfully updated' do
        before do
          allow(project.import_state).to receive(:ever_updated_successfully?).and_return(false)
        end

        it 'returns true' do
          expect(service.send(:first_sync?)).to be true
        end
      end

      context 'when project has been successfully updated before' do
        before do
          allow(project.import_state).to receive(:ever_updated_successfully?).and_return(true)
        end

        it 'returns false' do
          expect(service.send(:first_sync?)).to be false
        end
      end

      context 'when project has no import_state' do
        before do
          allow(project).to receive(:import_state).and_return(nil)
        end

        it 'returns true' do
          expect(service.send(:first_sync?)).to be true
        end
      end
    end

    describe 'branch creation on first sync' do
      let(:branches_to_create) do
        {
          'master' => 'abc123',
          'feature-1' => 'def456',
          'feature-2' => 'ghi789'
        }
      end

      before do
        allow(project.import_state).to receive(:ever_updated_successfully?).and_return(false)
      end

      # NOTE: In 19.3, callers do NOT pass skip_ci to workers yet (Sidekiq compatibility).
      # The worker accepts skip_ci with default=false, but callers won't pass it until 19.4.
      # These tests verify the current 19.3 behavior where default branch is created
      # separately (allowing a pipeline) while other branches go through bulk_create.
      #
      context 'when feature flag is enabled' do
        # Feature flags are enabled by default in the test environment
        it 'creates default branch via execute() to allow pipeline', :aggregate_failures do
          create_service = instance_double(::Branches::CreateService)
          allow(::Branches::CreateService).to receive(:new).with(project, current_user).and_return(create_service)

          # Default branch should be created via execute() (allows pipeline)
          expect(create_service).to receive(:execute).with('master', 'abc123').and_return({ status: :success })

          # Other branches created via bulk_create (no skip_ci passed in 19.3)
          expect(create_service).to receive(:bulk_create)
            .with({ 'feature-1' => 'def456', 'feature-2' => 'ghi789' })
            .and_return({ status: :success })

          errors = []
          service.send(:create_branches, branches_to_create.dup, errors)

          expect(errors).to be_empty
        end

        context 'when default branch is not in branches_to_create' do
          let(:branches_to_create) do
            {
              'feature-1' => 'def456',
              'feature-2' => 'ghi789'
            }
          end

          it 'only calls bulk_create' do
            create_service = instance_double(::Branches::CreateService)
            allow(::Branches::CreateService).to receive(:new).with(project, current_user).and_return(create_service)

            expect(create_service).not_to receive(:execute)
            expect(create_service).to receive(:bulk_create)
              .with({ 'feature-1' => 'def456', 'feature-2' => 'ghi789' })
              .and_return({ status: :success })

            errors = []
            service.send(:create_branches, branches_to_create.dup, errors)
          end
        end

        context 'when only default branch needs to be created' do
          let(:branches_to_create) { { 'master' => 'abc123' } }

          it 'creates default branch via execute() and returns early', :aggregate_failures do
            create_service = instance_double(::Branches::CreateService)
            allow(::Branches::CreateService).to receive(:new).with(project, current_user).and_return(create_service)

            expect(create_service).to receive(:execute).with('master', 'abc123').and_return({ status: :success })
            expect(create_service).not_to receive(:bulk_create)

            errors = []
            result = service.send(:create_branches, branches_to_create.dup, errors)

            expect(errors).to be_empty
            expect(result).to eq({ status: :success })
          end
        end
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(skip_pipelines_for_mirror_first_sync_non_default_branches: false)
        end

        it 'creates all branches via bulk_create' do
          create_service = instance_double(::Branches::CreateService)
          allow(::Branches::CreateService).to receive(:new).with(project, current_user).and_return(create_service)

          expect(create_service).not_to receive(:execute)
          expect(create_service).to receive(:bulk_create)
            .with(branches_to_create)
            .and_return({ status: :success })

          errors = []
          service.send(:create_branches, branches_to_create.dup, errors)
        end
      end
    end

    describe 'branch creation on delta sync' do
      let(:branches_to_create) do
        {
          'master' => 'abc123',
          'feature-1' => 'def456'
        }
      end

      before do
        allow(project.import_state).to receive(:ever_updated_successfully?).and_return(true)
        # Feature flag is enabled by default in tests, but first_sync? returns false
        # so skip_ci_for_non_default_branches? returns false
      end

      it 'creates all branches via bulk_create' do
        create_service = instance_double(::Branches::CreateService)
        allow(::Branches::CreateService).to receive(:new).with(project, current_user).and_return(create_service)

        expect(create_service).not_to receive(:execute)
        expect(create_service).to receive(:bulk_create)
          .with(branches_to_create)
          .and_return({ status: :success })

        errors = []
        service.send(:create_branches, branches_to_create.dup, errors)
      end
    end

    describe 'tag pipeline skipping on first sync' do
      before do
        allow(project.import_state).to receive(:ever_updated_successfully?).and_return(false)
        # Feature flag is enabled by default in tests
      end

      it 'passes create_pipelines: false to TagPushService for all tags' do
        # Allow TagPushService to be called multiple times, but verify create_pipelines: false
        allow(Git::TagPushService).to receive(:new).and_call_original

        expect(Git::TagPushService).to receive(:new).with(
          project,
          project.first_owner,
          hash_including(mirror_update: true, create_pipelines: false)
        ).at_least(:once).and_return(double(execute: true))

        service.execute
      end
    end

    describe 'tag pipeline creation on delta sync' do
      before do
        allow(project.import_state).to receive(:ever_updated_successfully?).and_return(true)
        # Feature flag is enabled by default in tests, but first_sync? returns false
        # so skip_ci_for_tags? returns false
      end

      it 'passes create_pipelines: true to TagPushService for all tags' do
        # Allow TagPushService to be called multiple times, but verify create_pipelines: true
        allow(Git::TagPushService).to receive(:new).and_call_original

        expect(Git::TagPushService).to receive(:new).with(
          project,
          project.first_owner,
          hash_including(mirror_update: true, create_pipelines: true)
        ).at_least(:once).and_return(double(execute: true))

        service.execute
      end
    end
  end

  def stub_fetch_mirror(project, repository: project.repository, tags_changed: true, repo_changed: false)
    allow(project).to receive(:fetch_mirror) { fetch_mirror(repository, tags_changed: tags_changed, repo_changed: repo_changed) }
  end

  def fetch_mirror(repository, tags_changed: true, repo_changed: false)
    masterrev = repository.find_branch("master").dereferenced_target.id

    parentrev = repository.commit(masterrev).parent_id
    repository.write_ref("refs/heads/existing-branch", parentrev)

    repository.expire_branches_cache
    repository.branches

    # New branch
    repository.write_ref('refs/remotes/upstream/new-branch', masterrev)

    # Updated existing branch
    repository.write_ref('refs/remotes/upstream/existing-branch', masterrev)

    # Diverged branch
    repository.write_ref('refs/remotes/upstream/markdown', masterrev)

    # New tag
    repository.write_ref('refs/tags/new-tag', masterrev)

    # Protected tag
    repository.write_ref('refs/tags/protected-tag', masterrev)

    # New tag that point to a blob
    repository.write_ref('refs/tags/new-tag-on-blob', 'c74175afd117781cbc983664339a0f599b5bb34e')

    Gitaly::FetchRemoteResponse.new(tags_changed: tags_changed, repo_changed: repo_changed)
  end

  def modify_tag(repository, tag_name)
    masterrev = repository.find_branch('master').dereferenced_target.id

    # Modify tag
    repository.write_ref("refs/tags/#{tag_name}", masterrev)
    repository.find_tag(tag_name).dereferenced_target.id
  end

  def modify_branch(repository, branch_name, remote: false)
    masterrev = repository.find_branch('master').dereferenced_target.id

    # Modify branch
    if remote
      repository.write_ref("refs/remotes/upstream/#{branch_name}", masterrev)
    else
      repository.write_ref("refs/heads/#{branch_name}", masterrev)
      repository.find_branch(branch_name).dereferenced_target.id
    end
  end
end
