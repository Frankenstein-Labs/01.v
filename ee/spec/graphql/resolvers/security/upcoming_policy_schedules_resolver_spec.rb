# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::UpcomingPolicySchedulesResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:policy_management_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  let_it_be(:security_policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      name: 'test-policy',
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:policy_hash) do
    {
      policy_index: 0,
      type: 'pipeline_execution_schedule_policy',
      config: policy_configuration
    }
  end

  let(:ctx) { { current_user: user } }

  subject(:resolve_upcoming_schedules) { sync(resolve(described_class, obj: policy_hash, ctx: ctx)) }

  describe '#resolve' do
    context 'when policy type is not pipeline_execution_schedule_policy' do
      let(:policy_hash) do
        {
          policy_index: 0,
          type: 'scan_execution_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_upcoming_schedules.items).to be_empty
      end
    end

    context 'when policy_index is nil' do
      let(:policy_hash) do
        {
          policy_index: nil,
          type: 'pipeline_execution_schedule_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_upcoming_schedules.items).to be_empty
      end
    end

    context 'when config is nil' do
      let(:policy_hash) do
        {
          policy_index: 0,
          type: 'pipeline_execution_schedule_policy',
          config: nil
        }
      end

      it 'returns empty results' do
        expect(resolve_upcoming_schedules.items).to be_empty
      end
    end

    context 'when the security policy is not found' do
      let(:policy_hash) do
        {
          policy_index: 999,
          type: 'pipeline_execution_schedule_policy',
          config: policy_configuration
        }
      end

      it 'returns empty results' do
        expect(resolve_upcoming_schedules.items).to be_empty
      end
    end

    context 'when project schedules exist for the policy' do
      let!(:project_schedule) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          project: project)
      end

      it 'returns the upcoming schedules' do
        expect(resolve_upcoming_schedules.items).to contain_exactly(project_schedule)
      end
    end

    context 'when multiple schedules exist for different configurations' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_policy_management_project) { create(:project) }

      let_it_be(:other_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: other_policy_management_project,
          project: other_project
        )
      end

      let_it_be(:other_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          name: 'other-test-policy',
          security_orchestration_policy_configuration: other_policy_configuration)
      end

      let_it_be(:schedule_for_policy) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          project: project)
      end

      let_it_be(:schedule_for_other_policy) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: other_security_policy,
          project: other_project)
      end

      let(:policy_hash_one) do
        { policy_index: 0, type: 'pipeline_execution_schedule_policy', config: policy_configuration }
      end

      let(:policy_hash_two) do
        { policy_index: 0, type: 'pipeline_execution_schedule_policy', config: other_policy_configuration }
      end

      it 'returns only the schedules belonging to the given policy', :aggregate_failures do
        result_one = sync(resolve(described_class, obj: policy_hash_one, ctx: ctx)).items
        result_two = sync(resolve(described_class, obj: policy_hash_two, ctx: ctx)).items

        expect(result_one).to contain_exactly(schedule_for_policy)
        expect(result_two).to contain_exactly(schedule_for_other_policy)
      end

      it 'avoids N+1 queries when accessing associations' do
        resolve_both = -> do
          connections = batch_sync do
            [
              resolve(described_class, obj: policy_hash_one, ctx: ctx),
              resolve(described_class, obj: policy_hash_two, ctx: ctx)
            ]
          end
          connections.each do |conn|
            conn.items.each do |schedule|
              # Access all preloaded associations including the authorization path
              schedule.security_policy
              schedule.security_policy.security_policy_management_project
              schedule.project
              schedule.project.route
            end
          end
        end

        resolve_both.call
        control = ActiveRecord::QueryRecorder.new { resolve_both.call }

        create(:security_pipeline_execution_project_schedule, security_policy: security_policy, project: project)
        create(:security_pipeline_execution_project_schedule, security_policy: security_policy, project: project)
        create(:security_pipeline_execution_project_schedule, security_policy: other_security_policy,
          project: other_project)
        create(:security_pipeline_execution_project_schedule, security_policy: other_security_policy,
          project: other_project)

        expect { resolve_both.call }.not_to exceed_query_limit(control)
      end
    end

    context 'when schedules are ordered by next_run_at' do
      let_it_be(:ordering_project) { create(:project) }
      let_it_be(:ordering_policy_management_project) { create(:project) }

      let_it_be(:ordering_policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          security_policy_management_project: ordering_policy_management_project,
          project: ordering_project
        )
      end

      let_it_be(:ordering_security_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy,
          name: 'ordering-test-policy',
          security_orchestration_policy_configuration: ordering_policy_configuration)
      end

      let_it_be(:schedule_later, reload: true) do
        schedule = create(:security_pipeline_execution_project_schedule,
          security_policy: ordering_security_policy,
          project: ordering_project)
        # Use class-level update_all to bypass the frozen object and set next_run_at
        Security::PipelineExecutionProjectSchedule.where(id: schedule.id).update_all(next_run_at: 2.days.from_now)
        schedule
      end

      let_it_be(:schedule_earlier, reload: true) do
        schedule = create(:security_pipeline_execution_project_schedule,
          security_policy: ordering_security_policy,
          project: ordering_project)
        # Use class-level update_all to bypass the frozen object and set next_run_at
        Security::PipelineExecutionProjectSchedule.where(id: schedule.id).update_all(next_run_at: 1.day.from_now)
        schedule
      end

      let(:policy_hash) do
        { policy_index: 0, type: 'pipeline_execution_schedule_policy', config: ordering_policy_configuration }
      end

      # Using `eq` intentionally because we're testing that results are ordered by next_run_at
      it 'returns schedules ordered by next_run_at ascending' do
        result = resolve_upcoming_schedules.items

        expect(result).to eq([schedule_earlier, schedule_later])
      end
    end

    context 'when the policy is deleted' do
      let_it_be(:deleted_policy) do
        create(:security_policy, :pipeline_execution_schedule_policy, :deleted,
          name: 'deleted-policy',
          security_orchestration_policy_configuration: policy_configuration)
      end

      let_it_be(:schedule_for_deleted_policy) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: deleted_policy,
          project: project)
      end

      let(:policy_hash) do
        { policy_index: deleted_policy.policy_index, type: 'pipeline_execution_schedule_policy',
          config: policy_configuration }
      end

      it 'returns empty results' do
        expect(resolve_upcoming_schedules.items).to be_empty
      end
    end

    context 'when schedule is snoozed' do
      let_it_be(:active_schedule) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          project: project,
          snoozed_until: nil)
      end

      let_it_be(:snoozed_schedule) do
        create(:security_pipeline_execution_project_schedule,
          security_policy: security_policy,
          project: project,
          snoozed_until: 1.week.from_now)
      end

      it 'includes both active and snoozed schedules' do
        result = resolve_upcoming_schedules.items

        expect(result).to contain_exactly(active_schedule, snoozed_schedule)
      end
    end
  end
end
