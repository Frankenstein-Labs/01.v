# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::CreateBranchWorker, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let(:user) { maintainer }

  let(:branch_name) { 'new-test-branch' }
  let(:ref) { 'master' }
  let(:worker) { described_class.new }
  let(:notify_key) { Gitlab::JobWaiter.generate_key }
  let(:job_args) { [project.id, user.id, branch_name, ref, notify_key] }

  subject(:perform) { worker.perform(*job_args) }

  before do
    allow(worker).to receive(:jid).and_return('test-jid')
  end

  describe '.add_error' do
    subject(:add_error) { described_class.add_error(notify_key, branch_name, 'message') }

    it 'delegates to CreateBranchesFinishWorker' do
      expect(Repositories::CreateBranchesFinishWorker).to receive(:add_error).with(notify_key, branch_name, 'message')

      add_error
    end
  end

  describe '#perform' do
    context 'with a non-existing project' do
      let(:project) { instance_double(Project, id: non_existing_record_id) }

      it 'notifies the waiter without creating a branch' do
        expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)
        expect(::Branches::CreateService).not_to receive(:new)

        perform
      end
    end

    context 'with a non-existing user' do
      let(:user) { instance_double(User, id: non_existing_record_id) }

      it 'notifies the waiter without creating a branch' do
        expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)
        expect(::Branches::CreateService).not_to receive(:new)

        perform
      end
    end

    context 'with existing user and project' do
      it 'calls Branches::CreateService#execute' do
        expect_next_instance_of(::Branches::CreateService, project, user) do |instance|
          expect(instance).to receive(:execute).with(branch_name, ref).and_return({ status: :success })
        end

        perform
      end

      context 'when user is not allowed to access_git' do
        let(:user) { create(:user, :placeholder) }

        it 'adds an error and notifies the waiter without creating a branch' do
          expect(Gitlab::JobWaiter).to receive(:notify)
            .with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)
          expect(described_class).to receive(:add_error)
            .with(
              notify_key,
              branch_name,
              'The mirror user is not allowed to perform any git operations.'
            )
          expect(::Branches::CreateService).not_to receive(:new)

          perform
        end
      end

      context 'when user is not allowed to push_code_to_protected_branches' do
        let(:user) { create(:user) }

        it 'adds an error and notifies the waiter without creating a branch' do
          expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)
          expect(described_class).to receive(:add_error)
          .with(
            notify_key,
            branch_name,
            'The mirror user is not allowed to push code to all branches on this project.'
          )
          expect(::Branches::CreateService).not_to receive(:new)

          perform
        end
      end
    end

    it 'notifies the waiter on success' do
      expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)

      perform
    end

    it 'notifies the waiter even on service failure' do
      expect_next_instance_of(::Branches::CreateService, project, user) do |instance|
        expect(instance).to receive(:execute)
          .with(branch_name, ref)
          .and_return({ status: :error, message: 'Branch name is invalid' })
      end

      expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)

      perform
    end

    it 'avoids notifying the waiter even when an exception is raised' do
      expect_next_instance_of(::Branches::CreateService, project, user) do |instance|
        expect(instance).to receive(:execute).and_raise(StandardError, 'unexpected')
      end

      expect(Gitlab::JobWaiter).not_to receive(:notify)
        .with(notify_key, 'test-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)

      expect { perform }.to raise_error(StandardError)
    end

    context 'when branch creation fails' do
      it 'caches the error in Redis' do
        expect_next_instance_of(::Branches::CreateService, project, user) do |instance|
          expect(instance).to receive(:execute)
            .with(branch_name, ref)
            .and_return({ status: :error, message: 'Branch name is invalid' })
        end

        expect(described_class).to receive(:add_error)
          .with(notify_key, branch_name, 'Branch name is invalid')

        perform
      end
    end

    context 'when branch creation succeeds' do
      it 'does not cache any error' do
        expect_next_instance_of(::Branches::CreateService, project, user) do |instance|
          expect(instance).to receive(:execute)
            .with(branch_name, ref)
            .and_return({ status: :success })
        end

        expect(described_class).not_to receive(:add_error)

        perform
      end

      it 'injects "pull-mirror-update" => true into the gitaly_context', :request_store,
        :aggregate_failures do
        expect(::Gitlab::GitalyClient).to receive(:with_context)
          .with(Projects::UpdateMirrorService::GITALY_CONTEXT_KEY => true)
          .and_call_original

        perform
      end
    end

    context 'when skip_ci is true' do
      let(:job_args) { [project.id, user.id, branch_name, ref, notify_key, true] }

      it 'injects "skip-ci" => true into the gitaly_context', :request_store do
        expect(::Gitlab::GitalyClient).to receive(:with_context)
          .with(hash_including(Projects::UpdateMirrorService::GITALY_CONTEXT_KEY => true, 'skip-ci' => true))
          .and_call_original

        perform
      end
    end

    context 'when skip_ci is false' do
      let(:job_args) { [project.id, user.id, branch_name, ref, notify_key, false] }

      it 'does not inject "skip-ci" into the gitaly_context', :request_store do
        expect(::Gitlab::GitalyClient).to receive(:with_context)
          .with(Projects::UpdateMirrorService::GITALY_CONTEXT_KEY => true)
          .and_call_original

        perform
      end
    end
  end

  describe '.sidekiq_retries_exhausted' do
    let(:notify_key) { Gitlab::JobWaiter.generate_key }
    let(:job) do
      {
        'args' => job_args,
        'jid' => 'exhausted-jid',
        'error_message' => 'Something went wrong'
      }
    end

    it 'caches the error in Redis' do
      expect(described_class).to receive(:add_error)
        .with(notify_key, branch_name, 'Something went wrong')

      described_class.sidekiq_retries_exhausted_block.call(job)
    end

    it 'notifies the waiter when retries are exhausted' do
      expect(Gitlab::JobWaiter).to receive(:notify).with(notify_key, 'exhausted-jid',
        ttl: Gitlab::Import::JOB_WAITER_TTL)

      described_class.sidekiq_retries_exhausted_block.call(job)
    end

    context 'when skip_ci parameter is present' do
      let(:job_args_with_skip_ci) { [project.id, user.id, branch_name, ref, notify_key, true] }
      let(:job_with_skip_ci) do
        {
          'args' => job_args_with_skip_ci,
          'jid' => 'exhausted-jid',
          'error_message' => 'Something went wrong'
        }
      end

      it 'correctly extracts notify_key from index 4 (not args.last)', :aggregate_failures do
        expect(described_class).to receive(:add_error)
          .with(notify_key, branch_name, 'Something went wrong')
        expect(Gitlab::JobWaiter).to receive(:notify)
          .with(notify_key, 'exhausted-jid', ttl: Gitlab::Import::JOB_WAITER_TTL)

        described_class.sidekiq_retries_exhausted_block.call(job_with_skip_ci)
      end
    end
  end
end
