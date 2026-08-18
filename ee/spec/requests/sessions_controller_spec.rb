# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SessionsController, :with_organization_url_helpers, feature_category: :system_access do
  describe 'POST /users/sign_in (self_managed_welcome_onboarding redirect)', feature_category: :onboarding do
    let_it_be(:admin) { create(:admin) }

    def sign_in_as(user)
      post user_session_path, params: { user: { login: user.username, password: user.password } }
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(subscriptions_trials: true)
        stub_application_setting(admin_mode: false)
        allow(Group).to receive(:exists?).and_return(false)
      end

      it 'does not redirect to SM onboarding path' do
        sign_in_as(admin)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe '#create' do
    let_it_be_with_reload(:user) { create(:user, :unconfirmed) }
    let_it_be(:current_organization) { user.organization }

    subject(:sign_in) do
      post user_session_path(user: { login: user.username, password: user.password })
    end

    context 'when identity verification is turned off' do
      before do
        allow_next_found_instance_of(User) do |user|
          allow(user).to receive(:signup_identity_verification_enabled?).and_return(false)
        end
      end

      it { is_expected.to redirect_to(root_path) }

      it 'does not set the `verification_user_id` session variable' do
        sign_in

        expect(request.session.has_key?(:verification_user_id)).to be(false)
      end
    end

    context 'when identity verification is turned on' do
      before do
        allow_next_found_instance_of(User) do |user|
          allow(user).to receive(:signup_identity_verification_enabled?).and_return(true)
        end
      end

      it { is_expected.to redirect_to(signup_identity_verification_path) }

      it 'sets the `verification_user_id` session variable' do
        sign_in

        expect(request.session[:verification_user_id]).to eq(user.id)
      end

      context 'when the user is verified' do
        before do
          allow_next_found_instance_of(User) do |user|
            allow(user).to receive(:signup_identity_verified?).and_return(true)
          end
        end

        it { is_expected.to redirect_to(root_path) }
      end

      context 'when the user is locked' do
        before do
          user.lock_access!
        end

        it { is_expected.not_to have_gitlab_http_status(:redirect) }
      end

      context 'when the user is a GitLab QA user' do
        before do
          allow(Gitlab::Qa).to receive(:request?).and_return(true)
        end

        it { is_expected.not_to redirect_to(signup_identity_verification_path) }
      end
    end
  end

  describe 'GET /users/sign_in_path', :saas do
    let_it_be_with_reload(:user) { create(:user) }

    let(:valid_challenge) { 'a' * 64 }
    let(:iam_service_url) { 'https://iam.example.com' }

    before do
      stub_feature_flags(two_step_sign_in: true, iam_svc_login: true)
      allow(Authn::IamAuthService).to receive_messages(enabled?: true, url: iam_service_url)
    end

    def parsed_sign_in_params
      Rack::Utils.parse_query(URI.parse(json_response['sign_in_path']).query)
    end

    context 'when user is not found in default cell and login challenge is in session' do
      it 'includes the challenge value in the redirect URL', :aggregate_failures do
        get new_user_session_path, params: { login_challenge: valid_challenge }
        get users_sign_in_path_path, params: { login: 'cell2_user' }, as: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_sign_in_params['login_challenge']).to eq(valid_challenge)
        expect(parsed_sign_in_params['login']).to eq('cell2_user')
      end
    end

    context 'when user is not found in default cell and no login challenge is in session' do
      it 'does not include challenge in the redirect URL', :aggregate_failures do
        get users_sign_in_path_path, params: { login: 'cell2_user' }, as: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(parsed_sign_in_params).not_to have_key('login_challenge')
        expect(parsed_sign_in_params['login']).to eq('cell2_user')
      end
    end

    context 'when user is found on current cell' do
      it 'returns nil sign_in_path regardless of challenge' do
        get new_user_session_path, params: { login_challenge: valid_challenge }
        get users_sign_in_path_path, params: { login: user.username }, as: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['sign_in_path']).to be_nil
      end
    end
  end
end
