# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncProjectPolicyWorker, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_policy) { create(:security_policy) }

  let(:project_id) { project.id }
  let(:security_policy_id) { security_policy.id }
  let(:policy_changes) { { 'some_key' => 'some_value' } }
  let(:worker) { described_class.new }

  describe 'retry behavior' do
    let(:exception) { ActiveRecord::RecordInvalid.new }

    subject(:retry_in) { described_class.sidekiq_retry_in_block.call(0, exception, jobhash) }

    shared_examples_for 'when the exception is not an ActiveRecord::RecordInvalid' do
      let(:exception) { Timeout::Error.new }

      it 'returns nil to use the default delay' do
        expect(retry_in).to be_nil
      end
    end

    context 'when the job is not already a resync event' do
      let(:jobhash) { { 'args' => [project_id, security_policy_id, policy_changes, params] } }

      shared_examples_for 'enqueues a resync job and discards the original retry' do
        it 'enqueues a resync job and discards the original retry' do
          expect(described_class).to receive(:perform_async).with(
            project_id, security_policy_id, {},
            { event: { event_type: 'Security::PolicyResyncEvent', data: { security_policy_id: security_policy_id } } }
          ).once

          expect(retry_in).to eq(:discard)
        end
      end

      context 'when `params` is an empty hash' do
        let(:params) { {} }

        it_behaves_like 'enqueues a resync job and discards the original retry'
        it_behaves_like 'when the exception is not an ActiveRecord::RecordInvalid'
      end

      context 'when `params` is nil' do
        let(:params) { nil }

        it_behaves_like 'enqueues a resync job and discards the original retry'
        it_behaves_like 'when the exception is not an ActiveRecord::RecordInvalid'
      end
    end

    context 'when the job is already a resync event' do
      let(:params) do
        { 'event' => { 'event_type' => 'Security::PolicyResyncEvent',
                       'data' => { 'security_policy_id' => security_policy_id } } }
      end

      let(:jobhash) { { 'args' => [project_id, security_policy_id, policy_changes, params] } }

      it 'does not enqueue another resync job' do
        expect(described_class).not_to receive(:perform_async)

        expect(retry_in).to eq(:discard)
      end

      it_behaves_like 'when the exception is not an ActiveRecord::RecordInvalid'
    end
  end

  describe '#perform' do
    subject(:perform) { worker.perform(project_id, security_policy_id, policy_changes, params) }

    let(:params) { {} }

    context 'when project and security policy exist' do
      it 'calls the SyncProjectService with correct parameters' do
        sync_service = instance_double(Security::SecurityOrchestrationPolicies::SyncProjectService)
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).to receive(:new)
          .with(security_policy: security_policy, project: project, policy_changes: policy_changes.deep_symbolize_keys)
          .and_return(sync_service)
        expect(sync_service).to receive(:execute)

        perform
      end
    end

    context 'when params["event"] is present' do
      let(:event_type) { 'Repositories::ProtectedBranchCreatedEvent' }
      let(:event_data) do
        {
          'protected_branch_id' => non_existing_record_id,
          'parent_id' => non_existing_record_id,
          'parent_type' => 'project'
        }
      end

      let(:params) { { 'event' => { 'event_type' => event_type, 'data' => event_data } } }

      it 'calls the SyncPolicyEventService for supported event' do
        event_instance = instance_double(Repositories::ProtectedBranchCreatedEvent)
        allow(Repositories::ProtectedBranchCreatedEvent)
          .to receive(:new).with(data: event_data).and_return(event_instance)

        expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService).to receive(:new)
          .with(project: project, security_policy: security_policy, event: event_instance)
          .and_call_original

        perform
      end

      context 'when event_type is not supported' do
        let(:event_type) { 'UnsupportedEventType' }
        let(:params) { { 'event' => { 'event_type' => event_type, 'data' => event_data } } }

        it 'does not call the SyncPolicyEventService and logs an error' do
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService).not_to receive(:new)
          expect(Gitlab::AppJsonLogger).to receive(:error).with(hash_including(
            message: 'Invalid event type or data',
            event_type: event_type,
            event_data: event_data,
            project_id: project.id,
            security_policy_id: security_policy.id
          ))

          perform
        end
      end

      context 'when event_data is blank' do
        let(:event_data) { nil }
        let(:params) { { 'event' => { 'event_type' => event_type, 'data' => event_data } } }

        it 'does not call the SyncPolicyEventService and logs an error' do
          expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService).not_to receive(:new)
          expect(Gitlab::AppJsonLogger).to receive(:error).with(hash_including(
            message: 'Invalid event type or data',
            event_type: event_type,
            event_data: nil,
            project_id: project.id,
            security_policy_id: security_policy.id
          ))

          perform
        end
      end

      context 'when event_data is not a Hash' do
        let(:event_data) { 'not_a_hash' }
        let(:params) { { 'event' => { 'event_type' => event_type, 'data' => event_data } } }

        it 'raises Gitlab::EventStore::InvalidEvent' do
          expect { perform }.to raise_error(Gitlab::EventStore::InvalidEvent, /Event data must be a Hash/)
        end
      end

      context 'for SUPPORTED_EVENTS' do
        let(:event_payloads) do
          {
            'Repositories::ProtectedBranchCreatedEvent' => {
              'protected_branch_id' => non_existing_record_id,
              'parent_id' => project.id,
              'parent_type' => 'project'
            },
            'Repositories::ProtectedBranchDestroyedEvent' => {
              'parent_id' => project.id,
              'parent_type' => 'project'
            },
            'Repositories::DefaultBranchChangedEvent' => {
              'container_id' => project.id,
              'container_type' => 'Project'
            },
            'Projects::ComplianceFrameworkChangedEvent' => {
              'project_id' => project.id,
              'compliance_framework_id' => non_existing_record_id,
              'event_type' => 'added'
            },
            'Security::PolicyResyncEvent' => {
              'security_policy_id' => security_policy.id
            }
          }
        end

        it "calls the SyncPolicyEventService for each supported event" do
          event_payloads.each do |event_type, event_data|
            params = { 'event' => { 'event_type' => event_type, 'data' => event_data } }
            event_class = event_type.constantize
            event_instance = instance_double(event_class)
            allow(event_class).to receive(:new).with(data: event_data).and_return(event_instance)

            expect(Security::SecurityOrchestrationPolicies::SyncPolicyEventService).to receive(:new)
              .with(project: project, security_policy: security_policy, event: event_instance)
              .and_call_original

            described_class.new.perform(project.id, security_policy.id, policy_changes, params)
          end
        end
      end
    end

    context 'when project does not exist' do
      let(:project_id) { non_existing_record_id }

      it 'does not call the SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end

    context 'when security policy does not exist' do
      let(:security_policy_id) { non_existing_record_id }

      it 'does not call the SyncProjectService' do
        expect(Security::SecurityOrchestrationPolicies::SyncProjectService).not_to receive(:new)

        perform
      end
    end
  end

  describe 'deduplication' do
    let(:policy_changes_2) { { 'some_key' => 'some_other_value' } }
    let(:job_a) { { 'class' => described_class.name, 'args' => [project_id, security_policy_id, policy_changes] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [project_id, security_policy_id, policy_changes_2] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end
end
