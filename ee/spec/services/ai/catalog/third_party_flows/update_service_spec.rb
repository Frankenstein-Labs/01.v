# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ThirdPartyFlows::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, :third_party_flow, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, version: '1.1.0', item: item)
  end

  let(:params) do
    {
      item: item,
      name: "New name",
      description: "New description",
      visibility: :restricted,
      release: true,
      definition: <<-YAML
      injectGatewayToken: false
      image: example/new_image:latest
      commands:
        - /bin/newcmd
      variables:
        - NEWVAR1
      YAML
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      {
        'injectGatewayToken' => false,
        'image' => 'example/new_image:latest',
        'commands' => ['/bin/newcmd'],
        'variables' => ['NEWVAR1'],
        'yaml_definition' => params[:definition]
      }
    end

    let(:expected_update_event_properties) do
      {
        label: 'third_party_flow',
        item_type: 'custom_external_agent',
        item_version: '1.1.0',
        custom_item_id: item.id
      }
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when item is not an third_party_flow' do
        before do
          allow(item).to receive(:third_party_flow?).and_return(false)
        end

        it_behaves_like 'an error response', 'ThirdPartyFlow not found'
      end

      context 'when ai_catalog_third_party_flows feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_third_party_flows: false)
        end

        it_behaves_like 'an error response', 'You have insufficient permissions'
      end

      it_behaves_like 'validates yaml definition syntax', 'ThirdPartyFlow'
    end
  end

  describe 'audit events' do
    let(:params) { super().except(:visibility).merge(public: true) }
    let(:execute_service) do
      service.execute
    end

    before_all do
      project.add_maintainer(user)
    end

    it 'creates audit events for the changes', :aggregate_failures do
      expect { execute_service }.to change { AuditEventReader.count }.by(3)

      audit_events = AuditEventReader.last(3)

      expect(audit_events[0]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[0].details).to include(
        custom_message: "Updated AI external agent: Changed image, Changed commands, Changed variables, " \
          "Disabled AI Gateway token injection",
        event_name: "update_ai_catalog_third_party_flow",
        target_type: "Ai::Catalog::Item"
      )

      expect(audit_events[1]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[1].details).to include(
        custom_message: 'Made AI external agent public'
      )

      expect(audit_events[2]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id
      )
      expect(audit_events[2].details).to include(
        custom_message: 'Released version 1.1.0 of AI external agent'
      )
    end

    context 'when update fails' do
      before do
        allow(item).to receive(:save).and_return(false)
        item.errors.add(:base, 'Item cannot be updated')
      end

      it 'does not create an audit event' do
        expect { execute_service }.not_to change { AuditEventReader.count }
      end
    end
  end
end
