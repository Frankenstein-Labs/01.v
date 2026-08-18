# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::RunService, feature_category: :duo_agent_platform do
  include Ai::Catalog::TestHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, group:) }
  let_it_be_with_reload(:service_account) { create(:service_account, maintainer_of: project, name: 'Service Account') }

  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be_with_reload(:resource) { create(:issue, project: project) }
  let_it_be(:existing_note) { create(:note, project: project, noteable: resource) }

  let(:params) { { input: 'test input', event: :assign, discussion: existing_note.discussion } }

  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger, project: project, user: service_account, config_path: '.gitlab/duo/flow.yml')
  end

  let(:flow_definition) do
    {
      'image' => 'ruby:3.0',
      'commands' => ['echo "Hello World"', 'ruby script.rb'],
      'variables' => %w[API_KEY DATABASE_URL],
      'injectGatewayToken' => true
    }.to_yaml
  end

  let_it_be(:project_variable1) do
    create(:ci_variable, project: project, key: 'DATABASE_URL', value: 'postgres://test')
  end

  let_it_be(:project_variable2) do
    create(:ci_variable, project: project, key: 'API_KEY', value: 'secret123')
  end

  let_it_be(:project_variable3) do
    create(:ci_variable, project: project, key: 'ANOTHER_VAR_THAT_SHOULD_NOT_BE_PASSED', value: 'really secret')
  end

  let(:mock_token_response) do
    ServiceResponse.success(payload: {
      token: 'test-token-123',
      headers: {
        'Authorization' => 'Bearer test-token-123',
        'Content-Type' => 'application/json',
        'X-Missing-Header' => nil
      }
    })
  end

  subject(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      resource: resource,
      flow_trigger: flow_trigger
    )
  end

  def expected_gitlab_hostname
    host = Gitlab.config.gitlab.host
    port = Gitlab.config.gitlab.port

    [80, 443].include?(port) ? host : "#{host}:#{port}"
  end

  def build_token_response(token:, headers: :default)
    headers_value = if headers == :default
                      {
                        'Authorization' => 'test-token-123',
                        'Content-Type' => 'application/json'
                      }
                    else
                      headers
                    end

    ServiceResponse.success(payload: {
      token: token,
      headers: headers_value
    })
  end

  def build_service(flow_trigger:, resource: self.resource, current_user: self.current_user)
    described_class.new(
      project: project,
      current_user: current_user,
      resource: resource,
      flow_trigger: flow_trigger
    )
  end

  def build_catalog_item_setup(ai_catalog_item)
    parent_item_consumer = build(
      :ai_catalog_item_consumer,
      :for_flow, item: ai_catalog_item, service_account: service_account, group: group
    )
    ai_catalog_item_consumer = create(
      :ai_catalog_item_consumer, :child_item_consumer,
      item: ai_catalog_item, project: project, pinned_version_prefix: nil, parent_item_consumer: parent_item_consumer
    )

    flow_trigger_with_catalog = create(:ai_flow_trigger,
      :for_catalog_consumer,
      project: project,
      ai_catalog_item_consumer: ai_catalog_item_consumer,
      event_types: ai_catalog_item_consumer.item.foundational_flow&.supported_events.presence ||
        [::Ai::FlowTrigger::EVENT_TYPES[:mention]])

    { item: ai_catalog_item, consumer: ai_catalog_item_consumer, trigger: flow_trigger_with_catalog }
  end

  def assert_ai_flow_variables(variables)
    expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
    expect(variables[:AI_FLOW_INPUT]).to eq('test input')
    expect(variables[:AI_FLOW_EVENT]).to eq('assign')
    expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
    expect(variables[:AI_FLOW_PROJECT_PATH]).to eq(project.full_path)
    expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq(expected_gitlab_hostname)

    assert_git_identity_variables(variables)
  end

  # Commits are authored by the service account and committed by the human user.
  def assert_git_identity_variables(variables)
    expect(variables[:GIT_AUTHOR_NAME]).to eq(service_account.name)
    expect(variables[:GIT_AUTHOR_EMAIL]).to eq(service_account.commit_email_or_default)
    expect(variables[:GIT_COMMITTER_NAME]).to eq(current_user.name)
    expect(variables[:GIT_COMMITTER_EMAIL]).to eq(current_user.commit_email_or_default)
  end

  def stub_token_service(response)
    token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
    allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
     .with(hash_including(current_user: current_user, project: project, organization: project.organization))
     .and_return(token_service_double)
    allow(token_service_double).to receive(:direct_access_token).and_return(response)
  end

  before do
    # Enable duo features on project
    project.project_setting.update!(
      duo_features_enabled: true,
      duo_remote_flows_enabled: true
    )

    # Setup LLM stage check
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    allow(::Ability).to receive(:allowed?).and_return(true)
    allow(current_user).to receive(:allowed_to_use?).and_return(true)

    # Setup chat authorizer
    authorizer_double = instance_double(::Gitlab::Llm::Utils::Authorizer::Response)
    allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer)
      .to receive(:resource)
      .and_return(authorizer_double)
    allow(authorizer_double).to receive(:allowed?).and_return(true)

    allow_next_instance_of(Ai::UsageQuotaService) do |instance|
      allow(instance).to receive(:execute).and_return(
        ServiceResponse.success
      )
    end
  end

  describe '#initialize' do
    context 'when composite identity can be used' do
      let_it_be(:oauth_app) do
        create(:oauth_application, name: 'Duo Workflow', scopes: %w[ai_workflows mcp user:*])
      end

      before do
        service_account.update!(composite_identity_enforced: true)
        ::Ai::Setting.for_organization(project.organization).update!(
          duo_workflow_service_account_user: service_account,
          duo_workflow_oauth_application: oauth_app
        )
      end

      it 'calls link_composite_identity!' do
        identity_double = instance_double(::Gitlab::Auth::Identity)
        allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(identity_double)
        allow(identity_double).to receive(:composite?).and_return(true)
        expect(identity_double).to receive(:link!).with(current_user)

        service
      end

      context 'when identity is not composite' do
        it 'does not call link! on identity' do
          identity_double = instance_double(::Gitlab::Auth::Identity)
          allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(identity_double)
          allow(identity_double).to receive(:composite?).and_return(false)
          expect(identity_double).not_to receive(:link!)
          service
        end
      end

      context 'when identity is nil' do
        it 'does not raise an error' do
          allow(::Gitlab::Auth::Identity).to receive(:fabricate).with(service_account).and_return(nil)

          expect { service }.not_to raise_error
        end
      end
    end

    context 'when composite identity cannot be used' do
      it 'does not call link_composite_identity!' do
        expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

        service
      end

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end

      context 'when oauth application is not configured' do
        before do
          ::Ai::Setting.for_organization(project.organization).update!(duo_workflow_oauth_application: nil)
        end

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end

      context 'when service account does not have composite identity enforced' do
        before do
          service_account.update!(composite_identity_enforced: false)
        end

        it 'does not call fabricate on Gitlab::Auth::Identity' do
          expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

          service
        end
      end
    end
  end

  describe '#execute' do
    before do
      # Mock the flow definition fetching instead of creating/updating files
      allow(project.repository).to receive(:blob_data_at).and_return(flow_definition)

      token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
      allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
        .with(hash_including(current_user: current_user, project: project, organization: project.organization))
        .and_return(token_service_double)
      allow(token_service_double).to receive(:direct_access_token).and_return(mock_token_response)
    end

    it 'creates duo workflow with correct parameters' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.workflow_definition).to eq("Trigger - #{flow_trigger.description}")
      expect(workflow.goal).to eq('test input')
      expect(workflow.environment).to eq('web')
      expect(workflow.project).to eq(project)
      expect(workflow.user).to eq(current_user)
      expect(workflow.service_account_id).to eq(service_account.id)
      expect(workflow.service_account).to eq(service_account)
    end

    it 'creates workflow_workload association' do
      expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::WorkflowsWorkload.count }.by(1)

      workflow = ::Ai::DuoWorkflows::Workflow.last
      workload = ::Ci::Workloads::Workload.last

      association = ::Ai::DuoWorkflows::WorkflowsWorkload.last
      expect(association.workflow).to eq(workflow)
      expect(association.project_id).to eq(project.id)
      expect(association.workload_id).to eq(workload.id)
    end

    it 'executes the workload service and creates a workload' do
      expect { service.execute(params) }.to change { ::Ci::Workloads::Workload.count }.by(1)

      response = service.execute(params)
      expect(response).to be_success

      workload = response.payload
      expect(workload).to be_persisted
      expect(workload.variable_inclusions.map(&:variable_name)).to eq(%w[API_KEY DATABASE_URL])
    end

    it_behaves_like 'initializes Ai::Catalog::Logger but does not log to it' do
      subject { service.execute(params) }
    end

    context 'when injectGatewayToken is true' do
      it 'builds workload definition with gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          workload_definition = kwargs[:workload_definition]
          expect(workload_definition.image).to eq('ruby:3.0')
          expect(workload_definition.commands).to eq(['echo "Hello World"', 'ruby script.rb'])
          expect(workload_definition.tags).to eq([::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG])

          variables = workload_definition.variables

          expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
          expect(variables[:AI_FLOW_INPUT]).to eq('test input')
          expect(variables[:AI_FLOW_EVENT]).to eq('assign')
          expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
          expect(variables[:AI_FLOW_PROJECT_PATH]).to eq(project.full_path)
          expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq(expected_gitlab_hostname)

          expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
          expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq(
            "Authorization: Bearer test-token-123\nContent-Type: application/json")

          expect(kwargs[:ci_variables_included]).to eq(%w[API_KEY DATABASE_URL])
          expect(kwargs[:source]).to eq(:duo_workflow)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'calls token service to get direct access token' do
        token_service_double = instance_double(::Ai::ThirdPartyAgents::TokenService)
        expect(::Ai::ThirdPartyAgents::TokenService).to receive(:new)
          .with(hash_including(current_user: current_user, project: project, organization: project.organization))
          .and_return(token_service_double)
        expect(token_service_double).to receive(:direct_access_token).and_return(mock_token_response)
        stub_token_service(mock_token_response)

        response = service.execute(params)
        expect(response).to be_success
      end

      context 'when token service returns error' do
        let(:error_token_response) do
          ServiceResponse.error(message: 'Token generation failed')
        end

        before do
          stub_token_service(error_token_response)
        end

        it 'returns error without creating workload' do
          expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)
          expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('Token generation failed')
        end
      end

      context 'when a flow is triggered by a service account' do
        let_it_be(:current_user) { create(:service_account, maintainer_of: project) }

        it 'returns an error' do
          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('cannot be triggered by non-human users')
        end

        it 'creates a note with the error message' do
          expect { service.execute(params) }.to change { Note.count }.by(1)
          expect(Note.last.note).to include('cannot be triggered by non-human users')
        end

        it 'logs the validation error' do
          mock_logger = Ai::Catalog::Logger.build
          allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
          allow(mock_logger).to receive(:context).and_return(mock_logger)
          allow(mock_logger).to receive(:error)
          expect(mock_logger).to receive(:error).with(
            message: 'Flow trigger validation failed', error_message: 'cannot be triggered by non-human users'
          )

          service.execute(params)
        end

        context 'when resource is not noteable' do
          let(:resource) { nil }
          let(:params) { { input: 'test input', event: :pipeline_hooks } }

          subject(:service) do
            described_class.new(
              project: project,
              current_user: current_user,
              flow_trigger: flow_trigger
            )
          end

          it 'returns an error without creating a note' do
            expect { service.execute(params) }.not_to change { Note.count }

            response = service.execute(params)
            expect(response).to be_error
            expect(response.message).to eq('cannot be triggered by non-human users')
          end
        end
      end

      context 'when token response has empty headers' do
        before do
          stub_token_service(build_token_response(token: 'test-token-123', headers: {}))
        end

        it 'builds variables with empty headers string' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            variables = kwargs[:workload_definition].variables
            expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
            expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq('')
            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when token response has nil headers' do
        before do
          stub_token_service(build_token_response(token: 'test-token-123', headers: nil))
        end

        it 'builds variables with empty headers string' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            variables = kwargs[:workload_definition].variables
            expect(variables[:AI_FLOW_AI_GATEWAY_TOKEN]).to eq('test-token-123')
            expect(variables[:AI_FLOW_AI_GATEWAY_HEADERS]).to eq('')
            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end
    end

    context 'when injectGatewayToken is false' do
      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"', 'ruby script.rb'],
          'variables' => %w[API_KEY DATABASE_URL],
          'injectGatewayToken' => false
        }.to_yaml
      end

      before do
        allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new).and_call_original
      end

      it 'does not call token service' do
        expect(::Ai::ThirdPartyAgents::TokenService).not_to receive(:new)

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'builds workload definition without gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          variables = kwargs[:workload_definition].variables
          assert_ai_flow_variables(variables)

          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_TOKEN)
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_HEADERS)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when injectGatewayToken is not present' do
      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"', 'ruby script.rb'],
          'variables' => %w[API_KEY DATABASE_URL]
          # injectGatewayToken is not present
        }.to_yaml
      end

      before do
        allow(::Ai::ThirdPartyAgents::TokenService).to receive(:new).and_call_original
      end

      it 'does not call token service' do
        expect(::Ai::ThirdPartyAgents::TokenService).not_to receive(:new)

        response = service.execute(params)
        expect(response).to be_success
      end

      it 'builds workload definition without gateway token variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          variables = kwargs[:workload_definition].variables
          assert_ai_flow_variables(variables)

          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_TOKEN)
          expect(variables).not_to have_key(:AI_FLOW_AI_GATEWAY_HEADERS)

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when the flow definition declares id_tokens' do
      # Each example only varies `id_tokens`, so share a baseline flow definition
      # and override just that key to keep the cause of each result obvious.
      let(:id_tokens) do
        { 'SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' } }
      end

      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"'],
          'variables' => %w[API_KEY DATABASE_URL],
          'injectGatewayToken' => true,
          'id_tokens' => id_tokens
        }.to_yaml
      end

      it 'forwards id_tokens to the workload without allowlisting them as CI variables' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          expect(kwargs[:workload_definition].id_tokens).to eq('SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' })
          # id_tokens are runner-generated JWTs injected via the job's id_tokens
          # keyword, so they must not be added to the ci_variables_included
          # allowlist (which only governs stored CI/CD variables).
          expect(kwargs[:ci_variables_included]).to eq(%w[API_KEY DATABASE_URL])

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end

      context 'when aud is an array of strings' do
        let(:id_tokens) do
          { 'SIGSTORE_ID_TOKEN' => { 'aud' => %w[sigstore other] } }
        end

        it 'forwards the entry to the workload' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens).to eq('SIGSTORE_ID_TOKEN' => { 'aud' => %w[sigstore other] })

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when the id_tokens value is malformed' do
        let(:id_tokens) { 'invalid' }

        it 'ignores the malformed value without raising and leaves ci_variables_included unchanged' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens).to be_nil
            expect(kwargs[:ci_variables_included]).to eq(%w[API_KEY DATABASE_URL])

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when an id_token has an invalid CI variable name' do
        let(:id_tokens) do
          {
            'SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' },
            'GIT_SSH COMMAND' => { 'aud' => 'evil' }
          }
        end

        it 'drops the invalid name from the workload' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens).to eq('SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' })

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when an id_token entry is missing aud' do
        let(:id_tokens) do
          {
            'SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' },
            'BROKEN_TOKEN' => { 'foo' => 'bar' }
          }
        end

        it 'drops the malformed entry from the workload' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens).to eq('SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' })

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when an id_token aud has an invalid shape' do
        let(:id_tokens) do
          {
            'SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' },
            'NUMERIC_TOKEN' => { 'aud' => 123 },
            'EMPTY_ARRAY_TOKEN' => { 'aud' => [] },
            'MIXED_ARRAY_TOKEN' => { 'aud' => ['sigstore', 123] }
          }
        end

        it 'drops entries whose aud is not a string or array of strings' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens).to eq('SIGSTORE_ID_TOKEN' => { 'aud' => 'sigstore' })

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when more id_tokens than the maximum are declared' do
        let(:id_tokens) do
          (1..(::Ai::FlowTriggers::RunService::MAX_ID_TOKENS + 5)).each_with_object({}) do |i, hash|
            hash["TOKEN_#{i}"] = { 'aud' => 'sigstore' }
          end
        end

        it 'caps the number of id_tokens forwarded to the workload' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].id_tokens.size).to eq(::Ai::FlowTriggers::RunService::MAX_ID_TOKENS)

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end
    end

    context 'when the flow definition declares report_artifacts' do
      let(:report_artifacts) do
        { 'sast' => ['gl-sast-report.json'] }
      end

      let(:flow_definition) do
        {
          'image' => 'ruby:3.0',
          'commands' => ['echo "Hello World"'],
          'variables' => %w[API_KEY DATABASE_URL],
          'injectGatewayToken' => true,
          'report_artifacts' => report_artifacts
        }.to_yaml
      end

      it 'forwards report_artifacts to the workload definition' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          expect(kwargs[:workload_definition].artifacts_reports).to eq('sast' => ['gl-sast-report.json'])

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end

      context 'when report_artifacts is not a Hash' do
        let(:report_artifacts) { 'invalid' }

        it 'ignores the malformed value' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].artifacts_reports).to be_nil

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end

      context 'when report_artifacts is not present in the flow definition' do
        let(:flow_definition) do
          {
            'image' => 'ruby:3.0',
            'commands' => ['echo "Hello World"'],
            'variables' => %w[API_KEY DATABASE_URL],
            'injectGatewayToken' => true
          }.to_yaml
        end

        it 'does not set artifacts_reports on the workload definition' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            expect(kwargs[:workload_definition].artifacts_reports).to be_nil

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end
      end
    end

    context 'when duo_workflow_oauth_application is set in Ai::Setting' do
      let_it_be(:oauth_app) do
        create(:oauth_application, name: 'Duo Workflow', scopes: %w[ai_workflows mcp user:*])
      end

      before do
        ::Ai::Setting.for_organization(project.organization).update!(
          duo_workflow_service_account_user: service_account, duo_workflow_oauth_application: oauth_app
        )
      end

      context 'when composite identity is not enforced for trigger user' do
        it 'does not create variable AI_FLOW_GITLAB_TOKEN' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            variables = workload_definition.variables

            expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
            expect(variables[:AI_FLOW_INPUT]).to eq('test input')
            expect(variables[:AI_FLOW_EVENT]).to eq('assign')
            expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
            expect(variables[:AI_FLOW_PROJECT_PATH]).to eq(project.full_path)
            expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq(expected_gitlab_hostname)
            expect(variables[:AI_FLOW_GITLAB_TOKEN]).to be_nil

            original_method.call(**kwargs)
          end

          initial_oauth_access_tokens_count = OauthAccessToken.count

          response = service.execute(params)

          expect(response).to be_success
          expect(OauthAccessToken.count).to eq initial_oauth_access_tokens_count
        end
      end

      context 'when composite identity is enforced for service account' do
        before do
          service_account.update!(composite_identity_enforced: true)
        end

        it 'creates variable AI_FLOW_GITLAB_TOKEN along with other AI flow variables' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            variables = workload_definition.variables

            expect(variables[:AI_FLOW_CONTEXT]).to match(/id..#{resource.id}/)
            expect(variables[:AI_FLOW_INPUT]).to eq('test input')
            expect(variables[:AI_FLOW_EVENT]).to eq('assign')
            expect(variables[:AI_FLOW_DISCUSSION_ID]).to eq(existing_note.discussion_id)
            expect(variables[:AI_FLOW_PROJECT_PATH]).to eq(project.full_path)
            expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq(expected_gitlab_hostname)
            expect(variables[:AI_FLOW_GITLAB_TOKEN]).to be_present

            original_method.call(**kwargs)
          end

          initial_oauth_access_tokens_count = OauthAccessToken.count

          response = service.execute(params)

          expect(response).to be_success
          expect(OauthAccessToken.count).to eq initial_oauth_access_tokens_count + 1
          oauth_access_token = OauthAccessToken.last
          expect(oauth_access_token.resource_owner).to eq(service_account)
          expect(oauth_access_token.application).to eq(oauth_app)
          duration = Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService::TOKEN_EXPIRES_IN
          expect(oauth_access_token.expires_in).to eq(duration)
          expect(oauth_access_token.scopes).to contain_exactly('ai_workflows', 'mcp', "user:#{current_user.id}")
          expect(oauth_access_token.organization).to eq(project.organization)
        end

        context 'when organization-scoped AI settings are enabled' do
          let_it_be(:organization_oauth_app) do
            create(:oauth_application, name: 'Duo Workflow Org', scopes: %w[ai_workflows mcp user:*])
          end

          before do
            ::Ai::Setting.for_organization(project.organization).update!(
              duo_workflow_service_account_user: service_account,
              duo_workflow_oauth_application: organization_oauth_app
            )
          end

          it 'creates the token with the organization settings OAuth application' do
            response = service.execute(params)

            expect(response).to be_success
            expect(OauthAccessToken.last.application).to eq(organization_oauth_app)
          end
        end
      end
    end

    it 'creates appropriate notes' do
      expect(Note.count).to eq(1)
      expect(::Ci::Workloads::Workload.count).to eq(0)

      response = service.execute(params)

      expect(response).to be_success
      expect(::Ci::Workloads::Workload.count).to eq(1)
      expect(Note.count).to eq(2)

      expect(Note.last.note).to include('✅ Service Account has started. You can view progress')

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(Note.last.note).to match(/automate.agent.sessions.#{workflow.id}/)
    end

    context 'when resource is nil' do
      let(:resource) { nil }
      let(:params) { { input: 'pipeline data', event: :pipeline_hooks } }

      subject(:service) do
        described_class.new(
          project: project,
          current_user: current_user,
          flow_trigger: flow_trigger
        )
      end

      it 'creates workload without creating note' do
        expect { service.execute(params) }.to change { ::Ci::Workloads::Workload.count }.by(1)
        expect { service.execute(params) }.not_to change { Note.count }

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    it 'updates workflow status to running initially and then to start on success' do
      response = service.execute(params)
      expect(response).to be_success

      workflow = ::Ai::DuoWorkflows::Workflow.last
      expect(workflow.status_name).to eq(:running)
    end

    context 'when workload execution fails' do
      before do
        allow_next_instance_of(::Ci::Workloads::RunWorkloadService) do |instance|
          error = ServiceResponse.error(
            message: 'Workload failed', payload: instance_double(::Ci::Workloads::Workload, id: 999)
          )

          allow(instance).to receive(:execute).and_return(error)
        end
      end

      it 'still creates workflow and handles the failure' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

        # The service should still attempt to update workflow status even on failure
        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(workflow).to be_present
      end
    end

    context 'when workflow creation fails' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateWorkflowService) do |instance|
          error_response = ServiceResponse.error(message: 'Workflow creation failed')
          allow(error_response).to receive(:error?).and_return(true)
          allow(instance).to receive(:execute).and_return(error_response)
        end
      end

      it 'returns error response without creating workload' do
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('Workflow creation failed')
      end

      it 'logs the flow execution failure' do
        mock_logger = Ai::Catalog::Logger.build
        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
        expect(mock_logger).to receive(:error).with(
          message: 'Flow execution failed', error_message: 'Workflow creation failed'
        )

        service.execute(params)
      end
    end

    context 'when resource is a MergeRequest' do
      let_it_be_with_reload(:merge_request) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          source_branch: 'feature-branch',
          target_branch: 'another-branch'
        )
      end

      let_it_be(:resource) { merge_request }

      shared_examples 'passes workload ref to RunWorkloadService' do |ref_value|
        it "creates workload ref from merge request source branch and passes ref #{ref_value} to RunWorkloadService" do
          workload_branch_service = instance_double(Ci::Workloads::WorkloadBranchService)
          expect(Ci::Workloads::WorkloadBranchService).to receive(:new).with(
            current_user: service_account,
            project: project,
            source_branch: 'feature-branch'
          ).and_return(workload_branch_service)
          expect(workload_branch_service).to receive(:execute).and_return(
            ServiceResponse.success(payload: { ref: ref_value })
          )

          expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
            project: project,
            current_user: service_account,
            source: :duo_workflow,
            workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
            ci_variables_included: %w[API_KEY DATABASE_URL],
            ref: ref_value
          ).and_call_original

          service.execute(params)
        end
      end

      context 'with workload branch' do
        it_behaves_like 'passes workload ref to RunWorkloadService', 'workloads/xyz789'
      end

      context 'with workload internal_refs' do
        it_behaves_like 'passes workload ref to RunWorkloadService', 'refs/workloads/123'
      end
    end

    context 'when resource is not a MergeRequest' do
      shared_examples 'creates workload ref and passes ref to RunWorkloadService' do |ref_value|
        it "creates workload ref without source branch and passes ref #{ref_value} to RunWorkloadService" do
          workload_branch_service = instance_double(Ci::Workloads::WorkloadBranchService)
          expect(Ci::Workloads::WorkloadBranchService).to receive(:new).with(
            current_user: service_account,
            project: project,
            source_branch: nil
          ).and_return(workload_branch_service)
          expect(workload_branch_service).to receive(:execute).and_return(
            ServiceResponse.success(payload: { ref: ref_value })
          )

          expect(Ci::Workloads::RunWorkloadService).to receive(:new).with(
            project: project,
            current_user: service_account,
            source: :duo_workflow,
            workload_definition: an_instance_of(Ci::Workloads::WorkloadDefinition),
            ci_variables_included: %w[API_KEY DATABASE_URL],
            ref: ref_value
          ).and_call_original

          service.execute(params)
        end
      end

      context 'with workload branch' do
        it_behaves_like 'creates workload ref and passes ref to RunWorkloadService', 'workloads/xyz789'
      end

      context 'with workload internal_refs' do
        it_behaves_like 'creates workload ref and passes ref to RunWorkloadService', 'refs/workloads/123'
      end
    end

    context 'when resource is a Ci::Pipeline' do
      let_it_be(:pipeline_resource) { create(:ci_pipeline, project: project, ref: 'feature/test-branch') }

      subject(:service) do
        described_class.new(
          project: project,
          current_user: current_user,
          resource: pipeline_resource,
          flow_trigger: flow_trigger
        )
      end

      it 'serializes pipeline context into AI_FLOW_CONTEXT', :aggregate_failures do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          context_json = kwargs[:workload_definition].variables[:AI_FLOW_CONTEXT]
          context = Gitlab::Json::SafeParser.parse(context_json)
          expect(context['ref']).to eq('feature/test-branch')
          expect(context['source']).to eq(pipeline_resource.source)
          expect(context['sha']).to eq(pipeline_resource.sha)
          expect(context['id']).to eq(pipeline_resource.id)

          original_method.call(**kwargs)
        end

        service.execute({ input: {}.to_json, event: :pipeline_hooks })
      end

      it 'passes pipeline source_ref as source_branch to WorkloadBranchService' do
        workload_branch_service = instance_double(Ci::Workloads::WorkloadBranchService)
        expect(Ci::Workloads::WorkloadBranchService).to receive(:new).with(
          current_user: service_account,
          project: project,
          source_branch: 'feature/test-branch'
        ).and_return(workload_branch_service)
        expect(workload_branch_service).to receive(:execute).and_return(
          ServiceResponse.success(payload: { ref: 'refs/workloads/abc123' })
        )

        service.execute(params)
      end

      context 'when pipeline is associated with a merge request' do
        let_it_be(:mr) do
          create(:merge_request,
            source_project: project,
            target_project: project,
            source_branch: 'mr-source-branch'
          )
        end

        let_it_be(:pipeline_resource) do
          create(:ci_pipeline, project: project, ref: 'mr-source-branch',
            merge_request: mr, source: :merge_request_event)
        end

        it 'passes MR source_branch via source_ref' do
          workload_branch_service = instance_double(Ci::Workloads::WorkloadBranchService)
          expect(Ci::Workloads::WorkloadBranchService).to receive(:new).with(
            current_user: service_account,
            project: project,
            source_branch: 'mr-source-branch'
          ).and_return(workload_branch_service)
          expect(workload_branch_service).to receive(:execute).and_return(
            ServiceResponse.success(payload: { ref: 'refs/workloads/abc123' })
          )

          service.execute(params)
        end
      end
    end

    context 'when branch creation fails' do
      before do
        workload_branch_service = instance_double(Ci::Workloads::WorkloadBranchService)
        allow(Ci::Workloads::WorkloadBranchService).to receive(:new).and_return(workload_branch_service)
        allow(workload_branch_service).to receive(:execute).and_return(
          ServiceResponse.error(message: 'Failed to create branch')
        )
      end

      it 'returns error without creating workload' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }

        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('Failed to create branch')
      end

      it 'does not call RunWorkloadService' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        service.execute(params)
      end
    end

    context 'when flow definition file does not exist' do
      before do
        allow(service).to receive(:fetch_flow_definition).and_return(nil)
      end

      it 'returns error without calling workload service' do
        response = service.execute(params)
        expect(response).to be_error
        expect(response.message).to eq('invalid or missing flow definition')
      end
    end

    context 'when flow definition is not valid' do
      before do
        allow(service).to receive(:fetch_flow_definition).and_return(nil)
      end

      it 'returns error without calling workload service' do
        expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

        response = service.execute(params)

        expect(response).to be_error
        expect(response.message).to eq('invalid or missing flow definition')
      end
    end

    context 'when flow trigger has ai_catalog_item_consumer' do
      let(:ai_catalog_item) { create(:ai_catalog_flow) }
      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }
      let(:ai_catalog_item_consumer) { catalog_setup[:consumer] }
      let(:flow_trigger_with_catalog) { catalog_setup[:trigger] }

      let(:catalog_workflow) { create(:duo_workflows_workflow, project: project, user: current_user) }
      let(:catalog_execute_response) do
        ServiceResponse.success(payload: { workflow: catalog_workflow })
      end

      subject(:service) do
        build_service(flow_trigger: flow_trigger_with_catalog)
      end

      before do
        allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
          allow(instance).to receive(:execute).and_return(catalog_execute_response)
        end
      end

      it 'calls Ai::Catalog::Flows::ExecuteService with correct parameters' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: {
            item_consumer: ai_catalog_item_consumer,
            flow: ai_catalog_item,
            service_account: service_account,
            flow_version: ai_catalog_item.latest_version,
            event_type: 'assign',
            user_prompt: 'test input',
            triggering_conversation: nil,
            execute_workflow: true,
            source_branch: nil,
            additional_context: nil,
            issue_id: resource.iid
          }
        ).and_call_original

        service.execute(params)
      end

      context 'when resource is a MergeRequest' do
        let_it_be(:merge_request) do
          build(:merge_request,
            source_project: project,
            target_project: project,
            source_branch: 'feature-branch',
            target_branch: 'another-branch'
          )
        end

        subject(:service) do
          build_service(flow_trigger: flow_trigger_with_catalog, resource: merge_request)
        end

        it 'passes merge_request_id to ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(merge_request_id: merge_request.iid)
          ).and_call_original

          service.execute(params)
        end

        it 'passes the merge request source_branch to ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(source_branch: 'feature-branch')
          ).and_call_original

          service.execute(params)
        end
      end

      context 'when the flow is recommend_reviewers/v1 and the resource is a merge request' do
        let(:ai_catalog_item) do
          create(:ai_catalog_flow, :public, foundational_flow_reference: 'recommend_reviewers/v1')
        end

        let_it_be(:reviewer_data_merge_request) do
          create(:merge_request, source_project: project, target_project: project)
        end

        let(:reviewer_data) { { "current_reviewers" => [], "approval_rules" => [] } }

        subject(:service) do
          build_service(flow_trigger: flow_trigger_with_catalog, resource: reviewer_data_merge_request)
        end

        before do
          allow(::Ai::DuoWorkflows::RecommendReviewers::ReviewerDataBuilder)
            .to receive(:build).with(reviewer_data_merge_request).and_return(reviewer_data)
        end

        # Both halves of the fix in one assertion: the flow config binds context:goal as
        # merge_request_iid, and the reviewer data has to survive the hop into
        # ExecuteService. Either one missing leaves a trigger-driven run with nothing to do.
        it 'passes the bare iid as the goal and the resolved reviewer data as additional_context' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              user_prompt: reviewer_data_merge_request.iid.to_s,
              additional_context: [
                { "Category" => "reviewer_data", "Content" => ::Gitlab::Json.dump(reviewer_data) }
              ]
            )
          ).and_call_original

          service.execute(params)
        end
      end

      it_behaves_like 'initializes Ai::Catalog::Logger but does not log to it' do
        subject { service.execute(params) }
      end

      context 'when ai_catalog_third_party_flows feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_third_party_flows: false)
        end

        it 'calls Ai::Catalog::Flows::ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new)

          service.execute(params)
        end
      end

      it 'creates a new workflow' do
        expect { service.execute(params) }.to change { ::Ai::DuoWorkflows::Workflow.count }

        response = service.execute(params)

        expect(response).to be_success
      end

      it 'does not create workload or workload association' do
        expect { service.execute(params) }.not_to change { ::Ci::Workloads::Workload.count }
        expect { service.execute(params) }.not_to change { ::Ai::DuoWorkflows::WorkflowsWorkload.count }
      end

      it 'does not trigger trigger_ai_catalog_item from RunService for the flow path' do
        # Flow execution is tracked inside Ai::Catalog::Flows::ExecuteService (stubbed here),
        # not by RunService. Only the external-agent workload path emits it from RunService.
        expect { service.execute(params) }
          .not_to trigger_internal_events('trigger_ai_catalog_item')
      end

      it 'creates appropriate notes with catalog workflow' do
        expect(::Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)
        expect(Note.count).to eq(1)

        response = service.execute(params)

        expect(response).to be_success
        expect(Note.count).to eq(2)

        expect(Note.last.note).to include('✅ Service Account has started. You can view progress')
        expect(Note.last.note).to match(/automate.agent.sessions.#{catalog_workflow.id}/)
      end

      context 'when the event is a mention' do
        let(:mention_params) { params.merge(event: :mention) }

        it 'forwards the mention input as the triggering_conversation' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(event_type: 'mention', triggering_conversation: 'test input')
          ).and_call_original

          service.execute(mention_params)
        end

        context 'and the flow opts into suppressing the mention progress note' do
          let(:ai_catalog_item) do
            create(:ai_catalog_flow, :with_foundational_flow_reference,
              foundational_flow_reference: 'security_review/v1')
          end

          it 'skips CreateNoteService and posts no progress note', :aggregate_failures do
            expect(::Ai::FlowTriggers::CreateNoteService).not_to receive(:new)

            expect { service.execute(mention_params) }.not_to change { Note.count }
          end

          it 'still executes the flow and returns a successful response' do
            response = service.execute(mention_params)

            expect(response).to be_success
          end
        end

        context 'and the flow does not opt into suppression' do
          # Guards against regressing other mention-triggered flows (e.g. developer/v1):
          # the default-false attribute means they keep posting the progress note.
          it 'posts the progress note via CreateNoteService' do
            expect(::Ai::FlowTriggers::CreateNoteService).to receive(:new).and_call_original

            service.execute(mention_params)
          end
        end
      end

      context 'when catalog execute service fails' do
        let(:catalog_execute_error_response) do
          ServiceResponse.error(message: 'Catalog execution failed')
        end

        before do
          allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
            allow(instance).to receive(:execute).and_return(catalog_execute_error_response)
          end
        end

        it 'returns error response' do
          expect(::Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('Catalog execution failed')
        end
      end

      context 'in adapter mode (messaging_callback_context present)' do
        let(:callback_context) { { 'adapter' => 'gitlab_duo_note', 'note_id' => existing_note.id } }
        let(:adapter_params) { params.merge(messaging_callback_context: callback_context) }

        it 'returns [response, workflow] and skips the legacy CreateNoteService', :aggregate_failures do
          expect(::Ai::FlowTriggers::CreateNoteService).not_to receive(:new)

          response, workflow = service.execute(adapter_params)

          expect(response).to be_success
          expect(workflow).to eq(catalog_workflow)
        end

        it 'threads the callback context into the catalog ExecuteService' do
          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(messaging_callback_context: callback_context)
          ).and_call_original

          service.execute(adapter_params)
        end

        it 'does not post the legacy processing note' do
          expect { service.execute(adapter_params) }.not_to change { Note.count }
        end
      end

      context 'when flow trigger has ai_catalog_item with third_party_flow_type' do
        let(:ai_catalog_item) { create(:ai_catalog_third_party_flow, latest_version:) }
        let(:latest_version) do
          create(:ai_catalog_item_version, :for_third_party_flow, definition: third_party_flow_definition)
        end

        let(:third_party_flow_definition) do
          {
            'image' => 'node:18',
            'commands' => ['npm install', 'node index.js'],
            'variables' => ['API_TOKEN'],
            'injectGatewayToken' => true
          }
        end

        context 'when user cannot execute the item' do
          before do
            allow(Ability).to receive(:allowed?).with(current_user, :execute_ai_catalog_item, ai_catalog_item_consumer)
          end

          it 'returns an error response' do
            expect(::Ci::Workloads::RunWorkloadService).not_to receive(:new)
            expect(::Ai::Catalog::Flows::ExecuteService).not_to receive(:new)

            response = service.execute(params)

            expect(response).to be_error
            expect(response.message).to eq('current user not permitted to execute external agent')
          end

          it 'creates a note with the error message' do
            expect { service.execute(params) }.to change { Note.count }.by(1)
            expect(Note.last.note).to include('current user not permitted to execute external agent')
          end
        end

        it 'creates workload with third party flow definition' do
          expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
            workload_definition = kwargs[:workload_definition]
            expect(workload_definition.image).to eq('node:18')
            expect(workload_definition.commands).to eq(['npm install', 'node index.js'])
            expect(kwargs[:ci_variables_included]).to eq(['API_TOKEN'])

            original_method.call(**kwargs)
          end

          response = service.execute(params)
          expect(response).to be_success
        end

        it 'logs to Ai::Catalog::Logger' do
          mock_logger = Ai::Catalog::Logger.build

          expect(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
          expect(mock_logger).to receive(:context).with(klass: described_class.name).and_call_original
          expect(mock_logger).to receive(:context).with(
            consumer: ai_catalog_item_consumer, item: ai_catalog_item_consumer.item
          ).and_call_original
          expect(mock_logger).to receive(:info).with(message: 'External agent executed')

          service.execute(params)
        end

        it 'triggers trigger_ai_catalog_item', :clean_gitlab_redis_shared_state do
          stub_event_properties_builder

          expect { service.execute(params) }
            .to trigger_internal_events('trigger_ai_catalog_item')
            .with(
              user: current_user,
              project: project,
              additional_properties: stubbed_event_properties.merge(
                label: ai_catalog_item.item_type,
                property: 'assign',
                value: ai_catalog_item.id
              )
            )
            .and increment_usage_metrics(
              'counts.count_total_trigger_ai_catalog_item_weekly',
              'counts.count_total_trigger_ai_catalog_item_monthly',
              'counts.count_total_trigger_ai_catalog_item'
            )
        end

        context 'when workload execution fails' do
          before do
            allow_next_instance_of(::Ci::Workloads::RunWorkloadService) do |instance|
              allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'workload failed'))
            end
          end

          it 'does not trigger trigger_ai_catalog_item' do
            expect { service.execute(params) }
              .not_to trigger_internal_events('trigger_ai_catalog_item')
          end
        end
      end
    end

    context 'when a pipeline resource is passed' do
      let(:ai_catalog_item) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }
      let(:ai_catalog_item_consumer) { catalog_setup[:consumer] }
      let(:flow_trigger_with_catalog) { catalog_setup[:trigger] }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

      let(:catalog_workflow) { create(:duo_workflows_workflow, project: project, user: current_user) }
      let(:catalog_execute_response) do
        ServiceResponse.success(payload: { workflow: catalog_workflow })
      end

      subject(:service) do
        build_service(flow_trigger: flow_trigger_with_catalog, resource: pipeline)
      end

      before do
        allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
          allow(instance).to receive(:execute).and_return(catalog_execute_response)
        end
      end

      it 'calls Ai::Catalog::Flows::ExecuteService with the pipeline URL as user_prompt' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: hash_including(
            user_prompt: Gitlab::UrlBuilder.build(pipeline),
            event_type: 'pipeline_hooks'
          )
        ).and_call_original

        service.execute({ input: {}.to_json, event: :pipeline_hooks })
      end

      it 'passes source_branch from pipeline ref' do
        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: hash_including(source_branch: pipeline.ref)
        ).and_call_original

        service.execute({ input: {}.to_json, event: :pipeline_hooks })
      end

      it 'passes additional_context with empty MR URL when pipeline has no MR' do
        expected_mr_content = ::Gitlab::Json.dump({ "url" => "" })
        expected_pipeline_content =
          ::Gitlab::Json.dump({ "source_branch" => pipeline.source_ref, "source" => pipeline.source })
        expected_metadata = { "version" => "1.0.0" }

        expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
          project: project,
          current_user: current_user,
          params: hash_including(
            additional_context: [
              { "Content" => expected_mr_content, "Category" => "merge_request",
                "metadata" => expected_metadata },
              { "Content" => expected_pipeline_content, "Category" => "pipeline",
                "metadata" => expected_metadata }
            ]
          )
        ).and_call_original

        service.execute({ input: {}.to_json, event: :pipeline_hooks })
      end

      context 'when the pipeline is associated with a merged merge request' do
        let_it_be(:merge_request) do
          create(:merge_request, :merged, source_project: project, target_project: project)
        end

        let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }

        it 'passes an empty merge request URL in additional_context' do
          expected_mr_content = ::Gitlab::Json.dump({ "url" => "" })
          expected_metadata = { "version" => "1.0.0" }

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              additional_context: array_including(
                { "Content" => expected_mr_content, "Category" => "merge_request",
                  "metadata" => expected_metadata }
              )
            )
          ).and_call_original

          service.execute({ input: {}.to_json, event: :pipeline_hooks })
        end
      end

      context 'when the pipeline is associated with a merge request' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project)
        end

        let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }

        it 'includes the MR URL, author ID, and pipeline source_branch in additional_context as JSON strings' do
          expected_mr_content = ::Gitlab::Json.dump(
            {
              "url" => ::Gitlab::UrlBuilder.build(merge_request),
              "author_id" => merge_request.author_id.to_s
            }
          )
          expected_pipeline_content =
            ::Gitlab::Json.dump({ "source_branch" => pipeline.source_ref, "source" => pipeline.source })
          expected_metadata = { "version" => "1.0.0" }

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              additional_context: [
                { "Content" => expected_mr_content, "Category" => "merge_request",
                  "metadata" => expected_metadata },
                { "Content" => expected_pipeline_content, "Category" => "pipeline",
                  "metadata" => expected_metadata }
              ]
            )
          ).and_call_original

          service.execute({ input: {}.to_json, event: :pipeline_hooks })
        end
      end

      context 'when a branch pipeline has an open merge request for its branch' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project,
            source_branch: 'feature', target_branch: 'master')
        end

        let_it_be(:pipeline) do
          create(:ci_pipeline, project: project, ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
        end

        it 'includes the merge request URL and author ID in additional_context' do
          expected_mr_content = ::Gitlab::Json.dump(
            {
              "url" => ::Gitlab::UrlBuilder.build(merge_request),
              "author_id" => merge_request.author_id.to_s
            }
          )
          expected_pipeline_content =
            ::Gitlab::Json.dump({ "source_branch" => pipeline.source_ref, "source" => pipeline.source })
          expected_metadata = { "version" => "1.0.0" }

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              additional_context: [
                { "Content" => expected_mr_content, "Category" => "merge_request",
                  "metadata" => expected_metadata },
                { "Content" => expected_pipeline_content, "Category" => "pipeline",
                  "metadata" => expected_metadata }
              ]
            )
          ).and_call_original

          service.execute({ input: {}.to_json, event: :pipeline_hooks })
        end
      end

      context 'when the branch pipeline commit is not part of the merge request' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project,
            source_branch: 'feature', target_branch: 'master')
        end

        let_it_be(:pipeline) do
          create(:ci_pipeline, project: project, ref: merge_request.source_branch,
            sha: OpenSSL::Digest.hexdigest('SHA256', 'foo'))
        end

        it 'passes an empty merge request URL in additional_context' do
          expected_mr_content = ::Gitlab::Json.dump({ "url" => "" })
          expected_metadata = { "version" => "1.0.0" }

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              additional_context: array_including(
                { "Content" => expected_mr_content, "Category" => "merge_request",
                  "metadata" => expected_metadata }
              )
            )
          ).and_call_original

          service.execute({ input: {}.to_json, event: :pipeline_hooks })
        end
      end

      context 'when the merge request for the branch is closed' do
        let_it_be(:merge_request) do
          create(:merge_request, :closed, source_project: project, target_project: project,
            source_branch: 'feature', target_branch: 'master')
        end

        let_it_be(:pipeline) do
          create(:ci_pipeline, project: project, ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
        end

        it 'passes an empty merge request URL in additional_context' do
          expected_mr_content = ::Gitlab::Json.dump({ "url" => "" })
          expected_metadata = { "version" => "1.0.0" }

          expect(::Ai::Catalog::Flows::ExecuteService).to receive(:new).with(
            project: project,
            current_user: current_user,
            params: hash_including(
              additional_context: array_including(
                { "Content" => expected_mr_content, "Category" => "merge_request",
                  "metadata" => expected_metadata }
              )
            )
          ).and_call_original

          service.execute({ input: {}.to_json, event: :pipeline_hooks })
        end
      end

      it 'does not raise NotImplementedError' do
        expect { service.execute({ input: {}.to_json, event: :pipeline_hooks }) }.not_to raise_error
      end
    end

    context 'when GitLab is running on a non-default port' do
      before do
        allow(Gitlab.config.gitlab).to receive_messages(host: 'gitlab.example.com', port: 8080)
      end

      it 'includes port in AI_FLOW_GITLAB_HOSTNAME' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          variables = kwargs[:workload_definition].variables
          expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq('gitlab.example.com:8080')

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when GitLab is running on default HTTPS port' do
      before do
        allow(Gitlab.config.gitlab).to receive_messages(host: 'gitlab.example.com', port: 443)
      end

      it 'does not include port in AI_FLOW_GITLAB_HOSTNAME' do
        expect(::Ci::Workloads::RunWorkloadService).to receive(:new).and_wrap_original do |original_method, kwargs|
          variables = kwargs[:workload_definition].variables
          expect(variables[:AI_FLOW_GITLAB_HOSTNAME]).to eq('gitlab.example.com')

          original_method.call(**kwargs)
        end

        response = service.execute(params)
        expect(response).to be_success
      end
    end

    context 'when flow definition is not a valid' do
      where(:flow_definition) do
        ['invalid yaml', '[not_a_hash]', "--- &1\n- *1\n", "%x", ""]
      end

      with_them do
        it 'returns nil without calling workload service' do
          expect(Ci::Workloads::RunWorkloadService).not_to receive(:new)

          response = service.execute(params)
          expect(response).to be_error
          expect(response.message).to eq('invalid or missing flow definition')
        end
      end
    end

    context 'when flow definition YAML is malformed' do
      let(:flow_definition) { "--- &1\n- *1\n" }

      it 'logs the YAML parsing failure' do
        mock_logger = Ai::Catalog::Logger.build
        allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
        allow(mock_logger).to receive(:context).and_return(mock_logger)
        allow(mock_logger).to receive(:error)
        expect(mock_logger).to receive(:error).with(hash_including(message: 'Failed to parse flow definition YAML'))

        service.execute(params)
      end
    end

    context 'for foundational flows' do
      let_it_be(:input) { 'test input' }
      let(:ai_catalog_item) { create(:ai_catalog_flow, :with_foundational_flow_reference) }
      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }
      let(:ai_catalog_item_consumer) { catalog_setup[:consumer] }
      let(:flow_trigger_with_catalog) { catalog_setup[:trigger] }

      let(:catalog_execute_response) do
        ServiceResponse.success(payload: { workflow: create(:duo_workflows_workflow, project: project,
          user: current_user) })
      end

      subject(:service) do
        build_service(flow_trigger: flow_trigger_with_catalog)
      end

      before do
        allow_next_instance_of(::Ai::Catalog::Flows::ExecuteService) do |instance|
          allow(instance).to receive(:execute).and_return(catalog_execute_response)
        end
      end

      context 'when event type is assign' do
        let(:params) { { input: 'test input', event: :assign } }

        context 'when resource is an Issue' do
          it 'returns success response' do
            response = service.execute(params)
            expect(response).to be_success
          end
        end
      end
    end
  end

  describe '#catalog_item_user_prompt' do
    let(:input) { '11' }

    context 'when flow is non-foundational' do
      context 'when event type is mention' do
        let(:input) { '@duo Please help me with this task' }

        it 'returns the default mention goal format' do
          result = service.send(:catalog_item_user_prompt, input, :mention)
          expect(result).to eq("Input: #{input}\nContext: {Issue IID: #{resource.iid}}")
        end
      end

      context 'when event type is assign' do
        it 'returns raw user input' do
          result = service.send(:catalog_item_user_prompt, input, :assign)
          expect(result).to eq(input)
        end
      end

      context 'when event type is assign_reviewer' do
        it 'returns raw user input' do
          result = service.send(:catalog_item_user_prompt, input, :assign_reviewer)
          expect(result).to eq(input)
        end
      end
    end

    context 'when flow is foundational without goal_templates' do
      let(:input) { 'test input' }
      let(:ai_catalog_item) { create(:ai_catalog_flow, :with_foundational_flow_reference) }
      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }
      let(:ai_catalog_item_consumer) { catalog_setup[:consumer] }
      let(:flow_trigger_with_catalog) { catalog_setup[:trigger] }

      subject(:service) do
        build_service(flow_trigger: flow_trigger_with_catalog)
      end

      it 'returns the resource URL as the goal for non-mention events' do
        result = service.send(:catalog_item_user_prompt, input, :assign)
        expect(result).to eq(Gitlab::UrlBuilder.build(resource))
      end

      context 'when event type is mention' do
        let(:input) { '@duo Please help me with this task' }

        it 'returns the default mention goal format' do
          result = service.send(:catalog_item_user_prompt, input, :mention)
          expect(result).to eq("Input: #{input}\nContext: {Issue IID: #{resource.iid}}")
        end
      end
    end

    context 'when flow is foundational with goal_templates (developer/v1)' do
      let(:input) { '@duo Please help me with this task' }
      let(:ai_catalog_item) do
        create(:ai_catalog_flow, :public, foundational_flow_reference: 'developer/v1')
      end

      let(:ai_catalog_item_consumer) do
        create(
          :ai_catalog_item_consumer, :child_item_consumer,
          item: ai_catalog_item, project: project, pinned_version_prefix: nil
        )
      end

      let(:flow_trigger_with_catalog) do
        create(:ai_flow_trigger,
          :for_catalog_consumer,
          project: project,
          ai_catalog_item_consumer: ai_catalog_item_consumer,
          event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention], ::Ai::FlowTrigger::EVENT_TYPES[:assign]])
      end

      let(:discussion) { instance_double(Discussion, id: 'abc123') }

      subject(:service) do
        build_service(flow_trigger: flow_trigger_with_catalog)
      end

      context 'when event type is mention' do
        let(:params) { { note_id: 42, discussion: discussion, triggered_by_username: 'alice' } }

        it 'returns a goal built from the mention template' do
          result = service.send(:catalog_item_user_prompt, input, :mention, params)
          resource_url = Gitlab::UrlBuilder.build(resource)
          expect(result).to include('@alice is talking to you in a conversation on this')
          expect(result).to include("#{resource_url}#note_42")
          expect(result).to include('<conversation>')
          expect(result).to include(input)
          expect(result).to include('Reply to @alice in your response')
        end
      end

      context 'when event type is assign_reviewer with MergeRequest resource' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project)
        end

        subject(:service) do
          build_service(flow_trigger: flow_trigger_with_catalog, resource: merge_request)
        end

        it 'returns a goal from the MergeRequest review template' do
          result = service.send(:catalog_item_user_prompt, input, :assign_reviewer,
            { triggered_by_username: 'alice' })
          expect(result).to include('@alice requested your review on a merge request:')
          expect(result).to include(Gitlab::UrlBuilder.build(merge_request))
        end
      end

      context 'when event type is assign with MergeRequest resource' do
        let_it_be(:merge_request) do
          create(:merge_request, source_project: project, target_project: project)
        end

        subject(:service) do
          build_service(flow_trigger: flow_trigger_with_catalog, resource: merge_request)
        end

        it 'returns a goal from the MergeRequest assign template' do
          result = service.send(:catalog_item_user_prompt, input, :assign,
            { triggered_by_username: 'alice' })
          expect(result).to include('@alice assigned you to a merge request:')
          expect(result).to include(Gitlab::UrlBuilder.build(merge_request))
        end
      end

      context 'when event type is assign with Issue resource' do
        it 'returns a goal from the assign template with resource name' do
          result = service.send(:catalog_item_user_prompt, input, :assign,
            { triggered_by_username: 'alice' })
          expect(result).to include('@alice assigned you to solve the following issue:')
          expect(result).to include(Gitlab::UrlBuilder.build(resource))
        end
      end

      context 'when user input contains format string sequences' do
        let(:input) { 'Please fix %{resource_url} and %{unknown_key} for me' }
        let(:params) { { note_id: 42, discussion: discussion, triggered_by_username: 'alice' } }

        it 'does not raise and preserves the literal text in user input' do
          result = service.send(:catalog_item_user_prompt, input, :mention, params)
          expect(result).to include('%{unknown_key}')
          expect(result).to include('<conversation>')
          expect(result).to include(input)
        end
      end
    end

    context 'when flow is foundational with goal_templates (recommend_reviewers/v1)' do
      let_it_be(:merge_request) do
        create(:merge_request, source_project: project, target_project: project)
      end

      let(:ai_catalog_item) do
        create(:ai_catalog_flow, :public, foundational_flow_reference: 'recommend_reviewers/v1')
      end

      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }

      subject(:service) do
        build_service(flow_trigger: catalog_setup[:trigger], resource: merge_request)
      end

      it 'returns the bare merge request iid for merge_request_ready events' do
        result = service.send(:catalog_item_user_prompt, merge_request.iid.to_s, :merge_request_ready)

        expect(result).to eq(merge_request.iid.to_s)
      end

      it 'returns the bare merge request iid for mention events' do
        result = service.send(
          :catalog_item_user_prompt, '@duo please recommend reviewers', :mention, { note_id: 42 }
        )

        expect(result).to eq(merge_request.iid.to_s)
      end
    end
  end

  describe '#additional_context' do
    let_it_be(:merge_request) do
      create(:merge_request, source_project: project, target_project: project)
    end

    let(:reviewer_data) { { "current_reviewers" => [], "approval_rules" => [] } }

    def expected_reviewer_data_envelope
      { "Category" => "reviewer_data", "Content" => ::Gitlab::Json.dump(reviewer_data) }
    end

    def expected_pipeline_envelopes(pipeline, merge_request)
      metadata = { "version" => "1.0.0" }

      [
        {
          "Category" => "merge_request",
          "Content" => ::Gitlab::Json.dump(
            { "url" => ::Gitlab::UrlBuilder.build(merge_request), "author_id" => merge_request.author_id.to_s }
          ),
          "metadata" => metadata
        },
        {
          "Category" => "pipeline",
          "Content" => ::Gitlab::Json.dump({ "source_branch" => pipeline.source_ref, "source" => pipeline.source }),
          "metadata" => metadata
        }
      ]
    end

    context 'when the flow is non-foundational and the resource is not a pipeline' do
      it 'returns nil' do
        expect(service.send(:additional_context)).to be_nil
      end
    end

    context 'when the flow is foundational without an additional_context_resolver' do
      let(:ai_catalog_item) { create(:ai_catalog_flow, :with_foundational_flow_reference) }
      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }

      it 'returns nil' do
        service = build_service(flow_trigger: catalog_setup[:trigger])

        expect(service.send(:additional_context)).to be_nil
      end
    end

    context 'when the flow is foundational with an additional_context_resolver' do
      let(:ai_catalog_item) do
        create(:ai_catalog_flow, :public, foundational_flow_reference: 'recommend_reviewers/v1')
      end

      let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }

      before do
        allow(::Ai::DuoWorkflows::RecommendReviewers::ReviewerDataBuilder)
          .to receive(:build).with(merge_request).and_return(reviewer_data)
      end

      it 'returns the envelopes resolved by the flow' do
        service = build_service(flow_trigger: catalog_setup[:trigger], resource: merge_request)

        expect(service.send(:additional_context)).to eq([expected_reviewer_data_envelope])
      end

      context 'when the resource is not a merge request' do
        it 'returns nil without building reviewer data' do
          service = build_service(flow_trigger: catalog_setup[:trigger], resource: resource)

          expect(::Ai::DuoWorkflows::RecommendReviewers::ReviewerDataBuilder).not_to receive(:build)
          expect(service.send(:additional_context)).to be_nil
        end
      end
    end

    context 'when the resource is a pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }

      it 'returns the pipeline envelopes' do
        service = build_service(flow_trigger: flow_trigger, resource: pipeline)

        expect(service.send(:additional_context)).to eq(expected_pipeline_envelopes(pipeline, merge_request))
      end

      context 'and the flow also declares an additional_context_resolver' do
        let(:ai_catalog_item) do
          create(:ai_catalog_flow, :public, foundational_flow_reference: 'recommend_reviewers/v1')
        end

        let(:catalog_setup) { build_catalog_item_setup(ai_catalog_item) }

        # No shipped foundational flow pairs a pipeline trigger with a resolver, so a
        # synthetic flow covers the merge of both context sources.
        let(:flow_with_resolver) do
          ::Ai::Catalog::FoundationalFlow.new(
            additional_context_resolver: ->(**_) { { "reviewer_data" => reviewer_data } }
          )
        end

        it 'returns the pipeline envelopes followed by the resolved envelopes' do
          service = build_service(flow_trigger: catalog_setup[:trigger], resource: pipeline)
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(flow_with_resolver)

          expect(service.send(:additional_context))
            .to eq(expected_pipeline_envelopes(pipeline, merge_request) + [expected_reviewer_data_envelope])
        end
      end
    end
  end

  describe '#resolve_service_account' do
    subject(:result) { service.send(:resolve_service_account, flow_trigger_user) }

    context 'when user is a service account' do
      let(:flow_trigger_user) { service_account }

      it 'returns the service account' do
        expect(result).to eq(service_account)
      end
    end

    context 'when user is a regular user' do
      let(:flow_trigger_user) { current_user }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  describe 'autonomous execution path' do
    let_it_be(:scoped_group) { create(:group) }
    let_it_be_with_refind(:scoped_project) { create(:project, :repository, group: scoped_group) }
    let_it_be_with_reload(:scoped_sa) do
      create(:service_account, maintainer_of: scoped_project).tap do |sa|
        sa.user_detail.update!(provisioned_by_group_id: scoped_group.id)
      end
    end

    let_it_be(:autonomous_trigger) do
      create(:ai_flow_trigger,
        project: scoped_project,
        user: scoped_sa,
        config_path: '.gitlab/duo/flow.yml'
      )
    end

    let(:autonomous_params) { { input: 'test input', event: :assign } }

    let(:autonomous_flow_definition) do
      {
        'image' => 'ruby:3.0',
        'commands' => ['echo "Hello"']
      }.to_yaml
    end

    subject(:autonomous_service) do
      described_class.new(
        project: scoped_project,
        flow_trigger: autonomous_trigger,
        trigger_source: :system
      )
    end

    before do
      allow(scoped_project.repository).to receive_messages(root_ref: 'main', blob_data_at: autonomous_flow_definition)

      allow_next_instance_of(Ai::UsageQuotaService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    describe '#autonomous_trigger?' do
      it 'returns true for system trigger source' do
        service = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          trigger_source: :system
        )
        expect(service.send(:autonomous_trigger?)).to be true
      end

      it 'returns true for scheduled trigger source' do
        service = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          trigger_source: :scheduled
        )
        expect(service.send(:autonomous_trigger?)).to be true
      end

      it 'returns false for human trigger source' do
        service = described_class.new(
          project: scoped_project,
          current_user: current_user,
          flow_trigger: autonomous_trigger,
          trigger_source: :human
        )
        expect(service.send(:autonomous_trigger?)).to be false
      end
    end

    describe 'validation' do
      context 'when service account is instance-wide' do
        let_it_be(:unscoped_sa) { create(:service_account, maintainer_of: scoped_project) }
        let_it_be(:unscoped_trigger) do
          create(:ai_flow_trigger,
            project: scoped_project,
            user: unscoped_sa,
            config_path: '.gitlab/duo/unscoped.yml'
          )
        end

        it 'returns an error at runtime' do
          service = described_class.new(
            project: scoped_project,
            flow_trigger: unscoped_trigger,
            trigger_source: :system
          )

          response = service.execute(autonomous_params)
          expect(response).to be_error
          expect(response.message).to include('group or project scoped')
        end
      end

      context 'when service account is not a project member' do
        let_it_be(:non_member_sa) do
          create(:service_account).tap do |sa|
            sa.user_detail.update!(provisioned_by_group_id: scoped_group.id)
          end
        end

        let_it_be(:non_member_trigger) do
          create(:ai_flow_trigger,
            project: scoped_project,
            user: non_member_sa,
            config_path: '.gitlab/duo/nonmember.yml'
          )
        end

        it 'returns an error' do
          service = described_class.new(
            project: scoped_project,
            flow_trigger: non_member_trigger,
            trigger_source: :system
          )

          response = service.execute(autonomous_params)
          expect(response).to be_error
          expect(response.message).to include('member of the target project')
        end
      end
    end

    describe 'does not link composite identity' do
      it 'skips composite identity linking' do
        expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)
        autonomous_service
      end
    end

    describe 'existing human path is not affected' do
      context 'when current_user is a non-human user on human path' do
        it 'returns the existing error message' do
          service = described_class.new(
            project: scoped_project,
            current_user: scoped_sa,
            flow_trigger: autonomous_trigger,
            trigger_source: :human
          )

          response = service.execute(autonomous_params)
          expect(response).to be_error
          expect(response.message).to eq('cannot be triggered by non-human users')
        end
      end
    end

    describe 'with nil current_user' do
      it 'creates a workflow with the SA as owner', :aggregate_failures do
        expect { autonomous_service.execute(autonomous_params) }
          .to change { ::Ai::DuoWorkflows::Workflow.count }.by(1)

        workflow = ::Ai::DuoWorkflows::Workflow.last
        expect(workflow.user).to eq(scoped_sa)
        expect(workflow.service_account).to eq(scoped_sa)
        expect(workflow.project).to eq(scoped_project)
        expect(workflow.trigger_source).to eq('system')
        expect(workflow.trigger_flow_trigger_id).to eq(autonomous_trigger.id)
      end

      it 'sets the SA as both git author and committer in build_variables' do
        allow(autonomous_service).to receive(:autonomous_execution_token).and_return('test-token')

        variables = autonomous_service.send(:build_variables, autonomous_params)
        expect(variables[:GIT_AUTHOR_NAME]).to eq(scoped_sa.name)
        expect(variables[:GIT_AUTHOR_EMAIL]).to eq(scoped_sa.commit_email_or_default)
        expect(variables[:GIT_COMMITTER_NAME]).to eq(scoped_sa.name)
        expect(variables[:GIT_COMMITTER_EMAIL]).to eq(scoped_sa.commit_email_or_default)
        expect(variables[:AI_FLOW_GITLAB_TOKEN]).to eq('test-token')
      end

      it 'does not link composite identity' do
        expect(::Gitlab::Auth::Identity).not_to receive(:fabricate)

        autonomous_service.execute(autonomous_params)
      end

      it 'serializes the resource using the SA' do
        service_with_resource = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          resource: resource,
          trigger_source: :system
        )

        expect(Ai::AiResource::Wrapper).to receive(:new).with(scoped_sa, resource).and_call_original

        service_with_resource.send(:serialized_resource)
      end
    end

    describe 'third-party flow permission check' do
      let_it_be(:latest_version) { create(:ai_catalog_item_version, :for_third_party_flow) }
      let_it_be(:third_party_item) { create(:ai_catalog_third_party_flow, latest_version: latest_version) }
      let_it_be(:parent_consumer) do
        create(:ai_catalog_item_consumer, :for_flow, item: third_party_item,
          service_account: scoped_sa, group: scoped_group)
      end

      let_it_be(:child_consumer) do
        create(:ai_catalog_item_consumer, item: third_party_item,
          project: scoped_project, parent_item_consumer: parent_consumer)
      end

      let_it_be(:third_party_trigger) do
        create(:ai_flow_trigger, :for_catalog_consumer,
          project: scoped_project, ai_catalog_item_consumer: child_consumer)
      end

      context 'when SA is not permitted to execute the catalog item' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(scoped_sa, :execute_ai_catalog_item, child_consumer)
            .and_return(false)
        end

        it 'returns an error' do
          service = described_class.new(
            project: scoped_project,
            flow_trigger: third_party_trigger,
            trigger_source: :system
          )

          response = service.execute(autonomous_params)
          expect(response).to be_error
          expect(response.message).to eq('service account not permitted to execute external agent')
        end
      end

      context 'when SA is permitted to execute the catalog item' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(scoped_sa, :execute_ai_catalog_item, child_consumer)
            .and_return(true)
        end

        it 'does not return a permission error' do
          service = described_class.new(
            project: scoped_project,
            flow_trigger: third_party_trigger,
            trigger_source: :system
          )

          error = service.send(:validation_error)
          expect(error).to be_nil
        end
      end
    end

    describe 'serialized_resource on autonomous path' do
      it 'uses the SA instead of current_user for resource serialization' do
        service = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          resource: resource,
          trigger_source: :system
        )

        expect(Ai::AiResource::Wrapper).to receive(:new).with(scoped_sa, resource).and_call_original

        service.send(:serialized_resource)
      end

      it 'returns nil when wrap returns nil' do
        service = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          resource: resource,
          trigger_source: :system
        )

        allow_next_instance_of(Ai::AiResource::Wrapper) do |wrapper|
          allow(wrapper).to receive(:wrap).and_return(nil)
        end

        expect(service.send(:serialized_resource)).to be_nil
      end
    end

    describe 'autonomous token failure' do
      it 'raises AutonomousTokenError when token creation fails' do
        allow_next_instance_of(Ai::DuoWorkflows::CreateAutonomousOauthAccessTokenService) do |instance|
          allow(instance).to receive(:execute).and_return(
            ServiceResponse.error(message: 'OAuth application not configured')
          )
        end

        service = described_class.new(
          project: scoped_project,
          flow_trigger: autonomous_trigger,
          trigger_source: :system
        )

        expect do
          service.send(:autonomous_execution_token)
        end.to raise_error(described_class::AutonomousTokenError, 'OAuth application not configured')
      end
    end
  end
end
