# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ClickHouse::DataIngestion::CiFinishedBuildsSyncService,
  :click_house, feature_category: :fleet_visibility do
  subject(:execute) { service.execute }

  let(:service) { described_class.new }

  let_it_be(:runner) { create(:ci_runner) }
  let_it_be(:runner_manager1) do
    create(:ci_runner_machine, runner: runner, version: '16.4.0', revision: 'abc', platform: 'linux',
      architecture: 'amd64')
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }

  let_it_be(:deploy_stage) { create(:ci_stage, name: 'deploy', position: 0) }
  let_it_be(:build1) { create(:ci_build, :success, runner_manager: runner_manager1, stage: deploy_stage) }
  let_it_be(:build2) { create(:ci_build, :canceled) }
  let_it_be(:build3) { create(:ci_build, :failed, runner: group_runner) }
  let_it_be(:build4) { create(:ci_build, :pending) }

  before_all do
    create_sync_events(*Ci::Build.finished.order(id: :desc))
  end

  context 'when all builds fit in a single batch' do
    it 'processes the builds' do
      expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original

      expect { execute }.to change { ci_finished_builds_row_count }.by(3)
      expect(execute).to have_attributes({
        payload: {
          reached_end_of_table: true,
          records_inserted: 3,
          worker_index: 0, total_workers: 1
        }
      })

      records = ci_finished_builds
      expect(records.count).to eq 3
      expect(records).to contain_exactly_builds(build1, build2, build3)
    end

    it 'processes only builds from Ci::FinishedBuildChSyncEvent' do
      build = create(:ci_build, :failed)

      expect { execute }.to change { ci_finished_builds_row_count }.by(3)
      expect(execute).to have_attributes({
        payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
      })

      create_sync_events(build)
      expect { service.execute }.to change { ci_finished_builds_row_count }.by(1)
    end

    context 'when a finished build has nil finished_at value' do
      it 'skips the build' do
        create(:ci_build, :failed, finished_at: nil)

        expect { execute }.to change { ci_finished_builds_row_count }.by(3)
        records = ci_finished_builds
        expect(records.count).to eq 3
        expect(records).to contain_exactly_builds(build1, build2, build3)
      end
    end

    context 'when a finished build has been deleted' do
      let!(:deleted_build) { create(:ci_build, :success, finished_at: Time.current).tap(&:destroy!) }

      it 'marks the sync event as processed' do
        sync_event = create_ci_build_sync_event(deleted_build)

        expect { execute }
          .to change { ci_finished_builds_row_count }.by(3)
          .and change { sync_event.reload.processed }.to(true)
      end
    end

    it 'sets runner_owner_namespace_id only for group runners' do
      execute

      records = ci_finished_builds
      expect(records.count).to eq 3

      expect(records).to contain_exactly(
        include(id: build1.id, runner_owner_namespace_id: 0),
        include(id: build2.id, runner_owner_namespace_id: 0),
        include(id: build3.id, runner_owner_namespace_id: group_runner.groups.first.id)
      )
    end

    context 'with build attributes syncing' do
      let_it_be(:nested_group) { create(:group, parent: group) }
      let_it_be(:nested_group_lev_3) { create(:group, parent: nested_group) }
      let_it_be(:nested_project) { create(:project, group: nested_group_lev_3) }

      describe 'namespace_path' do
        context 'when project is deeply nested' do
          let(:pipeline) { create(:ci_pipeline, project: nested_project) }
          let(:build) { create(:ci_build, :success, pipeline: pipeline, project: nested_project) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it 'syncs correct namespace_path' do
            expect(record[:namespace_path]).to eq("#{nested_project.namespace.traversal_ids.join('/')}/")
          end
        end

        context 'when ci_namespace_mirror is missing' do
          let(:group2) { create(:group) }
          let(:project2) { create(:project, group: group2) }
          let(:pipeline) { create(:ci_pipeline, project: project2) }
          let(:build) { create(:ci_build, :success, pipeline: pipeline, project: project2) }
          let(:record) { find_synced_build_record(build) }

          before do
            group2.ci_namespace_mirror.destroy!
            create_sync_events(build)
            execute
          end

          it 'syncs empty namespace_path' do
            expect(record[:namespace_path]).to eq('/')
          end
        end
      end

      describe 'failure_reason' do
        context 'when build has failed with script_failure' do
          let(:build) { create(:ci_build, :script_failure) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:failure_reason]).to eq('script_failure') }
        end

        context 'when build is successful' do
          let(:record) { find_synced_build_record(build1) }

          before do
            execute
          end

          it { expect(record[:failure_reason]).to eq('unknown_failure') }
        end
      end

      describe 'manual and when columns' do
        context 'when build is manual' do
          let(:build) { create(:ci_build, :success, :manual) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it 'syncs manual=true and when=manual' do
            expect(record[:manual]).to be_truthy
            expect(record[:when]).to eq('manual')
          end
        end

        context 'when build is not manual' do
          let(:record) { find_synced_build_record(build1) }

          before do
            execute
          end

          it 'syncs manual=false and when=on_success' do
            expect(record[:manual]).to be_falsey
            expect(record[:when]).to eq('on_success')
          end
        end
      end

      describe 'allow_failure' do
        context 'when build is allowed to fail' do
          let(:build) { create(:ci_build, :success, :allowed_to_fail) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:allow_failure]).to be_truthy }
        end

        context 'when build is not allowed to fail' do
          let(:record) { find_synced_build_record(build1) }

          before do
            execute
          end

          it { expect(record[:allow_failure]).to be_falsey }
        end
      end

      describe 'user_id' do
        context 'when build has a user' do
          let(:user) { create(:user) }
          let(:build) { create(:ci_build, :success, user: user) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:user_id]).to eq(user.id) }
        end

        context 'when build has no user' do
          let(:build) { create(:ci_build, :success, user: nil) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:user_id]).to eq(0) }
        end
      end

      describe 'artifacts_filename and artifacts_size' do
        context 'when build has artifacts' do
          let(:build) { create(:ci_build, :success, :artifacts) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it 'syncs artifact attributes' do
            expect(record[:artifacts_filename]).to eq(build.artifacts_file&.filename)
            expect(record[:artifacts_size]).to eq(build.artifacts_size)
          end
        end

        context 'when build has no artifacts' do
          let(:record) { find_synced_build_record(build1) }

          before do
            execute
          end

          it 'syncs empty values' do
            expect(record[:artifacts_filename]).to eq('')
            expect(record[:artifacts_size]).to eq(0)
          end
        end
      end

      describe 'retries_count' do
        context 'when build has no retries' do
          let(:record) { find_synced_build_record(build1) }

          before do
            execute
          end

          it { expect(record[:retries_count]).to eq(0) }
        end

        context 'when build has been retried' do
          let(:pipeline) { create(:ci_pipeline) }
          let(:final_build) { create(:ci_build, :success, pipeline: pipeline, name: 'test-job') }
          let(:record) { find_synced_build_record(final_build) }

          before do
            create(:ci_build, :success, :retried, pipeline: pipeline, name: 'test-job')
            create(:ci_build, :success, :retried, pipeline: pipeline, name: 'test-job')
            create_sync_events(final_build)
            execute
          end

          it { expect(record[:retries_count]).to eq(2) }
        end

        context 'with multiple builds and different retry counts' do
          let(:pipeline_1) { create(:ci_pipeline) }
          let(:pipeline_2) { create(:ci_pipeline) }
          let(:final_build_1) { create(:ci_build, :success, pipeline: pipeline_1, name: 'job-1') }
          let(:final_build_2) { create(:ci_build, :success, pipeline: pipeline_2, name: 'job-2') }

          let(:record_1) { find_synced_build_record(final_build_1) }
          let(:record_2) { find_synced_build_record(final_build_2) }

          before do
            # Pipeline 1: 1 retry (2 total builds)
            create(:ci_build, :success, :retried, pipeline: pipeline_1, name: 'job-1')
            # Pipeline 2: 3 retries (4 total builds)
            create(:ci_build, :success, :retried, pipeline: pipeline_2, name: 'job-2')
            create(:ci_build, :success, :retried, pipeline: pipeline_2, name: 'job-2')
            create(:ci_build, :success, :retried, pipeline: pipeline_2, name: 'job-2')
            create_sync_events(final_build_1, final_build_2)
            execute
          end

          it 'syncs correct retries_count for each build' do
            expect(record_1[:retries_count]).to eq(1)
            expect(record_2[:retries_count]).to eq(3)
          end
        end
      end

      describe 'runner_tags' do
        context 'when runner has tags' do
          let(:tagged_runner) { create(:ci_runner, tag_list: %w[docker linux production]) }
          let(:build) { create(:ci_build, :success, runner: tagged_runner) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:runner_tags]).to match_array(%w[docker linux production]) }
        end

        context 'when runner has no tags' do
          let(:untagged_runner) { create(:ci_runner, tag_list: []) }
          let(:build) { create(:ci_build, :success, runner: untagged_runner) }
          let(:record) { find_synced_build_record(build) }

          before do
            create_sync_events(build)
            execute
          end

          it { expect(record[:runner_tags]).to eq([]) }
        end

        context 'when build has no runner' do
          let(:record) { find_synced_build_record(build2) }

          before do
            execute
          end

          it { expect(record[:runner_tags]).to eq([]) }
        end

        context 'with multiple builds and different runner tags' do
          let(:runner_with_tags_1) { create(:ci_runner, tag_list: %w[docker linux]) }
          let(:runner_with_tags_2) { create(:ci_runner, tag_list: %w[kubernetes windows]) }
          let(:build_with_tags_1) { create(:ci_build, :success, runner: runner_with_tags_1) }
          let(:build_with_tags_2) { create(:ci_build, :success, runner: runner_with_tags_2) }

          let(:record_1) { find_synced_build_record(build_with_tags_1) }
          let(:record_2) { find_synced_build_record(build_with_tags_2) }

          before do
            create_sync_events(build_with_tags_1, build_with_tags_2)
            execute
          end

          it 'syncs correct runner_tags for each build' do
            expect(record_1[:runner_tags]).to match_array(%w[docker linux])
            expect(record_2[:runner_tags]).to match_array(%w[kubernetes windows])
          end
        end
      end

      describe 'job_definition_id' do
        subject { record[:job_definition_id] }

        context 'when build has no job_definition' do
          let(:build_without_job_definition) { create(:ci_build, :success, :without_job_definition) }
          let(:record) { find_synced_build_record(build_without_job_definition) }

          before do
            create_sync_events(build_without_job_definition)
            execute
          end

          it { is_expected.to eq(0) }
        end
      end
    end

    describe 'N+1 query prevention', :use_sql_query_cache do
      let(:pipeline) { create(:ci_pipeline) }
      let(:tagged_runner) { create(:ci_runner, tag_list: %w[docker linux]) }

      let(:control) do
        ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }
      end

      def create_build_with_retries
        build = create(:ci_build, :success, :artifacts, pipeline: pipeline, runner: tagged_runner)
        create(:ci_build, :success, :retried, pipeline: pipeline, name: build.name)
        create_sync_events(build)
      end

      before do
        create_build_with_retries
        control
        2.times { create_build_with_retries }
      end

      it 'avoids N+1 queries when syncing builds with artifacts, runner_tags, and retries' do
        expect { described_class.new.execute }.to issue_same_number_of_queries_as(control)
      end
    end
  end

  context 'when multiple batches are required' do
    before do
      stub_const("#{described_class}::BUILDS_BATCH_SIZE", 2)
    end

    it 'processes the builds' do
      expect(ClickHouse::Client).to receive(:insert_csv).once.and_call_original

      expect { execute }.to change { ci_finished_builds_row_count }.by(3)
      expect(execute).to have_attributes({
        payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
      })
    end
  end

  context 'when multiple CSV uploads are required' do
    before do
      stub_const("#{described_class}::BUILDS_BATCH_SIZE", 1)
      stub_const("#{described_class}::BUILDS_BATCH_COUNT", 2)
    end

    it 'processes the builds' do
      expect_next_instance_of(Gitlab::Pagination::Keyset::Iterator) do |iterator|
        expect(iterator).to receive(:each_batch).once.with(of: described_class::BUILDS_BATCH_SIZE).and_call_original
      end

      expect(ClickHouse::Client).to receive(:insert_csv).twice.and_call_original

      expect { execute }.to change { ci_finished_builds_row_count }.by(3)
      expect(execute).to have_attributes({
        payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
      })
    end

    context 'with time limit being reached' do
      it 'processes the builds of the first batch' do
        over_time = false

        expect_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |limiter|
          expect(limiter).to receive(:over_time?).at_least(1) { over_time }
        end

        expect(service).to receive(:yield_builds).and_wrap_original do |original, *args|
          over_time = true
          original.call(*args)
        end

        expect { execute }.to change { ci_finished_builds_row_count }.by(described_class::BUILDS_BATCH_SIZE)
        expect(execute).to have_attributes({
          payload: a_hash_including(
            reached_end_of_table: false, records_inserted: described_class::BUILDS_BATCH_SIZE
          )
        })
      end
    end

    context 'when batches fail to be written to ClickHouse' do
      it 'does not mark any records as processed' do
        expect(ClickHouse::Client).to receive(:insert_csv) { raise ClickHouse::Client::DatabaseError }

        expect { execute }.to raise_error(ClickHouse::Client::DatabaseError)
          .and not_change { Ci::FinishedBuildChSyncEvent.pending.count }
      end
    end
  end

  context 'with multiple calls to service' do
    it 'processes the builds' do
      expect_next_instances_of(Gitlab::Pagination::Keyset::Iterator, 2) do |iterator|
        expect(iterator).to receive(:each_batch).once.with(of: described_class::BUILDS_BATCH_SIZE).and_call_original
      end

      expect { execute }.to change { ci_finished_builds_row_count }.by(3)
      expect(execute).to have_attributes({
        payload: a_hash_including(reached_end_of_table: true, records_inserted: 3)
      })

      build5 = create(:ci_build, :failed)
      create_sync_events(build5)

      expect { service.execute }.to change { ci_finished_builds_row_count }.by(1)
      records = ci_finished_builds
      expect(records.count).to eq 4
      expect(records).to contain_exactly_builds(build1, build2, build3, build5)
    end

    context 'with same updated_at value' do
      it 'processes the builds' do
        expect { service.execute }.to change { ci_finished_builds_row_count }.by(3)

        build5 = create(:ci_build, :failed)
        build6 = create(:ci_build, :failed)
        create_sync_events(build5, build6)

        expect { execute }.to change { ci_finished_builds_row_count }.by(2)

        records = ci_finished_builds
        expect(records.count).to eq 5
        expect(records).to contain_exactly_builds(build1, build2, build3, build5, build6)
      end
    end

    context 'with older finished_at value' do
      it 'does not process the build' do
        expect { service.execute }.to change { ci_finished_builds_row_count }.by(3)

        create(:ci_build, :failed)

        expect { service.execute }.not_to change { ci_finished_builds_row_count }
      end
    end
  end

  context 'when no ClickHouse databases are configured' do
    before do
      allow(Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'skips execution' do
      is_expected.to have_attributes({
        status: :error,
        message: 'Disabled: ClickHouse database is not configured.',
        reason: :db_not_configured,
        payload: { worker_index: 0, total_workers: 1 }
      })
    end
  end

  context 'when exclusive lease error happens' do
    context 'when the exclusive lease is already locked for the worker' do
      let(:service) { described_class.new(worker_index: 2, total_workers: 3) }

      before do
        lock_name = "#{described_class.name.underscore}/worker/2"
        allow(service).to receive(:in_lock).with(lock_name, retries: 0, ttl: 360)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
      end

      it 'does nothing' do
        expect { execute }.not_to change { ci_finished_builds_row_count }

        expect(execute).to have_attributes({
          status: :error, reason: :skipped, payload: { worker_index: 2, total_workers: 3 }
        })
      end
    end
  end

  def create_sync_events(*builds)
    builds.each { |build| create_ci_build_sync_event(build) }
  end

  def ci_finished_builds_row_count
    ClickHouse::Client.select('SELECT COUNT(*) AS count FROM ci_finished_builds FINAL', :main).first['count']
  end

  def ci_finished_builds
    ClickHouse::Client
      .select('SELECT *, date FROM ci_finished_builds', :main)
      .map(&:symbolize_keys)
  end

  def expected_build_attributes(build)
    {
      **build.slice(:id, :status, :project_id, :pipeline_id).symbolize_keys,
      **build_timing_attributes(build),
      **build_basic_attributes(build),
      **runner_attributes(build.runner, build.runner_manager)
    }
  end

  def build_timing_attributes(build)
    {
      created_at: a_value_within(1.second).of(build.created_at),
      started_at: a_value_within(1.second).of(build.started_at),
      queued_at: a_value_within(1.second).of(build.queued_at),
      finished_at: a_value_within(1.second).of(build.finished_at),
      date: build.finished_at.beginning_of_month
    }
  end

  def build_basic_attributes(build)
    {
      name: build.name || '',
      stage_id: build.stage_id || 0,
      stage_name: build.stage_name || '',
      group_name: build.group_name || '',
      root_namespace_id: build.project.root_namespace.id,
      version: be_a(Time),
      deleted: false,
      namespace_path: "#{build.project.namespace.traversal_ids.join('/')}/",
      failure_reason: build.failure_reason || '',
      when: build.when || '',
      manual: build.action?,
      allow_failure: build.allow_failure || false,
      user_id: build.user_id || 0,
      artifacts_filename: build.artifacts_file&.filename || '',
      artifacts_size: build.artifacts_size || 0,
      retries_count: build.retries_count,
      job_definition_id: build.job_definition.id || 0
    }
  end

  def runner_attributes(runner, runner_manager)
    {
      runner_id: runner&.id || 0,
      runner_type: Ci::Runner.runner_types.fetch(runner&.runner_type, 0),
      runner_owner_namespace_id: runner&.owner_runner_namespace&.namespace_id || 0,
      runner_run_untagged: runner&.run_untagged || false,
      runner_tags: runner&.tag_list.to_a,
      **runner_manager_attributes(runner_manager)
    }
  end

  def runner_manager_attributes(runner_manager)
    {
      runner_manager_system_xid: runner_manager&.system_xid || '',
      runner_manager_version: runner_manager&.version || '',
      runner_manager_revision: runner_manager&.revision || '',
      runner_manager_platform: runner_manager&.platform || '',
      runner_manager_architecture: runner_manager&.architecture || ''
    }
  end

  def contain_exactly_builds(*builds)
    expected_builds = builds.map do |build|
      expected_build_attributes(build)
    end

    contain_exactly(*expected_builds)
  end

  def build_ci_build_sync_event(build)
    Ci::FinishedBuildChSyncEvent.new(
      build_id: build.id, project_id: build.project_id, build_finished_at: build.finished_at)
  end

  def create_ci_build_sync_event(build)
    build_ci_build_sync_event(build).tap(&:save!)
  end

  def find_synced_build_record(build)
    ci_finished_builds.find { |r| r[:id] == build.id }
  end
end
