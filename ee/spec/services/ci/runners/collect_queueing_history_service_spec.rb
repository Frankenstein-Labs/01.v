# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::CollectQueueingHistoryService,
  :click_house, :enable_admin_mode, feature_category: :fleet_visibility do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance, :with_runner_manager) }
  let_it_be(:project_runner) { create(:ci_runner, :project, :with_runner_manager, projects: [project]) }
  let_it_be(:group_runner) { create(:ci_runner, :group, :with_runner_manager, groups: [group]) }
  let_it_be(:current_user) { create(:user, :admin) }

  let_it_be(:starting_time) { Time.utc(2023) }

  let(:percentiles) { [50, 75, 90, 95, 99] }
  let(:runner_type) { nil }
  let(:from_time) { starting_time }
  let(:to_time) { 3.hours.after(starting_time) }
  let(:owner_namespace) { nil }

  let(:service) do
    described_class.new(current_user: current_user,
      percentiles: percentiles,
      runner_type: runner_type,
      from_time: from_time,
      to_time: to_time,
      owner_namespace: owner_namespace)
  end

  let(:licensed_feature_available) { true }

  before do
    stub_licensed_features(
      runner_performance_insights: licensed_feature_available,
      runner_performance_insights_for_namespace: licensed_feature_available
    )
  end

  subject(:result) { service.execute }

  context 'when ClickHouse database is not configured' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'returns error' do
      expect(result.error?).to be(true)
      expect(result.errors).to contain_exactly('ClickHouse database is not configured')
    end
  end

  shared_examples 'returns Not allowed error' do
    it 'returns error' do
      expect(result.error?).to be(true)
      expect(result.errors).to contain_exactly('Not allowed')
    end
  end

  context 'when runner_performance_insights feature is disabled' do
    let(:licensed_feature_available) { false }

    include_examples 'returns Not allowed error'
  end

  context 'when user is nil' do
    let(:current_user) { nil }

    include_examples 'returns Not allowed error'
  end

  context 'when user is not admin' do
    let(:current_user) { create(:user) }

    include_examples 'returns Not allowed error'
  end

  shared_examples 'calculates percentiles' do
    context 'when requesting invalid percentiles' do
      let(:percentiles) { [88] }

      it 'returns an error' do
        expect(result.error?).to be(true)
        expect(result.errors).to contain_exactly('At least one of 50, 75, 90, 95, 99 percentiles should be requested')
      end
    end

    context 'when requesting only some percentiles' do
      let(:percentiles) { [95, 90] }

      it 'returns only those percentiles' do
        build = build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 2.5.seconds,
          finished_at: starting_time + 1.minute,
          runner: runner,
          runner_manager: runner.runner_managers.first)

        insert_ci_builds_to_click_house([build])

        expect(result.success?).to be(true)
        expect(result.payload).to contain_exactly(
          { 'p90' => 2.5.seconds, 'p95' => 2.5.seconds, 'time' => starting_time }
        )
      end
    end

    it 'returns empty result if there is no data in ClickHouse' do
      expect(result.success?).to be(true)
      expect(result.payload).to be_empty
    end

    context 'with different build statuses' do
      using RSpec::Parameterized::TableSyntax

      where(:build_status) { %i[success failed] }

      with_them do
        let(:build) do
          build_stubbed(:ci_build, build_status, created_at: starting_time, queued_at: starting_time,
            started_at: starting_time + 2.seconds,
            finished_at: starting_time + 1.minute,
            runner: runner,
            runner_manager: runner.runner_managers.first)
        end

        before do
          insert_ci_builds_to_click_house([build])
        end

        it 'returns equal percentiles for a single build', :freeze_time do
          expect(result.success?).to be(true)
          expect(result.payload).to contain_exactly(
            { 'p50' => 2.seconds, 'p75' => 2.seconds, 'p90' => 2.seconds, 'p95' => 2.seconds, 'p99' => 2.seconds,
              'time' => starting_time }
          )
        end
      end
    end

    it 'groups builds by 5 minute intervals of started_at' do
      builds = Array.new(2) do |i|
        time_shift = 7.minutes * i
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time + time_shift,
          queued_at: starting_time + time_shift,
          started_at: starting_time + 6.minutes + time_shift,
          finished_at: starting_time + 20.minutes + time_shift,
          runner: runner,
          runner_manager: runner.runner_managers.first)
      end

      insert_ci_builds_to_click_house(builds)

      expect(result.success?).to be(true)

      expect(result.payload).to eq([
        { 'p50' => 6.minutes, 'p75' => 6.minutes, 'p90' => 6.minutes, 'p95' => 6.minutes, 'p99' => 6.minutes,
          'time' => starting_time + 5.minutes },
        { 'p50' => 6.minutes, 'p75' => 6.minutes, 'p90' => 6.minutes, 'p95' => 6.minutes, 'p99' => 6.minutes,
          'time' => starting_time + 10.minutes }
      ])
    end

    it 'properly calculates percentiles' do
      builds = Array.new(10) do |i|
        queueing_delay = 1 + i.seconds

        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + queueing_delay,
          finished_at: starting_time + queueing_delay + 1.minute,
          runner: runner,
          runner_manager: runner.runner_managers.first)
      end

      insert_ci_builds_to_click_house(builds)

      expect(result.success?).to be(true)

      payload = result.payload.first
      p50 = payload['p50']
      p75 = payload['p75']
      p90 = payload['p90']
      p95 = payload['p95']
      p99 = payload['p99']

      # the percentile calculations are fuzzy, so we compare them among themselves
      # instead of comparing them to fixed values
      expect(p50).to be < p75
      expect(p75).to be < p90
      expect(p90).to be < p95
      expect(p95).to be < p99
    end

    it 'properly handles from_time and to_time' do
      builds = [from_time - 1.second,
        from_time,
        to_time,
        (5.minutes + 1.second).after(to_time)].map do |started_at|
        build_stubbed(:ci_build,
          :success,
          created_at: 1.minute.before(started_at),
          queued_at: 1.minute.before(started_at),
          started_at: started_at,
          finished_at: 10.minutes.after(started_at),
          runner: runner,
          runner_manager: runner.runner_managers.first)
      end

      insert_ci_builds_to_click_house(builds)

      expect(result.success?).to be(true)

      expect(result.payload).to eq([
        { 'p50' => 1.minute, 'p75' => 1.minute, 'p90' => 1.minute, 'p95' => 1.minute, 'p99' => 1.minute,
          'time' => from_time },
        { 'p50' => 1.minute, 'p75' => 1.minute, 'p90' => 1.minute, 'p95' => 1.minute, 'p99' => 1.minute,
          'time' => to_time }
      ])
    end

    context 'when from_time and to_time are not specified' do
      let(:from_time) { nil }
      let(:to_time) { nil }

      around do |example|
        travel_to(starting_time + 3.hours) do
          example.run
        end
      end

      it 'defaults time frame to the last 3 hours' do
        from_time_default = starting_time
        to_time_default = starting_time + 3.hours
        builds = [from_time_default - 1.second,
          from_time_default,
          to_time_default,
          to_time_default + 5.minutes + 1.second].map do |started_at|
          build_stubbed(:ci_build,
            :success,
            created_at: started_at - 1.minute,
            queued_at: started_at - 1.minute,
            started_at: started_at,
            finished_at: started_at + 10.minutes,
            runner: runner,
            runner_manager: runner.runner_managers.first)
        end

        insert_ci_builds_to_click_house(builds)

        expect(result.success?).to be(true)

        expect(result.payload).to eq([
          { 'p50' => 1.minute, 'p75' => 1.minute, 'p90' => 1.minute, 'p95' => 1.minute, 'p99' => 1.minute,
            'time' => from_time_default },
          { 'p50' => 1.minute, 'p75' => 1.minute, 'p90' => 1.minute, 'p95' => 1.minute, 'p99' => 1.minute,
            'time' => to_time_default }
        ])
      end
    end

    context 'when requesting more that TIME_BUCKETS_LIMIT' do
      let(:to_time) { 190.minutes.after(starting_time) }

      it 'returns error' do
        expect(result.error?).to be(true)

        expect(result.errors).to contain_exactly('Maximum of 37 5-minute intervals can be requested')
      end
    end
  end

  include_examples 'calculates percentiles' do
    let(:runner) { instance_runner }
  end

  context 'when owner_namespace_id is specified' do
    let_it_be(:owner_namespace) { group_runner.owner_runner_namespace&.namespace }
    let_it_be(:current_user) { create(:user, owner_of: owner_namespace) }

    include_examples 'calculates percentiles' do
      let(:runner) { group_runner }
    end

    it 'filters by owner_namespace' do
      group2 = create(:group)
      ignored_runner = create(:ci_runner, :group, :with_runner_manager, groups: [group2])

      builds = [
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 1.minute,
          finished_at: starting_time + 10.minutes,
          runner: ignored_runner,
          runner_manager: ignored_runner.runner_managers.first),
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time + 10.minutes,
          queued_at: starting_time + 10.minutes,
          started_at: starting_time + 10.minutes + 3.seconds,
          finished_at: starting_time + 11.minutes,
          runner: group_runner,
          runner_manager: group_runner.runner_managers.first)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(result.success?).to be(true)

      expect(result.payload).to contain_exactly(
        { 'p50' => 3.seconds, 'p75' => 3.seconds, 'p90' => 3.seconds, 'p95' => 3.seconds, 'p99' => 3.seconds,
          'time' => starting_time + 10.minutes }
      )
    end

    context 'when user is a developer' do
      let_it_be(:current_user) { create(:user, developer_of: owner_namespace) }

      include_examples 'returns Not allowed error'
    end
  end

  # this currently doesn't make sense in the context of filtering by owner_namespace
  # because we only push namespace id for group runners
  # so it's not part of the shared context
  context 'when runner_type is specified' do
    let(:runner_type) { :group_type }

    it 'filters data by runner type' do
      builds = [
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 1.minute,
          finished_at: starting_time + 10.minutes,
          runner: instance_runner,
          runner_manager: instance_runner.runner_managers.first),
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time + 10.minutes,
          queued_at: starting_time + 10.minutes,
          started_at: starting_time + 10.minutes + 3.seconds,
          finished_at: starting_time + 11.minutes,
          runner: group_runner,
          runner_manager: group_runner.runner_managers.first)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(result.success?).to be(true)

      expect(result.payload).to contain_exactly(
        { 'p50' => 3.seconds, 'p75' => 3.seconds, 'p90' => 3.seconds, 'p95' => 3.seconds, 'p99' => 3.seconds,
          'time' => starting_time + 10.minutes }
      )
    end
  end
end
