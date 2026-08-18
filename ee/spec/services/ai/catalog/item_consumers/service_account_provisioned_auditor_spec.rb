# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::ServiceAccountProvisionedAuditor,
  feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user, name: "Group name") }
  let_it_be(:item_project) { create(:project, developers: user) }
  let_it_be(:flow_item, refind: true, reload: true) do
    create(:ai_catalog_flow, :public, project: item_project, name: 'item_name')
  end

  let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: group) }

  let(:item_consumer) do
    build_stubbed(:ai_catalog_item_consumer, group: group, item: flow_item)
  end

  subject(:auditor) do
    described_class.new(
      current_user: user,
      service_account: service_account,
      item: flow_item,
      item_consumer: item_consumer
    )
  end

  describe '#audit' do
    it 'fires the audit event with the expected attributes, details, and message', :aggregate_failures do
      expect(::Gitlab::Audit::Auditor).to receive(:audit) do |audit_context|
        expect(audit_context).to include(
          name: 'duo_service_account_provisioned',
          author: user,
          scope: group,
          target: service_account,
          target_details: service_account.username
        )

        expect(audit_context[:additional_details]).to include(
          service_account_id: service_account.id,
          service_account_username: service_account.username,
          composite_identity_enforced: service_account.composite_identity_enforced?,
          provisioned_by_group_id: service_account.provisioned_by_group_id,
          item_id: flow_item.id,
          item_type: flow_item.item_type,
          item_name: flow_item.name,
          item_consumer_id: item_consumer.id,
          access_level: Ai::Catalog::ItemConsumers::CreateService::SERVICE_ACCOUNT_ACCESS_LEVEL
        )

        expect(audit_context[:message]).to include(
          "Auto-provisioned Duo service account",
          service_account.username
        )
      end

      auditor.audit
    end

    context 'when service_account is nil' do
      subject(:auditor) do
        described_class.new(
          current_user: user,
          service_account: nil,
          item: flow_item,
          item_consumer: item_consumer
        )
      end

      it 'is a no-op and does not call the auditor' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        auditor.audit
      end
    end

    context 'when item_consumer is nil' do
      subject(:auditor) do
        described_class.new(
          current_user: user,
          service_account: service_account,
          item: flow_item,
          item_consumer: nil
        )
      end

      it 'falls back to the service account as the audit scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            scope: service_account,
            target: service_account
          )
        )

        auditor.audit
      end
    end

    context 'when item_consumer is project-scoped' do
      let_it_be(:project) { build_stubbed(:project, group: group) }

      let(:item_consumer) do
        build_stubbed(:ai_catalog_item_consumer, group: nil, project: project, item: flow_item)
      end

      it 'uses the project as the audit scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            scope: project,
            target: service_account
          )
        )

        auditor.audit
      end
    end

    context 'when item is a foundational flow' do
      let_it_be(:foundational_flow_item) do
        create(:ai_catalog_flow, :public, project: item_project, name: 'foundational_flow',
          foundational_flow_reference: 'code_review/v1')
      end

      subject(:auditor) do
        described_class.new(
          current_user: user,
          service_account: service_account,
          item: foundational_flow_item,
          item_consumer: item_consumer
        )
      end

      it 'includes the foundational flow reference in the message and details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit) do |audit_context|
          expect(audit_context[:message]).to include('foundational flow: code_review/v1')
          expect(audit_context[:additional_details]).to include(
            foundational_flow_reference: 'code_review/v1'
          )
        end

        auditor.audit
      end
    end

    context 'when item has no foundational_flow_reference' do
      it 'omits the foundational_flow_reference key from additional_details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit) do |audit_context|
          expect(audit_context[:additional_details]).not_to have_key(:foundational_flow_reference)
          expect(audit_context[:message]).not_to include('foundational flow:')
        end

        auditor.audit
      end
    end
  end

  describe 'integration with CreateService', :aggregate_failures do
    include Ai::Catalog::TestHelpers

    let_it_be(:released_flow_version) do
      create(:ai_catalog_flow_version, :released, item: flow_item.class.find(flow_item.id), version: '3.2.1')
    end

    subject(:execute) do
      Ai::Catalog::ItemConsumers::CreateService.new(
        container: group, current_user: user, params: { item: flow_item }
      ).execute
    end

    before do
      enable_ai_catalog
      allow_next_instance_of(Ai::Catalog::ItemConsumers::CreateService) do |instance|
        allow(instance).to receive(:foundational_flow_not_in_allowlist?).and_return(false)
      end
    end

    it 'fires the audit event through CreateService#execute' do
      allow(::Gitlab::Audit::Auditor).to receive(:audit).and_call_original
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: 'duo_service_account_provisioned')
      ).and_call_original

      expect(execute).to be_success
    end

    context 'when service account creation fails' do
      before do
        allow(::Namespaces::ServiceAccounts::GroupCreateService).to receive_message_chain(:new, :execute)
          .and_return(ServiceResponse.error(message: 'service account error'))
      end

      it 'does not emit a duo_service_account_provisioned audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: 'duo_service_account_provisioned')
        )

        execute
      end
    end

    context 'when the item is an agent (no service account provisioned)' do
      let_it_be(:agent_item, refind: true) { create(:ai_catalog_agent, :public, project: item_project) }
      let_it_be(:released_agent_version) do
        create(:ai_catalog_agent_version, :released, item: agent_item.class.find(agent_item.id), version: '3.2.1')
      end

      subject(:execute) do
        Ai::Catalog::ItemConsumers::CreateService.new(
          container: group, current_user: user, params: { item: agent_item }
        ).execute
      end

      it 'does not emit a duo_service_account_provisioned audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
          hash_including(name: 'duo_service_account_provisioned')
        )

        execute
      end
    end
  end
end
