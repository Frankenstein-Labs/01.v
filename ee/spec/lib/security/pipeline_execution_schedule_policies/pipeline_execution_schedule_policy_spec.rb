# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionSchedulePolicies::PipelineExecutionSchedulePolicy, feature_category: :security_policy_management do
  let(:policy_content) do
    {
      content: {
        include: [
          { project: 'group/compliance-project', file: 'compliance/pipeline.yml', ref: 'main' }
        ]
      },
      schedules: [
        {
          type: 'daily',
          branches: %w[main develop],
          start_time: '09:00',
          time_window: {
            value: 3600,
            distribution: 'random'
          },
          timezone: 'America/New_York',
          snooze: {
            until: '2025-12-31T23:59:59+00:00',
            reason: 'Holiday break'
          }
        }
      ]
    }
  end

  let(:scope) do
    { groups: { including: [{ id: 1 }] }, projects: { excluding: [{ id: 5 }] } }
  end

  let(:policy_record) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      name: 'Test Pipeline Execution Schedule Policy',
      description: 'Test Description',
      enabled: true,
      scope: scope.as_json,
      content: policy_content)
  end

  let(:pipeline_execution_schedule_policy) { described_class.new(policy_record) }

  describe '#content' do
    subject(:content) { pipeline_execution_schedule_policy.content }

    it 'returns a Content instance with correct values' do
      expect(content).to be_a(Security::PipelineExecutionSchedulePolicies::Content)

      include_item = content.include[0]
      expect(include_item).to be_a(Security::PipelineExecutionPolicies::Include)
      expect(include_item.project).to eq('group/compliance-project')
      expect(include_item.file).to eq('compliance/pipeline.yml')
      expect(include_item.ref).to eq('main')
    end

    it 'passes the content data from policy_content' do
      expect(Security::PipelineExecutionSchedulePolicies::Content).to receive(:new).with(
        {
          include: [
            { project: 'group/compliance-project', file: 'compliance/pipeline.yml', ref: 'main' }
          ]
        }
      )

      content
    end

    context 'when content is not present in policy_content' do
      let(:policy_content) do
        { schedules: [{ type: 'daily', start_time: '09:00', time_window: { value: 3600, distribution: 'random' } }] }
      end

      it 'returns a content instance with default values' do
        expect(content.include).to be_empty
      end

      it 'passes an empty hash to Content' do
        expect(Security::PipelineExecutionSchedulePolicies::Content).to receive(:new).with({})

        content
      end
    end
  end

  describe '#schedules' do
    subject(:schedules) { pipeline_execution_schedule_policy.schedules }

    it 'returns an array of Schedule instances' do
      expect(schedules).to be_an(Array)
      expect(schedules.length).to eq(1)
      expect(schedules.first).to be_a(Security::PipelineExecutionSchedulePolicies::Schedule)
    end

    it 'returns schedules with correct values' do
      schedule = schedules.first
      expect(schedule.type).to eq('daily')
      expect(schedule.branches).to match_array(%w[main develop])
      expect(schedule.start_time).to eq('09:00')
      expect(schedule.timezone).to eq('America/New_York')
    end

    context 'when schedules is not present in policy_content' do
      let(:policy_content) { { content: { include: [{ project: 'group/project', file: 'file.yml' }] } } }

      it 'returns an empty array' do
        expect(schedules).to be_empty
      end
    end
  end

  describe 'inherited methods from BaseSecurityPolicy' do
    it 'delegates name to policy_record' do
      expect(pipeline_execution_schedule_policy.name).to eq('Test Pipeline Execution Schedule Policy')
    end

    it 'delegates description to policy_record' do
      expect(pipeline_execution_schedule_policy.description).to eq('Test Description')
    end

    it 'delegates enabled to policy_record' do
      expect(pipeline_execution_schedule_policy.enabled).to be true
    end

    describe '#policy_scope' do
      subject(:policy_scope) { pipeline_execution_schedule_policy.policy_scope }

      it 'returns a PolicyScope instance with correct values' do
        expect(policy_scope).to be_a(Security::PolicyScope)

        expect(policy_scope.projects).to eq({ excluding: [{ id: 5 }] })
        expect(policy_scope.groups).to eq({ including: [{ id: 1 }] })
      end

      it 'passes the policy scope data to PolicyScope' do
        expect(Security::PolicyScope).to receive(:new).with(scope)

        policy_scope
      end

      context 'when scope is not present in policy' do
        let(:scope) { {} }

        it 'returns a PolicyScope instance with default values' do
          expect(policy_scope.projects).to eq({})
          expect(policy_scope.groups).to eq({})
        end

        it 'passes an empty hash to PolicyScope' do
          expect(Security::PolicyScope).to receive(:new).with({})

          policy_scope
        end
      end
    end
  end
end
