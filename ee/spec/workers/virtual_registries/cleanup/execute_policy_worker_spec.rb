# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Cleanup::ExecutePolicyWorker, feature_category: :virtual_registry do
  let(:worker) { described_class.new }

  subject(:perform_work) { worker.perform_work }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker'
  it 'has a none deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:none)
  end

  describe '#max_running_jobs' do
    subject { worker.max_running_jobs }

    it { is_expected.to eq(2) }
  end

  describe '#remaining_work_count' do
    subject { worker.remaining_work_count }

    context 'when there are no runnable policies' do
      it { is_expected.to eq(0) }
    end

    context 'when there are runnable policies' do
      before do
        create(:virtual_registries_cleanup_policy, :enabled).tap { |p| p.update_column(:next_run_at, 1.hour.ago) }
        create(:virtual_registries_cleanup_policy).tap { |p| p.update_column(:next_run_at, 1.hour.ago) }
        create(:virtual_registries_cleanup_policy, :enabled).tap { |p| p.update_column(:next_run_at, 1.hour.from_now) }
        create(:virtual_registries_cleanup_policy, :enabled, :running).tap do |p|
          p.update_column(:next_run_at, 1.hour.ago)
        end
      end

      it { is_expected.to eq(1) }
    end

    context 'when there are more runnable policies than max capacity' do
      before do
        5.times do
          create(:virtual_registries_cleanup_policy, :enabled).tap { |p| p.update_column(:next_run_at, 1.hour.ago) }
        end
      end

      it { is_expected.to eq(3) } # MAX_CAPACITY + 1
    end
  end

  describe '#perform_work' do
    let_it_be_with_reload(:policy) { create(:virtual_registries_cleanup_policy) }

    let(:service) { instance_double(VirtualRegistries::Cleanup::ExecutePolicyService) }
    let(:service_result) { ServiceResponse.success(payload:) }
    let(:payload) do
      {
        maven: {
          deleted_entries_count: 10,
          deleted_size: 1024
        }
      }
    end

    before do
      allow(VirtualRegistries::Cleanup::ExecutePolicyService).to receive(:new).and_return(service)
      allow(service).to receive(:execute).and_return(service_result)
    end

    context 'when there is no policy to run' do
      it 'does nothing' do
        expect(VirtualRegistries::Cleanup::ExecutePolicyService).not_to receive(:new)

        perform_work
      end
    end

    context 'when there is a policy to run' do
      before do
        policy.update_columns(enabled: true, next_run_at: 1.hour.ago)
      end

      it 'executes the cleanup service' do
        expect(VirtualRegistries::Cleanup::ExecutePolicyService).to receive(:new).with(policy)
        expect(service).to receive(:execute)

        perform_work
      end

      context 'when service execution is successful' do
        it 'updates policy with success attributes', :aggregate_failures, :freeze_time do
          expect_next_found_instance_of(VirtualRegistries::Cleanup::Policy) do |policy|
            expect(policy).to receive(:assign_attributes).with({
              status: :scheduled,
              failure_message: nil,
              last_run_detailed_metrics: payload,
              last_run_deleted_entries_count: 10,
              last_run_deleted_size: 1024
            })
            expect(policy).to receive(:last_run_at=).with(Time.current)
            expect(policy).to receive(:schedule_next_run!)
          end

          expect(worker).to receive(:log_extra_metadata_on_done).with(:deleted_entries_count, 10)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:deleted_size, 1024)

          perform_work
        end

        context 'with multiple upstream types in payload' do
          let(:payload) do
            {
              maven: {
                deleted_entries_count: 10,
                deleted_size: 1024
              },
              container: {
                deleted_entries_count: 5,
                deleted_size: 512
              }
            }
          end

          it 'sums up counts from all upstream types', :aggregate_failures, :freeze_time do
            expect_next_found_instance_of(VirtualRegistries::Cleanup::Policy) do |policy|
              expect(policy).to receive(:assign_attributes).with({
                status: :scheduled,
                failure_message: nil,
                last_run_detailed_metrics: payload,
                last_run_deleted_entries_count: 15, # 10 + 5
                last_run_deleted_size: 1536 # 1024 + 512
              })
              expect(policy).to receive(:last_run_at=).with(Time.current)
              expect(policy).to receive(:schedule_next_run!)
            end

            expect(worker).to receive(:log_extra_metadata_on_done).with(:deleted_entries_count, 15)
            expect(worker).to receive(:log_extra_metadata_on_done).with(:deleted_size, 1536)

            perform_work
          end
        end

        context 'when notify_on_success is true' do
          before do
            policy.update_column(:notify_on_success, true)
            create(:user, owner_of: policy.group)
          end

          it 'sends success notification email' do
            expect(Notify).to receive(:virtual_registry_cleanup_complete)
              .with(policy, instance_of(User)).and_call_original

            perform_work
          end
        end

        context 'when notify_on_success is false' do
          before do
            policy.update_column(:notify_on_success, false)
          end

          it 'does not send notification email' do
            expect(Notify).not_to receive(:virtual_registry_cleanup_complete)

            perform_work
          end
        end
      end

      context 'when service execution fails' do
        let(:error_message) { 'Something went wrong' }
        let(:service_result) { ServiceResponse.error(message: error_message) }

        it 'updates policy with failure attributes', :aggregate_failures, :freeze_time do
          expect_next_found_instance_of(VirtualRegistries::Cleanup::Policy) do |policy|
            expect(policy).to receive(:assign_attributes).with({
              status: :failed,
              failure_message: error_message
            })
            expect(policy).to receive(:last_run_at=).with(Time.current)
            expect(policy).to receive(:schedule_next_run!)
          end

          perform_work
        end

        context 'when notify_on_failure is true' do
          before do
            policy.update_column(:notify_on_failure, true)
            create(:user, owner_of: policy.group)
          end

          it 'sends failure notification email' do
            expect(Notify).to receive(:virtual_registry_cleanup_failure)
              .with(policy, instance_of(User)).and_call_original

            perform_work
          end
        end

        context 'when notify_on_failure is false' do
          before do
            policy.update_column(:notify_on_failure, false)
          end

          it 'does not send notification email' do
            expect(Notify).not_to receive(:virtual_registry_cleanup_failure)

            perform_work
          end
        end
      end
    end
  end

  describe '#log_running_policy' do
    let_it_be_with_reload(:policy) { create(:virtual_registries_cleanup_policy) }

    let(:logger) { instance_double(Logger) }

    before do
      allow(worker).to receive(:logger).and_return(logger)
    end

    it 'logs structured payload with policy and group information' do
      expect(logger).to receive(:info).with(
        worker.send(:structured_payload,
          virtual_registry_cleanup_policy_id: policy.id,
          group_id: policy.group_id
        )
      )

      worker.send(:log_running_policy, policy)
    end
  end
end
