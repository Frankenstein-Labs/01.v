# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::NamespaceDetailChangesAuditor, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

    subject(:auditor) { described_class.new(user, group.namespace_details, group) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    shared_examples 'audited detail' do
      before do
        group.namespace_details.update!(column_name => prev_value)
      end

      it 'creates an audit event' do
        group.namespace_details.update!(column_name => new_value)

        expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
        audit_details = {
          change: column_name,
          from: prev_value,
          to: new_value,
          target_details: group.full_path
        }
        expect(AuditEventReader.last.details).to include(audit_details)
      end

      it 'streams correct audit event stream' do
        group.namespace_details.update!(column_name => new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          described_class::EVENT_NAME_PER_COLUMN[column_name], anything, anything)

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          group.namespace_details.update!(column_name => prev_value)

          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'for all columns' do
      where(:column_name, :prev_value, :new_value) do
        :description | 'description1' | 'description2'
      end

      with_them do
        context 'when details are changed for saas', :saas do
          let_it_be_with_reload(:group) do
            create(:group_with_plan, plan: :ultimate_plan, trial_ends_on: Date.tomorrow)
          end

          let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }

          before do
            stub_licensed_features(
              extended_audit_events: true,
              external_audit_events: true
            )
            stub_ee_application_setting(should_check_namespace_plan: true)
          end

          it_behaves_like 'audited detail'
        end

        context 'when details are changed for self-managed' do
          it_behaves_like 'audited detail'
        end
      end
    end
  end
end
