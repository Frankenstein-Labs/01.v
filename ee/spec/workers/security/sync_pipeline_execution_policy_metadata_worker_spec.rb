# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SyncPipelineExecutionPolicyMetadataWorker, '#perform', feature_category: :security_policy_management do
  include RepoHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:configuration) { create(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:config_project) { create(:project, :repository) }
  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_policy, security_orchestration_policy_configuration: configuration,
      content: {
        pipeline_config_strategy: 'inject_ci',
        content: { include: [{ project: config_project.full_path, file: 'file.yml' }] }
      })
  end

  let(:content) { policy.content['content'] }
  let(:config_file_content) do
    {
      include: [
        { template: 'Jobs/Secret-Detection.gitlab-ci.yml' },
        { template: 'Jobs/Dependency-Scanning.gitlab-ci.yml' },
        { template: 'Jobs/Container-Scanning.gitlab-ci.yml' },
        { template: 'Jobs/SAST.gitlab-ci.yml' }
      ]
    }
  end

  let(:security_policy_id) { policy.id }
  let(:config_project_id) { config_project.id }
  let(:user_id) { user.id }

  before do
    allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |configuration|
      allow(configuration).to receive(:policy_last_updated_by).and_return(user)
    end
  end

  around do |example|
    create_and_delete_files(
      config_project, { 'file.yml' => config_file_content.to_yaml }
    ) do
      example.run
    end
  end

  subject(:perform) do
    described_class.new.perform(config_project_id, user_id, content, [security_policy_id])
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [config_project_id, user_id, content, [security_policy_id]] }
  end

  context 'when user has access to the config project' do
    before_all do
      config_project.add_developer(user)
    end

    it 'analyzes the policy config and updates the metadata' do
      perform

      expect(policy.reload.metadata).to match("enforced_scans" => an_array_matching(
        %w[secret_detection dependency_scanning container_scanning sast]
      ), "prefill_variables" => {})
    end

    it 'calls AnalyzePipelineExecutionPolicyConfigService and UpdatePipelineExecutionPolicyMetadataService' do
      expect_next_instance_of(
        Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService
      ) do |service|
        expect(service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { enforced_scans: %w[sast],
                                             prefill_variables: { 'VAR' => { description: 'desc' } } })
        )
      end

      update_metadata_service = instance_double(
        Security::SecurityOrchestrationPolicies::UpdatePipelineExecutionPolicyMetadataService,
        execute: ServiceResponse.success
      )
      expect(Security::SecurityOrchestrationPolicies::UpdatePipelineExecutionPolicyMetadataService)
        .to receive(:new).with(
          security_policy: policy,
          enforced_scans: %w[sast],
          prefill_variables: { 'VAR' => { description: 'desc' } }
        ).and_return(update_metadata_service)
      expect(update_metadata_service).to receive(:execute)

      perform
    end

    context 'when the analyze service fails' do
      before do
        allow_next_instance_of(
          Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService
        ) do |service|
          allow(service)
            .to receive(:execute).and_return(
              ServiceResponse.error(message: 'error', payload: { enforced_scans: [], prefill_variables: {} })
            )
        end
      end

      it 'logs the error with application context' do
        expect(Sidekiq.logger).to receive(:warn).with(hash_including(
          'class' => described_class.to_s,
          'message' => 'Error occurred while analyzing the CI configuration',
          'errors' => 'error',
          'security_policy_ids' => [security_policy_id],
          'meta.project' => config_project.full_path,
          'meta.user' => user.username
        ))

        perform
      end

      it 'persists empty array as metadata' do
        perform

        expect(policy.reload.metadata).to eq("enforced_scans" => [], "prefill_variables" => {})
      end
    end
  end

  context 'when the user does not have access to the project' do
    it 'persists empty array as metadata' do
      perform

      expect(policy.reload.metadata).to eq("enforced_scans" => [], "prefill_variables" => {})
    end

    it 'logs the error with application context' do
      expect(Sidekiq.logger).to receive(:warn).with(hash_including(
        'class' => described_class.to_s,
        'message' => 'Error occurred while analyzing the CI configuration',
        'errors' => a_string_including('not found or access denied!'),
        'security_policy_ids' => [security_policy_id],
        'meta.project' => config_project.full_path,
        'meta.user' => user.username
      ))

      perform
    end
  end

  context 'when project does not exist' do
    let(:config_project_id) { non_existing_record_id }

    it 'does not call AnalyzePipelineExecutionPolicyConfigService' do
      expect(Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService).not_to receive(:new)

      perform
    end
  end

  context 'when user does not exist' do
    let(:user_id) { non_existing_record_id }

    it 'does not call AnalyzePipelineExecutionPolicyConfigService' do
      expect(Security::SecurityOrchestrationPolicies::AnalyzePipelineExecutionPolicyConfigService).not_to receive(:new)

      perform
    end
  end
end
