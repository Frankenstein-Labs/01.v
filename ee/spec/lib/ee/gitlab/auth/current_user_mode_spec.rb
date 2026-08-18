# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::CurrentUserMode, :request_store, feature_category: :system_access do
  let_it_be(:user) { create(:user, :admin) }

  subject { described_class.new(user) }

  context 'when session is available' do
    include_context 'custom session'

    before do
      allow(ActiveSession).to receive(:list_sessions).with(user).and_return([session])
    end

    context 'when the user is a regular user with admin custom permission' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let_it_be(:user) { create(:user) }
      let_it_be(:admin_role) { create(:member_role, :admin) }
      let_it_be(:user_member_role) { create(:user_member_role, member_role: admin_role, user: user) }

      describe '#admin_mode?' do
        it_behaves_like 'admin_mode? check if admin_mode can be enabled'
      end

      describe '#enable_admin_mode!' do
        it_behaves_like 'enabling admin_mode when it can be enabled'
      end

      describe '#disable_admin_mode!' do
        it_behaves_like 'disabling admin_mode'
      end
    end

    describe '#enable_admin_mode!' do
      before do
        stub_licensed_features(extended_audit_events: true)
      end

      context 'when enabling admin mode succeeds' do
        it 'creates an audit event', :aggregate_failures do
          subject.request_admin_mode!

          expect do
            subject.enable_admin_mode!(password: user.password)
          end.to change { AuditEventReader.count }.by(1)

          expect(AuditEventReader.last).to have_attributes(
            author: user,
            entity: user,
            target_id: user.id,
            target_type: user.class.name,
            target_details: user.name,
            details: include(custom_message: 'Enabled Admin Mode')
          )
        end
      end

      context 'when enabling admin mode fails' do
        it 'does not create an audit event' do
          subject.request_admin_mode!

          expect do
            subject.enable_admin_mode!(password: 'wrong password')
          end.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
