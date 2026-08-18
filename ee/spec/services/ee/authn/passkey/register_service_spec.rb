# frozen_string_literal: true

require 'spec_helper'
require 'webauthn/fake_client'

RSpec.describe Authn::Passkey::RegisterService, feature_category: :system_access do
  let_it_be(:user) { create(:user) }

  # WebAuthn Request Options (from GitLab and stored in session store)
  let(:challenge) { Base64.strict_encode64(SecureRandom.random_bytes(32)) }
  let(:origin) { 'http://localhost' }

  # Setup authenticator (from user & browser)
  let(:client) { WebAuthn::FakeClient.new(origin) }

  # Response
  let(:webauthn_creation_result) do
    client.create( # rubocop:disable Rails/SaveBang -- .create is a WebAuthn::FakeClient method
      challenge: challenge,
      user_verified: true,
      extensions: { "credProps" => { "rk" => true } }
    )
  end

  let(:device_response) { webauthn_creation_result.to_json }
  let(:device_name) { 'My WebAuthn Authenticator (Passkey)' }
  let(:params) { { device_response: device_response, name: device_name } }

  describe '#execute' do
    subject(:execute) { described_class.new(user, params, challenge).execute }

    describe 'audit events' do
      context 'when licensed' do
        before do
          stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
        end

        context 'on success' do
          it 'creates an audit event', :aggregate_failures do
            expect do
              expect(execute).to be_success
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: user,
              entity_type: user.class.name,
              entity_id: user.id,
              target_type: user.class.name,
              target_id: user.id,
              target_details: user.name,
              details: hash_including(
                event_name: 'user_enable_passkey',
                custom_message: 'Registered Passkey',
                device_name: device_name
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
                  author: user,
                  entity_type: enterprise_group.class.name,
                  entity_id: enterprise_group.id,
                  target_type: user.class.name,
                  target_id: user.id,
                  target_details: user.name,
                  details: hash_including(
                    event_name: 'user_enable_passkey',
                    custom_message: 'Registered Passkey',
                    device_name: device_name
                  )
                )
              end
            end
          end
        end

        context 'on failure' do
          let(:device_response) { 'bad response' }

          it 'does not create an audit event' do
            expect do
              expect(execute).to be_error
            end.not_to change { AuditEventReader.count }
          end
        end
      end

      context 'when unlicensed' do
        context 'on success' do
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
