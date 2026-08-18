# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::Abuse::NamespaceBans::DestroyService, feature_category: :insider_threat do
  let_it_be(:user_with_permissions) { create(:user) }
  let_it_be(:user_without_permissions) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  let!(:namespace_ban) { create(:namespace_ban, namespace: namespace) }
  let(:current_user) { user_with_permissions }
  let(:service) { described_class.new(namespace_ban, current_user) }

  before_all do
    namespace.add_maintainer(user_without_permissions)
    namespace.add_owner(user_with_permissions)
  end

  describe '#execute' do
    shared_examples 'error response' do |message|
      it 'has an informative message' do
        expect(response).to be_error
        expect(response.message).to eq(message)
        expect(response.payload[:namespace_ban]).to eq(namespace_ban)
        expect { namespace_ban.reload }.not_to raise_error
      end
    end

    subject(:response) { service.execute }

    context 'when the current_user is anonymous' do
      let(:current_user) { nil }

      it_behaves_like 'error response', 'You have insufficient permissions to remove this Namespace Ban'
    end

    context 'when current_user does not have permission to remove namespace bans' do
      let(:current_user) { user_without_permissions }

      it_behaves_like 'error response', 'You have insufficient permissions to remove this Namespace Ban'
    end

    context 'when an error occurs during removal' do
      before do
        allow(namespace_ban).to receive(:destroy).and_return(false)
        namespace_ban.errors.add(:base, 'Ban cannot be removed')
      end

      it_behaves_like 'error response', 'Ban cannot be removed'
    end

    context 'when the ban is successfully removed' do
      it 'deletes and returns the namespace_ban' do
        expect(response).to be_success
        expect(response.payload[:namespace_ban]).to eq(namespace_ban)
        expect { namespace_ban.reload }.to raise_error ActiveRecord::RecordNotFound
      end

      context 'with audit events' do
        context 'when licensed' do
          before do
            stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
          end

          it 'creates an audit event', :aggregate_failures do
            expect { response }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: current_user,
              entity_type: 'Group',
              entity_id: namespace.id,
              target_details: namespace_ban.user.username,
              details: include(
                event_name: 'namespace_ban_destroyed',
                custom_message: 'Unbanned user'
              )
            )
          end
        end

        context 'when not licensed' do
          before do
            stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
          end

          it 'does not create an audit event' do
            expect { response }.not_to change { AuditEventReader.count }
          end
        end
      end
    end
  end
end
