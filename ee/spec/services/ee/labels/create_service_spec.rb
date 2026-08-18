# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Labels::CreateService, feature_category: :team_planning do
  describe '#execute' do
    context 'with audit events' do
      let_it_be(:user) { create(:user) }
      let_it_be(:project) { create(:project) }
      let_it_be(:group) { create(:group) }

      let(:valid_params) { { title: 'New Label', color: '#FF0000' } }

      context 'when current_user is present' do
        subject(:service) { described_class.new(user, valid_params) }

        context 'for a project label' do
          it 'creates an audit event' do
            expect { service.execute(project: project) }.to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event).to have_attributes(
              author_id: user.id,
              entity_type: 'Project',
              entity_id: project.id
            )
            expect(audit_event.details).to include(
              event_name: 'label_created',
              custom_message: 'Created label New Label'
            )
          end
        end

        context 'for a group label' do
          it 'creates an audit event' do
            expect { service.execute(group: group) }.to change { AuditEventReader.count }.by(1)

            audit_event = AuditEventReader.order(:id).last
            expect(audit_event).to have_attributes(
              author_id: user.id,
              entity_type: 'Group',
              entity_id: group.id
            )
            expect(audit_event.details).to include(
              event_name: 'label_created',
              custom_message: 'Created label New Label'
            )
          end
        end

        context 'when label creation fails' do
          subject(:service) { described_class.new(user, { title: '', color: '' }) }

          it 'does not create an audit event' do
            expect { service.execute(project: project) }.not_to change { AuditEventReader.count }
          end
        end

        context 'for a template label' do
          let_it_be(:organization) { create(:organization) }

          it 'does not create an audit event' do
            expect { service.execute(template: true, organization_id: organization.id) }
              .not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when current_user is nil' do
        subject(:service) { described_class.new(nil, valid_params) }

        it 'does not create an audit event' do
          expect { service.execute(project: project) }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
