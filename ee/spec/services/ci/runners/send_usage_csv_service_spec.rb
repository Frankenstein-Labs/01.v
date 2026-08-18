# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runners::SendUsageCsvService, :enable_admin_mode, :click_house, :freeze_time,
  feature_category: :fleet_visibility do
  let_it_be(:current_user) { build_stubbed(:admin) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }

  let(:full_path) { nil }
  let(:from_date) { 1.month.ago }
  let(:to_date) { Date.current }
  let(:max_project_count) { 5 }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }
  let(:service) do
    described_class.new(current_user: current_user,
      full_path: full_path, runner_type: :instance_type, from_date: from_date, to_date: to_date,
      max_project_count: max_project_count)
  end

  subject(:response) { service.execute }

  before do
    stub_licensed_features(runner_performance_insights: true)

    started_at = created_at = 1.hour.ago
    project = build(:project)
    build = build_stubbed(:ci_build, :success, created_at: created_at, queued_at: created_at, started_at: started_at,
      finished_at: started_at + 10.minutes, project: project, runner: instance_runner)
    insert_ci_builds_to_click_house([build])
  end

  it 'sends the csv by email' do
    expect_next_instance_of(Ci::Runners::GenerateUsageCsvService,
      current_user, scope: nil, runner_type: :instance_type, from_date: from_date, to_date: to_date,
      max_project_count: max_project_count
    ) do |service|
      expect(service).to receive(:execute).and_call_original
    end

    expected_status = { projects_expected: 1, projects_written: 1, rows_expected: 1, rows_written: 1, truncated: false }
    expect(Notify).to receive(:runner_usage_by_project_csv_email)
      .with(user: current_user, scope: nil, from_date: from_date, to_date: to_date, csv_data: anything,
        export_status: expected_status)
      .and_return(message_delivery)

    expect(response).to be_success
    expect(response.payload).to eq({ status: expected_status })
  end

  it 'creates tracking event' do
    expect { response }.to trigger_internal_events('export_runner_usage_by_project_as_csv')
      .with(
        category: 'InternalEventTracking',
        user: current_user,
        additional_properties: { property: 'instance_type', label: 'instance' }
      )
  end

  it 'creates audit event' do
    expect(Gitlab::Audit::Auditor).to receive(:audit).with(
      a_hash_including(
        name: 'ci_runner_usage_export',
        author: current_user,
        target: an_instance_of(Gitlab::Audit::NullTarget),
        scope: an_instance_of(Gitlab::Audit::InstanceScope),
        message: 'Sent email with runner usage CSV',
        additional_details: {
          runner_type: :instance_type,
          from_date: from_date.iso8601,
          to_date: to_date.iso8601
        }
      )
    )

    response
  end

  context 'when report fails to be generated' do
    before do
      allow(::Gitlab::ClickHouse).to receive(:configured?).and_return(false)
    end

    it 'returns error from GenerateUsageCsvService' do
      expect(Notify).not_to receive(:runner_usage_by_project_csv_email)

      expect(response).to be_error
      expect(response.message).to eq('ClickHouse database is not configured')
    end

    it 'does not create audit event' do
      expect(Gitlab::Audit::Auditor).not_to receive(:audit)

      response
    end
  end

  context 'when full_path is specified' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:full_path) { specified_scope.full_path }
    let(:expected_status) do
      {
        projects_expected: max_project_count, projects_written: 0, rows_expected: 0, rows_written: 0, truncated: false
      }
    end

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: true)
    end

    context 'when scope is a group' do
      let_it_be(:specified_scope) { group }

      it 'calls GenerateUsageCsvService with correct scope' do
        expect_next_instance_of(Ci::Runners::GenerateUsageCsvService,
          current_user, scope: specified_scope, runner_type: :instance_type, from_date: from_date, to_date: to_date,
          max_project_count: max_project_count
        ) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(Notify).to receive(:runner_usage_by_project_csv_email)
          .with(user: current_user, scope: specified_scope, from_date: from_date, to_date: to_date, csv_data: anything,
            export_status: expected_status)
          .and_return(message_delivery)

        expect(response).to be_success
        expect(response.payload).to eq({ status: expected_status })
      end

      it 'creates tracking event' do
        expect { response }.to trigger_internal_events('export_runner_usage_by_project_as_csv')
          .with(
            category: 'InternalEventTracking',
            user: current_user,
            namespace: specified_scope,
            additional_properties: { property: 'instance_type', label: 'group' }
          )
      end
    end

    context 'when scope is a project' do
      let_it_be(:specified_scope) { project }

      it 'calls GenerateUsageCsvService with correct scope' do
        expect_next_instance_of(Ci::Runners::GenerateUsageCsvService,
          current_user, scope: specified_scope, runner_type: :instance_type, from_date: from_date, to_date: to_date,
          max_project_count: max_project_count
        ) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        expect(Notify).to receive(:runner_usage_by_project_csv_email)
          .with(user: current_user, scope: specified_scope, from_date: from_date, to_date: to_date, csv_data: anything,
            export_status: expected_status)
          .and_return(message_delivery)

        expect(response).to be_success
        expect(response.payload).to eq({ status: expected_status })
      end

      it 'creates tracking event' do
        expect { response }.to trigger_internal_events('export_runner_usage_by_project_as_csv')
          .with(
            category: 'InternalEventTracking',
            user: current_user,
            project: specified_scope,
            additional_properties: { property: 'instance_type', label: 'project' }
          )
      end
    end
  end
end
