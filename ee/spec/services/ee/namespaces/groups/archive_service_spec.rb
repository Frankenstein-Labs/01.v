# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Groups::ArchiveService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }

  let(:service) { described_class.new(group, user) }

  describe '#execute' do
    context 'when group archiving fails' do
      it 'does not log an audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when group archiving succeeds' do
      before_all do
        group.add_owner(user)
      end

      it 'logs an audit event' do
        expect { service.execute }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        expect(audit_event).to have_attributes(
          author_id: user.id,
          entity_type: 'Group',
          target_type: "Group",
          author_name: user.name
        )
        expect(audit_event.details).to include(
          event_name: "group_archived",
          author_name: user.name,
          author_class: "User",
          target_type: "Group",
          custom_message: "Group archived"
        )
      end
    end
  end
end
