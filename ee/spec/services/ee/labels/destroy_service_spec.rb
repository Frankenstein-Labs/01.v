# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Labels::DestroyService, feature_category: :team_planning do
  describe '#execute' do
    context 'with audit events' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project) }
      let_it_be(:group) { create(:group) }

      context 'when current_user is present' do
        context 'for a project label' do
          it 'creates an audit event' do
            label = create(:label, project: project, title: 'Doomed')

            expect { described_class.new(user, label).execute }.to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.last
            expect(audit_event).to have_attributes(
              author_id: user.id,
              entity_type: 'Project',
              entity_id: project.id
            )
            expect(audit_event.details).to include(
              event_name: 'label_deleted',
              custom_message: 'Deleted label Doomed'
            )
          end
        end

        context 'for a group label' do
          it 'creates an audit event scoped to the group' do
            label = create(:group_label, group: group, title: 'Group Doomed')

            expect { described_class.new(user, label).execute }.to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event).to have_attributes(
              entity_type: 'Group',
              entity_id: group.id
            )
            expect(audit_event.details).to include(
              event_name: 'label_deleted',
              custom_message: 'Deleted label Group Doomed'
            )
          end
        end

        context 'when destroy fails' do
          it 'does not create an audit event' do
            label = create(:label, project: project, title: 'Survivor')
            allow(label).to receive(:destroy).and_return(false)

            expect { described_class.new(user, label).execute }.not_to change { AuditEventReader.count }
          end
        end

        # Coverage-only test: Template label auditing excluded from initial implementation.
        # Replace this test when template label auditing is added.
        context 'for a template label (coverage only)' do
          it 'does not create an audit event' do
            label = create(:admin_label, title: 'Template Label')

            expect { described_class.new(user, label).execute }.not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when current_user is nil' do
        it 'does not create an audit event' do
          label = create(:label, project: project, title: 'Unaudited')

          expect { described_class.new(nil, label).execute }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
