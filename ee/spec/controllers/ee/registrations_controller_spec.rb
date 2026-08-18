# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RegistrationsController, feature_category: :system_access do
  let(:member) { nil }

  shared_examples 'an unrestricted IP address' do
    it 'does not redirect to the restricted identity verification path' do
      subject

      expect(response).not_to redirect_to restricted_signup_identity_verification_path
    end
  end

  shared_examples 'a restricted IP address' do
    it 'redirects to the restricted identity verification path' do
      subject

      expect(response).to redirect_to restricted_signup_identity_verification_path
    end
  end

  shared_examples 'a restricted invite' do
    it_behaves_like 'a restricted IP address'

    it 'deletes the invite' do
      subject

      expect(Member.find_by(id: member.id)).to be_nil
    end
  end

  shared_examples 'geo-ip restriction' do
    context 'when IP is not from a restricted location' do
      it_behaves_like 'an unrestricted IP address'
    end

    context 'when IP is from a restricted location on self-managed' do
      before do
        request.headers['Cf-IPCountry'] = 'CN'
      end

      it_behaves_like 'an unrestricted IP address'
    end

    context 'when IP is from a restricted location', :saas do
      before do
        request.headers['Cf-IPCountry'] = 'CN'
      end

      it_behaves_like 'a restricted IP address'

      context 'when user is invited', :saas do
        let_it_be(:user) { create(:user) }

        let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
        let_it_be(:ultimate_project) { create(:project, group: ultimate_group) }
        let_it_be(:ultimate_group_trial) do
          create(:group_with_plan, :public, plan: :ultimate_plan, trial_ends_on: Time.current + 30.days)
        end

        let_it_be_with_reload(:project_member) { create(:project_member, :invited, invite_email: user.email) }
        let_it_be_with_reload(:group_member) { create(:group_member, :invited, invite_email: user.email) }

        let(:member) { group_member }
        let(:params) { { id: member.raw_invite_token } }

        before do
          session[:originating_member_id] = member.id
        end

        it_behaves_like 'a restricted invite'

        context 'when member is associated with a project' do
          let(:member) { project_member }

          it_behaves_like 'a restricted invite'
        end

        context 'when the user is already logged in' do
          before do
            sign_in(user)
          end

          it_behaves_like 'an unrestricted IP address'
        end

        context 'when the namespace is paid' do
          before do
            allow_next_instance_of(described_class) do |instance|
              allow(instance).to receive(:current_user_matches_invite?).and_return(true)
            end
          end

          context 'when the namespace is a group' do
            let_it_be(:member) { create(:group_member, :invited, invite_email: user.email, group: ultimate_group) }

            it_behaves_like 'an unrestricted IP address'
          end

          context 'when the namespace is a project' do
            let_it_be(:member) do
              create(:project_member, :invited, invite_email: user.email, project: ultimate_project)
            end

            it_behaves_like 'an unrestricted IP address'
          end
        end

        context 'when the namespace is a trial' do
          let_it_be(:member) { create(:group_member, :invited, invite_email: user.email, group: ultimate_group_trial) }

          it_behaves_like 'an unrestricted IP address'
        end
      end
    end
  end

  describe '#new' do
    subject { get :new }

    it_behaves_like 'geo-ip restriction'
  end

  describe '#create', :clean_gitlab_redis_rate_limiting do
    let_it_be(:new_user_email) { 'new@user.com' }
    let(:base_user_params) { build_stubbed(:user).slice(:first_name, :last_name, :username, :password) }
    let(:extra_params) { {} }
    let(:user_params) { { user: base_user_params.merge(email: new_user_email).merge(extra_params) } }
    let(:params) { {} }
    let(:session) { {} }

    subject(:post_create) { post :create, params: params.merge(user_params), session: session }

    def identity_verification_exempt_for_user?
      created_user = User.find_by(email: new_user_email)
      created_user.custom_attributes.by_key(UserCustomAttribute::IDENTITY_VERIFICATION_EXEMPT).any?
    end

    it_behaves_like 'geo-ip restriction'

    shared_examples 'not exempt from identity verification' do
      before do
        stub_saas_features(identity_verification: true)
        stub_application_setting_enum('email_confirmation_setting', 'hard')
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      it 'does not exempt identity verification', :aggregate_failures do
        subject
        created_user = User.find_by(email: new_user_email)

        expect(created_user.signup_identity_verification_enabled?).to be(true)
        expect(identity_verification_exempt_for_user?).to be(false)
      end
    end

    shared_examples 'blocked user by default' do
      it 'registers the user in blocked_pending_approval state' do
        subject
        created_user = User.find_by(email: new_user_email)

        expect(created_user).to be_present
        expect(created_user).to be_blocked_pending_approval
      end

      it 'does not log in the user after sign up' do
        subject

        expect(controller.current_user).to be_nil
      end

      it 'shows flash message after signing up' do
        subject

        expect(response).to redirect_to(new_user_session_path(anchor: 'login-pane'))
        expect(flash[:notice])
          .to match(/your account is awaiting approval from your GitLab administrator/)
      end

      it_behaves_like 'not exempt from identity verification'
    end

    shared_examples 'active user by default' do
      it 'registers the user in active state' do
        subject
        created_user = User.find_by(email: new_user_email)

        expect(created_user).to be_present
        expect(created_user).to be_active
      end

      it 'does not show any flash message after signing up' do
        subject

        expect(flash[:notice]).to be_nil
      end

      it_behaves_like 'not exempt from identity verification'
    end

    context 'for onboarding concerns' do
      let(:extra_params) { { onboarding_status_email_opt_in: 'true' } }
      let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
      let(:registration_params) { { **glm_params, bogus: 'bogus' } }
      let(:params) { registration_params }

      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)

        allow_next_instance_of(::Onboarding::StatusPresenter) do |instance|
          allow(instance).to receive(:redirect_to_customers_portal?).and_return(false)
        end
      end

      context 'with free' do
        it_behaves_like EE::Onboarding::Redirectable, 'free'
      end

      context 'with invited by email' do
        before_all do
          create(:group_member, :invited, invite_email: new_user_email)
        end

        it_behaves_like EE::Onboarding::Redirectable, 'invite'
      end

      context 'with subscription registration' do
        let(:session) { { user_return_to: new_subscriptions_path } }

        it_behaves_like EE::Onboarding::Redirectable, 'subscription'
      end
    end

    context 'for onboarding concerns with a self-managed subscription under unification' do
      let(:extra_params) { { onboarding_status_email_opt_in: 'true' } }
      let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
      let(:registration_params) { { **glm_params, bogus: 'bogus' } }
      let(:params) { registration_params }
      let(:session) do
        { user_return_to: new_subscriptions_path(plan_id: 'abc123', deployment_type: 'self_managed') }
      end

      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      it_behaves_like 'EE::Onboarding::Redirectable for the customers portal interstitial'
    end

    context 'when require admin approval setting is enabled' do
      before do
        stub_application_setting(require_admin_approval_after_user_signup: true)
      end

      context 'when user signup cap is set' do
        before do
          stub_application_setting(new_user_signups_cap: 3)
          stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
        end

        it_behaves_like 'blocked user by default'
      end

      context 'when user signup cap is not set' do
        before do
          stub_application_setting(new_user_signups_cap: nil)
          stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF)
        end

        it_behaves_like 'blocked user by default'
      end
    end

    context 'when identity verification is enabled', :saas do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:free_group) { create(:group) }
      let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:ultimate_trial_group) { create(:group_with_plan, plan: :ultimate_trial_plan) }
      let_it_be(:free_member) { create(:group_member, :invited, invite_email: new_user_email, group: free_group) }
      let_it_be(:paid_member) { create(:group_member, :invited, invite_email: new_user_email, group: ultimate_group) }
      let_it_be(:trial_member) do
        create(:group_member, :invited, invite_email: new_user_email, group: ultimate_trial_group)
      end

      before do
        allow_next_instance_of(User) do |instance|
          allow(instance).to receive(:signup_identity_verification_enabled?).and_return(true)
        end
        session[:originating_member_id] = member.id
      end

      where(:member, :exempt) do
        ref(:free_member)  | false
        ref(:paid_member)  | true
        ref(:trial_member) | false
      end

      with_them do
        exempts = params[:exempt] ? 'exempts' : 'does not exempt'

        it "#{exempts} the user from identity verification" do
          subject

          expect(identity_verification_exempt_for_user?).to eq(exempt)
        end
      end
    end

    context 'when identity verification is disabled', :saas do
      let_it_be(:ultimate_group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:member) { create(:group_member, :invited, invite_email: new_user_email, group: ultimate_group) }

      before do
        allow_next_instance_of(User) do |instance|
          allow(instance).to receive(:signup_identity_verification_enabled?).and_return(false)
        end
        session[:originating_member_id] = member.id
      end

      it "does not create an exemption for a user invited to a paid namespace" do
        subject

        expect(identity_verification_exempt_for_user?).to be(false)
      end
    end

    shared_examples 'user cap handling without admin approval' do
      context 'when user signup cap is set' do
        before do
          stub_application_setting(new_user_signups_cap: 3)
          stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
        end

        context 'when user signup cap would be exceeded by new user signup' do
          let!(:users) { create_list(:user, 3) }

          it_behaves_like 'blocked user by default'
        end

        context 'when user signup cap would not be exceeded by new user signup' do
          let!(:users) { create_list(:user, 1) }

          it_behaves_like 'active user by default'
        end
      end

      context 'when user signup cap is not set' do
        before do
          stub_application_setting(new_user_signups_cap: nil)
          stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_OFF)
        end

        it_behaves_like 'active user by default'
      end
    end

    context 'when require admin approval setting is disabled' do
      it_behaves_like 'user cap handling without admin approval' do
        before do
          stub_application_setting(require_admin_approval_after_user_signup: false)
        end
      end
    end

    context 'when require admin approval setting is nil' do
      it_behaves_like 'user cap handling without admin approval' do
        before do
          stub_application_setting(require_admin_approval_after_user_signup: nil)
        end
      end
    end

    context 'with audit events' do
      context 'when licensed' do
        before do
          stub_licensed_features(admin_audit_log: true, external_audit_events: true)
        end

        context 'when user registers for the instance' do
          it 'logs add email event and instance access request event' do
            expect { subject }.to change { AuditEventReader.count }.by(2)
          end

          it 'logs the audit event info', :aggregate_failures do
            create(:audit_events_instance_external_streaming_destination)

            # Stub .audit here so that only relevant audit events are received below
            allow(::Gitlab::Audit::Auditor).to receive(:audit)
            expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
                                                                .with('registration_created', anything, anything)
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
              name: "registration_created",
              additional_details: {
                registration_details: hash_including({
                  email: new_user_email
                })
              }
            })).and_call_original

            subject

            created_user = User.find_by(email: new_user_email)
            audit_event = AuditEventReader.where(author_id: created_user.id).last

            expect(audit_event).to have_attributes(
              entity: created_user,
              author: created_user,
              ip_address: created_user.current_sign_in_ip,
              attributes: hash_including({
                "target_details" => created_user.username,
                "target_id" => created_user.id,
                "target_type" => "User",
                "entity_path" => created_user.full_path
              }),
              details: hash_including({
                target_details: created_user.username,
                custom_message: "Instance access request",
                registration_details: {
                  id: created_user.id,
                  username: created_user.username,
                  name: created_user.name,
                  email: created_user.email,
                  access_level: created_user.access_level
                }
              }))
          end

          context 'with invalid user' do
            before do
              # By creating the user beforehand, the next request
              # will be invalid (duplicate email / username)
              create(:user, **user_params[:user])
            end

            it 'does not log registration failure' do
              expect { subject }.not_to change { AuditEventReader.count }
              expect(response).to render_template(:new)
            end
          end
        end
      end
    end
  end

  describe '#destroy' do
    let(:user) { create(:user) }

    before do
      user.update!(password_automatically_set: true)
      sign_in(user)
    end

    shared_examples 'it succeeds' do
      it 'succeeds' do
        post :destroy, params: { username: user.username }

        expect(flash[:notice]).to eq s_('Profiles|Account scheduled for removal.')
        expect(response).to have_gitlab_http_status(:see_other)
        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'on GitLab.com when the password is automatically set' do
      before do
        stub_application_setting(password_authentication_enabled_for_web: false)
        stub_application_setting(password_authentication_enabled_for_git: false)
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      it 'redirects without deleting the account' do
        expect(DeleteUserWorker).not_to receive(:perform_async)

        post :destroy, params: { username: user.username }

        expect(flash[:alert]).to eq 'Account could not be deleted. GitLab was unable to verify your identity.'
        expect(response).to have_gitlab_http_status(:see_other)
        expect(response).to redirect_to profile_account_path
      end
    end

    context 'when license feature available' do
      before do
        stub_licensed_features(disable_deleting_account_for_users: true)
      end

      context 'when allow_account_deletion is false' do
        before do
          stub_application_setting(allow_account_deletion: false)
        end

        it 'fails with message' do
          post :destroy, params: { username: user.username }

          expect(flash[:alert]).to eq 'Account deletion is not allowed.'
          expect(response).to have_gitlab_http_status(:see_other)
          expect(response).to redirect_to profile_account_path
        end
      end

      context 'when allow_account_deletion is true' do
        before do
          stub_application_setting(allow_account_deletion: true)
        end

        include_examples 'it succeeds'
      end
    end

    context 'when license feature unavailable' do
      before do
        stub_licensed_features(disable_deleting_account_for_users: false)
      end

      context 'when allow_account_deletion is false' do
        before do
          stub_application_setting(allow_account_deletion: false)
        end

        include_examples 'it succeeds'
      end

      context 'when allow_account_deletion is true' do
        before do
          stub_application_setting(allow_account_deletion: true)
        end

        include_examples 'it succeeds'
      end
    end

    context 'with SaaS enterprise user account deletion prevention' do
      let(:enterprise_group) { create(:group) }
      let(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      before do
        stub_licensed_features(disable_deleting_account_for_users: false)
        stub_application_setting(allow_account_deletion: true)
        sign_in(user)
      end

      context 'when enterprise group prevents account deletion' do
        before do
          user.update!(password_automatically_set: false)
          allow(::Gitlab).to receive(:com?).and_return(true)

          stub_licensed_features(
            disable_deleting_account_for_users: false,
            domain_verification: true,
            prevent_enterprise_user_account_deletion: true
          )
          stub_saas_features(prevent_enterprise_user_account_deletion: true)
          stub_feature_flags(deleting_account_disabled_for_enterprise_users: enterprise_group)

          enterprise_group.namespace_settings.update!(allow_enterprise_user_account_deletion: false)
        end

        it 'redirects with alert' do
          post :destroy, params: { username: user.username }

          expect(flash[:alert]).to eq s_('Profiles|Account deletion is not allowed.')
          expect(response).to have_gitlab_http_status(:see_other)
          expect(response).to redirect_to profile_account_path
        end
      end

      context 'when enterprise group allows account deletion' do
        before do
          enterprise_group.namespace_settings.update!(allow_enterprise_user_account_deletion: true)
        end

        include_examples 'it succeeds'
      end

      context 'when user is not an enterprise user' do
        let(:user) { create(:user) }

        include_examples 'it succeeds'
      end
    end
  end
end
