# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Webauthn::DestroyService, feature_category: :system_access do
  let_it_be(:user, freeze: false) { create(:user, :two_factor_via_webauthn, registrations_count: 1) }
  let_it_be(:current_user, freeze: false) { user }
  let(:webauthn_registration) { user.second_factor_webauthn_registrations.first }
  let(:webauthn_id) { webauthn_registration.id }
  let(:webauthn_name) { webauthn_registration.name }

  subject(:execute) { described_class.new(current_user, user, webauthn_id).execute }

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
      end

      context 'when disabling a WebAuthn device' do
        context 'when the user has two-factor authentication enabled' do
          it 'creates an audit event', :aggregate_failures do
            expect { execute }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: current_user,
              entity_type: "User",
              entity_id: user.id,
              target_id: user.id,
              target_type: user.class.name,
              target_details: user.name,
              details: hash_including(
                custom_message: 'Deleted WebAuthn device',
                device_name: webauthn_name
              )
            )
          end

          context 'when on SaaS', :saas do
            context 'when user is an Enterprise User', :aggregate_failures do
              let_it_be(:enterprise_group) { create(:group) }
              let_it_be(:current_user, freeze: false) do
                create(:enterprise_user, :with_namespace, :two_factor_via_webauthn, registrations_count: 1,
                  enterprise_group: enterprise_group)
              end

              let(:user) { current_user }
              let(:webauthn_registration) { user.second_factor_webauthn_registrations.first }
              let(:webauthn_id) { webauthn_registration.id }
              let(:webauthn_name) { webauthn_registration.name }

              it 'creates a group audit event' do
                expect { execute }.to change { AuditEventReader.count }.by(1)

                expect(AuditEventReader.last).to have_attributes(
                  author: current_user,
                  entity_type: "Group",
                  entity_id: enterprise_group.id,
                  target_id: user.id,
                  target_type: user.class.name,
                  target_details: user.name,
                  details: hash_including(
                    custom_message: 'Deleted WebAuthn device',
                    device_name: webauthn_name
                  )
                )
              end
            end
          end
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      let_it_be(:user, freeze: false) { create(:user, :two_factor_via_webauthn, registrations_count: 1) }
      let_it_be(:current_user, freeze: false) { user }
      let(:webauthn_id) { webauthn_registration.id }

      it 'does not track audit event' do
        expect { execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
