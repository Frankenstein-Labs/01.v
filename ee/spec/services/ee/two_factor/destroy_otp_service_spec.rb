# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TwoFactor::DestroyOtpService, feature_category: :system_access do
  let_it_be_with_reload(:current_user) { create(:user) }

  subject(:execute) { described_class.new(current_user, user: user).execute }

  describe 'audit events' do
    context 'when licensed' do
      before do
        stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
      end

      context 'when disabling the OTP authenticator' do
        context 'when the user has an OTP authenticator enabled' do
          let_it_be_with_reload(:current_user) { create(:user, :two_factor_via_otp) }
          let_it_be(:user) { current_user }

          it 'creates an audit event', :aggregate_failures do
            expect { execute }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: current_user,
              entity_type: "User",
              entity_id: user.id,
              target_id: user.id,
              target_type: user.class.name,
              target_details: user.name,
              details: include(custom_message: 'Disabled One-time password authenticator')
            )
          end

          context 'when on SaaS', :saas do
            context 'when user is an Enterprise User', :aggregate_failures do
              let_it_be(:enterprise_group) { create(:group) }
              let_it_be_with_reload(:current_user) do
                create(:enterprise_user, :two_factor_via_otp, :with_namespace, enterprise_group: enterprise_group)
              end

              let_it_be(:user) { current_user }

              it 'creates a group audit event' do
                expect { execute }.to change { AuditEventReader.count }.by(1)

                expect(AuditEventReader.last).to have_attributes(
                  author: current_user,
                  entity_type: "Group",
                  entity_id: enterprise_group.id,
                  target_id: user.id,
                  target_type: user.class.name,
                  target_details: user.name,
                  details: include(custom_message: 'Disabled One-time password authenticator')
                )
              end
            end
          end
        end

        context 'when the user does not have an OTP authenticator enabled' do
          let(:user) { current_user }

          it 'does not track audit event' do
            expect { execute }.not_to change { AuditEventReader.count }
          end
        end
      end
    end

    context 'when unlicensed' do
      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      let(:user) { create(:user, :two_factor_via_otp) }

      it 'does not track audit event' do
        expect { execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
