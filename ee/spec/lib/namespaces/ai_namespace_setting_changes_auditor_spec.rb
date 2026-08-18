# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::AiNamespaceSettingChangesAuditor, feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

    subject(:auditor) { described_class.new(user, group.ai_settings, group) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)

      unless group.ai_settings
        group.create_ai_settings!(
          duo_workflow_mcp_enabled: true,
          prompt_injection_protection_level: :log_only,
          ai_usage_data_collection_enabled: true
        )
      end
    end

    shared_examples 'audited ai setting' do
      before do
        group.ai_settings.update!(column_name => prev_value)
      end

      it 'creates an audit event' do
        group.ai_settings.update!(column_name => new_value)

        expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details).to include(
          change: column_name,
          from: prev_value,
          to: new_value,
          target_details: group.full_path
        )
      end

      it 'streams the correct audit event' do
        group.ai_settings.update!(column_name => new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[column_name], anything, anything
        )

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          group.ai_settings.update!(column_name => prev_value)

          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'for all columns' do
      where(:column_name, :prev_value, :new_value) do
        :duo_agent_platform_enabled               | true       | false
        :duo_workflow_mcp_enabled                 | true       | false
        :prompt_injection_protection_level        | 'log_only' | 'interrupt'
        :ai_usage_data_collection_enabled         | true       | false
        :ai_catalog_restricted_to_group_hierarchy | true       | false
      end

      with_them do
        context 'when settings are changed for self-managed' do
          it_behaves_like 'audited ai setting'
        end
      end
    end

    context 'when model is blank' do
      subject(:auditor) { described_class.new(user, nil, group) }

      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
