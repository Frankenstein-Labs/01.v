# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::TwoFactorAuthsController, feature_category: :system_access do
  before do
    sign_in(user)

    allow(subject).to receive(:current_user).and_return(user) # rubocop:disable RSpec/NamedSubject -- .
  end

  describe 'POST create - OTP' do
    let_it_be_with_reload(:user) { create(:user) }

    let(:pin) { 'pin-code' }
    let(:current_password) { user.password }

    def go
      post :create, params: { pin_code: pin, current_password: current_password }
    end

    describe 'audit events' do
      context 'when licensed' do
        before do
          stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
        end

        context 'with invalid pin' do
          before do
            allow(user).to receive(:validate_and_consume_otp!).with(pin).and_return(false)
          end

          it 'does not track audit event' do
            expect { go }.not_to change { AuditEventReader.count }
          end
        end

        context 'with valid pin' do
          before do
            allow(user).to receive(:validate_and_consume_otp!).with(pin).and_return(true)
          end

          it 'creates an audit event', :aggregate_failures do
            expect { go }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: user,
              entity_type: "User",
              entity_id: user.id,
              target_id: user.id,
              target_type: user.class.name,
              target_details: user.name,
              details: include(custom_message: 'Registered One-time password authenticator')
            )
          end

          context 'when on SaaS', :saas do
            context 'when user is an Enterprise User', :aggregate_failures do
              let_it_be(:enterprise_group) { create(:group) }
              let_it_be(:user, freeze: false) do
                create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
              end

              it 'creates a group audit event' do
                expect { go }.to change { AuditEventReader.count }.by(1)

                expect(AuditEventReader.last).to have_attributes(
                  author: user,
                  entity_type: "Group",
                  entity_id: enterprise_group.id,
                  target_id: user.id,
                  target_type: user.class.name,
                  target_details: user.name,
                  details: include(custom_message: 'Registered One-time password authenticator')
                )
              end
            end
          end
        end

        context 'when unlicensed' do
          before do
            stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
          end

          context 'with valid pin' do
            before do
              allow(user).to receive(:validate_and_consume_otp!).with(pin).and_return(true)
            end

            it 'does not track audit event' do
              expect { go }.not_to change { AuditEventReader.count }
            end
          end
        end
      end
    end
  end

  describe 'POST create - WebAuthn' do
    let_it_be_with_reload(:user) { create(:user) }
    let(:client) { WebAuthn::FakeClient.new('http://localhost', encoding: :base64) }
    let(:credential) { create_credential(client: client, rp_id: request.host) }

    let(:params) { { device_registration: { name: 'touch id', device_response: device_response } } }

    let(:params_with_password) do
      { device_registration: { name: 'touch id', device_response: device_response }, current_password: user.password }
    end

    before do
      session[:challenge] = challenge
    end

    def go
      post :create_webauthn, params: params_with_password
    end

    def challenge
      @_challenge ||= begin
        options_for_create = WebAuthn::Credential.options_for_create(
          user: { id: user.webauthn_xid, name: user.username },
          authenticator_selection: { user_verification: 'discouraged' },
          rp: { name: 'GitLab' }
        )
        options_for_create.challenge
      end
    end

    def device_response
      client.create(challenge: challenge).to_json # rubocop:disable Rails/SaveBang -- .
    end

    describe 'audit events' do
      context 'when licensed' do
        before do
          stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
        end

        context 'when an invalid password is given' do
          it 'does not track audit event' do
            expect { post :create_webauthn, params: params }.not_to change { AuditEventReader.count }
          end
        end

        context "when valid password is given" do
          it 'creates an audit event', :aggregate_failures do
            expect { go }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: user,
              entity_type: "User",
              entity_id: user.id,
              target_id: user.id,
              target_type: user.class.name,
              target_details: user.name,
              details: hash_including(
                custom_message: 'Registered WebAuthn device',
                device_name: 'touch id'
              )
            )
          end

          context 'when on SaaS', :saas do
            context 'when user is an Enterprise User', :aggregate_failures do
              let_it_be(:enterprise_group) { create(:group) }
              let_it_be(:user, freeze: false) do
                create(:enterprise_user, :with_namespace, enterprise_group: enterprise_group)
              end

              it 'creates a group audit event' do
                expect { go }.to change { AuditEventReader.count }.by(1)

                expect(AuditEventReader.last).to have_attributes(
                  author: user,
                  entity_type: "Group",
                  entity_id: enterprise_group.id,
                  target_id: user.id,
                  target_type: user.class.name,
                  target_details: user.name,
                  details: hash_including(
                    custom_message: 'Registered WebAuthn device',
                    device_name: 'touch id'
                  )
                )
              end
            end
          end
        end
      end

      context 'when unlicensed' do
        before do
          stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
        end

        it 'does not track audit event' do
          expect { go }.not_to change { AuditEventReader.count }
        end
      end
    end
  end
end
