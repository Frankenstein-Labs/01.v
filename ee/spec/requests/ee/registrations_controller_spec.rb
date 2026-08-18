# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RegistrationsController, :with_current_organization, feature_category: :system_access do
  include SessionHelpers
  include IdentityVerificationHelpers

  let_it_be(:user_attrs) do
    build_stubbed(:user).slice(:first_name, :last_name, :username, :email, :password)
  end

  before do
    allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_enabled?).and_return(false)
  end

  describe 'GET #new' do
    let(:params) { { user: user_attrs } }

    subject(:new_user) { get new_user_registration_path, params: params }

    context 'with tracking' do
      it 'tracks page render' do
        new_user

        expect_snowplow_event(
          category: described_class.name,
          action: 'render_registration_page',
          label: 'free_registration'
        )
      end

      context 'when invite' do
        let(:params) { { user: user_attrs, invite_email: 'new@email.com' } }

        it 'tracks page render' do
          new_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'invite_registration'
          )
        end
      end

      context 'when subscription', :saas, :clean_gitlab_redis_sessions do
        before do
          stub_session(session_data: { user_return_to: new_subscriptions_path })
        end

        it 'tracks successful form submission' do
          new_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'render_registration_page',
            label: 'subscription_registration'
          )
        end
      end
    end

    context 'when arriving from the subscription portal with self-managed plan params' do
      let(:params) { { plan_id: 'abc123', deployment_type: 'self_managed' } }

      subject(:new_user) { get new_user_registration_path(params) }

      context 'when onboarding is enabled', :saas_onboarding do
        it 'stores the subscription path in session for post-signup redirect' do
          new_user

          expect(request.session['user_return_to'])
            .to eq(new_subscriptions_path(plan_id: 'abc123', deployment_type: 'self_managed', auto_submit_sso: 'true'))
        end

        context 'when deployment_type is not self_managed' do
          let(:params) { super().merge(deployment_type: 'other') }

          it 'does not store the subscription path' do
            new_user

            expect(request.session['user_return_to']).to be_nil
          end
        end

        context 'when plan_id is blank' do
          let(:params) { super().except(:plan_id) }

          it 'does not store the subscription path' do
            new_user

            expect(request.session['user_return_to']).to be_nil
          end
        end
      end

      context 'when onboarding is not enabled' do
        it 'does not store the subscription path' do
          new_user

          expect(request.session['user_return_to']).to be_nil
        end
      end
    end

    context 'when arriving from the subscription portal with gitlab_credits purchase for self_managed' do
      let(:params) { { plan_type: 'gitlab_credits', deployment_type: 'self_managed' } }

      subject(:new_user) { get new_user_registration_path(params) }

      context 'when onboarding is enabled', :saas_onboarding do
        it 'stores the subscription path in session for post-signup redirect' do
          new_user

          expect(request.session['user_return_to']).to eq(
            new_subscriptions_path(
              plan_type: 'gitlab_credits',
              deployment_type: 'self_managed',
              auto_submit_sso: 'true'
            )
          )
        end

        context 'when deployment_type is not self_managed' do
          let(:params) { super().merge(deployment_type: 'other') }

          it 'does not store the subscription path' do
            new_user

            expect(request.session['user_return_to']).to be_nil
          end
        end

        context 'when plan_type is not gitlab_credits' do
          let(:params) { super().merge(plan_type: 'other') }

          it 'does not store the subscription path' do
            new_user

            expect(request.session['user_return_to']).to be_nil
          end
        end
      end

      context 'when onboarding is not enabled' do
        it 'does not store the subscription path' do
          new_user

          expect(request.session['user_return_to']).to be_nil
        end
      end
    end

    describe 'layout dispatch' do
      context 'when unified registration is enabled', :saas_onboarding do
        it 'wraps the page in the unified two-panel layout' do
          new_user

          expect(response.body).to include('registration-marketing-panel-illustration')
        end
      end

      context 'when unified registration is not enabled' do
        it 'wraps the page in the devise layout' do
          new_user

          expect(response.body).not_to include('registration-marketing-panel-illustration')
        end
      end
    end
  end

  describe 'POST #create' do
    subject(:create_user) { post user_registration_path, params: { user: user_attrs } }

    it_behaves_like 'creates a user with ArkoseLabs risk band on signup request' do
      let(:registration_path) { user_registration_path }
    end

    describe 'identity verification' do
      before do
        stub_application_setting_enum('email_confirmation_setting', 'hard')
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      context 'when identity verification is turned off' do
        let_it_be(:devise_token) { Devise.friendly_token }

        before do
          allow(Devise).to receive(:friendly_token).and_return(devise_token)
        end

        describe 'sending confirmation instructions' do
          it 'sends Devise confirmation instructions' do
            expect { create_user }.to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
          end

          it 'does not send custom confirmation instructions' do
            expect(::Notify).not_to receive(:confirmation_instructions_email)

            create_user
          end

          it 'sets the confirmation_sent_at time', :freeze_time do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_sent_at).to eq(Time.current)
          end

          it 'sets the confirmation_token to the unencrypted Devise token' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_token).to eq(devise_token)
          end
        end

        describe 'setting a session variable' do
          it 'does not set the `verification_user_id` session variable' do
            create_user

            expect(request.session.has_key?(:verification_user_id)).to be(false)
          end
        end

        describe 'redirection' do
          it 'redirects to the `users_almost_there_path`' do
            create_user

            expect(response).to redirect_to(users_almost_there_path(email: user_attrs[:email]))
          end
        end
      end

      context 'when identity verification is available' do
        let_it_be(:custom_token) { '123456' }
        let_it_be(:encrypted_token) { Devise.token_generator.digest(User, user_attrs[:email], custom_token) }

        before do
          stub_saas_features(identity_verification: true)
          allow_next_instance_of(::Users::EmailVerification::GenerateTokenService) do |srvc|
            allow(srvc).to receive(:generate_token).and_return(custom_token)
          end
        end

        describe 'sending confirmation instructions' do
          it 'does not send Devise confirmation instructions' do
            expect { create_user }.not_to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
          end

          it 'sends custom confirmation instructions' do
            expect(::Notify).to receive(:confirmation_instructions_email)
              .with(user_attrs[:email], token: custom_token).once.and_call_original

            create_user
          end

          it 'sets the confirmation_sent_at time', :freeze_time do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_sent_at).to eq(Time.current)
          end

          it 'sets the confirmation_token to the encrypted custom token' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(user.confirmation_token).to eq(encrypted_token)
          end
        end

        describe 'preventing token collisions' do
          it 'does not raise an error when an identical token exists in the database' do
            create_user

            user_attrs = build_stubbed(:user).slice(:first_name, :last_name, :username, :email, :password)

            expect { post user_registration_path, params: { user: user_attrs } }.not_to raise_error
          end
        end

        describe 'setting a session variable' do
          it 'sets the `verification_user_id` session variable' do
            create_user
            user = User.find_by_username(user_attrs[:username])

            expect(request.session[:verification_user_id]).to eq(user.id)
          end
        end

        describe 'handling sticking' do
          it 'sticks or unsticks the request' do
            allow(User.sticking).to receive(:find_caught_up_replica)

            create_user

            user = User.find_by_username(user_attrs[:username])
            expect(User.sticking)
              .to have_received(:find_caught_up_replica)
              .with(:user, user.id, hash_id: false)

            stick_object = request.env[::Gitlab::Database::LoadBalancing::RackMiddleware::STICK_OBJECT].first
            expect(stick_object[0]).to eq(User.sticking)
            expect(stick_object[1]).to eq(:user)
            expect(stick_object[2]).to eq(user.id)
          end
        end

        describe 'redirection' do
          it 'redirects to the `signup_identity_verification_path`' do
            create_user

            expect(response).to redirect_to(signup_identity_verification_path)
          end
        end

        it_behaves_like 'bypasses email confirmation for the QA user agent on staging' do
          let(:registration_path) { user_registration_path }
          let(:registration_params) { { user: user_attrs } }
          let(:submitted_email) { user_attrs[:email] }
        end

        context 'when user is not persisted' do
          before do
            create(:user, email: user_attrs[:email])
          end

          it 'does not try to send custom confirmation instructions' do
            expect_next_instance_of(Users::EmailVerification::SendCustomConfirmationInstructionsService) do |service|
              expect(service).not_to receive(:send_instructions)
            end

            create_user
          end

          it 'tracks registration error' do
            create_user

            expect_snowplow_event(
              category: 'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
              action: 'track_free_registration_error',
              label: 'failed_creating_user'
            )
          end
        end
      end
    end

    context 'with onboarding progress' do
      before do
        allow(::Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(false)
      end

      context 'when onboarding feature is available' do
        before do
          stub_saas_features(onboarding: true)
        end

        it 'sets onboarding' do
          create_user

          created_user = User.find_by(email: user_attrs[:email])
          expect(created_user.onboarding_in_progress).to be_truthy
        end

        context 'and the user is eligible to be an enterprise user', :saas do
          let_it_be(:pages_domain) { create(:pages_domain, project: create(:project, group: create(:group))) }
          let_it_be(:user_attrs) do
            build_stubbed(:user)
              .slice(:first_name, :last_name, :username, :password).merge(email: "example@#{pages_domain.domain}")
          end

          before do
            stub_licensed_features(domain_verification: true)
          end

          it 'does not set onboarding' do
            create_user

            created_user = User.find_by(email: user_attrs[:email])
            expect(created_user.onboarding_in_progress).to be_falsey
          end
        end
      end

      context 'when onboarding feature is not available' do
        it 'does not set onboarding' do
          create_user

          created_user = User.find_by(email: user_attrs[:email])
          expect(created_user.onboarding_in_progress).to be_falsey
        end
      end
    end

    describe 'phone verification service daily transaction limit check' do
      it 'sets high risk attribute when phone verification limit is exceeded' do
        allow(Gitlab::ApplicationRateLimiter).to receive(:peek)
          .with(:soft_phone_verification_transactions_limit, scope: :global)
          .and_return(true)
        create_user
        expect(
          User.last.custom_attributes.find_by_value('Phone verification daily transaction limit exceeded')
        ).not_to be_nil
      end
    end

    describe 'user signup cap' do
      before do
        stub_application_setting(require_admin_approval_after_user_signup: false)
      end

      context 'when user signup cap is exceeded on an ultimate license' do
        before do
          stub_ee_application_setting(new_user_signups_cap: 1)

          create(:group_member, :developer)
          license = create(:license, plan: License::ULTIMATE_PLAN)
          allow(License).to receive(:current).and_return(license)
        end

        it 'sets a new non-billable user state to active' do
          create_user

          user = User.find_by(email: user_attrs[:email])
          expect(user).to be_active
        end
      end
    end

    describe 'block seat overages' do
      context 'when there are no seats remaining on a premium license' do
        before do
          stub_ee_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)

          create(:user, :developer)
          license = create(:license, plan: License::PREMIUM_PLAN, seats: 1)
          allow(License).to receive(:current).and_return(license)
        end

        it 'prevents new user registration' do
          create_user

          expect(flash[:alert]).to eq('There are no seats left on your GitLab instance. ' \
            'Please contact your GitLab administrator.')
          expect(User.count).to eq(1)
        end
      end

      context 'when there are no seats remaining on an ultimate license' do
        before do
          stub_ee_application_setting(seat_control: ::EE::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)

          create(:user, :developer)
          license = create(:license, plan: License::ULTIMATE_PLAN, seats: 1)
          allow(License).to receive(:current).and_return(license)
        end

        it 'allows new user registration' do
          create_user

          expect(User.count).to eq(2)
        end
      end
    end

    context 'with tracking' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'tracks successful form submission' do
        create_user

        expect_snowplow_event(
          category: described_class.name,
          action: 'successfully_submitted_form',
          label: 'free_registration',
          user: User.find_by(email: user_attrs[:email])
        )
      end

      context 'when invite' do
        before do
          # We are doing this here so that invites are accepted as this is a guard for
          # that happening and not a focus of this test in general.
          allow_next_instance_of(User) do |user|
            allow(user).to receive(:active_for_authentication?).and_return(true)
          end

          create(:group_member, :invited, invite_email: user_attrs[:email])
        end

        subject(:create_user) do
          post user_registration_path, params: { user: user_attrs, invite_email: user_attrs[:email] }
        end

        it 'tracks successful form submission' do
          create_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'invite_registration',
            user: User.find_by(email: user_attrs[:email])
          )
        end
      end

      context 'when subscription', :saas, :clean_gitlab_redis_sessions do
        before do
          stub_session(session_data: { user_return_to: new_subscriptions_path })
        end

        it 'tracks successful form submission' do
          create_user

          expect_snowplow_event(
            category: described_class.name,
            action: 'successfully_submitted_form',
            label: 'subscription_registration',
            user: User.find_by(email: user_attrs[:email])
          )
        end
      end
    end
  end
end
