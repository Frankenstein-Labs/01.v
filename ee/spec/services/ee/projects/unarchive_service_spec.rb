# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UnarchiveService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :archived) }

  let(:service) { described_class.new(project: project, current_user: user) }

  describe '#execute' do
    context 'when project unarchiving fails' do
      it 'does not log an audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when project unarchiving succeeds' do
      before_all do
        project.add_owner(user)
      end

      it 'logs an audit event' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        expect(audit_event).to have_attributes(
          author_id: user.id,
          entity_type: 'Project',
          target_type: "Project",
          author_name: user.name
        )
        expect(audit_event.details).to include(
          event_name: "project_unarchived",
          author_name: user.name,
          author_class: "User",
          target_type: "Project",
          custom_message: "Project unarchived"
        )
      end
    end
  end
end
