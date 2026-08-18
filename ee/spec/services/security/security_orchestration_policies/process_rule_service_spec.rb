# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProcessRuleService, feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:owner) { create(:user) }

    let(:policy) do
      rules = [
        { type: 'pipeline', branches: %w[production] },
        { type: 'schedule', branches: %w[production], cadence: '*/15 * * * *' }
      ]

      build(:scan_execution_policy, rules: rules)
    end

    subject(:service) { described_class.new(policy_configuration: policy_configuration, policy_index: 0, policy: policy) }

    before do
      allow(policy_configuration).to receive(:policy_last_updated_by).and_return(owner)
    end

    context 'when security_orchestration_policies_configuration policy is scheduled' do
      it 'creates new schedule' do
        service.execute

        expect(Security::OrchestrationPolicyRuleSchedule.count).to eq(1)
        schedule = Security::OrchestrationPolicyRuleSchedule.last
        expect(schedule.security_orchestration_policy_configuration).to eq(policy_configuration)
        expect(schedule.policy_index).to eq(0)
        expect(schedule.rule_index).to eq(1)
        expect(schedule.cron).to eq('*/15 * * * *')
        expect(schedule.owner).to eq(owner)
        expect(schedule.policy_type).to eq('scan_execution_policy')
        expect(schedule.next_run_at).to be_future
      end

      context 'when there is no policy_last_updated_by user' do
        before do
          allow(policy_configuration).to receive(:policy_last_updated_by).and_return(nil)
        end

        it 'creates new schedule' do
          service.execute

          expect(Security::OrchestrationPolicyRuleSchedule.count).to eq(1)
          schedule = Security::OrchestrationPolicyRuleSchedule.last
          expect(schedule.security_orchestration_policy_configuration).to eq(policy_configuration)
          expect(schedule.policy_index).to eq(0)
          expect(schedule.rule_index).to eq(1)
          expect(schedule.cron).to eq('*/15 * * * *')
          expect(schedule.owner).to be_nil
          expect(schedule.policy_type).to eq('scan_execution_policy')
          expect(schedule.next_run_at).to be_future
        end
      end

      context 'when rule schedule is invalid' do
        before do
          allow_next_instance_of(Security::OrchestrationPolicyRuleSchedule) do |rule_schedule|
            allow(rule_schedule).to receive_messages(
              valid?: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['Invalid cron'])
            )
          end
        end

        it 'logs with structured data' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              message: "Failed to create policy rule schedule: [\"Invalid cron\"]",
              policy_configuration_id: policy_configuration.id,
              policy_index: 0,
              rule_index: 1
            )
          )

          service.execute
        end
      end

      describe "rule schedule limit" do
        before do
          allow(Gitlab::CurrentSettings).to receive(:scan_execution_policies_schedule_limit).and_return(limit)
        end

        let(:rules) do
          [
            { type: 'pipeline', branches: %w[production] },
            { type: 'schedule', branches: %w[production], cadence: '*/15 * * * *' },
            { type: 'schedule', branches: %w[production], cadence: '2 * * * *' },
            { type: 'schedule', branches: %w[production], cadence: '4 * * * *' }
          ]
        end

        let(:policy) { build(:scan_execution_policy, rules: rules) }

        context 'with zero schedule limit' do
          let(:limit) { 0 }

          it 'creates all schedules' do
            service.execute

            expect(Security::OrchestrationPolicyRuleSchedule.count).to be(3)
          end
        end

        context 'when below schedule limit' do
          let(:limit) { 4 }

          it 'creates all schedules' do
            service.execute

            expect(Security::OrchestrationPolicyRuleSchedule.count).to be(3)
          end
        end

        context 'when equal to limit' do
          let(:limit) { 3 }

          it 'creates all schedules' do
            service.execute

            expect(Security::OrchestrationPolicyRuleSchedule.count).to be(3)
          end
        end

        context 'when exceeding schedule limit' do
          let(:limit) { 2 }

          it 'creates schedules only to a configured limit' do
            service.execute

            expect(Security::OrchestrationPolicyRuleSchedule.count).to be(2)
          end
        end
      end
    end

    context 'when cadence is not valid' do
      let(:policy) do
        rules = [
          { type: 'pipeline', branches: %w[production] },
          { type: 'schedule', branches: %w[production], cadence: 'invalid cadence' }
        ]

        build(:scan_execution_policy, rules: rules)
      end

      it 'does not create a new schedule' do
        expect { service.execute }.not_to change { Security::OrchestrationPolicyRuleSchedule.count }
      end
    end

    context 'when cadence is empty' do
      let(:policy) do
        rules = [
          { type: 'pipeline', branches: %w[production] },
          { type: 'schedule', branches: %w[production], cadence: '' }
        ]

        build(:scan_execution_policy, rules: rules)
      end

      it 'does not create a new schedule' do
        expect { service.execute }.not_to change { Security::OrchestrationPolicyRuleSchedule.count }
      end
    end

    context 'when cadence is missing' do
      let(:policy) do
        rules = [
          { type: 'pipeline', branches: %w[production] },
          { type: 'schedule', branches: %w[production], cadence: nil }
        ]

        build(:scan_execution_policy, rules: rules)
      end

      it 'does not create a new schedule' do
        expect { service.execute }.not_to change { Security::OrchestrationPolicyRuleSchedule.count }
      end
    end

    context 'when policy is not of type scheduled' do
      let(:policy) { build(:scan_execution_policy) }

      it 'does not create a new schedule' do
        expect { service.execute }.not_to change { Security::OrchestrationPolicyRuleSchedule.count }
      end
    end
  end
end
