# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::RepositoryManager, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:subgroup) { create(:group) }
  let_it_be(:mirrors_group) { create(:group, parent: subgroup) }
  let_it_be(:mirror) { create(:project, namespace: mirrors_group, name: 'django') }

  let(:instance_id) { 'django__django-13112' }
  let(:base_commit) { 'abc123def456abc123def456abc123def456abc1' }
  let(:config_class) { Gitlab::Duo::Developments::SweBenchSeeder::Config }

  before do
    allow(config_class).to receive_messages(seed_base_url: 'http://gdk.test:3000', source_base_url: 'https://github.com')
  end

  describe '.setup_instance_projects' do
    let(:examples) do
      [
        { 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django',
                        'base_commit' => 'abc123' } }
      ]
    end

    context 'when mirrors_group creation fails' do
      before do
        allow(described_class).to receive(:find_or_create_mirrors_group).and_return(nil)
      end

      it 'returns empty hash' do
        result = described_class.setup_instance_projects(examples, subgroup, user)
        expect(result).to eq({})
      end
    end

    context 'when mirrors_group is created successfully' do
      before do
        allow(described_class).to receive_messages(
          find_or_create_mirrors_group: mirrors_group,
          ensure_mirrors: { 'django/django' => mirror },
          enqueue_clones: { 'django__django-13112' => mirror }
        )
      end

      it 'calls ensure_mirrors and enqueue_clones' do
        expect(described_class).to receive(:ensure_mirrors).with(examples, mirrors_group, subgroup, user)
        expect(described_class).to receive(:enqueue_clones).with(examples, anything, subgroup, user)
        described_class.setup_instance_projects(examples, subgroup, user)
      end
    end
  end

  describe '.find_or_create_mirrors_group' do
    context 'when mirrors group already exists' do
      let(:existing_group) { create(:group, parent: subgroup, name: 'mirrors') }

      before do
        allow(Group).to receive(:find_by_full_path)
          .with("#{subgroup.full_path}/mirrors")
          .and_return(existing_group)
      end

      it 'returns the existing group' do
        result = described_class.find_or_create_mirrors_group(subgroup, user)
        expect(result).to eq(existing_group)
      end
    end

    context 'when mirrors group does not exist' do
      let(:new_group) { create(:group, parent: subgroup, name: 'mirrors') }
      let(:create_response) { ServiceResponse.success(payload: { group: new_group }) }

      before do
        allow(Group).to receive(:find_by_full_path)
          .with("#{subgroup.full_path}/mirrors")
          .and_return(nil)
        allow_next_instance_of(Groups::CreateService) do |service|
          allow(service).to receive(:execute).and_return(create_response)
        end
      end

      it 'creates and returns a new group' do
        result = described_class.find_or_create_mirrors_group(subgroup, user)
        expect(result).to eq(new_group)
      end
    end

    context 'when group creation fails' do
      let(:error_response) { ServiceResponse.error(message: 'Name already taken') }

      before do
        allow(Group).to receive(:find_by_full_path).and_return(nil)
        allow_next_instance_of(Groups::CreateService) do |service|
          allow(service).to receive(:execute).and_return(error_response)
        end
      end

      it 'returns nil and logs the error' do
        expect { described_class.find_or_create_mirrors_group(subgroup, user) }
          .to output(/Failed to create mirrors group/).to_stdout
      end
    end

    context 'when an exception is raised' do
      before do
        allow(Group).to receive(:find_by_full_path).and_raise(StandardError, 'Database error')
      end

      it 'returns nil and logs the error' do
        expect { described_class.find_or_create_mirrors_group(subgroup, user) }
          .to output(/Error creating mirrors group/).to_stdout
      end
    end
  end

  describe '.ensure_mirrors' do
    let(:examples) do
      [
        { 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django',
                        'base_commit' => 'abc123' } },
        { 'inputs' => { 'instance_id' => 'flask__flask-5678', 'repo' => 'pallets/flask', 'base_commit' => 'def456' } }
      ]
    end

    context 'when all mirrors are created successfully' do
      before do
        allow(described_class).to receive(:ensure_mirror).and_return(mirror)
        allow(mirror).to receive(:persisted?).and_return(true)
      end

      it 'creates mirrors for unique repos' do
        expect(described_class).to receive(:ensure_mirror).twice
        described_class.ensure_mirrors(examples, mirrors_group, subgroup, user)
      end

      it 'returns hash of repo to mirror' do
        result = described_class.ensure_mirrors(examples, mirrors_group, subgroup, user)
        expect(result).to have_key('django/django')
        expect(result).to have_key('pallets/flask')
      end
    end

    context 'when examples have duplicate repos' do
      let(:examples_with_duplicates) do
        [
          { 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django',
                          'base_commit' => 'abc' } },
          { 'inputs' => { 'instance_id' => 'django__django-13113', 'repo' => 'django/django', 'base_commit' => 'def' } }
        ]
      end

      before do
        allow(described_class).to receive(:ensure_mirror).and_return(mirror)
        allow(mirror).to receive(:persisted?).and_return(true)
      end

      it 'only creates one mirror per unique repo' do
        expect(described_class).to receive(:ensure_mirror).once
        described_class.ensure_mirrors(examples_with_duplicates, mirrors_group, subgroup, user)
      end
    end

    context 'when mirror creation fails' do
      before do
        allow(described_class).to receive(:ensure_mirror).and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.ensure_mirrors(examples, mirrors_group, subgroup, user) }
          .to raise_error(/Mirror creation failed/)
      end
    end

    context 'when mirror is not persisted' do
      let(:unpersisted_mirror) { instance_double(Project, persisted?: false) }

      before do
        allow(described_class).to receive(:ensure_mirror).and_return(unpersisted_mirror)
      end

      it 'raises an error' do
        expect { described_class.ensure_mirrors(examples, mirrors_group, subgroup, user) }
          .to raise_error(/Mirror creation failed/)
      end
    end
  end

  describe '.enqueue_clones' do
    let(:examples) do
      [
        { 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django',
                        'base_commit' => 'abc123' } }
      ]
    end

    let(:mirrors) { { 'django/django' => mirror } }
    let(:project) { create(:project, namespace: subgroup) }

    context 'when mirror is not found for repo' do
      let(:empty_mirrors) { {} }

      it 'skips the example and logs' do
        expect { described_class.enqueue_clones(examples, empty_mirrors, subgroup, user) }
          .to output(/skipped \(no mirror for/).to_stdout
      end
    end

    context 'when clone is enqueued successfully' do
      before do
        allow(described_class).to receive_messages(
          start_clone_from_mirror: project,
          wait_for_all_imports: { 'django__django-13112' => project }
        )
      end

      it 'returns results from wait_for_all_imports' do
        result = described_class.enqueue_clones(examples, mirrors, subgroup, user)
        expect(result['django__django-13112']).to eq(project)
      end
    end

    context 'when start_clone_from_mirror returns nil' do
      before do
        allow(described_class).to receive_messages(
          start_clone_from_mirror: nil,
          wait_for_all_imports: {}
        )
      end

      it 'skips the example' do
        result = described_class.enqueue_clones(examples, mirrors, subgroup, user)
        expect(result).to be_empty
      end
    end

    context 'when some clones fail and need retry' do
      let(:examples) do
        [{ 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django', 'base_commit' => 'abc' } }]
      end

      # rubocop:disable RSpec/ReceiveMessages -- wait_for_all_imports uses chained returns
      before do
        allow(described_class).to receive(:start_clone_from_mirror).and_return(project)
        # First attempt: no results (all failed)
        # Second attempt: success
        allow(described_class).to receive(:wait_for_all_imports)
          .and_return({}, { 'django__django-13112' => project })
        allow(described_class).to receive(:reenqueue_clones).and_return(
          { 'django__django-13112' => { project: project, base_commit: 'abc' } }
        )
      end
      # rubocop:enable RSpec/ReceiveMessages

      it 'retries failed clones' do
        expect(described_class).to receive(:reenqueue_clones)
        described_class.enqueue_clones(examples, mirrors, subgroup, user)
      end
    end

    context 'when clones fail after max retries' do
      before do
        allow(described_class).to receive_messages(
          start_clone_from_mirror: project,
          wait_for_all_imports: {},
          reenqueue_clones: { 'django__django-13112' => { project: project, base_commit: 'abc123' } }
        )
      end

      it 'raises an error after max retries' do
        expect { described_class.enqueue_clones(examples, mirrors, subgroup, user) }
          .to raise_error(/clone\(s\) failed after.*attempts/)
      end
    end
  end

  describe '.reenqueue_clones' do
    let(:examples) do
      [
        { 'inputs' => { 'instance_id' => 'django__django-13112', 'repo' => 'django/django',
                        'base_commit' => 'abc123' } }
      ]
    end

    let(:mirrors) { { 'django/django' => mirror } }
    let(:project) { create(:project, namespace: subgroup) }
    let(:pending) { { 'django__django-13112' => { project: project, base_commit: 'abc123' } } }

    context 'when re-enqueue succeeds' do
      let(:new_project) { create(:project, namespace: subgroup) }

      before do
        allow(described_class).to receive(:start_clone_from_mirror).and_return(new_project)
      end

      it 'returns new pending hash with fresh projects' do
        result = described_class.reenqueue_clones(pending, examples, mirrors, subgroup, user)
        expect(result['django__django-13112'][:project]).to eq(new_project)
      end
    end

    context 'when start_clone_from_mirror returns nil' do
      before do
        allow(described_class).to receive(:start_clone_from_mirror).and_return(nil)
      end

      it 'excludes the failed instance from results' do
        result = described_class.reenqueue_clones(pending, examples, mirrors, subgroup, user)
        expect(result).to be_empty
      end
    end
  end

  describe '.instance_id_to_project_name' do
    it 'converts double underscores to single hyphens' do
      expect(described_class.instance_id_to_project_name('django__django-13112')).to eq('django-django-13112')
    end

    it 'converts remaining underscores to hyphens' do
      result = described_class.instance_id_to_project_name('scikit_learn__scikit_learn-123')
      expect(result).to eq('scikit-learn-scikit-learn-123')
    end
  end

  describe '.start_clone_from_mirror' do
    subject(:start_clone) do
      described_class.start_clone_from_mirror(mirror, instance_id, subgroup, user, 1, 10)
    end

    context 'when the project does not exist yet' do
      it 'creates a new project with import_url pointing at the local mirror' do
        project = create(:project, namespace: subgroup, name: 'django-django-13112')
        expect(::Projects::CreateService).to receive(:new).with(
          user,
          hash_including(
            name: 'django-django-13112',
            path: 'django-django-13112',
            namespace_id: subgroup.id,
            import_url: "http://gdk.test:3000/#{mirror.full_path}.git"
          )
        ).and_return(instance_double(::Projects::CreateService, execute: project))

        result = start_clone
        expect(result).to eq(project)
      end
    end

    context 'when a project with that path already exists' do
      it 'destroys it synchronously before creating the new one' do
        existing = create(:project, namespace: subgroup, name: 'django-django-13112')
        new_project = create(:project, namespace: subgroup, name: 'django-django-13112-new')

        allow(Project).to receive(:find_by_full_path).and_return(existing)
        destroy_service = instance_double(::Projects::DestroyService, execute: true)
        expect(::Projects::DestroyService).to receive(:new).with(existing, user).and_return(destroy_service)

        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: new_project)
        )

        start_clone
      end
    end

    context 'when project creation fails' do
      let(:failed_project) do
        build_stubbed(:project).tap do |p|
          allow(p).to receive(:errors).and_return(
            instance_double(ActiveModel::Errors, any?: true, full_messages: ['Name has already been taken'])
          )
        end
      end

      before do
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: failed_project)
        )
      end

      it 'returns nil and logs the error' do
        expect(start_clone).to be_nil
      end

      it 'logs the failure' do
        expect { start_clone }.to output(/clone failed/).to_stdout
      end
    end

    context 'when an exception is raised during clone' do
      before do
        allow(::Projects::CreateService).to receive(:new).and_raise(StandardError, 'Unexpected error')
      end

      it 'returns nil and logs the error' do
        expect(start_clone).to be_nil
      end

      it 'logs the error message' do
        expect { start_clone }.to output(/error enqueuing clone/).to_stdout
      end
    end
  end

  describe '.wait_for_all_imports' do
    let(:project) { create(:project, namespace: subgroup) }
    let(:pending) do
      { instance_id => { project: project, base_commit: base_commit } }
    end

    subject(:wait) do
      described_class.wait_for_all_imports(pending, user, total: 1, max_wait_seconds: 5, poll_interval: 0)
    end

    context 'when import finishes successfully' do
      before do
        allow(ProjectImportState).to receive(:where).and_return(
          [instance_double(ProjectImportState)].tap do |arr|
            allow(arr).to receive(:pluck).and_return([[project.id, 'finished', nil]])
          end
        )
        allow(described_class).to receive(:strip_to_commit)
        allow(project).to receive(:reset).and_return(project)
      end

      it 'calls strip_to_commit and returns the project' do
        result = wait
        expect(described_class).to have_received(:strip_to_commit).with(project, base_commit, user)
        expect(result[instance_id]).to eq(project)
      end
    end

    context 'when import fails' do
      before do # -- AR scope chain double
        terminal_scope = double
        allow(terminal_scope).to receive(:pluck).and_return([[project.id, 'failed', 'some error']])
        allow(ProjectImportState).to receive(:where).and_return(terminal_scope)
      end

      it 'does not include the project in results' do
        result = wait
        expect(result).not_to have_key(instance_id)
      end

      it 'logs the failure' do
        expect { wait }.to output(/import failed/).to_stdout
      end
    end

    context 'when timeout is exceeded' do
      before do # -- AR scope chain doubles
        # Terminal query returns nothing; zombie query also returns nothing.
        terminal_scope = double
        allow(terminal_scope).to receive(:pluck).with(:project_id, :status, :last_error).and_return([])
        zombie_scope = double
        allow(zombie_scope).to receive(:where).and_return(zombie_scope)
        allow(zombie_scope).to receive(:pluck).with(:project_id).and_return([])
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [project.id], status: %w[finished failed canceled])
          .and_return(terminal_scope)
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [project.id], status: 'started')
          .and_return(zombie_scope)
      end

      it 'logs timeout and returns partial results' do
        expect { wait }.to output(/Timeout/).to_stdout
      end
    end

    context 'when zombie jobs are detected' do
      let(:repository) { instance_double(Repository, exists?: false) }
      let(:zombie_project) { instance_double(Project, id: project.id, repository: repository) }
      let(:pending_with_zombie) do
        { instance_id => { project: zombie_project, base_commit: base_commit } }
      end

      subject(:wait_with_zombie) do
        described_class.wait_for_all_imports(
          pending_with_zombie, user, total: 1, max_wait_seconds: 5,
          poll_interval: 0, zombie_threshold_seconds: 0
        )
      end

      before do # -- AR scope chain doubles
        terminal_scope = double
        allow(terminal_scope).to receive(:pluck).with(:project_id, :status, :last_error).and_return([])
        zombie_scope = double
        allow(zombie_scope).to receive(:where).and_return(zombie_scope)
        allow(zombie_scope).to receive(:pluck).with(:project_id).and_return([zombie_project.id])
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [zombie_project.id], status: %w[finished failed canceled])
          .and_return(terminal_scope)
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [zombie_project.id], status: 'started')
          .and_return(zombie_scope)
      end

      it 'detects zombie jobs and removes them from pending' do
        expect { wait_with_zombie }.to output(/ZOMBIE/).to_stdout
      end
    end

    context 'when zombie job has repository that exists' do
      let(:repository) { instance_double(Repository, exists?: true) }
      let(:zombie_project) { instance_double(Project, id: project.id, repository: repository) }
      let(:pending_with_zombie) do
        { instance_id => { project: zombie_project, base_commit: base_commit } }
      end

      subject(:wait_with_zombie) do
        described_class.wait_for_all_imports(
          pending_with_zombie, user, total: 1, max_wait_seconds: 1,
          poll_interval: 0, zombie_threshold_seconds: 0
        )
      end

      before do # -- AR scope chain doubles
        terminal_scope = double
        allow(terminal_scope).to receive(:pluck).with(:project_id, :status, :last_error).and_return([])
        zombie_scope = double
        allow(zombie_scope).to receive(:where).and_return(zombie_scope)
        allow(zombie_scope).to receive(:pluck).with(:project_id).and_return([zombie_project.id])
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [zombie_project.id], status: %w[finished failed canceled])
          .and_return(terminal_scope)
        allow(ProjectImportState).to receive(:where)
          .with(project_id: [zombie_project.id], status: 'started')
          .and_return(zombie_scope)
      end

      it 'skips zombie detection if repository exists' do
        expect { wait_with_zombie }.not_to output(/ZOMBIE/).to_stdout
      end
    end

    context 'when processing a finished import raises an error' do
      before do
        allow(ProjectImportState).to receive(:where).and_return(
          [instance_double(ProjectImportState)].tap do |arr|
            allow(arr).to receive(:pluck).and_return([[project.id, 'finished', nil]])
          end
        )
        allow(project).to receive(:reset).and_raise(StandardError, 'Reset failed')
      end

      it 'catches the error and continues' do
        expect { wait }.to output(/FAILED/).to_stdout
      end
    end
  end

  describe '.strip_to_commit' do
    let_it_be(:project) { create(:project, :small_repo, namespace: subgroup) }
    let(:raw_repo) { instance_double(Gitlab::Git::Repository) }

    before do
      allow(project.repository).to receive(:raw_repository).and_return(raw_repo)
      allow(raw_repo).to receive(:write_ref)
      allow(project.repository).to receive(:expire_all_method_caches)
    end

    context 'when base_commit does not exist in the repository' do
      it 'raises an error' do
        allow(project.repository).to receive_messages(root_ref: 'main', commit: nil)

        expect do
          described_class.strip_to_commit(project, base_commit, user)
        end.to raise_error(/base_commit.*not found/)
      end
    end

    context 'when base_commit exists' do
      let(:commit) { instance_double(Commit, id: base_commit) }

      before do
        allow(project.repository).to receive(:branch_names).and_return(['main'], ['main'])
        allow(project.repository).to receive(:delete_refs)
        allow(project.repository).to receive_messages(commit: commit, tag_names: [], root_ref: 'main')
      end

      it 'force-resets the default branch to base_commit' do
        expect(raw_repo).to receive(:write_ref).with('main', base_commit)
        described_class.strip_to_commit(project, base_commit, user)
      end

      it 'deletes all non-default branches' do
        allow(project.repository).to receive(:branch_names).and_return(%w[main other], ['main'])
        expect(project.repository).to receive(:delete_refs).with("refs/heads/other")
        described_class.strip_to_commit(project, base_commit, user)
      end

      it 'deletes all tags' do
        allow(project.repository).to receive(:tag_names).and_return(['v1.0'], [])
        expect(project.repository).to receive(:delete_refs).with("refs/tags/v1.0")
        described_class.strip_to_commit(project, base_commit, user)
      end
    end

    context 'when verification fails after reset' do
      let(:commit) { instance_double(Commit, id: base_commit) }
      let(:wrong_commit) { instance_double(Commit, id: 'wrongsha') }

      before do
        allow(project.repository).to receive(:commit).and_return(commit, wrong_commit)
        allow(project.repository).to receive(:branch_names).and_return(['main'], ['main'])
        allow(project.repository).to receive_messages(tag_names: [], root_ref: 'main')
      end

      it 'raises an error' do
        expect do
          described_class.strip_to_commit(project, base_commit, user)
        end.to raise_error(/HEAD mismatch|strip_to_commit failed/)
      end
    end
  end

  describe '.ensure_mirror' do
    let(:repository_url) { 'https://github.com/django/django.git' }
    let(:repo) { 'django/django' }

    before do
      allow(Project).to receive(:find_by_full_path)
        .with("#{mirrors_group.full_path}/django")
        .and_return(mirror)
    end

    context 'when mirror exists with a valid repository' do
      before do
        allow(mirror.repository).to receive_messages(exists?: true, commit: instance_double(Commit))
      end

      it 'returns the existing mirror without re-creating' do
        expect(::Projects::DestroyService).not_to receive(:new)
        expect(::Projects::CreateService).not_to receive(:new)

        result = described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user)
        expect(result).to eq(mirror)
      end
    end

    context 'when mirror exists but repository is empty' do
      let(:new_mirror) { create(:project, namespace: mirrors_group, name: 'django-new') }

      before do
        allow(mirror.repository).to receive_messages(exists?: true, commit: nil)
        destroy_service = instance_double(::Projects::DestroyService, execute: true)
        allow(::Projects::DestroyService).to receive(:new).with(mirror, user).and_return(destroy_service)
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: new_mirror)
        )
        allow(described_class).to receive(:wait_for_single_import).and_return(true)
      end

      it 'destroys the broken mirror and re-creates it' do
        expect(::Projects::DestroyService).to receive(:new).with(mirror, user)
        expect(::Projects::CreateService).to receive(:new)

        described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user)
      end
    end

    context 'when mirror exists but repository does not exist on disk' do
      let(:new_mirror) { create(:project, namespace: mirrors_group, name: 'django-new') }

      before do
        allow(mirror.repository).to receive_messages(exists?: false)
        destroy_service = instance_double(::Projects::DestroyService, execute: true)
        allow(::Projects::DestroyService).to receive(:new).with(mirror, user).and_return(destroy_service)
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: new_mirror)
        )
        allow(described_class).to receive(:wait_for_single_import).and_return(true)
      end

      it 'destroys the broken mirror and re-creates it' do
        expect(::Projects::DestroyService).to receive(:new).with(mirror, user)

        described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user)
      end
    end

    context 'when no existing mirror exists' do
      let(:new_mirror) { create(:project, namespace: mirrors_group, name: 'django-new') }

      before do
        allow(Project).to receive(:find_by_full_path).and_return(nil)
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: new_mirror)
        )
        allow(described_class).to receive(:wait_for_single_import).and_return(true)
      end

      it 'creates a new mirror' do
        expect(::Projects::CreateService).to receive(:new)
        result = described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user)
        expect(result).to eq(new_mirror)
      end
    end

    context 'when project creation fails with errors' do
      let(:failed_project) do
        build_stubbed(:project).tap do |p|
          allow(p).to receive(:errors).and_return(
            instance_double(ActiveModel::Errors, any?: true, full_messages: ['Name has already been taken'])
          )
        end
      end

      before do
        allow(Project).to receive(:find_by_full_path).and_return(nil)
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: failed_project)
        )
      end

      it 'returns nil and logs the error' do
        expect { described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user) }
          .to output(/Failed to create mirror/).to_stdout
      end
    end

    context 'when wait_for_single_import returns false' do
      let(:new_mirror) { create(:project, namespace: mirrors_group, name: 'django-new') }

      before do
        allow(Project).to receive(:find_by_full_path).and_return(nil)
        allow(::Projects::CreateService).to receive(:new).and_return(
          instance_double(::Projects::CreateService, execute: new_mirror)
        )
        allow(described_class).to receive(:wait_for_single_import).and_return(false)
      end

      it 'returns nil' do
        result = described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user)
        expect(result).to be_nil
      end
    end

    context 'when an exception is raised' do
      before do
        allow(Project).to receive(:find_by_full_path).and_raise(StandardError, 'Database error')
      end

      it 'returns nil and logs the error' do
        expect { described_class.ensure_mirror(repository_url, repo, mirrors_group, subgroup, user) }
          .to output(/Error creating mirror/).to_stdout
      end
    end
  end

  describe '.wait_for_single_import' do
    let(:project) { create(:project, namespace: subgroup) }

    subject(:wait) { described_class.wait_for_single_import(project, max_wait_seconds: 5, poll_interval: 0) }

    context 'when import finishes' do
      it 'returns true' do
        state = instance_double(ProjectImportState, status: 'finished', finished?: true, failed?: false,
          canceled?: false)
        allow(ProjectImportState).to receive(:find_by).and_return(state)
        expect(wait).to be true
      end
    end

    context 'when import fails' do
      it 'returns false' do
        state = instance_double(ProjectImportState, status: 'failed', finished?: false, failed?: true,
          canceled?: false)
        allow(ProjectImportState).to receive(:find_by).and_return(state)
        expect(wait).to be false
      end
    end

    context 'when timeout is exceeded' do
      it 'returns false' do
        state = instance_double(ProjectImportState, status: 'started', finished?: false, failed?: false,
          canceled?: false)
        allow(ProjectImportState).to receive(:find_by).and_return(state)
        expect(wait).to be false
      end
    end

    context 'when import is canceled' do
      it 'returns false' do
        state = instance_double(ProjectImportState, status: 'canceled', finished?: false, failed?: false,
          canceled?: true)
        allow(ProjectImportState).to receive(:find_by).and_return(state)
        expect(wait).to be false
      end
    end

    context 'when state is nil' do
      it 'continues polling until timeout' do
        allow(ProjectImportState).to receive(:find_by).and_return(nil)
        expect(wait).to be false
      end
    end

    context 'when an exception is raised' do
      before do
        allow(ProjectImportState).to receive(:find_by).and_raise(StandardError, 'Database error')
      end

      it 'returns false and logs the error' do
        expect { wait }.to output(/Error waiting for mirror import/).to_stdout
        expect(wait).to be false
      end
    end
  end

  describe '.verify_strip!' do
    let_it_be(:project) { create(:project, :small_repo, namespace: subgroup) }
    let(:expected_sha) { 'abc123def456abc123def456abc123def456abc1' }
    let(:default_branch) { 'main' }

    before do
      allow(project.repository).to receive(:expire_all_method_caches)
    end

    context 'when HEAD SHA does not match expected SHA' do
      let(:wrong_commit) { instance_double(Commit, id: 'wrongsha') }

      before do
        allow(project.repository).to receive(:commit).with(default_branch).and_return(wrong_commit)
      end

      it 'raises an error' do
        expect { described_class.verify_strip!(project, expected_sha, default_branch) }
          .to raise_error(/HEAD mismatch/)
      end
    end

    context 'when branch count is not 1' do
      let(:correct_commit) { instance_double(Commit, id: expected_sha) }

      before do
        allow(project.repository).to receive(:commit).with(default_branch).and_return(correct_commit)
        allow(project.repository).to receive(:branch_names).and_return(%w[main develop])
      end

      it 'raises an error' do
        expect { described_class.verify_strip!(project, expected_sha, default_branch) }
          .to raise_error(/Expected 1 branch/)
      end
    end

    context 'when tag count is not 0' do
      let(:correct_commit) { instance_double(Commit, id: expected_sha) }

      before do
        allow(project.repository).to receive(:commit).with(default_branch).and_return(correct_commit)
        allow(project.repository).to receive_messages(branch_names: ['main'], tag_names: ['v1.0'])
      end

      it 'raises an error' do
        expect { described_class.verify_strip!(project, expected_sha, default_branch) }
          .to raise_error(/Expected 0 tags/)
      end
    end

    context 'when commit returns nil' do
      before do
        allow(project.repository).to receive(:commit).with(default_branch).and_return(nil)
      end

      it 'raises an error due to nil id' do
        expect { described_class.verify_strip!(project, expected_sha, default_branch) }
          .to raise_error(/HEAD mismatch/)
      end
    end

    context 'when all verifications pass' do
      let(:correct_commit) { instance_double(Commit, id: expected_sha) }

      before do
        allow(project.repository).to receive(:commit).with(default_branch).and_return(correct_commit)
        allow(project.repository).to receive_messages(branch_names: ['main'], tag_names: [])
      end

      it 'does not raise an error' do
        expect { described_class.verify_strip!(project, expected_sha, default_branch) }.not_to raise_error
      end
    end
  end
end
