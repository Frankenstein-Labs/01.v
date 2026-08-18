# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::ResumeWorkflowService, :request_store, feature_category: :duo_agent_platform do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }

  let(:image) { 'example.com/example-image:latest' }
  let(:workflow) { create(:duo_workflows_workflow, user: maintainer, image: image, project: project) }
  let(:duo_config) { instance_double(::Gitlab::DuoAgentPlatform::Config) }
  let(:sandbox) { instance_double(::Gitlab::DuoWorkflow::Sandbox) }

  let(:params) do
    {
      goal: 'test-goal',
      workflow: workflow,
      workflow_oauth_token: 'fresh-oauth-token',
      workflow_service_token: 'fresh-service-token',
      workflow_metadata: { key: 'val' }.to_json,
      human_approval: true,
      human_message: 'looks good',
      service_account: service_account
    }
  end

  let(:duo_cli_command) do
    "duo run --existing-session-id #{workflow.id} --connection-type websocket " \
      "--approval true --rejection-reason looks\\ good"
  end

  let(:wrapped_commands) do
    [
      %(if which srt > /dev/null; then),
      %(  echo "SRT found, creating config..."),
      %(  srt --settings /tmp/srt-settings.json #{duo_cli_command}),
      %(fi)
    ]
  end

  let(:sandbox_env_vars) { { NPM_CONFIG_CACHE: "/tmp/.npm-cache" } }
  let(:sandbox_setup_commands) { ["mkdir -p #{::Gitlab::DuoWorkflow::Sandbox::SANDBOX_SYSTEM_DIR}"] }

  let_it_be(:service_account) { create(:user, :service_account) }

  before_all do
    project.add_member(service_account, Gitlab::Access::DEVELOPER)
  end

  subject(:execute) { described_class.new(workflow: workflow, params: params).execute }

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow(maintainer).to receive(:allowed_to_use?).and_return(true)
    allow(::Gitlab::DuoAgentPlatform::Config).to receive(:new).with(project).and_return(duo_config)
    allow(duo_config).to receive_messages(
      config_present?: false,
      valid_format?: true,
      default_image: nil,
      cache_config: nil,
      setup_script: nil,
      network_policy: nil,
      id_tokens: nil
    )
    allow(::Gitlab::DuoWorkflow::Sandbox).to receive(:new).and_return(sandbox)
    allow(sandbox).to receive(:wrap_command).with(duo_cli_command).and_return(wrapped_commands)
    allow(sandbox).to receive_messages(
      setup_sandbox_commands: sandbox_setup_commands,
      environment_variables: sandbox_env_vars
    )
    allow(Ci::Workloads::RunWorkloadService).to receive(:new).and_call_original
  end

  context 'when a previous workload exists' do
    let!(:previous_pipeline) { create(:ci_pipeline, project: project) }
    let!(:previous_build) do
      create(:ci_build, pipeline: previous_pipeline, yaml_variables: [
        { key: 'DUO_WORKFLOW_SOURCE_BRANCH', value: 'feature-branch' },
        { key: 'DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT', value: 'previous context' },
        { key: 'GITLAB_OAUTH_TOKEN', value: 'old-expired-token' },
        { key: 'DUO_WORKFLOW_SERVICE_TOKEN', value: 'old-service-token' },
        { key: 'GIT_PASSWORD', value: 'old-expired-token' },
        { key: 'GITLAB_TOKEN', value: 'old-expired-token' },
        { key: 'DUO_WORKFLOW_GIT_HTTP_PASSWORD', value: 'old-expired-token' },
        { key: 'CUSTOM_PREVIOUS_VAR', value: 'custom-value' }
      ])
    end

    let!(:previous_workload) { create(:ci_workload, pipeline: previous_pipeline, project: project) }
    let!(:workflows_workload) do
      create(:duo_workflows_workload, workflow: workflow, workload: previous_workload, project: project)
    end

    it 'carries forward variables from the previous workload' do
      expect(Ci::Workloads::RunWorkloadService)
        .to receive(:new).and_wrap_original do |method, **kwargs|
        variables = kwargs[:workload_definition].variables

        expect(variables[:DUO_WORKFLOW_SOURCE_BRANCH]).to eq('feature-branch')
        expect(variables[:DUO_WORKFLOW_ADDITIONAL_CONTEXT_CONTENT]).to eq('previous context')
        expect(variables[:CUSTOM_PREVIOUS_VAR]).to eq('custom-value')
        method.call(**kwargs)
      end

      expect(execute).to be_success
    end

    it 'overrides token variables with fresh values' do
      expect(Ci::Workloads::RunWorkloadService)
        .to receive(:new).and_wrap_original do |method, **kwargs|
        variables = kwargs[:workload_definition].variables

        expect(variables[:GITLAB_OAUTH_TOKEN]).to eq('fresh-oauth-token')
        expect(variables[:DUO_WORKFLOW_SERVICE_TOKEN]).to eq('fresh-service-token')
        expect(variables[:GIT_PASSWORD]).to eq('fresh-oauth-token')
        expect(variables[:GITLAB_TOKEN]).to eq('fresh-oauth-token')
        expect(variables[:DUO_WORKFLOW_GIT_HTTP_PASSWORD]).to eq('fresh-oauth-token')
        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'when no previous workload exists' do
    it 'falls back to computing variables from scratch' do
      expect(execute).to be_success
    end
  end

  context 'when a previous workload exists with empty yaml_variables' do
    let!(:previous_pipeline) { create(:ci_pipeline, project: project) }
    let!(:previous_build) do
      create(:ci_build, pipeline: previous_pipeline, yaml_variables: [])
    end

    let!(:previous_workload) { create(:ci_workload, pipeline: previous_pipeline, project: project) }
    let!(:workflows_workload) do
      create(:duo_workflows_workload, workflow: workflow, workload: previous_workload, project: project)
    end

    it 'falls back to computing variables from scratch via super' do
      expect(Ci::Workloads::RunWorkloadService)
        .to receive(:new).and_wrap_original do |method, **kwargs|
        variables = kwargs[:workload_definition].variables

        expect(variables[:DUO_WORKFLOW_GOAL]).to eq('test-goal')
        expect(variables[:GITLAB_OAUTH_TOKEN]).to eq('fresh-oauth-token')
        method.call(**kwargs)
      end

      expect(execute).to be_success
    end
  end

  context 'when human_approval is false and human_message is nil' do
    let(:params) { super().merge(human_approval: false, human_message: nil) }
    let(:duo_cli_command) do
      "duo run --existing-session-id #{workflow.id} --connection-type websocket " \
        "--approval false"
    end

    it 'omits --rejection-reason when human_message is nil' do
      expect(execute).to be_success
    end
  end

  context 'when human_approval is false' do
    let(:params) { super().merge(human_approval: false, human_message: 'not ready yet') }
    let(:duo_cli_command) do
      "duo run --existing-session-id #{workflow.id} --connection-type websocket " \
        "--approval false --rejection-reason not\\ ready\\ yet"
    end

    it 'renders boolean false as string in the CLI command' do
      expect(execute).to be_success
    end
  end

  context 'when human_message contains shell metacharacters' do
    let(:params) { super().merge(human_message: '"; rm -rf /; echo "pwned') }
    let(:duo_cli_command) do
      escaped = Shellwords.shellescape('"; rm -rf /; echo "pwned')
      "duo run --existing-session-id #{workflow.id} --connection-type websocket " \
        "--approval true --rejection-reason #{escaped}"
    end

    it 'escapes shell metacharacters in human_message' do
      expect(execute).to be_success
    end
  end

  context 'when human_message contains subshell expansion' do
    let(:params) { super().merge(human_message: '$(whoami)') }
    let(:duo_cli_command) do
      escaped = Shellwords.shellescape('$(whoami)')
      "duo run --existing-session-id #{workflow.id} --connection-type websocket " \
        "--approval true --rejection-reason #{escaped}"
    end

    it 'escapes subshell expansion in human_message' do
      expect(execute).to be_success
    end
  end
end
