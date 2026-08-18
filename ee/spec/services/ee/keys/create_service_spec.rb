# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Keys::CreateService, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }

  let(:params) { attributes_for(:key).merge(user: user) }

  subject(:service) { described_class.new(user, params) }

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
      end

      context 'when user adds an SSH key' do
        it 'creates a user audit event' do
          expect { service.execute }.to change { AuditEventReader.count }.by(1)

          expect(AuditEventReader.last).to have_attributes(
            author: user,
            entity_type: "User",
            entity_id: user.id,
            details: include(custom_message: 'Added SSH key')
          )
        end

        context 'when on SaaS', :saas do
          context 'when user is an Enterprise User' do
            let_it_be(:enterprise_group) { create(:group) }
            let_it_be(:user) do
              create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
            end

            it 'creates a group audit event' do
              expect { service.execute }.to change { AuditEventReader.count }.by(1)

              expect(AuditEventReader.last).to have_attributes(
                author: user,
                entity_type: "Group",
                entity_id: enterprise_group.id,
                details: include(custom_message: 'Added SSH key')
              )
            end
          end
        end
      end

      context 'when an admin adds an SSH key to a user' do
        let_it_be(:admin) { create(:admin) }

        subject(:service) { described_class.new(admin, params) }

        it 'creates a user audit event' do
          expect { service.execute }.to change { AuditEventReader.count }.by(1)

          expect(AuditEventReader.last).to have_attributes(
            author: admin,
            entity_type: "User",
            entity_id: user.id,
            details: include(custom_message: 'Added SSH key')
          )
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      it 'does not track audit event' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
