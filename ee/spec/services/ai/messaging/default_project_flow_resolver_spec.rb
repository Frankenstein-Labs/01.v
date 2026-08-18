# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::DefaultProjectFlowResolver, feature_category: :duo_agent_platform do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:service_account) { create(:user, :service_account) }

  let(:flow_reference) { 'developer/v1' }
  let(:catalog_item) { instance_double(Ai::Catalog::Item, id: 1) }
  let(:workflow_definition) { instance_double(Ai::Catalog::FoundationalFlow, catalog_item: catalog_item) }

  subject(:result) do
    described_class.new(flow_reference: flow_reference, current_user: current_user).execute
  end

  before do
    allow(current_user).to receive(:default_duo_namespace).and_return(namespace)
    # namespace is a top-level group, so root_ancestor returns itself.
    allow(namespace).to receive_messages(
      root_ancestor: namespace,
      duo_foundational_flows_enabled: true,
      enabled_flow_catalog_item_ids: [catalog_item.id]
    )
    allow(Ai::Catalog::FoundationalFlow).to receive(:[]).with(flow_reference).and_return(workflow_definition)
    allow_next_instance_of(Ai::Messaging::WorkspaceProjectService) do |service|
      allow(service).to receive(:execute)
        .and_return(ServiceResponse.success(payload: { project: project }))
    end
    allow(Ai::Catalog::ItemConsumers::ResolveServiceAccountService).to receive(:new)
      .with(container: namespace, item: catalog_item)
      .and_return(instance_double(
        Ai::Catalog::ItemConsumers::ResolveServiceAccountService,
        execute: ServiceResponse.success(payload: { service_account: service_account })
      ))
    allow(Ai::DuoWorkflows::FoundationalFlowStartParamsResolver).to receive(:call)
      .with(flow_reference, project, user: current_user)
      .and_return({ flow_config_id: 'developer', flow_config_schema_version: 'v1', flow_version: nil })
  end

  describe '#execute' do
    context 'when everything resolves successfully' do
      it 'returns success with project, service account, and flow params' do
        expect(result).to be_success
        expect(result.payload).to include(
          project: project,
          service_account: service_account,
          flow_config_id: 'developer',
          flow_config_schema_version: 'v1',
          flow_version: nil
        )
      end
    end

    context 'when user has no default Duo namespace' do
      before do
        allow(current_user).to receive(:default_duo_namespace).and_return(nil)
      end

      it 'returns error with :namespace_not_configured' do
        expect(result).to be_error
        expect(result.reason).to eq(:namespace_not_configured)
      end
    end

    context 'when flow is not enabled for the namespace' do
      before do
        allow(namespace).to receive(:enabled_flow_catalog_item_ids).and_return([])
      end

      it 'returns error with :flow_not_enabled' do
        expect(result).to be_error
        expect(result.reason).to eq(:flow_not_enabled)
      end
    end

    context 'when duo_foundational_flows_enabled is false' do
      before do
        allow(namespace).to receive(:duo_foundational_flows_enabled).and_return(false)
      end

      it 'returns error with :flow_not_enabled' do
        expect(result).to be_error
        expect(result.reason).to eq(:flow_not_enabled)
      end
    end

    context 'when workflow definition is not found' do
      before do
        allow(Ai::Catalog::FoundationalFlow).to receive(:[]).with(flow_reference).and_return(nil)
      end

      it 'returns error with :flow_not_enabled' do
        expect(result).to be_error
        expect(result.reason).to eq(:flow_not_enabled)
      end
    end

    context 'when workspace project resolution fails' do
      before do
        allow_next_instance_of(Ai::Messaging::WorkspaceProjectService) do |service|
          allow(service).to receive(:execute)
            .and_return(ServiceResponse.error(message: 'Permission denied'))
        end
      end

      it 'returns error with :workspace_project_error' do
        expect(result).to be_error
        expect(result.reason).to eq(:workspace_project_error)
        expect(result.message).to include('Permission denied')
      end
    end

    context 'when service account cannot be resolved' do
      before do
        allow(Ai::Catalog::ItemConsumers::ResolveServiceAccountService).to receive(:new)
          .and_return(instance_double(
            Ai::Catalog::ItemConsumers::ResolveServiceAccountService,
            execute: ServiceResponse.error(message: 'No SA found')
          ))
      end

      it 'returns error with :service_account_error' do
        expect(result).to be_error
        expect(result.reason).to eq(:service_account_error)
      end
    end

    context 'with a different flow reference' do
      let(:flow_reference) { 'code_review/v1' }
      let(:other_catalog_item) { instance_double(Ai::Catalog::Item, id: 2) }
      let(:other_workflow_definition) do
        instance_double(Ai::Catalog::FoundationalFlow, catalog_item: other_catalog_item)
      end

      before do
        allow(Ai::Catalog::FoundationalFlow).to receive(:[]).with('code_review/v1')
          .and_return(other_workflow_definition)
        allow(namespace).to receive(:enabled_flow_catalog_item_ids).and_return([other_catalog_item.id])
        allow(Ai::Catalog::ItemConsumers::ResolveServiceAccountService).to receive(:new)
          .with(container: namespace, item: other_catalog_item)
          .and_return(instance_double(
            Ai::Catalog::ItemConsumers::ResolveServiceAccountService,
            execute: ServiceResponse.success(payload: { service_account: service_account })
          ))
        allow(Ai::DuoWorkflows::FoundationalFlowStartParamsResolver).to receive(:call)
          .with('code_review/v1', project, user: current_user)
          .and_return({ flow_config_id: 'code_review', flow_config_schema_version: 'v1', flow_version: '1.0.0' })
      end

      it 'resolves using the provided flow reference' do
        expect(result).to be_success
        expect(result.payload).to include(
          flow_config_id: 'code_review',
          flow_config_schema_version: 'v1',
          flow_version: '1.0.0'
        )
      end
    end
  end
end
