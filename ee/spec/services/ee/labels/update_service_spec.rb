# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Labels::UpdateService, feature_category: :team_planning do
  describe '#execute' do
    context 'with audit events' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project) }
      let_it_be(:group) { create(:group) }

      context 'when current_user is present' do
        context 'when title changes' do
          it 'creates an audit event with from/to message' do
            label = create(:label, project: project, title: 'Original', color: '#000000')

            expect { described_class.new(user, { title: 'Renamed' }).execute(label) }
              .to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event).to have_attributes(
              author_id: user.id,
              entity_type: 'Project',
              entity_id: project.id
            )
            expect(audit_event.details).to include(
              event_name: 'label_updated',
              custom_message: 'Changed label title from Original to Renamed'
            )
          end
        end

        context 'when description changes' do
          it 'creates an audit event with generic message' do
            label = create(:label, project: project, title: 'My Label', description: 'Old', color: '#000000')

            expect { described_class.new(user, { description: 'New' }).execute(label) }
              .to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event.details).to include(
              event_name: 'label_updated',
              custom_message: 'Updated label My Label'
            )
          end
        end

        context 'when color changes' do
          it 'creates an audit event with generic message' do
            label = create(:label, project: project, title: 'My Label', color: '#000000')

            expect { described_class.new(user, { color: '#FF0000' }).execute(label) }
              .to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event.details).to include(
              event_name: 'label_updated',
              custom_message: 'Updated label My Label'
            )
          end
        end

        context 'when multiple fields change including title' do
          it 'creates an audit event with title from/to message' do
            label = create(:label, project: project, title: 'Old Name', color: '#000000')

            expect { described_class.new(user, { title: 'New Name', color: '#FF0000' }).execute(label) }
              .to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event.details).to include(
              custom_message: 'Changed label title from Old Name to New Name'
            )
          end
        end

        context 'when no fields actually change' do
          it 'does not create an audit event' do
            label = create(:label, project: project, title: 'Same', color: '#000000')

            expect { described_class.new(user, { title: 'Same' }).execute(label) }
              .not_to change { AuditEventReader.count }
          end
        end

        context 'when update is invalid' do
          it 'does not create an audit event' do
            label = create(:label, project: project, title: 'Valid', color: '#000000')

            expect { described_class.new(user, { color: 'invalid' }).execute(label) }
              .not_to change { AuditEventReader.count }
          end
        end

        context 'for a group label' do
          it 'creates an audit event scoped to the group' do
            label = create(:group_label, group: group, title: 'Group Label', color: '#000000')

            expect { described_class.new(user, { title: 'Updated' }).execute(label) }
              .to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event).to have_attributes(
              entity_type: 'Group',
              entity_id: group.id
            )
          end
        end

        # Coverage-only test: Template label auditing excluded from initial implementation.
        # Replace this test when template label auditing is added.
        context 'for a template label (coverage only)' do
          it 'does not create an audit event' do
            label = create(:admin_label, title: 'Template', color: '#000000')

            expect { described_class.new(user, { title: 'Updated Template' }).execute(label) }
              .not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when current_user is nil' do
        it 'does not create an audit event' do
          label = create(:label, project: project, title: 'Test', color: '#000000')

          expect { described_class.new(nil, { title: 'Changed' }).execute(label) }
            .not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
