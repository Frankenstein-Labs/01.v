# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowsMetadataService, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: create(:group)) }

  let(:current_user) { user }
  let(:scoped_namespace) { nil }
  let(:scoped_project) { nil }

  subject(:capabilities) do
    described_class.new(current_user: current_user, namespace: scoped_namespace, project: scoped_project).execute
  end

  before do
    allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
      allow(client).to receive(:list_capabilities)
        .and_return(ServiceResponse.success(payload: { capabilities: [] }))
    end
  end

  it 'always includes the static Rails capabilities' do
    expect(capabilities).to include(
      { name: 'job_trace_pagination', metadata: nil },
      { name: 'tool_call_approval_source', metadata: nil }
    )
  end

  describe 'advanced_search capability' do
    context 'when no namespace or project is given' do
      it 'does not include advanced_search' do
        allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?).and_return(false)

        expect(capabilities.pluck(:name)).not_to include('advanced_search')
      end
    end

    context 'when a namespace is given' do
      let(:scoped_namespace) { namespace }

      it 'includes advanced_search when enabled for the namespace' do
        allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: namespace).and_return(true)

        expect(capabilities).to include({ name: 'advanced_search', metadata: nil })
      end

      it 'does not include advanced_search when disabled for the namespace' do
        allow(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: namespace).and_return(false)

        expect(capabilities.pluck(:name)).not_to include('advanced_search')
      end
    end

    context 'when a project is given' do
      let(:scoped_project) { project }

      it 'checks elasticsearch scope against the project, not a namespace' do
        expect(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: project).and_return(true)

        expect(capabilities).to include({ name: 'advanced_search', metadata: nil })
      end
    end

    context 'when both a namespace and a project are given' do
      let(:scoped_namespace) { namespace }
      let(:scoped_project) { project }

      it 'prioritizes the project over the namespace' do
        expect(::Gitlab::CurrentSettings).to receive(:search_using_elasticsearch?)
          .with(scope: project).and_return(false)

        capabilities
      end
    end
  end

  describe 'incremental_checkpoints capability' do
    let(:scoped_namespace) { namespace }

    it 'includes incremental_checkpoints when the feature flag is enabled for the namespace' do
      stub_feature_flags(duo_workflow_incremental_checkpoints: namespace)

      expect(capabilities).to include({ name: 'incremental_checkpoints', metadata: nil })
    end

    it 'does not include incremental_checkpoints when the feature flag is disabled' do
      stub_feature_flags(duo_workflow_incremental_checkpoints: false)

      expect(capabilities.pluck(:name)).not_to include('incremental_checkpoints')
    end

    context 'when scoped to a subgroup with the flag enabled on the root ancestor' do
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let(:scoped_namespace) { subgroup }

      it 'includes incremental_checkpoints' do
        stub_feature_flags(duo_workflow_incremental_checkpoints: namespace)

        expect(capabilities).to include({ name: 'incremental_checkpoints', metadata: nil })
      end
    end
  end

  describe 'incremental_checkpoints_only capability' do
    let(:scoped_namespace) { namespace }

    it 'includes incremental_checkpoints_only when the feature flag is enabled for the namespace' do
      stub_feature_flags(duo_workflow_write_incremental_only: namespace)

      expect(capabilities).to include({ name: 'incremental_checkpoints_only', metadata: nil })
    end

    it 'does not include incremental_checkpoints_only when the feature flag is disabled' do
      stub_feature_flags(duo_workflow_write_incremental_only: false)

      expect(capabilities.pluck(:name)).not_to include('incremental_checkpoints_only')
    end
  end

  describe 'duo_developer capability' do
    it 'includes the capability with registry coordinates when the feature flag is enabled' do
      stub_feature_flags(duo_cli_default_flow: user)

      expect(capabilities).to include(
        {
          name: 'duo_developer',
          metadata: {
            flow_config_id: 'developer',
            flow_config_schema_version: 'v1',
            flow_version: '2.0.0-interactive'
          }
        }
      )
    end

    it 'does not include the capability when the feature flag is disabled' do
      stub_feature_flags(duo_cli_default_flow: false)

      expect(capabilities.pluck(:name)).not_to include('duo_developer')
    end

    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'does not include the duo_developer capability' do
        expect(capabilities.pluck(:name)).not_to include('duo_developer')
      end
    end
  end

  describe 'Duo Workflow Service capabilities' do
    context 'when current_user is nil' do
      let(:current_user) { nil }

      it 'does not call the Duo Workflow Service' do
        expect(::Ai::DuoWorkflow::DuoWorkflowService::Client).not_to receive(:new)

        capabilities
      end
    end

    context 'when ListCapabilities succeeds' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(
            ServiceResponse.success(payload: { capabilities: [{ name: 'mcp_tools', metadata: nil }] })
          )
        end
      end

      it 'includes the capabilities returned by the Duo Workflow Service' do
        expect(capabilities).to include({ name: 'mcp_tools', metadata: nil })
      end
    end

    context 'when ListCapabilities fails' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(ServiceResponse.error(message: 'boom'))
        end
      end

      it 'does not raise and omits Duo Workflow Service capabilities' do
        expect(capabilities.pluck(:name)).not_to include('mcp_tools')
      end
    end

    context 'when calling the Duo Workflow Service raises' do
      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_raise(StandardError, 'connection refused')
        end
      end

      it 'does not raise and omits Duo Workflow Service capabilities' do
        expect { capabilities }.not_to raise_error
      end
    end

    context 'when filtering tool approval capabilities' do
      let(:dws_response) do
        ServiceResponse.success(
          payload: {
            capabilities: [
              { name: 'tool_call_approval', metadata: nil },
              { name: 'tool_call_pattern_approval', metadata: nil },
              { name: 'mcp_tools', metadata: nil }
            ]
          }
        )
      end

      before do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(dws_response)
        end
      end

      context 'when no namespace or project is given' do
        it 'filters out the tool approval capabilities' do
          expect(capabilities.pluck(:name)).to include('mcp_tools')
          expect(capabilities.pluck(:name)).not_to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end

      context 'when tool approval for session is disabled for the namespace' do
        let(:scoped_namespace) { namespace }

        it 'filters out the tool approval capabilities' do
          expect(capabilities.pluck(:name)).not_to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end

      context 'when tool approval for session is enabled for the namespace' do
        let(:scoped_namespace) { namespace }

        before do
          namespace.reload.namespace_settings.update!(tool_approval_for_session_enabled: true)
        end

        it 'keeps the tool approval capabilities' do
          expect(capabilities.pluck(:name)).to include('tool_call_approval')
        end
      end

      context 'when tool approval for session is disabled for the project' do
        let(:scoped_project) { project }

        it 'filters out the tool approval capabilities' do
          expect(capabilities.pluck(:name)).not_to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end

      context 'when tool approval for session is enabled for the project' do
        let(:scoped_project) { project }

        before do
          project.reload.project_setting.update!(tool_approval_for_session_enabled: true)
        end

        it 'keeps the tool approval capabilities' do
          expect(capabilities.pluck(:name)).to include('tool_call_approval')
        end
      end

      context 'when both a namespace and a project are given' do
        let(:scoped_namespace) { namespace }
        let(:scoped_project) { project }

        before do
          namespace.reload.namespace_settings.update!(tool_approval_for_session_enabled: true)
          # Guard against another example in this file leaving the in-memory
          # `project_setting` association stale (its underlying row is rolled
          # back, but the association proxy on the shared `let_it_be` object
          # isn't automatically reloaded).
          project.reload
        end

        it 'prioritizes the project setting over the namespace setting' do
          expect(capabilities.pluck(:name)).not_to include('tool_call_approval', 'tool_call_pattern_approval')
        end
      end
    end

    describe 'self-hosted DWS client configuration' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: self_hosted_model)
      end

      let(:scoped_project) { project }
      let(:self_hosted_url) { 'dws.example.com:50052' }
      let(:self_hosted_secure) { false }

      before do
        stub_application_setting(
          duo_agent_platform_service_url: self_hosted_url,
          self_hosted_duo_agent_platform_service_secure: self_hosted_secure
        )
      end

      it 'initializes the DWS client with the self-hosted URL and secure setting' do
        expect(::Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new)
          .with(hash_including(
            duo_workflow_service_url: self_hosted_url,
            secure: self_hosted_secure
          ))

        capabilities
      end

      context 'when self-hosted secure is enabled' do
        let(:self_hosted_secure) { true }

        it 'initializes the DWS client with secure: true' do
          expect(::Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new)
            .with(hash_including(
              duo_workflow_service_url: self_hosted_url,
              secure: true
            ))

          capabilities
        end
      end

      context 'when self-hosted URL is different' do
        let(:self_hosted_url) { 'other-server:9090' }

        it 'initializes the DWS client with the updated URL' do
          expect(::Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new)
            .with(hash_including(
              duo_workflow_service_url: 'other-server:9090',
              secure: self_hosted_secure
            ))

          capabilities
        end
      end
    end

    describe 'caching', :use_clean_rails_memory_store_caching do
      it 'only calls the Duo Workflow Service once for successful responses' do
        expect_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          expect(client).to receive(:list_capabilities).once.and_return(
            ServiceResponse.success(payload: { capabilities: [{ name: 'mcp_tools', metadata: nil }] })
          )
        end

        capabilities
        second_call = described_class.new(current_user: current_user).execute

        expect(second_call).to include({ name: 'mcp_tools', metadata: nil })
      end

      it 'does not cache failed responses' do
        allow_next_instance_of(::Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:list_capabilities).and_return(ServiceResponse.error(message: 'boom'))
        end

        capabilities

        expect(Rails.cache.read(described_class::DWS_CAPABILITIES_CACHE_KEY)).to be_nil
      end
    end
  end
end
