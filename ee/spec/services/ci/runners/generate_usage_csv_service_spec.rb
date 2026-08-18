# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::GenerateUsageCsvService, :enable_admin_mode, :click_house,
  feature_category: :fleet_visibility do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:group) { create(:group, maintainers: maintainer) }
  let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
  let_it_be(:group2) { create(:group, maintainers: maintainer) }
  let_it_be(:group2_runner) { create(:ci_runner, :group, groups: [group2]) }
  let_it_be(:group2_project) { create(:project, group: group2, maintainers: maintainer) }
  let_it_be(:projects) { create_list(:project, 6, group: group, maintainers: maintainer) }
  let_it_be(:builds) do
    starting_time = DateTime.new(2023, 12, 31, 21, 0, 0)

    builds = projects.first(5).map.with_index do |project, i|
      create_build(instance_runner, project, (50.minutes * i).after(starting_time),
        (14 + i).minutes, Ci::HasStatus::COMPLETED_STATUSES[i % Ci::HasStatus::COMPLETED_STATUSES.size])
    end

    builds << create_build(group2_runner, group2_project, starting_time, 2.hours, :success)

    project = projects.last
    builds << create_build(group_runner, project, starting_time, 8.hours, :failed)
    builds << create_build(instance_runner, project, starting_time, 10.minutes, :failed)
    builds << create_build(instance_runner, project, starting_time, 7.minutes)
    builds
  end

  let(:current_user) { admin }
  let(:runner_type) { :instance_type }
  let(:scope) { nil }
  let(:from_date) { Date.new(2023, 12, 1) }
  let(:to_date) { Date.new(2023, 12, 31) }
  let(:max_project_count) { 2 }
  let(:response_status) { response.payload[:status] }
  let(:response_csv_lines) { response.payload[:csv_data].lines }
  let(:service) do
    described_class.new(current_user,
      scope: scope, runner_type: runner_type, from_date: from_date, to_date: to_date,
      max_project_count: max_project_count)
  end

  let(:expected_header) do
    "Project ID,Project path,Status,Runner type,Build count,Total duration (minutes),Total duration\n"
  end

  subject(:response) { service.execute }

  before do
    stub_licensed_features(runner_performance_insights: true)

    insert_ci_builds_to_click_house(builds)
  end

  context 'when GetUsageByProjectService returns error' do
    let_it_be(:current_user) { create(:user) }

    it 'also returns error' do
      expect(response).to be_error
      expect(response.message).to eq('Insufficient permissions')
      expect(response.reason).to eq(:insufficient_permissions)
    end
  end

  it 'exports usage data for all runners for the last complete month' do
    expect_next_instance_of(CsvBuilder::SingleBatch, anything, anything) do |csv_builder|
      expect(csv_builder).to receive(:render)
        .with(ExportCsv::BaseService::TARGET_FILESIZE)
        .and_call_original
    end

    expect(response).to be_success
    expect(response_csv_lines).to eq([
      expected_header,
      "#{project_id_and_full_path(builds[3])},skipped,instance_type,1,17,17 minutes\n",
      "#{project_id_and_full_path(builds.last)},failed,instance_type,1,10,10 minutes\n",
      "#{project_id_and_full_path(builds.last)},success,instance_type,1,7,7 minutes\n",
      ",<Other projects>,canceled,instance_type,1,16,16 minutes\n",
      ",<Other projects>,failed,instance_type,1,15,15 minutes\n",
      ",<Other projects>,success,instance_type,1,14,14 minutes\n"
    ])

    expect(response_status).to eq({
      projects_expected: max_project_count, projects_written: 2, rows_expected: 6, rows_written: 6, truncated: false
    })
  end

  context 'when scope is specified' do
    let(:expected_svc_args) do
      [
        scope: scope,
        runner_type: runner_type,
        from_date: from_date,
        to_date: to_date,
        max_item_count: max_project_count,
        additional_group_by_columns: %w[status runner_type]
      ]
    end

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: true)
    end

    context 'and scope is group2' do
      let(:scope) { group2 }
      let(:runner_type) { nil }
      let(:current_user) { maintainer }
      let(:group2_build) { builds[-4] }

      it 'calls service with expected arguments and returns no results' do
        expect_next_instance_of(::Ci::Runners::GetUsageByProjectService, current_user, *expected_svc_args) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(response).to be_success
        expect(response_csv_lines).to eq([
          expected_header,
          "#{project_id_and_full_path(group2_build)},success,group_type,1,120,2 hours\n"
        ])

        expect(response_status).to eq({
          projects_expected: 1, projects_written: 1, rows_expected: 1, rows_written: 1, truncated: false
        })
      end
    end

    context 'and scope is project' do
      let(:scope) { projects.last }
      let(:current_user) { maintainer }

      it 'exports usage data for runners in project for the last complete month' do
        expect_next_instance_of(::Ci::Runners::GetUsageByProjectService, current_user, *expected_svc_args) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(response).to be_success
        expect(response_csv_lines).to eq([
          expected_header,
          "#{project_id_and_full_path(builds.last)},failed,instance_type,1,10,10 minutes\n",
          "#{project_id_and_full_path(builds.last)},success,instance_type,1,7,7 minutes\n"
        ])

        expect(response_status).to eq({
          projects_expected: 1, projects_written: 1, rows_expected: 2, rows_written: 2, truncated: false
        })
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

  def project_id_and_full_path(build)
    [build.project_id, build.project.full_path].join(',')
  end
end
