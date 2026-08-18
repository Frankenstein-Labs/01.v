# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::CreateMergeRequestService,
  feature_category: :dependency_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:project) { create(:project, :small_repo, group: group, organization: organization) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project, severity: :high) }
  let_it_be(:maintainer) { create(:user, organization: organization) }

  let(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let(:build) { create(:ci_build, :success, pipeline: pipeline) }

  let(:source_branch_name) { 'dependency-management/rack-3.x' }

  let(:output_json) { load_output_fixture("output_valid") }

  def load_output_fixture(name)
    File.read(Rails.root.join("ee/spec/fixtures/dependency_management/#{name}.json"))
  end

  subject(:execute) do
    described_class.new(
      project: project,
      pipeline: pipeline,
      vulnerability: vulnerability
    ).execute
  end

  before_all do
    project.add_maintainer(maintainer)
  end

  before do
    stub_licensed_features(dependency_scanning: true)
    stub_ee_application_setting(
      allow_top_level_group_owners_to_create_service_accounts: true
    )
    allow_next_instance_of(Namespaces::ServiceAccounts::ProjectCreateService) do |svc|
      allow(svc).to receive(:can_create_service_account?).and_return(true)
    end

    allow(pipeline).to receive(:find_job_with_archive_artifacts)
      .with('workload')
      .and_return(build)

    allow(Gitlab::Ci::ArtifactFileReader).to receive(:new)
      .with(build, max_archive_size: 5.megabytes)
      .and_return(instance_double(Gitlab::Ci::ArtifactFileReader,
        read: output_json
      ))

    allow(build).to receive(:variables).and_return([
      instance_double(
        Gitlab::Ci::Variables::Collection::Item,
        key: 'DEPENDENCY_MANAGEMENT_SOURCE_REF',
        value: source_branch_name
      )

    ])
  end

  after do
    project.repository.delete_branch(source_branch_name) if project.repository.branch_exists?(source_branch_name)
  end

  describe '#execute' do
    context 'when everything succeeds' do
      it 'returns a success response with the merge request' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:merge_request]).to be_a(MergeRequest)
        expect(result.payload[:merge_request]).to be_persisted
      end

      it 'creates a merge request with the correct attributes' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.source_branch).to eq(source_branch_name)
        expect(mr.target_branch).to eq(project.default_branch_or_main)
        expect(mr.title).to include('rack')
        expect(mr.title).to include('2.0.9')
        expect(mr.title).to include('2.2.0')
      end

      it 'creates the target branch' do
        expect(project.repository.branch_exists?(source_branch_name)).to be(false)

        execute

        expect(project.repository.branch_exists?(source_branch_name)).to be(true)
      end

      it 'creates a commit on the target branch with the updated files' do
        execute

        commit = project.repository.commit(source_branch_name)
        expect(commit).to be_present
        expect(commit.message).to include('rack')
        expect(commit.message).to include('2.0.9')
        expect(commit.message).to include('2.2.0')
      end

      it 'renders the description using the md.erb template' do
        expect(ApplicationController).to receive(:render).with(
          template: 'dependency_management/security_update/merge_request_description',
          formats: :md,
          locals: hash_including(
            :dependencies, :updated_files, :vulnerability, :vulnerability_url
          )
        ).and_call_original

        result = execute
        mr = result.payload[:merge_request]

        expect(mr.description).to include('Security Dependency Update')
        expect(mr.description).to include('`rack`')
        expect(mr.description).to include('`2.0.9`')
        expect(mr.description).to include('`2.2.0`')
        expect(mr.description).to include('`Gemfile`')
        expect(mr.description).to include('`Gemfile.lock`')
        expect(mr.description).to include("vulnerability ##{vulnerability.id}")
      end

      it 'does not include vulnerability details in the description', :aggregate_failures do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.description).not_to include(vulnerability.title)
        expect(mr.description).not_to include(vulnerability.severity.to_s.capitalize)
        expect(mr.description).not_to include(vulnerability.finding.cve_value)
      end

      it 'links the vulnerability to the merge request' do
        result = execute
        mr = result.payload[:merge_request]

        expect(Vulnerabilities::MergeRequestLink.exists?(
          vulnerability: vulnerability,
          merge_request: mr
        )).to be(true)
      end

      it 'updates vulnerability_reads has_merge_request' do
        expect(Vulnerabilities::Reads::UpsertService).to receive(:new).with(
          vulnerability,
          { has_merge_request: true },
          projects: project
        ).and_call_original

        execute
      end

      it 'assigns a random active maintainer as reviewer' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.reviewers).to contain_exactly(maintainer)
      end

      it 'assigns the service account as assignee' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.assignees).to contain_exactly(mr.author)
      end

      it 'tracks the create event with purl_type and merge_request_id' do
        sbom_occurrence = instance_double(Sbom::Occurrence, purl_type: 'gem')
        allow(vulnerability).to receive(:sbom_occurrences).and_return([sbom_occurrence])

        expect { execute }
          .to trigger_internal_events('create_dependency_management_auto_remediation_mr')
          .with(
            project: project,
            additional_properties: {
              purl_type: 'gem',
              merge_request_id: kind_of(Integer)
            }
          )
      end
    end

    context 'when the vulnerability has no sbom_occurrences' do
      before do
        allow(vulnerability).to receive(:sbom_occurrences).and_return([])
      end

      it 'tracks the create event with a nil purl_type' do
        expect { execute }
          .to trigger_internal_events('create_dependency_management_auto_remediation_mr')
          .with(
            project: project,
            additional_properties: {
              purl_type: nil,
              merge_request_id: kind_of(Integer)
            }
          )
      end
    end

    context 'when the exclusive lease cannot be obtained' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:in_lock).and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Could not obtain lock for merge request creation')
      end
    end

    context 'when the pipeline has not succeeded' do
      let(:pipeline) { create(:ci_pipeline, :failed, project: project) }

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Pipeline has not completed successfully')
      end

      it 'does not track the create event' do
        expect { execute }
          .not_to trigger_internal_events('create_dependency_management_auto_remediation_mr')
      end
    end

    context 'when the service account cannot be provisioned' do
      before do
        allow_next_instance_of(DependencyManagement::ProvisionServiceAccountService) do |svc|
          allow(svc).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'quota exceeded'))
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Service account not available')
      end
    end

    context 'when the job producing output artifact is not found' do
      before do
        allow(pipeline).to receive(:find_job_with_archive_artifacts)
          .with('workload')
          .and_return(nil)
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('job producing output.json artifact not found')
      end
    end

    context 'when the output artifact is too large' do
      before do
        allow(Gitlab::Ci::ArtifactFileReader).to receive(:new)
          .and_raise(Gitlab::Ci::ArtifactFileReader::Error,
            'Artifacts archive for job `workload` is too large')
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('too large')
      end
    end

    context 'when the output contains no dependency changes' do
      let(:output_json) { { 'dependency_updates' => [], 'updated_files' => [] }.to_json }

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('No dependency changes found')
      end
    end

    context 'when the output contains no updated files' do
      let(:output_json) do
        {
          'dependency_updates' => [{ 'name' => 'rack', 'new_version' => '3.1.18', 'previous_version' => '3.1.17' }],
          'updated_files' => []
        }.to_json
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('No updated files found')
      end
    end

    context 'when the source ref variable is missing' do
      before do
        allow(build).to receive(:variables).and_return([])
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Source ref is not set on pipeline')
      end
    end

    context 'when a merge request already exists for the branch' do
      before do
        project.repository.create_branch(source_branch_name, project.default_branch_or_main)

        ::Files::MultiService.new(project, project.creator, {
          commit_message: 'Add initial Gemfile',
          branch_name: source_branch_name,
          start_branch: source_branch_name,
          actions: [
            { action: 'create', file_path: 'Gemfile', content: 'gem "rack", "= 2.0.9"' },
            { action: 'create', file_path: 'Gemfile.lock', content: 'rack (2.0.9)' }
          ]
        }).execute
      end

      let!(:existing_mr) do
        create(:merge_request,
          source_project: project,
          source_branch: source_branch_name,
          target_branch: project.default_branch_or_main,
          state: :opened
        )
      end

      it 'updates the existing merge request instead of creating a new one' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:merge_request].id).to eq(existing_mr.id)
      end

      it 'does not create a new merge request' do
        expect { execute }.not_to change { MergeRequest.count }
      end

      it 'updates the description on the existing merge request' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.description).to include('Security Dependency Update')
        expect(mr.description).to include('`rack`')
      end

      it 'moves the title to the newly resolved version' do
        result = execute

        expect(result.payload[:merge_request].title).to eq(
          'Security: Update rack from 2.0.9 to 2.2.0'
        )
      end

      it 'restarts the refresh cooldown so the scheduler leaves it alone' do
        expect(DependencyManagement::SecurityUpdate::RefreshCooldown)
          .to receive(:start).with(existing_mr)

        execute
      end

      it 'links the vulnerability even when starting the cooldown fails' do
        allow(DependencyManagement::SecurityUpdate::RefreshCooldown)
          .to receive(:start).and_raise(Redis::BaseError)

        expect { execute }.to change { existing_mr.vulnerability_merge_request_links.count }.by(1)
      end
    end

    context 'when the output contains directory traversal paths' do
      let(:output_json) do
        {
          'dependency_updates' => [
            { 'name' => 'rack', 'new_version' => '3.1.18', 'previous_version' => '3.1.17' }
          ],
          'updated_files' => [
            { 'directory' => '../../../etc/', 'name' => 'passwd', 'content' => 'malicious' }
          ]
        }.to_json
      end

      it 'rejects the malicious path and returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('No updated files found')
      end
    end

    context 'when the licensed features are not available' do
      before do
        stub_licensed_features(dependency_scanning: false)
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Feature not available')
      end
    end

    context 'with multiple dependencies' do
      let(:output_json) { load_output_fixture('output_multiple_deps') }

      it 'creates a merge request with a multi-dependency title' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.title).to eq('Security: Update 2 dependencies')
      end

      it 'includes all dependencies in the description' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.description).to include('`rack`')
        expect(mr.description).to include('`rake`')
      end
    end

    context 'when untrusted input contains markdown-sensitive characters' do
      let(:output_json) do
        {
          'dependency_updates' => [
            { 'name' => 'evil<script>gem', 'new_version' => '2.0|injected', 'previous_version' => '1.0' }
          ],
          'updated_files' => [
            { 'name' => 'Gemfile', 'directory' => '/', 'content' => 'safe' }
          ]
        }.to_json
      end

      it 'wraps untrusted values in code spans and HTML-escapes them' do
        result = execute
        mr = result.payload[:merge_request]

        expect(mr.description).to include('`evil&lt;script&gt;gem`')
        expect(mr.description).to include('`2.0|injected`')
      end

      context 'when a dependency name contains a newline and markdown' do
        let(:output_json) do
          {
            'dependency_updates' => [
              { 'name' => "pkg\n## Injected", 'new_version' => '1.1.0', 'previous_version' => '1.0.0' }
            ],
            'updated_files' => [
              { 'name' => 'Gemfile', 'directory' => '/', 'content' => 'safe' }
            ]
          }.to_json
        end

        it 'collapses it into a single-line code span so the table row cannot break' do
          result = execute
          mr = result.payload[:merge_request]

          expect(mr.description).to include('`pkg ## Injected`')
          expect(mr.description).not_to include("pkg\n## Injected")
        end
      end

      context 'when the file path contains backticks' do
        let(:output_json) do
          {
            'dependency_updates' => [
              { 'name' => 'rack', 'new_version' => '2.2.0', 'previous_version' => '2.0.9' }
            ],
            'updated_files' => [
              { 'name' => 'a`b.lock', 'directory' => '/', 'content' => 'safe' }
            ]
          }.to_json
        end

        it 'wraps it in a backtick-safe code span' do
          result = execute
          mr = result.payload[:merge_request]

          expect(mr.description).to include('``a`b.lock``')
        end
      end
    end

    context 'when updating an existing merge request fails' do
      let!(:existing_mr) do
        create(:merge_request,
          source_project: project,
          source_branch: source_branch_name,
          target_branch: project.default_branch_or_main,
          state: :opened
        )
      end

      before do
        project.repository.create_branch(source_branch_name, project.default_branch_or_main)

        allow_next_instance_of(::MergeRequests::UpdateService) do |svc|
          allow(svc).to receive(:execute).and_return(
            existing_mr.tap { |mr| mr.errors.add(:base, 'Something went wrong') }
          )
        end
      end

      it 'returns an error response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Failed to update merge request')
      end

      it 'does not link the vulnerability' do
        execute

        expect(Vulnerabilities::MergeRequestLink.where(vulnerability: vulnerability)).not_to exist
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow_next_instance_of(described_class) do |svc|
          allow(svc).to receive(:create_branch_and_commit).and_raise(StandardError, 'boom')
        end
      end

      it 'returns an error response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('Unexpected error creating merge request')
      end
    end

    context 'when the artifact content cannot be read' do
      before do
        allow(Gitlab::Ci::ArtifactFileReader).to receive(:new)
          .and_raise(Gitlab::Ci::ArtifactFileReader::Error,
            'Path `output.json` does not exist inside the `workload` artifacts archive!')
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Failed to read output.json artifact')
      end
    end

    context 'when the output artifact contains invalid JSON' do
      before do
        allow(Gitlab::Ci::ArtifactFileReader).to receive(:new)
          .with(build, max_archive_size: 5.megabytes)
          .and_return(instance_double(Gitlab::Ci::ArtifactFileReader,
            read: 'not valid json {{{'
          ))
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Failed to parse output.json')
      end
    end

    context 'when the output contains too many file changes' do
      let(:output_json) do
        {
          'dependency_updates' => [{ 'name' => 'rack', 'new_version' => '3.1.18', 'previous_version' => '3.1.17' }],
          'updated_files' => Array.new(51) { |i| { 'directory' => '/', 'name' => "file_#{i}.rb", 'content' => 'x' } }
        }.to_json
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Too many file changes')
      end
    end

    context 'when committing files fails' do
      before do
        allow_next_instance_of(::Files::MultiService) do |svc|
          allow(svc).to receive(:execute).and_return({ status: :error, message: 'commit failed' })
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Failed to commit changes')
      end
    end

    context 'when a git pre-receive hook rejects the push' do
      before do
        allow_next_instance_of(::Files::MultiService) do |svc|
          allow(svc).to receive(:execute).and_raise(Gitlab::Git::PreReceiveError, 'hook rejected')
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Git pre-receive hook rejected the push')
      end
    end

    context 'when a git command error occurs during commit' do
      before do
        allow_next_instance_of(::Files::MultiService) do |svc|
          allow(svc).to receive(:execute).and_raise(Gitlab::Git::CommandError, 'git error')
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Git error while committing')
      end
    end

    context 'when branch creation fails' do
      before do
        allow_next_instance_of(::Branches::CreateService) do |svc|
          allow(svc).to receive(:execute).and_return({ status: :error, message: 'branch exists remotely' })
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
      end
    end

    context 'when updated files already exist on the branch' do
      before do
        project.repository.create_branch(source_branch_name, project.default_branch_or_main)
        project.repository.create_file(
          project.creator, 'Gemfile', 'original', message: 'init', branch_name: source_branch_name
        )
      end

      it 'uses update action for existing files' do
        result = execute

        expect(result).to be_success
      end

      it 'checks file existence in a single batched Gitaly call' do
        expect(project.repository).to receive(:blobs_at).once.and_call_original

        execute
      end

      it 'uses update for existing files and create for new files' do
        actions_used = nil

        expect_next_instance_of(::Files::MultiService) do |svc|
          expect(svc).to receive(:execute).with(no_args).and_wrap_original do |original|
            actions_used = svc.params[:actions]
            original.call
          end
        end

        execute

        expect(actions_used).to contain_exactly(
          hash_including(action: 'update', file_path: 'Gemfile'),
          hash_including(action: 'create', file_path: 'Gemfile.lock')
        )
      end
    end

    context 'when merge request creation fails' do
      before do
        allow_next_instance_of(::MergeRequests::CreateService) do |svc|
          allow(svc).to receive(:execute).and_return(
            MergeRequest.new.tap { |mr| mr.errors.add(:base, 'invalid') }
          )
        end
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Failed to create merge request')
      end
    end

    context 'when saving the vulnerability link fails' do
      before do
        allow_next_instance_of(Vulnerabilities::MergeRequestLink) do |link|
          allow(link).to receive(:save).and_return(false)
        end
      end

      it 'still returns success' do
        result = execute

        expect(result).to be_success
      end

      it 'does not call UpsertService' do
        expect(Vulnerabilities::Reads::UpsertService).not_to receive(:new)

        execute
      end

      it 'logs a warning' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: 'DependencyManagement: failed to link vulnerability to merge request',
            vulnerability_id: vulnerability.id,
            project_id: project.id
          )
        )

        execute
      end
    end

    context 'when linking the vulnerability raises an error' do
      before do
        allow_next_instance_of(Vulnerabilities::MergeRequestLink) do |link|
          allow(link).to receive(:save).and_raise(StandardError, 'db error')
        end
      end

      it 'still returns success' do
        result = execute

        expect(result).to be_success
      end
    end

    context 'when the output.json artifact reader returns nil' do
      before do
        allow(Gitlab::Ci::ArtifactFileReader).to receive(:new)
          .with(build, max_archive_size: 5.megabytes)
          .and_return(instance_double(Gitlab::Ci::ArtifactFileReader, read: nil))
      end

      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('output.json artifact not found')
      end
    end

    context 'when build.variables is nil' do
      before do
        allow(build).to receive(:variables).and_return(nil)
      end

      it 'returns an error about the missing source ref' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include('Source ref is not set on pipeline')
      end
    end

    context 'when no active maintainer is available to assign as reviewer' do
      before do
        allow(project).to receive_message_chain(:maintainers, :active, :human, :order_random, :first).and_return(nil)
      end

      it 'still succeeds without assigning a reviewer' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:merge_request].reviewers).to be_empty
      end

      it 'does not close the merge request that was created' do
        expect(::MergeRequests::CloseService).not_to receive(:new)

        execute
      end

      it 'logs a warning' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(message: 'DependencyManagement: no active maintainer found to assign as reviewer')
        )

        execute
      end
    end

    context 'when merge_request is nil in link_vulnerability_to_merge_request' do
      before do
        allow_next_instance_of(described_class) do |svc|
          allow(svc).to receive(:create_or_update_merge_request)
            .and_return(ServiceResponse.success(payload: { merge_request: nil }))
        end
      end

      it 'skips linking and still returns success' do
        result = execute

        expect(result).to be_success
        expect(Vulnerabilities::MergeRequestLink.where(vulnerability: vulnerability)).not_to exist
      end
    end

    describe 'reviewer assignment' do
      context 'when the project has maintainers' do
        let_it_be(:maintainer_1) { create(:user, organization: organization) }
        let_it_be(:maintainer_2) { create(:user, organization: organization) }

        before_all do
          project.add_maintainer(maintainer_1)
          project.add_maintainer(maintainer_2)
        end

        it 'assigns one of the maintainers as reviewer' do
          mr = execute.payload[:merge_request]

          assigned_maintainers = [maintainer, maintainer_1, maintainer_2] & mr.reviewers
          expect(assigned_maintainers.size).to eq(1)
        end

        it 'assigns the service account as assignee' do
          mr = execute.payload[:merge_request]

          expect(mr.assignees).to contain_exactly(mr.author)
        end

        it 'does not assign a bot or service account as reviewer' do
          mr = execute.payload[:merge_request]

          expect(mr.reviewers.map(&:user_type)).to all(eq('human'))
        end
      end

      context 'when the project has no maintainers' do
        before do
          allow(project).to receive_message_chain(:maintainers, :active, :human, :order_random, :first).and_return(nil)
        end

        it 'still succeeds' do
          result = execute

          expect(result).to be_success
        end

        it 'leaves the merge request open without a reviewer' do
          mr = execute.payload[:merge_request]

          expect(mr).to be_opened
          expect(mr.reviewers).to be_empty
        end
      end

      context 'when a maintainer dismissed a previous remediation' do
        # The valid output bumps `rack` 2.0.9 -> 2.2.0.
        let_it_be(:closer) { create(:user, organization: organization) }

        # The same service account the service provisions (idempotent), so it can push the
        # branch and authors the previously-dismissed MR.
        let(:service_account) do
          DependencyManagement::ProvisionServiceAccountService.new(project: project).execute.payload[:user]
        end

        before do
          # RemediationDismissalChecker derives the ecosystem from the vulnerability.
          allow(vulnerability).to receive(:sbom_occurrences)
            .and_return([instance_double(Sbom::Occurrence, purl_type: 'gem')])
        end

        def create_dismissed_mr(version:, closed_by:, vulnerability_for_link: vulnerability)
          mr = create(:merge_request, :closed, :with_closed_by,
            target_project: project, source_project: project, author: service_account,
            source_branch: source_branch_name, target_branch: project.default_branch_or_main,
            title: "Security: Update rack from 2.0.9 to #{version}", skip_branch_existence_check: true,
            closed_by: closed_by)
          create(:vulnerabilities_merge_request_link,
            vulnerability: vulnerability_for_link, finding: vulnerability_for_link.finding, merge_request: mr)
          mr
        end

        context 'and the proposed version is not newer' do
          before do
            create_dismissed_mr(version: '2.2.0', closed_by: closer)
          end

          it 'does not create a merge request' do
            allow(DependencyManagement::SecurityUpdate::RescheduleWorker).to receive(:perform_async)

            expect { execute }.not_to change { project.merge_requests.opened.count }
          end

          it 'returns a skipped response and reschedules the next candidate' do
            expect(DependencyManagement::SecurityUpdate::RescheduleWorker)
              .to receive(:perform_async).with(project.id)

            result = execute

            expect(result).to be_success
            expect(result.payload[:skipped]).to be(true)
          end
        end

        context 'and the proposed version is newer (resurface)' do
          before do
            create_dismissed_mr(version: '2.1.0', closed_by: closer)
          end

          it 'creates a merge request and does not reschedule' do
            expect(DependencyManagement::SecurityUpdate::RescheduleWorker).not_to receive(:perform_async)

            expect { execute }.to change { project.merge_requests.opened.count }.by(1)
          end
        end

        context 'when the bot auto-closed it (no maintainer available)' do
          before do
            create_dismissed_mr(version: '2.2.0', closed_by: service_account)
          end

          it 'recreates the merge request so it is still retried' do
            expect { execute }.to change { project.merge_requests.opened.count }.by(1)
          end
        end

        context 'when the dismissal was for a different vulnerability' do
          let_it_be(:other_vulnerability) { create(:vulnerability, :with_finding, project: project, severity: :high) }

          before do
            create_dismissed_mr(version: '2.2.0', closed_by: closer, vulnerability_for_link: other_vulnerability)
          end

          it 'creates a merge request (a new finding is not suppressed)' do
            expect { execute }.to change { project.merge_requests.opened.count }.by(1)
          end
        end
      end
    end
  end
end
