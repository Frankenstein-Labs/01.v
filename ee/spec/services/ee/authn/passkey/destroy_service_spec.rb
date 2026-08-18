# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::Passkey::DestroyService, feature_category: :system_access do
  let_it_be(:user) { create(:user, :with_passkey) }

  describe '#execute' do
    let(:passkey) { user.passkeys.first }
    let(:passkey_id) { passkey.id }

    subject(:execute) { described_class.new(current_user, user, passkey_id).execute }

    describe 'audit events' do
      context 'when licensed' do
        before do
          stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
        end

        context 'on success', :enable_admin_mode do
          let_it_be(:current_user) { create(:admin) }

          it 'creates an audit event', :aggregate_failures do
            expect do
              expect(execute).to be_success
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: current_user,
              entity_type: user.class.name,
              entity_id: user.id,
              target_type: user.class.name,
              target_id: user.id,
              target_details: user.name,
              details: hash_including(
                event_name: 'user_disable_passkey',
                custom_message: 'Deleted Passkey',
                device_name: passkey.name
              )
            )
          end

          context 'when on SaaS', :saas do
            context 'when user is an enterprise user' do
              let_it_be(:enterprise_group) { create(:group) }
              let_it_be(:user) do
                create(:enterprise_user, :with_passkey, enterprise_group: enterprise_group)
              end

              it 'creates a group audit event', :aggregate_failures do
                expect do
                  expect(execute).to be_success
                end.to change { AuditEventReader.count }.by(1)

                expect(AuditEventReader.last).to have_attributes(
                  author: current_user,
                  entity_type: enterprise_group.class.name,
                  entity_id: enterprise_group.id,
                  target_type: user.class.name,
                  target_id: user.id,
                  target_details: user.name,
                  details: hash_including(
                    event_name: 'user_disable_passkey',
                    custom_message: 'Deleted Passkey',
                    device_name: passkey.name
                  )
                )
              end
            end
          end
        end

        context 'on failure' do
          let_it_be(:current_user) { create(:user) }

          it 'does not create an audit event' do
            expect do
              expect(execute).to be_error
            end.not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when unlicensed' do
        context 'on success', :enable_admin_mode do
          let_it_be(:current_user) { create(:admin) }

          it 'does not create an audit event' do
            expect do
              expect(execute).to be_success
            end.not_to change { AuditEventReader.count }
          end
        end
      end
    end
  end
end
