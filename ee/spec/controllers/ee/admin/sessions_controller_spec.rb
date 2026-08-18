# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::SessionsController, :do_not_mock_admin_mode,
  feature_category: :system_access do
  include_context 'custom session'

  describe '#new' do
    let_it_be(:user) { create(:user) }
    let_it_be(:admin_role) { create(:member_role, :admin) }
    let_it_be(:user_member_role) { create(:user_member_role, member_role: admin_role, user: user) }

    context 'for regular users with admin custom role' do
      before do
        stub_licensed_features(custom_roles: true)

        sign_in(user)
      end

      it 'renders a password form' do
        get :new

        expect(response).to render_template :new
      end

      context 'when already in admin mode' do
        before do
          controller.current_user_mode.request_admin_mode!
          controller.current_user_mode.enable_admin_mode!(password: user.password)
        end

        it 'redirects to original location' do
          get :new

          expect(response).to redirect_to(admin_root_path)
        end
      end
    end
  end

  describe '#create' do
    context 'when using two-factor authentication' do
      def authenticate_2fa(otp_user_id: user.id, **user_params)
        post(:create, params: { user: user_params }, session: { otp_user_id: otp_user_id })
      end

      before do
        sign_in(user)
        controller.current_user_mode.request_admin_mode!
      end

      context 'when OTP authentication fails' do
        it_behaves_like 'an auditable failed authentication' do
          let(:user) { create(:admin, :two_factor) }
          let(:operation) { authenticate_2fa(otp_attempt: 'invalid', otp_user_id: user.id) }
          let(:method) { 'OTP' }
        end
      end

      context 'when WebAuthn authentication fails' do
        before do
          allow_next_instance_of(Webauthn::AuthenticateService) do |instance|
            allow(instance).to receive(:execute).and_return(
              ServiceResponse.error(message: _('Authentication via WebAuthn device failed.'))
            )
          end
        end

        it_behaves_like 'an auditable failed authentication' do
          let(:user) { create(:admin, :two_factor_via_webauthn) }
          let(:operation) { authenticate_2fa(device_response: 'invalid', otp_user_id: user.id) }
          let(:method) { 'WebAuthn' }
        end
      end
    end
  end
end
