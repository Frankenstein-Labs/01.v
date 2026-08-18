# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:definition) do
    <<~YAML
      version: v1
      environment: ambient
      components:
        - name: main_agent
          type: AgentComponent
          prompt_id: test_prompt
      routers: []
      flow:
        entry_point: main_agent
    YAML
  end

  let(:params) do
    {
      name: 'Flow',
      description: 'Description',
      visibility: :restricted,
      definition: definition
    }
  end

  before do
    enable_ai_catalog
  end

  subject(:service) { described_class.new(project: project, current_user: user, params: params) }

  it_behaves_like Ai::Catalog::Items::BaseCreateService do
    let(:expected_item_type) { Ai::Catalog::Item::FLOW_TYPE }
    let(:expected_item_schema_version) { Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION }
    let(:expected_audit_event_create_item_message) { 'Created a new restricted AI flow with no tools' }
    let(:expected_audit_event_item_name) { 'AI flow' }
    let(:expected_updated_definition) do
      YAML.safe_load(definition).merge('yaml_definition' => definition)
    end

    let(:expected_create_event_properties) do
      {
        label: 'flow',
        item_type: 'custom_flow',
        item_version: '1.0.0',
        item_schema_version: 'v1',
        custom_item_id: kind_of(Integer),
        components: 'AgentComponent'
      }
    end

    it_behaves_like 'yaml definition create service behavior'

    context 'when just the ai_catalog StageCheck passes' do
      let(:flows_available) { false }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(project, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project, :ai_catalog_flows).and_return(flows_available)
      end

      it_behaves_like 'an error response', 'You have insufficient permissions'

      context 'and the ai_catalog_flows StageCheck also passes' do
        let(:flows_available) { true }

        it 'is successful' do
          expect(execute_service).to be_success
        end
      end
    end

    context 'when prompts are present' do
      let(:definition) do
        super() + <<~YAML
          prompts:
            - prompt_id: local_prompt
              name: Local Test Prompt
              prompt_template:
                system: You are a helpful assistant
                user: Help me with {{goal}}
              unit_primitives: []
        YAML
      end

      it 'creates a flow with prompts' do
        expect(execute_service).to be_success

        item = Ai::Catalog::Item.last
        definition_hash = item.latest_version.definition

        expect(definition_hash['prompts']).to be_present
        expect(definition_hash['prompts'].first).to include(
          'prompt_id' => 'local_prompt',
          'name' => 'Local Test Prompt',
          'unit_primitives' => []
        )
      end

      context 'when unit_primitives is missing from prompts' do
        let(:definition) do
          <<~YAML
            version: v1
            environment: ambient
            components:
              - name: main_agent
                type: AgentComponent
                prompt_id: test_prompt
            routers: []
            flow:
              entry_point: main_agent
            prompts:
              - prompt_id: local_prompt
                name: Local Test Prompt
                prompt_template:
                  system: You are a helpful assistant
                  user: Help me with {{goal}}
          YAML
        end

        it_behaves_like 'an error response', [
          "Latest version definition object at `/prompts/0` is missing required properties: unit_primitives",
          "Versions is invalid"
        ]
      end
    end

    context 'with self-hosted DWS configuration' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }
      let_it_be(:feature_setting) do
        create(:ai_feature_setting, :duo_agent_platform, self_hosted_model: self_hosted_model)
      end

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

        execute_service
      end

      context 'when self-hosted secure is enabled' do
        let(:self_hosted_secure) { true }

        it 'initializes the DWS client with secure: true' do
          expect(::Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new)
            .with(hash_including(
              duo_workflow_service_url: self_hosted_url,
              secure: true
            ))

          execute_service
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

          execute_service
        end
      end
    end

    context 'when DWS returns validation errors' do
      before do
        allow_next_instance_of(Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:validate_flow_config)
            .and_return(ServiceResponse.error(message: ['Component missing input variables: goal']))
        end
      end

      it_behaves_like 'an error response', ['Component missing input variables: goal']
    end

    context 'when DWS is unavailable' do
      before do
        allow_next_instance_of(Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:validate_flow_config)
            .and_return(
              ServiceResponse.error(
                message: 'Unable to validate flow configuration. Duo Workflow Service is currently unavailable.'
              )
            )
        end
      end

      it_behaves_like 'an error response',
        ['Unable to validate flow configuration. Duo Workflow Service is currently unavailable.']
    end
  end
end
