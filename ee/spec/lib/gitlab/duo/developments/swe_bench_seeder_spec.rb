# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder, feature_category: :duo_chat do
  let(:config_class) { Gitlab::Duo::Developments::SweBenchSeeder::Config }

  describe '.ensure_local_url_allowed' do
    let(:settings) do
      instance_double(ApplicationSetting, outbound_local_requests_whitelist: existing_allowlist)
    end

    before do
      allow(config_class).to receive(:seed_base_url).and_return(seed_url)
      allow(ApplicationSetting).to receive(:current_without_cache).and_return(settings)
    end

    context 'when seed_host is nil' do
      let(:seed_url) { 'invalid-url-without-host' }
      let(:existing_allowlist) { [] }

      before do
        allow(URI).to receive(:parse).and_return(instance_double(URI::Generic, host: nil))
      end

      it 'returns early without updating settings' do
        expect(settings).not_to receive(:update!)
        described_class.ensure_local_url_allowed
      end
    end

    context 'when seed_host is already in allowlist' do
      let(:seed_url) { 'http://gdk.test:3000' }
      let(:existing_allowlist) { ['gdk.test'] }

      it 'returns early without updating settings' do
        expect(settings).not_to receive(:update!)
        described_class.ensure_local_url_allowed
      end
    end

    context 'when seed_host is not in allowlist' do
      let(:seed_url) { 'http://gdk.test:3000' }
      let(:existing_allowlist) { [] }

      it 'adds the host to the allowlist' do
        expect(settings).to receive(:update!).with(outbound_local_requests_whitelist: ['gdk.test'])
        expect { described_class.ensure_local_url_allowed }.to output(/Added 'gdk.test' to outbound/).to_stdout
      end
    end

    context 'when allowlist is nil' do
      let(:seed_url) { 'http://gdk.test:3000' }
      let(:existing_allowlist) { nil }

      it 'creates a new allowlist with the host' do
        expect(settings).to receive(:update!).with(outbound_local_requests_whitelist: ['gdk.test'])
        described_class.ensure_local_url_allowed
      end
    end
  end

  describe '.seed' do
    let(:user) { instance_double(User) }
    let(:parent_group) { instance_double(Group) }
    let(:subgroup) { instance_double(Group, full_path: 'gitlab-duo/swe-bench-seeded-data') }
    let(:project) do
      instance_double(Project, full_path: 'gitlab-duo/swe-bench-seeded-data/django-django-13112', persisted?: true)
    end

    let(:issue) { instance_double(Issue, iid: 1, title: 'Test Issue') }
    let(:group_manager) { Gitlab::Duo::Developments::SweBenchSeeder::GroupManager }
    let(:issue_manager) { Gitlab::Duo::Developments::SweBenchSeeder::IssueManager }
    let(:repository_manager) { Gitlab::Duo::Developments::SweBenchSeeder::RepositoryManager }
    let(:agent_config_manager) { Gitlab::Duo::Developments::SweBenchSeeder::AgentConfigManager }
    let(:dataset_processor) { Gitlab::Duo::Developments::SweBenchSeeder::DatasetProcessor }

    let(:example) do
      {
        'inputs' => {
          'instance_id' => 'django__django-13112',
          'repo' => 'django/django',
          'base_commit' => 'abc123',
          'problem_statement' => 'Fix the bug'
        },
        'outputs' => { 'solution' => 'patch' }
      }
    end

    before do
      allow(User).to receive(:find_by_username).with('root').and_return(user)
      allow(group_manager).to receive_messages(
        find_or_create_parent_group: parent_group,
        find_or_create_subgroup: subgroup
      )
      allow(config_class).to receive_messages(
        seed_base_url: 'http://gdk.test:3000',
        source_base_url: 'https://github.com'
      )
      allow(described_class).to receive(:ensure_local_url_allowed)
      # Stub out the foundational-flow provisioning step so unrelated seeder
      # examples don't need to set up the catalog services, cascade worker,
      # and admin-user policy checks that it depends on.
      allow(described_class).to receive(:ensure_developer_foundational_flow!)
      allow(issue_manager).to receive(:destroy_instance_projects)
      # rubocop:disable RSpec/VerifiedDoubles -- UrlHelpers is a module, not a class
      allow(Rails.application.routes).to receive(:url_helpers).and_return(
        double(project_issue_url: 'http://gdk.test:3000/gitlab-duo/swe-bench-seeded-data/django-django-13112/-/issues/1')
      )
      # rubocop:enable RSpec/VerifiedDoubles
    end

    context 'when dataset is empty' do
      before do
        allow(dataset_processor).to receive(:fetch_dataset_from_langsmith).and_return([[], 'test-dataset', 'split'])
      end

      it 'returns early without processing' do
        expect(repository_manager).not_to receive(:setup_instance_projects)
        described_class.seed
      end
    end

    context 'when dataset has examples missing required fields' do
      let(:incomplete_dataset) do
        [
          { 'inputs' => { 'repo' => 'org/repo', 'base_commit' => 'abc' }, 'outputs' => {} },
          { 'inputs' => { 'instance_id' => 'x', 'repo' => 'org/repo', 'base_commit' => 'abc' }, 'outputs' => {} }
        ]
      end

      before do
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [incomplete_dataset, 'ds', 'sp'],
          filter_by_project: incomplete_dataset)
      end

      it 'filters out examples without required fields before passing to repository_manager' do
        expect(repository_manager).to receive(:setup_instance_projects).with([], subgroup, user).and_return({})
        described_class.seed
      end
    end

    context 'when seeding completes successfully' do
      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [[example], 'test-dataset',
          'split'], filter_by_project: [example])
        allow(repository_manager).to receive(:setup_instance_projects).and_return(
          { 'django__django-13112' => project }
        )
        allow(agent_config_manager).to receive(:commit_agent_config)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
      end

      it 'commits agent config for each seeded project' do
        described_class.seed
        expect(agent_config_manager).to have_received(:commit_agent_config).with(project, user,
          instance_id: 'django__django-13112')
      end

      it 'creates an issue for each seeded project' do
        described_class.seed
        expect(issue_manager).to have_received(:create_issue_from_problem_statement).with(project, user, 'Fix the bug')
      end

      it 'prints seeding complete summary' do
        expect { described_class.seed }.to output(%r{SEEDING COMPLETE: 1/1 project}).to_stdout
      end
    end

    context 'when issue creation returns nil' do
      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [[example], 'test-dataset',
          'split'], filter_by_project: [example])
        allow(repository_manager).to receive(:setup_instance_projects).and_return(
          { 'django__django-13112' => project }
        )
        allow(agent_config_manager).to receive(:commit_agent_config)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(nil)
      end

      it 'skips saving to issue_data' do
        stub_env('SAVE_TO_LANGSMITH', 'target-dataset')
        expect(Gitlab::Duo::Developments::SweBenchSeeder::LangsmithClient).not_to receive(:save_issue_urls_to_langsmith)
        described_class.seed
      end
    end

    context 'when SAVE_TO_LANGSMITH is set' do
      before do
        stub_env('SAVE_TO_LANGSMITH', 'target-dataset')
        allow(dataset_processor).to receive_messages(fetch_dataset_from_langsmith: [[example], 'test-dataset',
          'split'], filter_by_project: [example])
        allow(repository_manager).to receive(:setup_instance_projects).and_return(
          { 'django__django-13112' => project }
        )
        allow(agent_config_manager).to receive(:commit_agent_config)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
        allow(Gitlab::Duo::Developments::SweBenchSeeder::LangsmithClient).to receive(:save_issue_urls_to_langsmith)
      end

      it 'saves issue data to LangSmith' do
        described_class.seed
        expect(Gitlab::Duo::Developments::SweBenchSeeder::LangsmithClient)
          .to have_received(:save_issue_urls_to_langsmith)
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(dataset_processor).to receive(:fetch_dataset_from_langsmith).and_raise(StandardError, 'Test error')
      end

      it 'logs the error and re-raises it' do
        expect { described_class.seed }
          .to raise_error(StandardError, 'Test error')
          .and output(/Error seeding SWE Bench structure: Test error/).to_stdout
      end
    end

    context 'when project_filter is provided and existing project exists' do
      let(:existing_project) do
        instance_double(Project, full_path: 'gitlab-duo/swe-bench-seeded-data/django-django-13112')
      end

      let(:destroy_service) { instance_double(::Projects::DestroyService, execute: true) }

      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(
          fetch_dataset_from_langsmith: [[example], 'test-dataset', 'split'],
          filter_by_project: [example]
        )
        allow(repository_manager).to receive_messages(
          instance_id_to_project_name: 'django-django-13112',
          setup_instance_projects: { 'django__django-13112' => project }
        )
        allow(Project).to receive(:find_by_full_path)
          .with('gitlab-duo/swe-bench-seeded-data/django-django-13112')
          .and_return(existing_project)
        allow(::Projects::DestroyService).to receive(:new)
          .with(existing_project, user, {})
          .and_return(destroy_service)
        allow(agent_config_manager).to receive(:commit_agent_config)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
      end

      it 'destroys existing projects before re-seeding' do
        expect { described_class.seed(project_filter: ['django']) }
          .to output(/Destroying existing project for re-seed/).to_stdout
        expect(destroy_service).to have_received(:execute)
      end
    end

    context 'when project_filter is provided but project does not exist' do
      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(
          fetch_dataset_from_langsmith: [[example], 'test-dataset', 'split'],
          filter_by_project: [example]
        )
        allow(repository_manager).to receive_messages(
          instance_id_to_project_name: 'django-django-13112',
          setup_instance_projects: { 'django__django-13112' => project }
        )
        allow(Project).to receive(:find_by_full_path)
          .with('gitlab-duo/swe-bench-seeded-data/django-django-13112')
          .and_return(nil)
        allow(agent_config_manager).to receive(:commit_agent_config)
        allow(issue_manager).to receive(:create_issue_from_problem_statement).and_return(issue)
      end

      it 'skips destruction when project does not exist' do
        expect(::Projects::DestroyService).not_to receive(:new)
        described_class.seed(project_filter: ['django'])
      end
    end

    context 'when seeding is incomplete (fewer projects than examples)' do
      before do
        stub_env('SAVE_TO_LANGSMITH', nil)
        allow(dataset_processor).to receive_messages(
          fetch_dataset_from_langsmith: [[example], 'test-dataset', 'split'],
          filter_by_project: [example]
        )
        # Return empty hash to simulate no projects seeded
        allow(repository_manager).to receive(:setup_instance_projects).and_return({})
      end

      it 'raises an error indicating seeding is incomplete' do
        expect { described_class.seed }
          .to raise_error(RuntimeError, %r{Seeding incomplete: only 0/1 projects seeded successfully})
          .and output(%r{SEEDING COMPLETE: 0/1}).to_stdout
      end
    end
  end
end
