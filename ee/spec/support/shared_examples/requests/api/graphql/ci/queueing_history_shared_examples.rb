# frozen_string_literal: true

RSpec.shared_examples 'ciQueueingHistory' do
  before do
    stub_licensed_features(required_license => true)
  end

  context 'when ClickHouse database is not configured' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'returns error' do
      execute_query
      expect_graphql_errors_to_include('ClickHouse database is not configured')
    end
  end

  shared_examples 'returns unauthorized error' do
    it 'returns error' do
      execute_query
      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist " \
                                       "or you don't have permission to perform this action")
    end
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(required_license => false)
    end

    include_examples 'returns unauthorized error'
  end

  context 'when user is nil' do
    let(:current_user) { nil }

    include_examples 'returns unauthorized error'
  end

  it 'returns empty time_series with no data' do
    expect(ci_queueing_history['timeSeries']).to eq([])
  end

  it 'returns time_series grouped by 5 minute intervals' do
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

    expect(ci_queueing_history['timeSeries']).to eq([
      { 'p50' => 360, 'p75' => 360, 'p90' => 360, 'p95' => 360, 'p99' => 360,
        'time' => (starting_time + 5.minutes).utc.iso8601 },
      { 'p50' => 360, 'p75' => 360, 'p90' => 360, 'p95' => 360, 'p99' => 360,
        'time' => (starting_time + 10.minutes).utc.iso8601 }
    ])
  end

  it 'properly handles from_time and to_time' do
    builds = [from_time - 1.second,
      from_time,
      to_time,
      to_time + 5.minutes + 1.second].map do |started_at|
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

    expect(ci_queueing_history['timeSeries']).to eq([
      { 'p50' => 60, 'p75' => 60, 'p90' => 60, 'p95' => 60, 'p99' => 60,
        "time" => from_time.utc.iso8601 },
      { 'p50' => 60, 'p75' => 60, 'p90' => 60, 'p95' => 60, 'p99' => 60,
        'time' => to_time.utc.iso8601 }
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

      expect(ci_queueing_history['timeSeries']).to eq([
        { 'p50' => 60, 'p75' => 60, 'p90' => 60, 'p95' => 60, 'p99' => 60,
          "time" => from_time_default.utc.iso8601 },
        { 'p50' => 60, 'p75' => 60, 'p90' => 60, 'p95' => 60, 'p99' => 60,
          'time' => to_time_default.utc.iso8601 }
      ])
    end
  end

  context 'when requesting more that TIME_BUCKETS_LIMIT' do
    let(:to_time) { starting_time + 190.minutes }

    it 'returns error' do
      execute_query

      expect_graphql_errors_to_include('Maximum of 37 5-minute intervals can be requested')
    end
  end
end
