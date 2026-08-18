# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::GroupChangesAuditor, feature_category: :groups_and_projects do
  describe '.audit_changes' do
    let!(:user) { create(:user) }
    let!(:group) { create(:group, visibility_level: 0).reload } # reload clears previous_changes on group settings
    let(:foo_instance) { described_class.new(user, group) }
    let_it_be(:audited_group_column_keys) { described_class::EVENT_NAME_PER_COLUMN.keys }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    describe 'non audit changes' do
      it 'does not call the audit event service' do
        group.update!(runners_token: 'new token')

        expect { foo_instance.execute }.not_to change { AuditEventReader.count }
      end
    end

    describe 'audit changes' do
      it 'creates and event when the visibility change' do
        group.update!(visibility_level: 20)

        expect { foo_instance.execute }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:change]).to eq 'visibility'
      end

      it 'creates an event for project creation level change' do
        group.update!(project_creation_level: 0)

        expect { foo_instance.execute }.to change { AuditEventReader.count }.by(1)

        event = AuditEventReader.last
        expect(event.details[:from]).to eq 'Maintainers'
        expect(event.details[:to]).to eq 'No one'
        expect(event.details[:change]).to eq 'project_creation_level'
      end

      it 'creates an event when attributes change' do
        # Exclude special cases covered from above
        columns = audited_group_column_keys -
          described_class::COLUMN_HUMAN_NAME.keys - [:project_creation_level]

        columns.each do |column|
          data = group.attributes[column.to_s]

          value =
            case Group.type_for_attribute(column.to_s).type
            when :integer
              data.present? ? data + 1 : 0
            when :boolean
              !data
            else
              "#{data}-next"
            end

          event_name = described_class::EVENT_NAME_PER_COLUMN[column]
          group.update_attribute(column, value)

          expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
            .with(event_name, anything, anything)

          expect { foo_instance.execute }.to change { AuditEventReader.count }.by(1)

          event = AuditEventReader.last
          expect(event.details[:from]).to eq data
          expect(event.details[:to]).to eq value
          expect(event.details[:change]).to eq column.to_s
        end
      end

      it 'does not create event when there is no change in attribute value' do
        audited_group_column_keys.each do |column|
          group.update_attribute(column, group.attributes[column.to_s])

          expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)
          expect { foo_instance.execute }.not_to change { AuditEventReader.count }
        end
      end

      it 'creates an audit event when ai_usage_data_collection_enabled changes' do
        group.ai_settings.update!(ai_usage_data_collection_enabled: true)

        expect { foo_instance.execute }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:change]).to eq :ai_usage_data_collection_enabled
      end

      it 'does not raise when ai_settings is nil' do
        allow(group).to receive(:ai_settings).and_return(nil)

        expect { foo_instance.execute }.not_to raise_error
      end

      it 'audits all the columns except the ones denylisted' do
        columns_not_to_audit = %w[created_at updated_at id owner_id type avatar ldap_sync_status
          ldap_sync_error ldap_sync_last_update_at ldap_sync_last_successful_update_at ldap_sync_last_sync_at
          description_html parent_id cached_markdown_version runners_token file_template_project_id
          saml_discovery_token runners_token_encrypted custom_project_templates_group_id auto_devops_enabled
          extra_shared_runners_minutes_limit last_ci_minutes_notification_at last_ci_minutes_usage_notification_level
          subgroup_creation_level max_pages_size max_artifacts_size default_branch_protection
          max_personal_access_token_lifetime shared_runners_enabled
          allow_descendants_override_disabled_shared_runners traversal_ids organization_id
          state]

        columns_to_audit = audited_group_column_keys.map(&:to_s)

        expect(Group.columns.map(&:name) - columns_not_to_audit).to match_array(columns_to_audit)
      end
    end
  end
end
