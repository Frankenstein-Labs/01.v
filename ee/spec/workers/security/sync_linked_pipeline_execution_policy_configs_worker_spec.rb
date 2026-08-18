# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncLinkedPipelineExecutionPolicyConfigsWorker, '#perform', feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:user) { create(:user) }
  let!(:policy) do
    create(:security_policy, :pipeline_execution_policy,
      security_orchestration_policy_configuration: configuration,
      content: {
        pipeline_config_strategy: 'inject_ci',
        content: { include: [{ project: project.full_path, file: 'policy.yml', ref: 'master' }] }
      }).tap do |policy|
      create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: project)
    end
  end

  let(:content) { policy.content['content'] }
  let(:project_id) { project.id }
  let(:user_id) { user.id }
  let(:oldrev) { 'oldrev' }
  let(:newrev) { 'newrev' }
  let(:ref) { 'refs/heads/master' }
  let(:modified_paths) { %w[policy.yml] }
  let(:branch_updated) { true }

  subject(:perform) { described_class.new.perform(project_id, user_id, oldrev, newrev, ref) }

  before do
    git_push_double = instance_double(::Gitlab::Git::Push,
      modified_paths: modified_paths, branch_updated?: branch_updated)
    allow(::Gitlab::Git::Push).to receive(:new).with(project, oldrev, newrev, ref).and_return(git_push_double)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [project_id, user_id, oldrev, newrev, ref] }
  end

  shared_examples_for 'does not enqueue the worker' do
    it 'does not enqueue the SyncPipelineExecutionPolicyMetadataWorker' do
      expect(Security::SyncPipelineExecutionPolicyMetadataWorker).not_to receive(:perform_async)

      perform
    end
  end

  it 'enqueues a SyncPipelineExecutionPolicyMetadataWorker for affected policy configs' do
    expect(Security::SyncPipelineExecutionPolicyMetadataWorker)
      .to receive(:perform_async).with(project_id, user_id, content, [policy.id])

    perform
  end

  context 'with multiple affected policies' do
    context 'when policies reference the same content' do
      let!(:policy_2) do
        create(:security_policy, :pipeline_execution_policy, name: 'Policy 2', policy_index: 1,
          security_orchestration_policy_configuration: configuration,
          content: { pipeline_config_strategy: 'inject_ci', content: content }).tap do |policy|
          create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: project)
        end
      end

      it 'groups by content to remove duplicate processing' do
        expect(Security::SyncPipelineExecutionPolicyMetadataWorker)
          .to receive(:perform_async).with(project_id, user_id, content, [policy.id, policy_2.id])

        perform
      end
    end

    context 'when policies reference different content' do
      let(:modified_paths) { %w[policy.yml policy_2.yml] }
      let!(:policy_2) do
        create(:security_policy, :pipeline_execution_policy, name: 'Policy 2', policy_index: 1,
          security_orchestration_policy_configuration: configuration,
          content: {
            pipeline_config_strategy: 'inject_ci',
            content: { include: [{ project: project.full_path, file: 'policy_2.yml' }] }
          }).tap do |policy|
          create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: project)
        end
      end

      it 'enqueues the worker for each policy' do
        expect(Security::SyncPipelineExecutionPolicyMetadataWorker)
          .to receive(:perform_async).with(project_id, user_id, policy.content['content'], [policy.id])
        expect(Security::SyncPipelineExecutionPolicyMetadataWorker)
          .to receive(:perform_async).with(project_id, user_id, policy_2.content['content'], [policy_2.id])

        perform
      end
    end
  end

  context 'when ref in the policy does not match the ref of the push' do
    let(:ref) { 'refs/heads/feature' }

    it_behaves_like 'does not enqueue the worker'
  end

  context 'when policy does not specify ref' do
    let!(:policy) do
      create(:security_policy, :pipeline_execution_policy,
        security_orchestration_policy_configuration: configuration,
        content: {
          pipeline_config_strategy: 'inject_ci',
          content: { include: [{ project: project.full_path, file: 'policy.yml' }] }
        }).tap do |policy|
        create(:security_pipeline_execution_policy_config_link, security_policy: policy, project: project)
      end
    end

    context 'when ref is the default branch' do
      it 'enqueues the worker on the default branch' do
        expect(Security::SyncPipelineExecutionPolicyMetadataWorker)
          .to receive(:perform_async).with(project_id, user_id, content, [policy.id])

        perform
      end
    end

    context 'when ref is not the default branch' do
      let(:ref) { 'refs/heads/feature' }

      it_behaves_like 'does not enqueue the worker'
    end
  end

  context 'when policy config file is not modified' do
    let(:modified_paths) { %w[README.md] }

    it_behaves_like 'does not enqueue the worker'
  end

  context 'when branch is not updated' do
    let(:branch_updated) { false }

    it_behaves_like 'does not enqueue the worker'
  end

  context 'when project cannot be found' do
    let(:project_id) { non_existing_record_id }

    it_behaves_like 'does not enqueue the worker'
  end

  context 'when user cannot be found' do
    let(:user_id) { non_existing_record_id }

    it_behaves_like 'does not enqueue the worker'
  end

  context 'when a config link has no associated security_policy (orphaned)' do
    before do
      # Simulate the policy being deleted between loading the link and calling
      # `security_policy` on it; `links.filter_map(&:security_policy)` should drop nils.
      # Use `allow_any_instance_of` rather than `allow_next_instance_of` because the link
      # is loaded via `includes(:security_policy)`, whose eager-loading instantiation path
      # is not reliably intercepted by `allow_next_instance_of`.
      allow_any_instance_of(Security::PipelineExecutionPolicyConfigLink) # rubocop:disable RSpec/AnyInstanceOf -- eager-loaded AR instance, see comment above
        .to receive(:security_policy).and_return(nil)
    end

    it 'skips the orphaned link without raising NoMethodError' do
      expect(Security::SyncPipelineExecutionPolicyMetadataWorker).not_to receive(:perform_async)

      expect { perform }.not_to raise_error
    end
  end
end
