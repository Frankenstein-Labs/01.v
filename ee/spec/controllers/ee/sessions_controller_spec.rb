# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SessionsController, :geo, feature_category: :system_access do
  include DeviseHelpers
  include EE::GeoHelpers

  before do
    set_devise_mapping(context: @request)
  end

  describe '#new' do
    context 'on a Geo secondary node' do
      let_it_be(:primary_node) { create(:geo_node, :primary) }
      let_it_be(:secondary_node) { create(:geo_node) }

      before do
        stub_current_geo_node(secondary_node)
      end

      shared_examples 'a valid oauth authentication redirect' do
        it 'redirects to the correct oauth_geo_auth_url' do
          get(:new)

          redirect_uri = URI.parse(response.location)
          redirect_params = CGI.parse(redirect_uri.query)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to %r{\A#{Gitlab.config.gitlab.url}/oauth/geo/auth}
          expect(redirect_params['state'].first).to end_with(':')
        end
      end

      context 'when relative URL is configured' do
        before do
          host = 'http://this.is.my.host/secondary-relative-url-part'

          stub_config_setting(url: host, https: false)
          stub_default_url_options(host: "this.is.my.host", script_name: '/secondary-relative-url-part')
          request.headers['HOST'] = host
        end

        it_behaves_like 'a valid oauth authentication redirect'
      end

      context 'with a tampered HOST header' do
        before do
          request.headers['HOST'] = 'http://this.is.not.my.host'
        end

        it_behaves_like 'a valid oauth authentication redirect'
      end

      context 'with a tampered X-Forwarded-Host header' do
        before do
          request.headers['X-Forwarded-Host'] = 'http://this.is.not.my.host'
        end

        it_behaves_like 'a valid oauth authentication redirect'
      end

      context 'without a tampered header' do
        it_behaves_like 'a valid oauth authentication redirect'
      end
    end

    context 'when login fails' do
      before do
        @request.env["warden.options"] = { action: 'unauthenticated' }
      end

      context 'for a non existent user' do
        it 'creates a failed authentication audit event' do
          audit_context = {
            name: "login_failed_with_standard_authentication",
            message: "Failed to login with STANDARD authentication",
            target: be_an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
            author: be_an_instance_of(Gitlab::Audit::UnauthenticatedAuthor),
            additional_details: {
              failed_login: 'STANDARD'
            }
          }

          expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with('foo@bar.com').and_call_original
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

          get(:new, params: { user: { login: 'foo@bar.com' } })
        end
      end

      context 'for an existing user' do
        let(:user) { create(:user) }

        it 'creates a failed authentication audit event associated with the user' do
          audit_context = {
            name: "login_failed_with_standard_authentication",
            message: "Failed to login with STANDARD authentication",
            target: user,
            scope: user,
            author: user,
            additional_details: {
              failed_login: 'STANDARD'
            }
          }

          expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with(user).and_call_original
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).and_call_original

          get(:new, params: { user: { login: user.username } })
        end
      end

      it 'creates audit event with unknown login when login param is nil' do
        expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with('unknown').and_call_original

        get(:new, params: { user: { login: nil } })
      end

      it 'creates audit event with unknown login when login param is empty' do
        expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with('unknown').and_call_original

        get(:new, params: { user: { login: '' } })
      end

      it 'creates audit event with login when user exists' do
        expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with('test@example.com').and_call_original

        get(:new, params: { user: { login: 'test@example.com' } })
      end

      context 'when 2FA login fails' do
        let(:user) { create(:user, :two_factor) }

        before do
          # We create an initial request to authenticate the user, creating a session, to test the 2FA failure
          post(:create, params: { user: { otp_attempt: 'invalid' } }, session: { otp_user_id: user.id })
        end

        it 'creates failed authentication audit event for invalid OTP' do
          expect(::Authn::UnauthenticatedSecurityEventAuditor).to receive(:new).with(user).and_call_original

          get(:new, params: { user: { otp_attempt: 'invalid' } })
        end
      end
    end
  end

  describe '#create', :saas do
    context 'with wrong credentials' do
      context 'when is a regular form' do
        it 'redirects to the regular sign in page' do
          post :create, params: { user: { login: 'foo@bar.com', password: '11111' } }

          expect(response).to render_template("devise/sessions/new")
        end
      end
    end

    context 'when Exposed-Credential-Check header is present for successful login' do
      let(:user) { create(:user) }
      let(:operation) { post(:create, params: { user: { login: user.username, password: user.password } }) }

      before do
        request.headers['Exposed-Credential-Check'] = '1'
      end

      it 'calls Users::CompromisedPasswords::DetectAndNotifyService' do
        expect(::Users::CompromisedPasswords::DetectAndNotifyService).to receive(:new)
          .with(user, user.password, anything)
          .and_call_original

        operation
      end
    end

    context 'when using two-factor authentication' do
      def authenticate_2fa(otp_user_id: user.id, **user_params)
        post(:create, params: { user: user_params }, session: { otp_user_id: otp_user_id })
      end

      context 'when OTP authentication fails' do
        it_behaves_like 'an auditable failed authentication' do
          let_it_be(:user) { create(:user, :two_factor) }
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
          let_it_be(:user) { create(:user, :two_factor_via_webauthn) }
          let(:operation) { authenticate_2fa(device_response: 'invalid', otp_user_id: user.id) }
          let(:method) { 'WebAuthn' }
        end
      end
    end

    context 'when password authentication disabled by enterprise group' do
      let_it_be(:enterprise_group) { create(:group) }
      let_it_be(:saml_provider) do
        create(
          :saml_provider,
          group: enterprise_group,
          enabled: true,
          disable_password_authentication_for_enterprise_users: true
        )
      end

      let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      it 'does not authenticate the user' do
        post(:create, params: { user: { login: user.username, password: user.password } })

        expect(response).to have_gitlab_http_status(:ok)
        expect(@request.env['warden']).not_to be_authenticated
        expect(flash[:alert]).to include(I18n.t('devise.failure.invalid'))
      end
    end
  end
end
