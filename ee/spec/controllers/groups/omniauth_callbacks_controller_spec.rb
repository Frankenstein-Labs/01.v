# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::OmniauthCallbacksController, :aggregate_failures, feature_category: :system_access do
  include LoginHelpers
  include ForgeryProtection

  let(:uid) { 'my-uid' }
  let(:user) { create(:user) }
  let(:provider) { :group_saml }
  let(:group) { create(:group, :private) }
  let!(:saml_provider) { create(:saml_provider, group: group) }
  let(:in_response_to) { '12345' }
  let(:last_request_id) { in_response_to }
  let(:saml_response) { instance_double(OneLogin::RubySaml::Response, in_response_to: in_response_to) }
  let(:saml_groups) { [] }

  before do
    stub_licensed_features(group_saml: true)
    allow(saml_response).to receive(:session_expires_at).and_return(nil)
  end

  def linked_accounts
    Identity.where(user: user, extern_uid: uid, provider: provider)
  end

  def create_linked_user
    create(:omniauth_user, extern_uid: uid, provider: provider, saml_provider: saml_provider)
  end

  def stub_last_request_id(id)
    session["last_authn_request_id"] = id
  end

  context "when request hasn't been validated by omniauth middleware" do
    it "prevents authentication" do
      sign_in(user)

      expect do
        post provider, params: { group_id: group }
      end.to raise_error(AbstractController::ActionNotFound)
    end
  end

  context 'when the user is invalid' do
    let(:user) { build_stubbed(:user) }

    before do
      group.saml_discovery_token # ensure discovery token is initialized
    end

    context 'when the email is blank' do
      before do
        @original_env_config_omniauth_auth = mock_auth_hash(provider, uid, nil, response_object: saml_response)
        stub_omniauth_provider(provider, context: request)
        stub_last_request_id(last_request_id)
      end

      after do
        Rails.application.env_config['omniauth.auth'] = @original_env_config_omniauth_auth
      end

      it "redirects to the Group SAML sign in page with flash alert" do
        post provider, params: { group_id: group }

        expect(response).to redirect_to(sso_group_saml_providers_path(group, token: group.saml_discovery_token))
        expect(flash[:alert]).to eq(s_('SAML|The SAML response did not contain an email address. Either the SAML identity provider is not configured to send the attribute, or the identity provider directory does not have an email address value for your user.'))
      end
    end

    context 'when any other validation error occurs' do
      before do
        bad_name = Devise.friendly_token(150)
        @original_env_config_omniauth_auth =
          mock_auth_hash(provider, uid, user.email, response_object: saml_response, name: bad_name)
        stub_omniauth_provider(provider, context: request)
        stub_last_request_id(last_request_id)
      end

      after do
        Rails.application.env_config['omniauth.auth'] = @original_env_config_omniauth_auth
      end

      it "redirects to the Group SAML sign in page with flash alert" do
        post provider, params: { group_id: group }

        expect(response).to redirect_to(sso_group_saml_providers_path(group, token: group.saml_discovery_token))
        expect(flash[:alert]).to eq("First name is too long (maximum is 127 characters)")
      end
    end
  end

  context "valid credentials" do
    let(:stub_last_request_id_active) { true }

    before do
      @original_env_config_omniauth_auth = mock_auth_hash(provider, uid, user.email, response_object: saml_response, groups: saml_groups)
      stub_omniauth_provider(provider, context: request)
      stub_last_request_id(last_request_id) if stub_last_request_id_active
    end

    after do
      Rails.application.env_config['omniauth.auth'] = @original_env_config_omniauth_auth
    end

    context 'when not GitLab initiated' do
      let(:last_request_id) { 'other' }
      let(:stub_last_request_id_active) { false }
      let!(:user) { create_linked_user }

      before do
        sign_in(user)
      end

      it "ignores RelayState" do
        post provider, params: { group_id: group, RelayState: '/explore' }

        expect(response).to redirect_to(group_path(group))
      end
    end

    shared_examples 'works with session enforcement' do
      it 'stores that a SAML session is active' do
        allow_next_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer, saml_provider, anything) do |instance|
          allow(instance).to receive(:update_session).with(anything)
        end
        expect_next_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer, saml_provider) do |instance|
          expect(instance).to receive(:update_session)
        end

        post provider, params: { group_id: group }
      end
    end

    shared_examples "SAML session initiated" do
      it "redirects to RelayState if its value is a subpath and starts with a slash" do
        post provider, params: { group_id: group, RelayState: '/explore' }

        expect(response).to redirect_to('/explore')
      end

      it "ignores RelayState that doesn't start with a slash" do
        post provider, params: { group_id: group, RelayState: 'explore' }
        expect(response).to redirect_to(group_path(group))
      end

      it "ignores RelayState that starts with two slashes" do
        post provider, params: { group_id: group, RelayState: '//example.com' }
        expect(response).to redirect_to(group_path(group))
      end

      it "ignores RelayState outside root domain without full URL" do
        post provider, params: { group_id: group, RelayState: '.example.com' }
        expect(response).to redirect_to(group_path(group))
      end

      it "ignores RelayState outside root domain with full URI" do
        post provider, params: { group_id: group, RelayState: 'https://abcd.example.com' }
        expect(response).to redirect_to(group_path(group))
      end

      it "ignores RelayState within root domain with full URI" do
        post provider, params: { group_id: group,
                                 RelayState: "http://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/explore" }
        expect(response).to redirect_to(group_path(group))
      end

      it "ignores RelayState when invalid URI" do
        post provider, params: { group_id: group, RelayState: "javascript://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/explore" }
        expect(response).to redirect_to(group_path(group))
      end

      it 'logs group audit event for authentication' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          {
            name: 'authenticated_with_group_saml',
            author: user,
            scope: group,
            target: user,
            message: "Signed in with #{provider.upcase} authentication",
            organization: user.organization,
            authentication_event: true,
            authentication_provider: provider,
            additional_details: {
              with: provider,
              registration_details: {
                email: user.email,
                id: user.id,
                name: user.name,
                username: user.username,
                access_level: user.access_level
              }
            }
          }
        ).and_call_original

        unless group.member?(user)
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'group_saml_member_added',
              message: 'Added as SAML group member',
              target: user,
              scope: group
            )
          ).and_call_original
        end

        expect { post provider, params: { group_id: group } }.to change { AuthenticationEvent.count }.by(1)
      end

      it 'logs saml_response for debugging' do
        expect(ParameterFilters::SamlResponse).to receive(:log).with(nil)

        post provider, params: { group_id: group, RelayState: '.example.com' }
      end

      include_examples 'works with session enforcement'
    end

    shared_examples "and identity already linked" do
      let!(:user) { create_linked_user }

      it_behaves_like "SAML session initiated"

      it 'uses existing linked identity' do
        expect { post provider, params: { group_id: group } }.not_to change { linked_accounts.count }
      end

      it 'skips authenticity token based forgery protection' do
        with_forgery_protection do
          post provider, params: { group_id: group }

          expect(response).not_to be_client_error
          expect(response).not_to be_server_error
        end
      end

      context 'when user is in onboarding' do
        before do
          stub_saas_features(onboarding: true)
          user.update!(onboarding_in_progress: true)
        end

        it 'finishes onboarding' do
          expect do
            post provider, params: { group_id: group }
          end.to change { user.reload.onboarding_in_progress }.to(false)
        end
      end

      context 'with 2FA' do
        before do
          user.update!(otp_required_for_login: true)
        end

        include_examples 'works with session enforcement'
      end
    end

    context "when signed in" do
      before do
        sign_in(user)
      end

      it_behaves_like "and identity already linked"

      context 'oauth linked with different NameID' do
        before do
          create(:identity, user: user, extern_uid: 'some-other-name-id', provider: provider, saml_provider: saml_provider)
        end

        it "displays a flash message verifying group sign in" do
          post provider, params: { group_id: group }

          expect(flash[:notice]).to eq(s_("SAML|Your organization's SSO has been connected to your GitLab account"))
        end

        context 'when user email address does not match auth hash email address' do
          before do
            mock_auth_hash(provider, uid, generate(:email), response_object: saml_response)
            stub_omniauth_provider(provider, context: request)
          end

          it 'redirects and displays an error', :aggregate_failures do
            post provider, params: { group_id: group }

            expect(flash[:alert]).to eq(format(
              s_("GroupSAML|%{group_name} SAML authentication failed: %{message}"),
              group_name: group.name,
              message: s_('GroupSAML|SAML Name ID and email address do not match your user account. Contact an administrator.')
            ))
            expect(response).to redirect_to(root_path)
          end
        end
      end

      context 'oauth already linked to another account' do
        before do
          create_linked_user
        end

        it 'redirects and displays an error' do
          post provider, params: { group_id: group }

          expect(flash[:alert]).to eq(format(
            s_("GroupSAML|%{group_name} SAML authentication failed: %{message}"),
            group_name: group.name,
            message: 'Extern uid has already been taken. Please contact your administrator to generate a unique extern_uid / NameID'
          ))
          expect(response).to redirect_to(root_path)
        end
      end

      context "and identity hasn't been linked" do
        it "links the identity" do
          post provider, params: { group_id: group }

          expect(group).to be_member(user)
        end

        context 'when a default access level is specified in the SAML provider' do
          let!(:saml_provider) do
            create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
          end

          it 'sets the access level of the member as per the specified `default_membership_role`' do
            post provider, params: { group_id: group }

            created_member = group.members.find_by(user: user)
            expect(created_member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end
        end

        context 'custom roles', feature_category: :permissions do
          let(:member_role) { create(:member_role, namespace: group) }

          before do
            stub_licensed_features(group_saml: true, saml_group_sync: true, custom_roles: true)
          end

          context 'when a custom role is specified in the SAML provider' do
            let!(:saml_provider) do
              create(:saml_provider, group: group,
                default_membership_role: member_role.base_access_level,
                member_role: member_role)
            end

            it 'sets the `member_role` of the member as per the specified `member_role`' do
              post provider, params: { group_id: group }

              expect(group.member(user).member_role).to eq(member_role)
            end
          end

          context 'when a group is provided and a saml group link exists with a custom role' do
            let(:custom_roles_group_name) { 'Custom Roles Group' }
            let(:saml_groups) { [custom_roles_group_name] }
            let!(:saml_group_link) do
              create(:saml_group_link, group: group,
                saml_group_name: custom_roles_group_name,
                member_role: member_role,
                access_level: member_role.base_access_level)
            end

            it 'sets the `member_role` of the member as defined in the saml group link', :sidekiq_inline do
              post provider, params: { group_id: group }

              expect(group.member(user).member_role).to eq(member_role)
            end
          end
        end

        it_behaves_like "SAML session initiated"

        it "displays a flash indicating the account has been linked" do
          post provider, params: { group_id: group }

          expect(flash[:notice]).to eq(s_("SAML|Your organization's SSO has been connected to your GitLab account"))
        end

        it 'logs group audit event for being added to the group' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'authenticated_with_group_saml'
            )
          ).ordered.and_call_original

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'group_saml_member_added',
              message: 'Added as SAML group member',
              target: user,
              scope: group
            )
          ).ordered.and_call_original

          post provider, params: { group_id: group }
        end

        context 'with IdP initiated request' do
          let(:last_request_id) { '99999' }

          it 'redirects to account link page' do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(sso_group_saml_providers_path(group))
          end

          it "lets the user know their account isn't linked yet" do
            post provider, params: { group_id: group }

            expect(flash[:notice]).to eq 'Request to link SAML account must be authorized'
          end
        end
      end
    end

    context "when not signed in" do
      context "and identity hasn't been linked" do
        it "redirects to sign in page with flash notice" do
          post provider, params: { group_id: group }

          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:notice]).to eq(s_("SAML|There is already a GitLab account associated with this email address. Sign in with your existing credentials to connect your organization's account"))
        end

        context 'when user is an enterprise user of the group' do
          let(:user) { create(:enterprise_user, enterprise_group: group) }

          it_behaves_like 'SAML session initiated'

          it 'find the user by email and authenticates' do
            post provider, params: { group_id: group }

            expect(request.env['warden']).to be_authenticated
            expect(controller.current_user).to eq user
            expect(flash[:notice]).to match(/Signed in with SAML/i)
          end

          it 'links identity' do
            expect { post provider, params: { group_id: group } }
              .to change { Identity.exists?(user: user, extern_uid: uid, provider: provider, saml_provider_id: group.saml_provider.id) }
              .from(false).to(true)
          end

          context 'when user has minimal access to the group' do
            before do
              stub_licensed_features(minimal_access_role: true)
              saml_provider.update!(default_membership_role: Gitlab::Access::MINIMAL_ACCESS)
            end

            it 'redirects to user dashboard' do
              post provider, params: { group_id: group }

              expect(response).to redirect_to(dashboard_groups_path)
            end

            context 'when RelayState is to the SAML group' do
              it 'redirects to user dashboard' do
                post provider, params: { group_id: group, RelayState: group_path(group) }

                expect(response).to redirect_to(dashboard_groups_path)
              end
            end

            context 'when RelayState is to another page' do
              it 'redirects to that page' do
                post provider, params: { group_id: group, RelayState: '/explore' }

                expect(response).to redirect_to('/explore')
              end
            end
          end
        end

        context 'when user is an enterprise user of another group' do
          let(:user) { create(:enterprise_user) }

          it "redirects to sign in page with flash notice" do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:notice]).to eq(s_("SAML|There is already a GitLab account associated with this email address. Sign in with your existing credentials to connect your organization's account"))
          end

          it 'does not link identity' do
            expect { post provider, params: { group_id: group } }
              .not_to change { Identity.count }
          end
        end
      end

      it_behaves_like "and identity already linked"

      context 'oauth linked with different NameID' do
        let(:linked_identity) { create(:identity, user: user, extern_uid: 'some-other-name-id', provider: provider, saml_provider: saml_provider) }

        it "redirects to sign in page with flash notice" do
          post provider, params: { group_id: group }

          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:notice]).to eq(s_("SAML|There is already a GitLab account associated with this email address. Sign in with your existing credentials to connect your organization's account"))
        end

        context 'when user is an enterprise user of the group' do
          let(:user) { create(:user, enterprise_group: group) }

          it_behaves_like 'SAML session initiated'

          it 'find the user by email and authenticates' do
            post provider, params: { group_id: group }

            expect(request.env['warden']).to be_authenticated
            expect(controller.current_user).to eq user
            expect(flash[:notice]).to match(/Signed in with SAML/i)
          end

          it 'updates linked identity' do
            expect { post provider, params: { group_id: group } }
              .to change { linked_identity.reload.extern_uid }
              .from('some-other-name-id').to(uid)
          end
        end

        context 'when user is an enterprise user of another group' do
          let(:user) { create(:enterprise_user) }

          it "redirects to sign in page with flash notice" do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:notice]).to eq(s_("SAML|There is already a GitLab account associated with this email address. Sign in with your existing credentials to connect your organization's account"))
          end

          it 'does not update linked identity' do
            expect { post provider, params: { group_id: group } }.not_to change { linked_identity.reload.extern_uid }
          end
        end
      end

      context 'for sign up', :aggregate_failures do
        let(:user) { build_stubbed(:user) }

        before do
          enable_namespace_license_check!
          stub_omniauth_setting(block_auto_created_users: false)
        end

        it 'does not enforce onboarding for sign up' do
          post provider, params: { group_id: group }

          expect(request.env['warden']).to be_authenticated
          expect(response).to redirect_to(group_path(group))
          created_user = User.find_by_email(user.email)
          expect(created_user).not_to be_onboarding_in_progress
          expect(created_user.onboarding_status_step_url).to be_nil
        end

        context 'when the user is trying to sign-in from restricted country' do
          let(:error_message) { "It looks like you are visiting GitLab from Mainland China, Macau, or Hong Kong" }

          before do
            request.env['HTTP_CF_IPCOUNTRY'] = 'CN'
            stub_omniauth_setting(block_auto_created_users: false)
          end

          it 'allows sign ups even from restricted countries' do
            expect(User.find_by_email(user.email)).to be_nil

            post provider, params: { group_id: group }

            expect(flash[:alert]).not_to eq(error_message)
            expect(response).to redirect_to(group_path(group))

            created_user = User.find_by_email(user.email)
            expect(created_user).not_to be_onboarding_in_progress
            expect(created_user.onboarding_status_step_url).to be_nil
          end
        end
      end
    end

    describe 'identity verification', feature_category: :insider_threat do
      before do
        allow_next_instance_of(User) do |user|
          allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        end
      end

      shared_examples 'identity verification not required' do
        it 'does not redirect to identity verification' do
          allow_any_instance_of(::Users::EmailVerification::SendCustomConfirmationInstructionsService) do |instance|
            expect(instance).not_to receive(:execute)
          end

          post provider, params: { group_id: group }

          expect(request.session[:verification_user_id]).to be_nil
          expect(response).not_to redirect_to(signup_identity_verification_path)
        end
      end

      context 'on sign up' do
        let(:user) { build(:user) }

        it_behaves_like 'identity verification not required'
      end

      context 'on sign in when identity is not yet verified' do
        let(:user) { create_linked_user }

        before do
          user.update!(confirmed_at: nil)
        end

        it_behaves_like 'identity verification not required'
      end
    end
  end

  describe "#failure" do
    include RoutesHelpers

    def fake_error_callback_route
      fake_routes do
        post '/groups/:group_id/-/saml/callback', to: 'groups/omniauth_callbacks#failure'
      end
    end

    def stub_certificate_error
      strategy = OmniAuth::Strategies::GroupSaml.new(nil)
      exception = OneLogin::RubySaml::ValidationError.new("Fingerprint mismatch")
      stub_omniauth_failure(strategy, :invalid_ticket, exception)
    end

    before do
      fake_error_callback_route
      stub_certificate_error
      set_devise_mapping(context: @request)
    end

    context "not signed in" do
      it "doesn't disclose group existence" do
        expect do
          post :failure, params: { group_id: group }
        end.to raise_error(ActionController::RoutingError)
      end

      context "group doesn't exist" do
        it "doesn't disclose group non-existence" do
          expect do
            post :failure, params: { group_id: 'not-a-group' }
          end.to raise_error(ActionController::RoutingError)
        end
      end
    end

    context "with access" do
      before do
        sign_in(user)
      end

      it "has descriptive error flash" do
        post :failure, params: { group_id: group }

        expect(flash[:alert]).to start_with("Unable to sign in to group with SAML:")
        expect(flash[:alert]).to include("Fingerprint mismatch")
      end

      it "redirects back go the SSO page" do
        post :failure, params: { group_id: group }

        expect(response).to redirect_to(sso_group_saml_providers_path)
      end
    end

    context "with access to SAML settings for the group" do
      let(:user) { create_linked_user }

      before do
        group.add_owner(user)
        sign_in(user)
      end

      it "redirects to the settings page" do
        post :failure, params: { group_id: group }

        expect(response).to redirect_to(group_saml_providers_path)
      end
    end
  end
end
