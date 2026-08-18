# frozen_string_literal: true

require 'spec_helper'

RSpec.describe(
  Security::SecurityOrchestrationPolicies::PipelineExecutionPolicies::CreateProjectSchedulesService,
  '#execute',
  time_travel_to: '2025-01-01 00:00:00', # Wed, Jan 25th
  feature_category: :security_policy_management) do
  let_it_be(:project) { create(:project) }
  let(:policy) do
    create(
      :security_policy,
      :pipeline_execution_schedule_policy,
      content: {
        content: { include: [{ project: 'compliance-project', file: "compliance-pipeline.yml" }] },
        schedules: [schedule]
      })
  end

  let(:schedule) do
    {
      type: 'daily',
      start_time: "23:30",
      time_window: {
        value: 2.hours.to_i,
        distribution: 'random'
      },
      timezone: "Atlantic/Cape_Verde"
    }
  end

  subject(:execute) { described_class.new(project: project, security_policy: policy).execute }

  shared_examples 'creating a security policy project schedule with correct attributes' do
    it 'creates a new project schedule for the security policy' do
      expect { execute }.to change { policy.security_pipeline_execution_project_schedules.count }
        .from(0).to(1)
    end

    it 'ensures the created schedule has the expected attributes' do
      allow(Random).to receive(:rand).and_return(0)

      execute

      schedule = policy.security_pipeline_execution_project_schedules.sole

      expect(schedule).to have_attributes(expected_attributes)
    end
  end

  context 'with daily schedule' do
    it_behaves_like 'creating a security policy project schedule with correct attributes' do
      let(:schedule) do
        {
          type: 'daily',
          start_time: "23:30",
          time_window: {
            value: 2.hours.to_i,
            distribution: 'random'
          },
          timezone: "Atlantic/Cape_Verde"
        }
      end

      let(:expected_attributes) do
        {
          cron: "30 23 * * *",
          cron_timezone: "Atlantic/Cape_Verde",
          time_window_seconds: 7200,
          next_run_at: Time.zone.parse("2025-01-01 00:30:00"), # Thu, Jan 2nd
          project_id: project.id,
          security_policy_id: policy.id
        }
      end
    end
  end

  context 'with weekly schedule' do
    it_behaves_like 'creating a security policy project schedule with correct attributes' do
      let(:schedule) do
        { type: 'weekly',
          days: %w[Monday Tuesday],
          start_time: "12:00",
          time_window: {
            value: 4.hours.to_i,
            distribution: 'random'
          },
          timezone: "Europe/Berlin" } # 1 hour ahead of UTC
      end

      let(:expected_attributes) do
        {
          cron: "0 12 * * 1,2",
          cron_timezone: "Europe/Berlin", # 1 hour ahead of UTC
          time_window_seconds: 14400,
          next_run_at: Time.zone.parse("2025-01-06 11:00:00"), # Mon, Jan 6th
          project_id: project.id,
          security_policy_id: policy.id
        }
      end
    end
  end

  context 'with monthly schedule' do
    it_behaves_like 'creating a security policy project schedule with correct attributes' do
      let(:schedule) do
        { type: 'monthly',
          days_of_month: [29, 31],
          start_time: "23:00",
          time_window: {
            value: 8.hours.to_i,
            distribution: 'random'
          } }
      end

      let(:expected_attributes) do
        {
          cron: "0 23 29,31 * *",
          cron_timezone: "UTC",
          time_window_seconds: 28800,
          next_run_at: Time.zone.parse("2025-01-29 23:00:00"), # Wed, Jan 29th
          project_id: project.id,
          security_policy_id: policy.id
        }
      end
    end
  end

  context 'with snooze' do
    it_behaves_like 'creating a security policy project schedule with correct attributes' do
      let(:schedule) do
        {
          type: 'monthly',
          days_of_month: [29, 31],
          start_time: "23:00",
          time_window: {
            value: 8.hours.to_i,
            distribution: 'random'
          },
          snooze: {
            until: '2025-06-26T16:27:00+00:00'
          }
        }
      end

      let(:expected_attributes) do
        {
          cron: "0 23 29,31 * *",
          cron_timezone: "UTC",
          time_window_seconds: 28800,
          next_run_at: Time.zone.parse("2025-01-29 23:00:00"), # Wed, Jan 29th
          project_id: project.id,
          security_policy_id: policy.id,
          snoozed_until: Time.zone.parse("2025-06-26 16:27:00")
        }
      end
    end
  end

  context 'with snooze and time_zone' do
    it_behaves_like 'creating a security policy project schedule with correct attributes' do
      let(:schedule) do
        {
          type: 'weekly',
          days: %w[Monday Tuesday],
          start_time: "12:00",
          time_window: {
            value: 4.hours.to_i,
            distribution: 'random'
          },
          timezone: "Europe/Berlin", # 1 hour ahead of UTC
          snooze: {
            until: '2025-06-26T16:27:00+01:00'
          }
        }
      end

      let(:expected_attributes) do
        {
          cron: "0 12 * * 1,2",
          cron_timezone: "Europe/Berlin", # 1 hour ahead of UTC
          time_window_seconds: 14400,
          next_run_at: Time.zone.parse("2025-01-06 11:00:00"), # Mon, Jan 6th
          project_id: project.id,
          security_policy_id: policy.id,
          snoozed_until: Time.zone.parse("2025-06-26 15:27:00")
        }
      end
    end
  end

  it 'succeeds' do
    expect(execute[:status]).to be(:success)
  end

  context 'with invalid attributes' do
    let(:intervals) { Gitlab::Security::Orchestration::PipelineExecutionPolicies::Intervals }

    let(:invalid_interval) do
      intervals::Interval.new(cron: "* * * * *", time_window: 0, time_zone: "UTC", snoozed_until: nil)
    end

    let(:exception_message) do
      a_string_including('Time window seconds must be greater than or equal to 600')
    end

    let(:expected_log) do
      {
        "class" => described_class.name,
        "event" => described_class::EVENT_KEY,
        "exception_class" => ActiveRecord::RecordInvalid.name,
        "exception_message" => exception_message,
        "project_id" => project.id,
        "policy_id" => policy.id
      }
    end

    before do
      allow(intervals).to receive(:from_schedules).and_return([invalid_interval])
    end

    it 'logs and reraises the error', :aggregate_failures do
      expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

      expect { execute }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(scheduled_pipeline_execution_policies: false)
    end

    it 'does not create schedules' do
      expect { execute }.not_to change { policy.security_pipeline_execution_project_schedules.count }
    end
  end

  context 'with already existing schedule' do
    let!(:existing_schedule) do
      create(:security_pipeline_execution_project_schedule, project: project, security_policy: policy)
    end

    it 'does not create more schedules than before' do
      expect { execute }.not_to change {
        policy.security_pipeline_execution_project_schedules.for_project(project).count
      }

      expect(Security::PipelineExecutionProjectSchedule.where(id: existing_schedule.id).count).to be_zero
    end
  end
end
