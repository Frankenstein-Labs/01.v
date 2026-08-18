# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::GetUsageByProjectService, :click_house, feature_category: :fleet_visibility do
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:group) { create(:group) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
  let_it_be(:projects) { create_list(:project, 6, group: group) }
  let_it_be(:project1) { projects.first }
  let_it_be(:starting_time) { DateTime.new(2023, 12, 31, 21, 0, 0) }
  let_it_be(:developer) { create(:user, developer_of: group) }

  let_it_be(:builds) do
    builds = projects.reject { |p| p == project1 }.map.with_index do |project, i|
      create_build(instance_runner, project, starting_time + (50.minutes * i),
        (14 + i).minutes, Ci::HasStatus::COMPLETED_STATUSES[i % Ci::HasStatus::COMPLETED_STATUSES.size])
    end

    builds << create_build(group_runner, project1, starting_time, 2.hours, :failed)
    builds << create_build(instance_runner, project1, starting_time, 10.minutes, :failed)
    builds << create_build(instance_runner, project1, starting_time, 7.minutes)
    builds << create_build(group_runner, project1, starting_time, 3.minutes, :canceled)
    builds
  end

  let(:scope) { nil }
  let(:runner_type) { nil }
  let(:from_date) { Date.new(2023, 12, 1) }
  let(:to_date) { Date.new(2023, 12, 31) }
  let(:max_item_count) { 50 }
  let(:additional_group_by_columns) { nil }
  let(:service) do
    described_class.new(user,
      **{ scope: scope, runner_type: runner_type, from_date: from_date, to_date: to_date,
          additional_group_by_columns: additional_group_by_columns, max_item_count: max_item_count }.compact)
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

    it 'contains 9 builds in source ci_finished_builds table' do
      expect(ClickHouse::Client.select('SELECT count() FROM ci_finished_builds FINAL', :main))
        .to contain_exactly({ 'count()' => 9 })
    end

    it 'exports usage data' do
      is_expected.to eq([
        { 'project_id_bucket' => builds.last.project.id, 'count_builds' => 4, 'total_duration_in_mins' => 140 },
        { 'project_id_bucket' => builds[3].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 17 },
        { 'project_id_bucket' => builds[2].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 16 },
        { 'project_id_bucket' => builds[1].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 15 },
        { 'project_id_bucket' => builds[0].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 14 }
      ])
    end

    context 'when additional_group_by_columns specified' do
      let(:additional_group_by_columns) { %i[status runner_type] }

      it 'exports usage data grouped by status and runner_type' do
        is_expected.to eq([
          { 'project_id_bucket' => builds.last.project.id, 'status' => 'failed', 'runner_type' => 2,
            'count_builds' => 1, 'total_duration_in_mins' => 120 },
          { 'project_id_bucket' => builds[3].project.id, 'status' => 'skipped', 'runner_type' => 1,
            'count_builds' => 1, 'total_duration_in_mins' => 17 },
          { 'project_id_bucket' => builds[2].project.id, 'status' => 'canceled', 'runner_type' => 1,
            'count_builds' => 1, 'total_duration_in_mins' => 16 },
          { 'project_id_bucket' => builds[1].project.id, 'status' => 'failed', 'runner_type' => 1, 'count_builds' => 1,
            'total_duration_in_mins' => 15 },
          { 'project_id_bucket' => builds[0].project.id, 'status' => 'success', 'runner_type' => 1,
            'count_builds' => 1, 'total_duration_in_mins' => 14 },
          { 'project_id_bucket' => builds.last.project.id, 'status' => 'failed', 'runner_type' => 1,
            'count_builds' => 1, 'total_duration_in_mins' => 10 },
          { 'project_id_bucket' => builds.last.project.id, 'status' => 'success', 'runner_type' => 1,
            'count_builds' => 1, 'total_duration_in_mins' => 7 },
          { 'project_id_bucket' => builds.last.project.id, 'status' => 'canceled', 'runner_type' => 2,
            'count_builds' => 1, 'total_duration_in_mins' => 3 }
        ])
      end
    end

    context 'when the number of projects exceeds max_item_count' do
      let(:max_item_count) { 2 }

      it 'exports usage data for the 2 top projects plus aggregate for other projects' do
        is_expected.to eq([
          { 'project_id_bucket' => builds.last.project.id, 'count_builds' => 4, 'total_duration_in_mins' => 140 },
          { 'project_id_bucket' => builds[3].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 17 },
          { 'project_id_bucket' => nil, 'count_builds' => 3, 'total_duration_in_mins' => 45 }
        ])
      end
    end

    context 'with group_type runner_type argument specified' do
      let(:runner_type) { :group_type }

      it 'exports usage data for runners of specified type' do
        is_expected.to contain_exactly(
          { 'project_id_bucket' => builds.last.project.id, 'count_builds' => 2, 'total_duration_in_mins' => 123 }
        )
      end
    end

    context 'with project_type runner_type argument specified' do
      let(:runner_type) { :project_type }

      it 'exports usage data for runners of specified type' do
        is_expected.to eq([])
      end
    end

    context 'when dates are set' do
      let_it_be(:project) { create(:project) }

      let(:from_date) { Date.new(2024, 1, 2) }
      let(:to_date) { Date.new(2024, 1, 2) }

      let(:build_before) { create_build(instance_runner, project, Date.new(2024, 1, 1)) }
      let(:build_in_range) { create_build(instance_runner, project, Date.new(2024, 1, 2), 111.minutes) }
      let(:build_overflowing_the_range) { create_build(instance_runner, project, Date.new(2024, 1, 2, 23), 61.minutes) }
      let(:build_after) { create_build(instance_runner, project, Date.new(2024, 1, 3)) }

      let(:builds) { [build_before, build_in_range, build_overflowing_the_range, build_after] }

      it 'only exports usage data for builds created in the date range' do
        is_expected.to contain_exactly(
          { 'project_id_bucket' => project.id, 'count_builds' => 2, 'total_duration_in_mins' => 172 }
        )
      end
    end
  end

  context 'when scope is specified' do
    let_it_be(:group_maintainer) { create(:user, maintainer_of: group) }
    let_it_be(:group2) { create(:group, maintainers: [group_maintainer]) }
    let_it_be(:group2_project) { create(:project, group: group2) }

    let(:user) { group_maintainer }
    let(:project2) { projects.second }

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: true)
    end

    context 'with scope set to group' do
      let(:scope) { group }

      it_behaves_like 'a user without required permissions' do
        let(:user) { developer }
      end

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to eq([
          { 'project_id_bucket' => builds.last.project.id, 'count_builds' => 4, 'total_duration_in_mins' => 140 },
          { 'project_id_bucket' => builds[3].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 17 },
          { 'project_id_bucket' => builds[2].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 16 },
          { 'project_id_bucket' => builds[1].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 15 },
          { 'project_id_bucket' => builds[0].project.id, 'count_builds' => 1, 'total_duration_in_mins' => 14 }
        ])
      end
    end

    context 'with scope set to a different group' do
      let(:scope) { group2 }

      before do
        build = create_build(group_runner, group2_project, starting_time, 2.hours, :failed)

        insert_ci_builds_to_click_house([build])
      end

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to contain_exactly(
          { 'project_id_bucket' => group2_project.id, 'count_builds' => 1, 'total_duration_in_mins' => 120 }
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

        expect(data).to contain_exactly(
          { 'project_id_bucket' => scope.id, 'count_builds' => 4, 'total_duration_in_mins' => 140 }
        )
      end
    end

    context 'with scope set to project2' do
      let(:scope) { project2 }

      it 'exports usage data' do
        expect(result.errors).to be_empty

        expect(data).to contain_exactly(
          { 'project_id_bucket' => scope.id, 'count_builds' => 1, 'total_duration_in_mins' => 14 }
        )
      end
    end
  end

  def create_build(runner, project, created_at, duration = 14.minutes, status = :success)
    started_at = created_at + 6.minutes

    build_stubbed(:ci_build,
      status,
      created_at: created_at,
      queued_at: created_at,
      started_at: started_at,
      finished_at: started_at + duration,
      project: project,
      runner: runner)
  end
end
