# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::GetUsageService, :click_house, feature_category: :fleet_visibility do
  let_it_be(:instance_runners) { create_list(:ci_runner, 3, :instance) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:group_runners) { create_list(:ci_runner, 2, :group, groups: [group]) }

  let_it_be(:builds_finished_at) { Date.new(2023, 12, 1) }
  let_it_be(:group_runner_builds) do
    Array.new(3) { create_build(group_runners.first, builds_finished_at, 100.minutes, project: project1) } +
      Array.new(2) { create_build(group_runners.second, builds_finished_at, 100.minutes, project: project2) }
  end

  let_it_be(:instance_runner_builds) do
    instance_runners.flat_map.with_index(1) do |runner, index|
      Array.new(index) { create_build(runner, builds_finished_at, 10.minutes) }
    end
  end

  let_it_be(:builds) { instance_runner_builds + group_runner_builds }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let(:scope) { nil }
  let(:runner_type) { nil }
  let(:from_date) { Date.new(2023, 12, 1) }
  let(:to_date) { Date.new(2023, 12, 31) }
  let(:max_item_count) { 50 }
  let(:service) do
    described_class.new(user,
      **{ scope: scope, runner_type: runner_type, from_date: from_date, to_date: to_date,
          max_item_count: max_item_count }.compact)
  end

  let(:result) { service.execute }

  subject(:data) { result.payload }

  before do
    stub_licensed_features(runner_performance_insights: true)

    insert_ci_builds_to_click_house(builds)
  end

  shared_examples 'a user without required permissions' do
    it 'returns error' do
      expect(result).to be_error
      expect(result.message).to eq('Insufficient permissions')
      expect(result.reason).to eq(:insufficient_permissions)
    end
  end

  it_behaves_like 'a user without required permissions' do
    let(:user) { developer }
  end

  context 'when scope is not specified' do
    let(:scope) { nil }

    context 'when user is admin', :enable_admin_mode do
      let_it_be(:user) { create(:admin) }

      context 'when ClickHouse database is not configured' do
        before do
          allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(false)
        end

        it 'returns error' do
          expect(result).to be_error
          expect(result.message).to eq('ClickHouse database is not configured')
          expect(result.reason).to eq(:db_not_configured)
        end
      end

      it 'exports usage data by runner' do
        expect(data).to eq([
          { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 3, 'total_duration_in_mins' => 300 },
          { 'runner_id_bucket' => group_runners.second.id, 'count_builds' => 2, 'total_duration_in_mins' => 200 },
          { 'runner_id_bucket' => instance_runners[-1].id, 'count_builds' => 3, 'total_duration_in_mins' => 30 },
          { 'runner_id_bucket' => instance_runners[-2].id, 'count_builds' => 2, 'total_duration_in_mins' => 20 },
          { 'runner_id_bucket' => instance_runners[-3].id, 'count_builds' => 1, 'total_duration_in_mins' => 10 }
        ])
      end

      context 'when the number of runners exceeds max_item_count' do
        let(:max_item_count) { 3 }

        it 'exports usage data for the 3 top runners plus aggregate for other projects' do
          is_expected.to eq([
            { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 3, 'total_duration_in_mins' => 300 },
            { 'runner_id_bucket' => group_runners.second.id, 'count_builds' => 2, 'total_duration_in_mins' => 200 },
            { 'runner_id_bucket' => instance_runners.last.id, 'count_builds' => 3, 'total_duration_in_mins' => 30 },
            { 'runner_id_bucket' => nil, 'count_builds' => 3, 'total_duration_in_mins' => 30 }
          ])
        end
      end

      context 'with group_type runner_type argument specified' do
        let(:runner_type) { :group_type }

        it 'exports usage data for runners of specified type' do
          is_expected.to eq([
            { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 3, 'total_duration_in_mins' => 300 },
            { 'runner_id_bucket' => group_runners.second.id, 'count_builds' => 2, 'total_duration_in_mins' => 200 }
          ])
        end
      end

      context 'with project_type runner_type argument specified' do
        let(:runner_type) { :project_type }

        it 'exports usage data for runners of specified type' do
          is_expected.to eq([])
        end
      end

      context 'when dates are set' do
        let(:from_date) { Date.new(2024, 1, 2) }
        let(:to_date) { Date.new(2024, 1, 2) }

        let(:build_before) { create_build(group_runners.first, Date.new(2024, 1, 1), 14.minutes) }
        let(:build_in_range) { create_build(group_runners.first, Date.new(2024, 1, 2), 111.minutes) }
        let(:build_overflowing_the_range) { create_build(group_runners.first, Date.new(2024, 1, 2, 23), 61.minutes) }
        let(:build_after) { create_build(group_runners.first, Date.new(2024, 1, 3), 15.minutes) }

        let(:builds) { [build_before, build_in_range, build_overflowing_the_range, build_after] }

        it 'only exports usage data for builds created in the date range' do
          is_expected.to contain_exactly(
            { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 2, 'total_duration_in_mins' => 172 }
          )
        end
      end
    end
  end

  context 'when scope is specified' do
    let_it_be(:group_maintainer) { create(:user, maintainer_of: group) }
    let_it_be(:group2) { create(:group, maintainers: [group_maintainer]) }
    let_it_be(:group2_project) { create(:project, group: group2) }
    let_it_be(:group2_runner) { create(:ci_runner, :group, groups: [group2]) }

    let(:user) { group_maintainer }

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: true)
    end

    context 'with scope set to group' do
      let(:scope) { group }

      it_behaves_like 'a user without required permissions' do
        let(:user) { developer }
      end

      it 'exports usage data by runner' do
        expect(result.errors).to be_empty

        expect(data).to eq([
          { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 3, 'total_duration_in_mins' => 300 },
          { 'runner_id_bucket' => group_runners.second.id, 'count_builds' => 2, 'total_duration_in_mins' => 200 },
          { 'runner_id_bucket' => instance_runners[-1].id, 'count_builds' => 3, 'total_duration_in_mins' => 30 },
          { 'runner_id_bucket' => instance_runners[-2].id, 'count_builds' => 2, 'total_duration_in_mins' => 20 },
          { 'runner_id_bucket' => instance_runners[-3].id, 'count_builds' => 1, 'total_duration_in_mins' => 10 }
        ])
      end
    end

    context 'with scope set to a different group' do
      let(:scope) { group2 }

      before do
        build = create_build(group2_runner, builds_finished_at, 2.hours, project: group2_project, status: :failed)

        insert_ci_builds_to_click_house([build])
      end

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to contain_exactly(
          { 'runner_id_bucket' => group2_runner.id, 'count_builds' => 1, 'total_duration_in_mins' => 120 }
        )
      end
    end

    context 'with scope set to project1' do
      let(:scope) { project1 }

      it_behaves_like 'a user without required permissions' do
        let(:user) { developer }
      end

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to eq([
          { 'runner_id_bucket' => group_runners.first.id, 'count_builds' => 3, 'total_duration_in_mins' => 300 },
          { 'runner_id_bucket' => instance_runners[-1].id, 'count_builds' => 3, 'total_duration_in_mins' => 30 },
          { 'runner_id_bucket' => instance_runners[-2].id, 'count_builds' => 2, 'total_duration_in_mins' => 20 },
          { 'runner_id_bucket' => instance_runners[-3].id, 'count_builds' => 1, 'total_duration_in_mins' => 10 }
        ])
      end
    end

    context 'with scope set to project2' do
      let(:scope) { project2 }

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to contain_exactly(
          { 'runner_id_bucket' => group_runners.second.id, 'count_builds' => 2, 'total_duration_in_mins' => 200 }
        )
      end
    end
  end

  def create_build(runner, finished_at, duration, status: :success, project: project1)
    started_at = finished_at - duration

    build_stubbed(:ci_build,
      status,
      created_at: started_at,
      queued_at: started_at,
      started_at: started_at,
      finished_at: started_at + duration,
      project: project,
      runner: runner)
  end
end
