# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniauthCallbacksController, feature_category: :system_access do
  include LoginHelpers

  let_it_be(:extern_uid) { 'my-uid' }
  let_it_be(:provider) { :ldap }
  let_it_be_with_reload(:user) { create(:omniauth_user, extern_uid: extern_uid, provider: provider) }

  before do
    mock_auth_hash(provider.to_s, extern_uid, user.email)
    stub_omniauth_provider(provider, context: request)
  end

  context 'when sign in fails' do
    subject(:callbacks_controller) { controller }

    before do
      callbacks_controller.set_response!(ActionDispatch::Response.new)

      allow(callbacks_controller).to receive(:params)
        .and_return(ActionController::Parameters.new(username: user.username))

      stub_omniauth_failure(
        OmniAuth::Strategies::LDAP.new(nil),
        'invalid_credentials',
        OmniAuth::Strategies::LDAP::InvalidCredentialsError.new('Invalid credentials for ldap')
      )
    end

    it 'audits provider failed login when licensed', :aggregate_failures do
      stub_licensed_features(extended_audit_events: true)

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
        name: "omniauth_login_failed"
      })).and_call_original

      expect { callbacks_controller.failure }.to change { AuditEventReader.count }.by(1)

      expect(AuditEventReader.last).to have_attributes(
        entity_type: "User",
        attributes: hash_including({
          "author_name" => user.username,
          "target_details" => user.username
        }),
        details: hash_including({
          failed_login: "LDAP",
          author_name: user.username,
          target_details: user.username,
          custom_message: "LDAP login failed"
        })
      )
    end

    it 'does not audit provider failed login when unlicensed' do
      stub_licensed_features(extended_audit_events: false)
      expect { callbacks_controller.failure }.not_to change { AuditEventReader.count }
    end
  end

  describe '#openid_connect' do
    let(:user) { create(:omniauth_user, extern_uid: extern_uid, provider: provider) }
    let(:provider) { :openid_connect }

    before do
      prepare_provider_route(provider)

      allow(Gitlab::Auth::OAuth::Provider).to(
        receive_messages({ providers: [provider],
                           config_for: connect_config })
      )
      stub_omniauth_setting(
        { enabled: true,
          allow_single_sign_on: [provider],
          providers: [connect_config] }
      )

      request.env['devise.mapping'] = Devise.mappings[:user]
      request.env['omniauth.auth'] = Rails.application.env_config['omniauth.auth']
    end

    context 'when auth hash is missing required groups' do
      let(:connect_config) do
        ActiveSupport::InheritableOptions.new(
          HashWithIndifferentAccess.new({
            name: provider,
            args: {
              name: provider,
              client_options: {
                identifier: 'gitlab-test-client',
                gitlab: {
                  required_groups: ['Owls']
                }
              }
            }
          })
        )
      end

      before do
        mock_auth_hash(provider.to_s, extern_uid, user.email, additional_info: {})
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(oidc_client_groups_claim: true)
        end

        it 'prevents sign in' do
          post provider

          expect(request.env['warden']).not_to be_authenticated
        end
      end

      context 'when licensed feature is not available' do
        it 'allows sign in' do
          post provider

          expect(request.env['warden']).to be_authenticated
        end
      end
    end

    context 'when required_groups membership is configured' do
      let(:connect_config) do
        ActiveSupport::InheritableOptions.new(
          HashWithIndifferentAccess.new({
            name: provider,
            args: {
              name: provider,
              client_options: {
                identifier: 'gitlab-test-client',
                gitlab: {
                  required_groups: ['Owls']
                }
              }
            }
          })
        )
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(oidc_client_groups_claim: true)
        end

        context 'when the IDP auth hash has required_groups' do
          before do
            mock_auth_hash(
              provider.to_s,
              extern_uid,
              user.email,
              additional_info: {
                groups: ['Owls'],
                extra: {
                  raw_info: {
                    groups: ['Owls']
                  }
                }
              }
            )
            stub_omniauth_provider(provider, context: request)
          end

          it 'allows sign in', :aggregate_failures do
            post provider

            expect(request.env['omniauth.auth'].groups).to include('Owls')
            expect(request.env['warden']).to be_authenticated
          end
        end

        context 'when the IDP auth hash has the wrong required_groups' do
          before do
            mock_auth_hash(
              provider.to_s,
              extern_uid,
              user.email,
              additional_info: {
                groups: ['Bears'],
                extra: {
                  raw_info: {
                    groups: ['Bears']
                  }
                }
              }
            )
            stub_omniauth_provider(provider, context: request)
          end

          it 'prevents sign in', :aggregate_failures do
            post provider

            expect(request.env['omniauth.auth'].groups).not_to include('Owls')
            expect(request.env['warden']).not_to be_authenticated
          end
        end
      end
    end

    context 'when linking to existing profile' do
      let(:user) { create(:user) }
      let(:connect_config) do
        ActiveSupport::InheritableOptions.new(
          HashWithIndifferentAccess.new({
            name: provider,
            args: {
              name: provider,
              client_options: {
                identifier: 'gitlab-test-client'
              }
            }
          })
        )
      end

      before do
        sign_in user
        stub_licensed_features(oidc_client_groups_claim: true)
      end

      it 'links identity' do
        expect { post provider }.to change { user.identities.count }.by(1)
      end
    end
  end

  describe '#saml' do
    let(:provider) { 'saml_okta' }
    let(:mock_saml_response) { File.read('spec/fixtures/authentication/saml_response.xml') }

    controller(described_class) do
      alias_method :saml_okta, :handle_omniauth
    end

    context "with required_groups on saml config" do
      before do
        allow(routes).to receive(:generate_extras).and_return(['/users/auth/saml_okta/callback', []])

        saml_config = Gitlab::Configs.build_options(name: 'saml_okta',
          required_groups: ['Freelancers'],
          groups_attribute: 'groups',
          label: 'saml_okta',
          args: {
            'strategy_class' => 'OmniAuth::Strategies::SAML'
          })
        stub_omniauth_saml_config(
          enabled: true,
          auto_link_saml_user: true,
          providers: [saml_config]
        )
      end

      it 'fails to authenticate' do
        post :saml_okta, params: { SAMLResponse: mock_saml_response }
        expect(request.env['warden']).not_to be_authenticated
      end
    end

    context 'with session_not_on_or_after attribute in response' do
      let(:provider) { 'saml' }
      let(:last_request_id) { 'ONELOGIN_4fee3b046395c4e751011e97f8900b5273d56685' }
      let(:user) { create(:omniauth_user, :two_factor, extern_uid: 'my-uid', provider: 'saml') }
      let(:saml_config) { mock_saml_config_with_upstream_two_factor_authn_contexts }

      def stub_last_request_id(id)
        session['last_authn_request_id'] = id
      end

      before do
        allow(routes).to receive(:generate_extras).and_return(['/users/auth/saml/callback', []])

        stub_last_request_id(last_request_id)
        stub_omniauth_saml_config(
          enabled: true,
          auto_link_saml_user: true,
          allow_single_sign_on: ['saml'],
          providers: [saml_config]
        )
        mock_auth_hash_with_saml_xml('saml', +'my-uid', user.email, mock_saml_response)
        request.env['devise.mapping'] = Devise.mappings[:user]
        request.env['omniauth.auth'] = Rails.application.env_config['omniauth.auth']
      end

      it 'sets the SSO session expiration time in session store' do
        sso_state = instance_double(::Gitlab::Auth::Saml::SsoState)
        allow(::Gitlab::Auth::Saml::SsoState).to receive(:new).and_return(sso_state)

        expect(sso_state).to receive(:update_active)
          .with(session_not_on_or_after: Time.parse('2024-07-17T09:01:48Z'))
        post :saml, params: { SAMLResponse: mock_saml_response }
      end
    end
  end

  describe 'identity verification', feature_category: :insider_threat do
    subject(:oauth_request) { post :saml }

    let_it_be(:provider) { 'google_oauth2' }

    before do
      mock_auth_hash(provider, extern_uid, user_email)
      stub_omniauth_saml_config(external_providers: [provider], block_auto_created_users: false)
      stub_omniauth_provider(provider, context: request)
    end

    shared_examples 'identity verification required' do
      it 'handles sticking, sets the session and redirects to identity verification', :aggregate_failures do
        expect_any_instance_of(::Users::EmailVerification::SendCustomConfirmationInstructionsService) do |instance|
          expect(instance).to receive(:execute)
        end

        expect(User.sticking)
          .to receive(:find_caught_up_replica)
          .with(:user, anything, hash_id: false)

        oauth_request

        expect(request.session[:verification_user_id]).not_to be_nil
        expect(response).to redirect_to(signup_identity_verification_path)

        stick_object = request.env[::Gitlab::Database::LoadBalancing::RackMiddleware::STICK_OBJECT].first
        expect(stick_object[0]).to eq(User.sticking)
        expect(stick_object[1]).to eq(:user)
        expect(stick_object[2]).to eq(request.session[:verification_user_id])
      end
    end

    shared_examples 'identity verification not required' do
      it 'does not redirect to identity verification' do
        allow_any_instance_of(::Users::EmailVerification::SendCustomConfirmationInstructionsService) do |instance|
          expect(instance).not_to receive(:execute)
        end

        expect(User.sticking).not_to receive(:find_caught_up_replica)

        oauth_request

        expect(request.session[:verification_user_id]).to be_nil
        expect(response).not_to redirect_to(signup_identity_verification_path)
      end
    end

    context 'on sign up' do
      before do
        allow_next_instance_of(User) do |user|
          allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        end
      end

      let_it_be(:user_email) { 'test@example.com' }

      it_behaves_like 'identity verification required'

      context 'when auto blocking users after creation' do
        before do
          stub_omniauth_setting(block_auto_created_users: true)
        end

        it_behaves_like 'identity verification not required'
      end
    end

    context 'on sign in' do
      before do
        allow_next_found_instance_of(User) do |user|
          allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        end
      end

      let_it_be_with_reload(:user) { create(:omniauth_user, extern_uid: extern_uid, provider: provider) }
      let_it_be(:user_email) { user.email }

      it_behaves_like 'identity verification not required'

      context 'when identity is not yet verified' do
        before do
          user.update!(confirmed_at: nil)
        end

        it_behaves_like 'identity verification required'
      end
    end
  end

  describe 'restricted country login prevention' do
    let(:provider) { :github }
    let(:error_message) { "It looks like you are visiting GitLab from Mainland China, Macau, or Hong Kong" }

    before do
      stub_omniauth_provider(provider, context: request)
      stub_omniauth_setting(
        {
          enabled: true,
          allow_single_sign_on: [provider.to_s],
          auto_link_user: true,
          block_auto_created_users: false
        }
      )
    end

    shared_examples "restricted country message" do
      it 'prevents login and redirects to signin page with error' do
        post provider

        expect(request.env['warden']).not_to be_authenticated
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include(error_message)
      end

      it 'does not create a new user account' do
        expect { post provider }.not_to change { User.count }
      end
    end

    context 'when new user attempts signing-up from restricted country', :saas do
      before do
        user.destroy!

        request.env['HTTP_CF_IPCOUNTRY'] = 'CN'
      end

      it_behaves_like 'restricted country message'

      context 'when user is invited to a paid/trial group', :saas do
        let(:user) { create(:user) }

        before do
          mock_auth_hash(provider.to_s, extern_uid, user.email)
        end

        context 'with paid group invitation' do
          let(:paid_group) do
            group = create(:group)
            create(:gitlab_subscription, :ultimate, namespace: group) # if using subscriptions
            group
          end

          let(:member) { create(:group_member, :invited, group: paid_group, invite_email: user.email) }

          before do
            session[:originating_member_id] = member.id
          end

          it 'allows signup for invited users in paid groups' do
            post provider

            expect(request.env['warden']).to be_authenticated
            expect(User.find_by_email(user.email)).to be_present
          end
        end

        context 'with trial group invitation' do
          let(:ultimate_group_trial) do
            create(:group_with_plan, :public, plan: :ultimate_plan, trial_ends_on: Time.current + 30.days)
          end

          let(:member) { create(:group_member, :invited, group: ultimate_group_trial, invite_email: user.email) }

          before do
            session[:originating_member_id] = member.id
          end

          it 'allows signup for invited users in trial groups' do
            post provider

            expect(request.env['warden']).to be_authenticated
            expect(User.find_by_email(user.email)).to be_present
          end
        end

        context 'with free group invitation' do
          let!(:free_group) { create(:group) }
          let!(:member) { create(:group_member, :invited, group: free_group, invite_email: user.email) }

          before do
            session[:originating_member_id] = member.id
          end

          it_behaves_like 'restricted country message'
        end

        context 'with no invitation' do
          it_behaves_like 'restricted country message'
        end
      end
    end

    context 'when existing user attempts login from restricted country' do
      before do
        request.env['HTTP_CF_IPCOUNTRY'] = 'CN'
      end

      it 'allows existing user login' do
        post provider

        expect(request.env['warden']).to be_authenticated
      end
    end

    context 'when user attempts login from allowed country' do
      let(:user_email) { user.email }

      before do
        user.destroy!

        request.env['HTTP_CF_IPCOUNTRY'] = 'US'
        mock_auth_hash(provider.to_s, extern_uid, user_email)
      end

      it 'allows new user signup and login' do
        post provider

        expect(request.env['warden']).to be_authenticated

        created_user = User.find_by_email(user_email)
        expect(created_user).to be_present
        expect(created_user.identities.first.extern_uid).to eq(extern_uid)
      end
    end

    context 'when existing user attempts login from allowed country' do
      before do
        request.env['HTTP_CF_IPCOUNTRY'] = 'US'
        mock_auth_hash(provider.to_s, extern_uid, user.email)
      end

      it 'allows existing user login' do
        expect { post provider }.not_to change { User.count }
        expect(request.env['warden']).to be_authenticated
        expect(request.env['warden'].user).to eq(user)
      end
    end

    context 'when country header is missing' do
      before do
        request.env.delete('HTTP_CF_IPCOUNTRY')
        mock_auth_hash(provider.to_s, extern_uid, user.email)
      end

      it 'allows login (treats as non-restricted)' do
        post provider

        expect(request.env['warden']).to be_authenticated
      end
    end

    context 'with different OAuth providers', :saas do
      let(:providers_to_test) { [:github, :google_oauth2] }

      before do
        request.env['HTTP_CF_IPCOUNTRY'] = 'CN'
      end

      it 'blocks login for all OAuth providers from restricted countries' do
        providers_to_test.each do |test_provider|
          mock_auth_hash(test_provider.to_s, "uid-#{test_provider}", "user-#{test_provider}@example.com")
          stub_omniauth_provider(test_provider, context: request)

          post test_provider

          expect(request.env['warden']).not_to be_authenticated
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end
  end

  context 'with strategies', :aggregate_failures do
    let(:provider) { :github }
    let(:check_namespace_plan) { true }

    before do
      stub_application_setting(check_namespace_plan: check_namespace_plan)
      stub_omniauth_setting(block_auto_created_users: false)
    end

    context 'when user is not registered yet' do
      let_it_be(:new_user_email) { 'new@example.com' }
      let(:user) { build_stubbed(:user, email: new_user_email) }
      let(:extra_params) { { bogus: 'bogus', onboarding_status_email_opt_in: 'true' } }
      let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
      let(:registration_params) { extra_params.merge(glm_params) }

      subject(:post_create) { post provider }

      before do
        request.env['omniauth.params'] = registration_params.stringify_keys
      end

      context 'with trial omniauth', :saas_onboarding do
        let(:registration_params) { extra_params.merge(glm_params).merge(trial: true) }

        it 'onboards the user through the welcome step' do
          post_create

          expect(response).to redirect_to(users_sign_up_welcome_path)
          created_user = User.find_by_email(new_user_email)
          expect(created_user).to be_onboarding_in_progress
          expect(created_user.onboarding_status_step_url).to eq(users_sign_up_welcome_path)
          expect(created_user.onboarding_status_initial_registration_type).to eq('trial')
          expect(created_user.onboarding_status_registration_type).to eq('trial')
        end
      end

      context 'with free omniauth' do
        it_behaves_like EE::Onboarding::Redirectable, 'free'
      end

      context 'with invited by email' do
        before_all do
          create(:group_member, :invited, invite_email: new_user_email)
        end

        it_behaves_like EE::Onboarding::Redirectable, 'invite'
      end

      context 'with subscription concerns for stored location values' do
        let(:session) { { 'user_return_to' => return_to } }
        let(:registration_params) { {} }

        before do
          stub_saas_features(onboarding: true)
        end

        subject(:post_create) { post provider, session: session }

        context 'when it is a subscription' do
          let(:return_to) { ::Gitlab::Routing.url_helpers.new_subscriptions_path }

          it 'does not overwrite the stored location' do
            expect(controller).not_to receive(:store_location_for).with(:user, return_to)

            post_create
          end
        end

        context 'when it is not a subscription' do
          let(:return_to) { 'some_other/path' }

          it 'overwrites the stored location' do
            expect(controller).to receive(:store_location_for).with(:user, users_sign_up_welcome_path)

            post_create
          end
        end

        context 'when it is a self-managed subscription under unification' do
          let(:return_to) do
            ::Gitlab::Routing.url_helpers.new_subscriptions_path(
              plan_id: 'abc123', deployment_type: 'self_managed'
            )
          end

          it 'redirects to the customers portal interstitial without consuming the stored :user location' do
            post_create

            expect(response).to redirect_to(users_sign_up_customers_portal_redirect_path)
            expect(controller.stored_location_for(:user)).to eq(return_to)
          end

          context 'when unification is disabled' do
            before do
              allow_next_instance_of(::Onboarding::StatusPresenter) do |instance|
                allow(instance).to receive(:redirect_to_customers_portal?).and_return(false)
              end
            end

            it 'redirects to the stored subscription URL instead of the interstitial' do
              post_create

              expect(response).to redirect_to(return_to)
            end
          end
        end
      end
    end

    context 'when user is already registered' do
      let(:user) { create(:omniauth_user, extern_uid: extern_uid, provider: provider) }

      it 'does not have onboarding setup and redirects to root path' do
        post provider

        expect(request.env['warden']).to be_authenticated
        expect(response).to redirect_to(root_path)
        created_user = User.find_by_email(user.email)
        expect(created_user).not_to be_onboarding_in_progress
        expect(created_user.onboarding_status_step_url).to be_nil
      end

      context 'when the user registered via the self-managed subscription flow', :saas_onboarding do
        let(:return_to) do
          ::Gitlab::Routing.url_helpers.new_subscriptions_path(
            plan_id: 'abc123', deployment_type: 'self_managed'
          )
        end

        before do
          user.update!(onboarding_status_registration_type: 'subscription_sm')
        end

        it 'follows the normal stored-location resolution instead of the interstitial' do
          post provider, session: { 'user_return_to' => return_to }

          expect(response).to redirect_to(return_to)
        end
      end
    end
  end
end
