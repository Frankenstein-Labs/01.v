# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper, feature_category: :global_search do
  let(:migration_class) do
    Class.new(Elastic::Migration) do
      include ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper

      batch_size 10_000

      def index_name
        Repository.__elasticsearch__.index_name
      end

      def field_name
        'traversal_ids'
      end

      def document_type_value
        'commit'
      end

      def update_script(project)
        {
          source: "ctx._source.traversal_ids = params.traversal_ids",
          params: { traversal_ids: project.namespace_ancestry }
        }
      end

      def batch_update_script(projects)
        # Convert project IDs to strings to match rid keyword field in Elasticsearch
        project_values = projects.index_by { |p| p.id.to_s }.transform_values(&:namespace_ancestry)

        {
          source: "ctx._source.traversal_ids = params.project_values[ctx._source.rid.toString()]",
          params: { project_values: project_values }
        }
      end
    end
  end

  subject(:migration) { migration_class.new(20260216153009) }

  describe '#document_type_value' do
    it 'raises NotImplementedError when not overridden' do
      migration_without_overrides = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper
      end.new(20260216153009)

      expect { migration_without_overrides.send(:document_type_value) }.to raise_error(NotImplementedError)
    end
  end

  describe '#field_name' do
    it 'raises NotImplementedError when not overridden' do
      migration_without_overrides = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper
      end.new(20260216153009)

      expect { migration_without_overrides.send(:field_name) }.to raise_error(NotImplementedError)
    end
  end

  describe '#build_query' do
    it 'always includes a type filter' do
      query = migration.send(:build_query)

      expect(query[:bool][:filter]).to include({ term: { type: 'commit' } })
    end

    it 'builds the missing field query from field_name' do
      query = migration.send(:build_query)

      expect(query[:bool][:must_not]).to eq([{ exists: { field: 'traversal_ids' } }])
    end

    it 'excludes project ids using the project_id_field' do
      exclude_ids = %w[1 2]
      query = migration.send(:build_query, exclude_ids)

      expect(query[:bool][:must_not]).to include({ terms: { 'rid' => exclude_ids } })
      expect(query[:bool][:filter]).to include({ term: { type: 'commit' } })
    end
  end

  describe '#migrate' do
    let(:projects_in_progress) { [] }

    before do
      allow(migration).to receive_messages(
        get_projects_in_progress: projects_in_progress,
        set_migration_state: nil,
        remaining_documents_count: 100,
        max_concurrent_tasks: 5,
        completed?: false,
        log: nil
      )
    end

    context 'when projects in progress exceed max concurrent tasks' do
      let(:projects_in_progress) do
        Array.new(5) { |i| { project_id: i.to_s, task_id: "task#{i}" } }
      end

      it 'skips migration and logs the reason' do
        expect(migration).to receive(:log).with(
          "Skipping migration: projects already in progress",
          projects_in_progress: 5,
          limit: 5
        )

        migration.migrate

        expect(migration).not_to have_received(:completed?)
      end

      it 'still updates migration state with current progress' do
        expect(migration).to receive(:set_migration_state).with(
          projects_in_progress: projects_in_progress,
          documents_remaining: 100
        )

        migration.migrate
      end
    end

    context 'when migration is completed' do
      before do
        allow(migration).to receive(:completed?).and_return(true)
      end

      it 'does not proceed to migrate' do
        allow(migration).to receive(:current_phase)

        migration.migrate

        expect(migration).not_to have_received(:current_phase)
      end
    end

    context 'when in safe_mode phase' do
      before do
        allow(migration).to receive_messages(
          current_phase: :safe_mode,
          migrate_safe_mode: nil
        )
      end

      it 'calls migrate_safe_mode with projects in progress' do
        migration.migrate

        expect(migration).to have_received(:migrate_safe_mode).with(projects_in_progress)
      end
    end

    context 'when in speed_mode phase' do
      before do
        allow(migration).to receive_messages(
          current_phase: :speed_mode,
          migrate_speed_mode: nil
        )
      end

      it 'calls migrate_speed_mode with projects in progress' do
        migration.migrate

        expect(migration).to have_received(:migrate_speed_mode).with(projects_in_progress)
      end
    end

    context 'when current_phase returns unexpected value' do
      before do
        allow(migration).to receive_messages(
          current_phase: :unknown_phase,
          migrate_safe_mode: nil,
          migrate_speed_mode: nil
        )
      end

      it 'does not call any migration method' do
        migration.migrate

        expect(migration).not_to have_received(:migrate_safe_mode)
        expect(migration).not_to have_received(:migrate_speed_mode)
      end
    end
  end

  describe '#batch_size' do
    it 'returns the value from migration_state when set' do
      allow(migration).to receive(:migration_state).and_return({ batch_size: 5_000 })

      expect(migration.batch_size).to eq(5_000)
    end

    it 'falls back to the class-level batch_size when migration_state does not set it' do
      allow(migration).to receive(:migration_state).and_return({})

      expect(migration.batch_size).to eq(10_000)
    end
  end

  describe '#remaining_documents_count' do
    let(:helper) { instance_double(Search::Elastic::Helper) }
    let(:client) { instance_double(Gitlab::Search::Client) }

    before do
      allow(migration).to receive_messages(helper: helper, client: client, index_name: 'test-index')
      allow(helper).to receive(:refresh_index)
      allow(client).to receive(:count).and_return({ 'count' => 42 })
    end

    it 'refreshes the index and returns the document count' do
      expect(migration.send(:remaining_documents_count)).to eq(42)

      expect(helper).to have_received(:refresh_index).with(index_name: 'test-index')
    end
  end

  describe '#max_projects_to_process' do
    it 'returns value from migration_state when set' do
      allow(migration).to receive(:migration_state).and_return({ max_projects_to_process: 100 })

      expect(migration.send(:max_projects_to_process)).to eq(100)
    end

    it 'falls back to DEFAULT_MAX_PROJECTS_TO_PROCESS' do
      allow(migration).to receive(:migration_state).and_return({})

      expect(migration.send(:max_projects_to_process)).to eq(described_class::DEFAULT_MAX_PROJECTS_TO_PROCESS)
    end
  end

  describe '#max_concurrent_tasks' do
    it 'returns minimum of migration_state value and shard count' do
      allow(migration).to receive_messages(migration_state: { max_concurrent_tasks: 100 }, get_number_of_shards: 50)

      expect(migration.send(:max_concurrent_tasks)).to eq(50)
    end

    it 'returns requested value when shard count is higher' do
      allow(migration).to receive_messages(migration_state: { max_concurrent_tasks: 25 }, get_number_of_shards: 50)

      expect(migration.send(:max_concurrent_tasks)).to eq(25)
    end

    it 'falls back to max_projects_to_process and applies shard limit' do
      allow(migration).to receive_messages(migration_state: { max_projects_to_process: 75 }, get_number_of_shards: 50)

      expect(migration.send(:max_concurrent_tasks)).to eq(50)
    end
  end

  describe '#speed_mode_batch_size' do
    it 'returns value from migration_state when set' do
      allow(migration).to receive(:migration_state).and_return({ speed_mode_batch_size: 20_000 })

      expect(migration.send(:speed_mode_batch_size)).to eq(20_000)
    end

    it 'falls back to DEFAULT_SPEED_MODE_BATCH_SIZE' do
      allow(migration).to receive(:migration_state).and_return({})

      expect(migration.send(:speed_mode_batch_size)).to eq(described_class::DEFAULT_SPEED_MODE_BATCH_SIZE)
    end
  end

  describe '#large_project_threshold' do
    it 'returns value from migration_state when set' do
      allow(migration).to receive(:migration_state).and_return({ large_project_threshold: 15_000 })

      expect(migration.send(:large_project_threshold)).to eq(15_000)
    end

    it 'falls back to LARGE_PROJECT_THRESHOLD' do
      allow(migration).to receive(:migration_state).and_return({})

      expect(migration.send(:large_project_threshold)).to eq(described_class::LARGE_PROJECT_THRESHOLD)
    end
  end

  describe '#update_script' do
    it 'raises NotImplementedError when not overridden' do
      migration_without_overrides = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper
      end.new(20260216153009)

      project = build(:project)

      expect { migration_without_overrides.send(:update_script, project) }.to raise_error(NotImplementedError)
    end
  end

  describe '#batch_update_script' do
    it 'raises NotImplementedError when not overridden' do
      migration_without_overrides = Class.new(Elastic::Migration) do
        include ::Search::Elastic::MigrationProjectScopedUpdateByQueryHelper
      end.new(20260216153009)

      expect { migration_without_overrides.send(:batch_update_script, []) }.to raise_error(NotImplementedError)
    end
  end

  describe '#create_project_batches' do
    let(:projects_with_counts) do
      {
        1 => 5_000,
        2 => 3_000,
        3 => 8_000,
        4 => 1_000,
        5 => 2_000,
        6 => 4_000
      }
    end

    before do
      allow(migration).to receive(:speed_mode_batch_size).and_return(10_000)
    end

    it 'creates batches that respect speed_mode_batch_size' do
      batches = migration.send(:create_project_batches, projects_with_counts, 10)

      # Batch 1: [1:5000, 2:3000] = 8000 docs
      # Batch 2: [3:8000, 4:1000] = 9000 docs (fits under 10000)
      # Batch 3: [5:2000, 6:4000] = 6000 docs
      expect(batches.size).to eq(3)
      expect(batches[0]).to eq({ 1 => 5_000, 2 => 3_000 })
      expect(batches[1]).to eq({ 3 => 8_000, 4 => 1_000 })
      expect(batches[2]).to eq({ 5 => 2_000, 6 => 4_000 })
    end

    it 'limits the number of batches created' do
      batches = migration.send(:create_project_batches, projects_with_counts, 2)

      expect(batches.size).to eq(2)
    end

    it 'handles empty input' do
      batches = migration.send(:create_project_batches, {}, 10)

      expect(batches).to be_empty
    end

    it 'handles projects larger than speed_mode_batch_size' do
      large_projects = { 1 => 15_000, 2 => 12_000 }

      batches = migration.send(:create_project_batches, large_projects, 10)

      # Each large project gets its own batch
      expect(batches.size).to eq(2)
      expect(batches[0]).to eq({ 1 => 15_000 })
      expect(batches[1]).to eq({ 2 => 12_000 })
    end

    it 'skips projects with zero or negative document counts' do
      projects = {
        1 => 5_000,
        2 => 0,
        3 => -100,
        4 => 3_000
      }

      batches = migration.send(:create_project_batches, projects, 10)

      # Only projects 1 and 4 should be included
      expect(batches.size).to eq(1)
      expect(batches[0]).to eq({ 1 => 5_000, 4 => 3_000 })
    end

    it 'flushes current batch when encountering large project with existing batch' do
      projects = {
        1 => 3_000,
        2 => 2_000,
        3 => 15_000, # Large project when batch already has items
        4 => 4_000
      }

      batches = migration.send(:create_project_batches, projects, 10)

      # Batch 1: [1:3000, 2:2000] = 5000 docs (flushed before large project)
      # Batch 2: [3:15000] (large project gets own batch)
      # Batch 3: [4:4000]
      expect(batches.size).to eq(3)
      expect(batches[0]).to eq({ 1 => 3_000, 2 => 2_000 })
      expect(batches[1]).to eq({ 3 => 15_000 })
      expect(batches[2]).to eq({ 4 => 4_000 })
    end

    it 'stops creating batches when max_batches is reached after flushing' do
      projects = {
        1 => 3_000,
        2 => 2_000,
        3 => 15_000, # Large project - will trigger flush
        4 => 4_000,
        5 => 2_000
      }

      batches = migration.send(:create_project_batches, projects, 2)

      # Should only create 2 batches and stop
      expect(batches.size).to eq(2)
      expect(batches[0]).to eq({ 1 => 3_000, 2 => 2_000 })
      expect(batches[1]).to eq({ 3 => 15_000 })
      # Projects 4 and 5 are not included because max_batches reached
    end

    it 'does not add large project when max_batches is already reached' do
      projects = {
        1 => 5_000,
        2 => 4_000,
        3 => 15_000 # Large project, but max_batches already at limit
      }

      batches = migration.send(:create_project_batches, projects, 1)

      # Only first batch is created
      expect(batches.size).to eq(1)
      expect(batches[0]).to eq({ 1 => 5_000, 2 => 4_000 })
    end

    it 'skips large projects when max_batches already reached from previous large project' do
      projects = {
        1 => 15_000, # First large project - will be added
        2 => 12_000, # Second large project - max_batches reached, won't be added
        3 => 11_000  # Third large project - also won't be added
      }

      batches = migration.send(:create_project_batches, projects, 1)

      # Only the first large project should be added
      expect(batches.size).to eq(1)
      expect(batches[0]).to eq({ 1 => 15_000 })
      # Projects 2 and 3 are not added because max_batches (1) is already reached
    end

    it 'breaks after reaching max_batches limit during regular batching' do
      projects = {
        1 => 8_000,
        2 => 1_000,
        3 => 8_000,
        4 => 1_000,
        5 => 5_000 # This would exceed max_batches
      }

      batches = migration.send(:create_project_batches, projects, 2)

      expect(batches.size).to eq(2)
      expect(batches[0]).to eq({ 1 => 8_000, 2 => 1_000 })
      expect(batches[1]).to eq({ 3 => 8_000, 4 => 1_000 })
      # Project 5 is not included
    end
  end

  describe '#search_projects_with_counts' do
    let(:client) { instance_double(Gitlab::Search::Client) }
    let(:search_results) do
      {
        'aggregations' => {
          'project_ids' => {
            'buckets' => [
              { 'key' => 1, 'doc_count' => 5_000 },
              { 'key' => 2, 'doc_count' => 3_000 }
            ]
          }
        }
      }
    end

    before do
      allow(migration).to receive_messages(client: client, index_name: 'test-index')
      allow(client).to receive(:search).and_return(search_results)
    end

    it 'returns a hash of project_id => document_count' do
      result = migration.send(:search_projects_with_counts, exclude_project_ids: [])

      expect(result).to eq({ 1 => 5_000, 2 => 3_000 })
    end

    it 'queries with the correct size multiplier' do
      allow(migration).to receive(:max_projects_to_process).and_return(50)

      migration.send(:search_projects_with_counts, exclude_project_ids: [])

      expect(client).to have_received(:search) do |args|
        expect(args[:body][:aggs][:project_ids][:terms][:size]).to eq(100)
      end
    end

    it 'returns empty hash when no projects found' do
      allow(client).to receive(:search).and_return({ 'aggregations' => { 'project_ids' => { 'buckets' => [] } } })

      result = migration.send(:search_projects_with_counts, exclude_project_ids: [])

      expect(result).to eq({})
    end
  end

  describe '#current_phase' do
    before do
      allow(migration).to receive_messages(
        get_projects_in_progress: [],
        large_project_threshold: 10_000,
        set_migration_state: nil,
        migration_state: {}
      )
    end

    it 'returns :safe_mode when large projects exist' do
      allow(migration).to receive(:search_projects_with_counts)
        .and_return({ 1 => 15_000, 2 => 5_000 })

      expect(migration.send(:current_phase)).to eq(:safe_mode)
    end

    it 'returns :speed_mode when only small projects exist' do
      allow(migration).to receive(:search_projects_with_counts)
        .and_return({ 1 => 5_000, 2 => 3_000 })

      expect(migration.send(:current_phase)).to eq(:speed_mode)
    end

    it 'returns :speed_mode when no projects exist' do
      allow(migration).to receive(:search_projects_with_counts).and_return({})

      expect(migration.send(:current_phase)).to eq(:speed_mode)
    end

    it 'excludes projects already in progress' do
      in_progress = [{ project_id: '5' }, { project_id: '6' }]
      allow(migration).to receive_messages(
        get_projects_in_progress: in_progress,
        search_projects_with_counts: {}
      )

      migration.send(:current_phase)

      expect(migration).to have_received(:search_projects_with_counts)
        .with(exclude_project_ids: %w[5 6])
    end

    context 'with caching' do
      it 'returns cached phase when cache is valid' do
        cached_time = 30.seconds.from_now.utc.iso8601
        allow(migration).to receive(:migration_state).and_return({
          current_phase: 'safe_mode',
          phase_cache_expires_at: cached_time
        })
        allow(migration).to receive(:search_projects_with_counts)

        result = migration.send(:current_phase)

        expect(result).to eq(:safe_mode)
        expect(migration).not_to have_received(:search_projects_with_counts)
      end

      it 'recomputes phase when cache is expired' do
        expired_time = 30.seconds.ago.utc.iso8601
        allow(migration).to receive_messages(migration_state: {
          current_phase: 'safe_mode',
          phase_cache_expires_at: expired_time
        }, search_projects_with_counts: { 1 => 5_000 })

        result = migration.send(:current_phase)

        expect(result).to eq(:speed_mode)
        expect(migration).to have_received(:search_projects_with_counts)
      end

      it 'recomputes phase when cache timestamp is invalid' do
        allow(migration).to receive_messages(migration_state: {
          current_phase: 'safe_mode',
          phase_cache_expires_at: 'invalid-timestamp'
        }, search_projects_with_counts: { 1 => 5_000 })

        result = migration.send(:current_phase)

        expect(result).to eq(:speed_mode)
        expect(migration).to have_received(:search_projects_with_counts)
      end

      it 'sets cache when computing phase' do
        allow(migration).to receive(:search_projects_with_counts).and_return({ 1 => 5_000 })
        allow(Time).to receive(:now).and_return(Time.utc(2025, 1, 1, 12, 0, 0))

        migration.send(:current_phase)

        expect(migration).to have_received(:set_migration_state).with(
          hash_including(
            current_phase: :speed_mode,
            phase_cache_expires_at: '2025-01-01T12:01:00Z'
          )
        )
      end
    end
  end

  describe '#migrate_speed_mode' do
    let(:projects_in_progress) { [] }

    before do
      allow(migration).to receive_messages(
        log: nil,
        set_migration_state: nil,
        remaining_documents_count: 100,
        max_concurrent_tasks: 5,
        search_projects_with_counts: {}
      )
    end

    context 'when no available slots' do
      it 'returns early without processing' do
        projects_in_progress = [
          { project_id: '1', task_id: 'task1' },
          { project_id: '2', task_id: 'task2' },
          { project_id: '3', task_id: 'task3' },
          { project_id: '4', task_id: 'task4' },
          { project_id: '5', task_id: 'task5' }
        ]

        expect(migration).not_to receive(:search_projects_with_counts)

        migration.send(:migrate_speed_mode, projects_in_progress)
      end
    end

    context 'when no projects to process' do
      it 'returns early' do
        allow(migration).to receive(:search_projects_with_counts).and_return({})

        expect(migration).not_to receive(:batch_update_script)
        expect(migration).not_to receive(:execute_multi_project_update)

        migration.send(:migrate_speed_mode, projects_in_progress)
      end
    end

    context 'when batch_update_script is supported' do
      let(:projects_with_counts) { { 1 => 1_000, 2 => 2_000 } }

      before do
        allow(migration).to receive_messages(search_projects_with_counts: projects_with_counts,
          batch_update_script: { source: 'script', params: {} }, execute_multi_project_update: 'task123')
      end

      it 'creates batches and executes multi-project updates synchronously' do
        expect(migration).to receive(:create_project_batches)
          .with(projects_with_counts, 5)
          .and_return([{ 1 => 1_000, 2 => 2_000 }])

        expect(migration).to receive(:execute_multi_project_update)
          .with([1, 2])
          .and_return(true)

        migration.send(:migrate_speed_mode, projects_in_progress)

        # Speed mode processes synchronously - no tracking in projects_in_progress
        expect(projects_in_progress.size).to eq(0)
      end

      it 'processes all batches synchronously' do
        batches = [
          { 1 => 1_000 },
          { 2 => 2_000 },
          { 3 => 3_000 }
        ]
        allow(migration).to receive(:create_project_batches).and_return(batches)

        # All batches processed synchronously
        expect(migration).to receive(:execute_multi_project_update).exactly(3).times.and_return(true)

        migration.send(:migrate_speed_mode, projects_in_progress)

        # No tracking needed for synchronous execution
        expect(projects_in_progress.size).to eq(0)
      end

      it 'skips batches when execute_multi_project_update returns nil' do
        allow(migration).to receive(:create_project_batches)
          .and_return([{ 1 => 1_000 }, { 2 => 2_000 }])
        allow(migration).to receive(:execute_multi_project_update).and_return(nil, true)

        migration.send(:migrate_speed_mode, projects_in_progress)

        # Synchronous execution completes both batches (one fails, one succeeds)
        expect(projects_in_progress.size).to eq(0)
      end
    end
  end

  describe '#execute_multi_project_update' do
    let(:client) { instance_double(Gitlab::Search::Client) }

    before do
      allow(migration).to receive_messages(
        client: client,
        index_name: 'test-index',
        multi_project_script: { source: 'script', params: {} },
        speed_mode_batch_size: 10_000,
        log_warn: nil
      )
    end

    it 'returns nil when project_ids is empty' do
      allow(client).to receive(:update_by_query)

      result = migration.send(:execute_multi_project_update, [])

      expect(result).to be_nil
      expect(client).not_to have_received(:update_by_query)
    end

    it 'executes update_by_query with correct parameters' do
      allow(client).to receive(:update_by_query).and_return({ 'updated' => 10 })

      result = migration.send(:execute_multi_project_update, [1, 2])

      expect(result).to be true
      expect(client).to have_received(:update_by_query) do |args|
        expect(args[:index]).to eq('test-index')
        expect(args[:wait_for_completion]).to be true
        expect(args[:max_docs]).to be_nil
        expect(args[:body][:query][:bool][:filter]).to include({ terms: { 'rid' => %w[1 2] } })
      end
    end

    it 'returns nil when response has failures' do
      allow(client).to receive(:update_by_query).and_return({ 'failures' => ['error'] })

      result = migration.send(:execute_multi_project_update, [1, 2])

      expect(result).to be_nil
      expect(migration).to have_received(:log_warn).with(
        "update_by_query failed for batched projects",
        project_ids: [1, 2],
        error_message: ['error']
      )
    end
  end

  describe '#multi_project_script' do
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }

    it 'loads projects and passes them to batch_update_script' do
      expected_script = { source: 'test_script', params: {} }
      expect(migration).to receive(:batch_update_script)
        .with(match_array([project1, project2]))
        .and_return(expected_script)

      result = migration.send(:multi_project_script, [project1.id, project2.id])

      expect(result).to eq(expected_script)
    end
  end

  describe '#migrate_safe_mode' do
    let(:projects_in_progress) { [] }

    before do
      allow(migration).to receive_messages(
        log: nil,
        enqueue_tasks_for_projects: [{ project_id: '1', task_id: 'task1' }],
        set_migration_state: nil,
        remaining_documents_count: 100
      )
    end

    it 'logs safe mode message' do
      expect(migration).to receive(:log).with("Running migration in safe mode (processing large projects)")

      migration.send(:migrate_safe_mode, projects_in_progress)
    end

    it 'delegates to enqueue_tasks_for_projects' do
      expect(migration).to receive(:enqueue_tasks_for_projects).with(projects_in_progress)

      migration.send(:migrate_safe_mode, projects_in_progress)
    end

    it 'updates migration state with new projects and document count' do
      expect(migration).to receive(:set_migration_state).with(
        projects_in_progress: [{ project_id: '1', task_id: 'task1' }],
        documents_remaining: 100
      )

      migration.send(:migrate_safe_mode, projects_in_progress)
    end
  end

  describe 'speed mode batching with max_docs', :aggregate_failures do
    let(:client) { instance_double(Gitlab::Search::Client) }
    let(:projects_in_progress) { [] }

    before do
      allow(migration).to receive_messages(
        client: client,
        index_name: 'test-index',
        log: nil,
        set_migration_state: nil,
        max_concurrent_tasks: 5,
        multi_project_script: { source: 'script', params: {} }
      )
    end

    context 'when batching multiple small projects' do
      it 'does not set max_docs to avoid incomplete updates' do
        allow(migration).to receive_messages(
          speed_mode_batch_size: 10_000,
          remaining_documents_count: 8_000,
          search_projects_with_counts: { 1 => 3_000, 2 => 5_000 }
        )
        allow(client).to receive(:update_by_query).and_return({ 'task' => 'task123' })

        migration.send(:migrate_speed_mode, projects_in_progress)

        expect(client).to have_received(:update_by_query) do |args|
          expect(args[:max_docs]).to be_nil
        end
      end
    end

    context 'when project exceeds speed_mode_batch_size' do
      it 'does not set max_docs to ensure all documents are updated' do
        allow(migration).to receive_messages(
          large_project_threshold: 20_000,
          speed_mode_batch_size: 10_000,
          remaining_documents_count: 15_000,
          search_projects_with_counts: { 1 => 15_000 }
        )
        allow(client).to receive(:update_by_query).and_return({ 'task' => 'task123' })

        migration.send(:migrate_speed_mode, projects_in_progress)

        expect(client).to have_received(:update_by_query) do |args|
          expect(args[:max_docs]).to be_nil
        end
      end
    end
  end
end
