# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Sessions', feature_category: :system_access do
  include SessionHelpers

  let_it_be(:user, freeze: false) { create(:user, :with_namespace) }

  describe '.set_marketing_user_cookies', :saas do
    context 'when the gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when user signs in' do
        it 'sets marketing cookies' do
          post user_session_path(user: { login: user.username, password: user.password })

          expect(response.cookies['gitlab_user']).to be_present
          expect(response.cookies['gitlab_tier']).to be_present
        end

        context 'with multiple plans' do
          it 'sets marketing tier cookie with plan names' do
            create(:group_with_plan, plan: :free_plan, owners: user)
            create(:group_with_plan, plan: :ultimate_plan, owners: user)

            post user_session_path(user: { login: user.username, password: user.password })

            expect(response.cookies['gitlab_tier']).to eq 'free&ultimate'
          end
        end
      end

      context 'when user uses remember_me' do
        it 'sets the marketing cookies' do
          post user_session_path(user: { login: user.username, password: user.password, remember_me: true })

          expect(response.cookies['gitlab_user']).to be_present
          expect(response.cookies['gitlab_tier']).to be_present
        end
      end
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not set the marketing cookies' do
        post user_session_path(user: { login: user.username, password: user.password })

        expect(response.cookies['gitlab_user']).to be_nil
        expect(response.cookies['gitlab_tier']).to be_nil
      end
    end
  end

  describe '.unset_marketing_user_cookies', :saas do
    let(:cookie_domain) { ::Gitlab.config.gitlab.host }

    before do
      sign_in(user)
    end

    context 'when the gitlab_com_subscriptions saas feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'unsets marketing cookies' do
        post destroy_user_session_path

        expect(response.cookies).to have_key('gitlab_user')
        expect(response.cookies).to have_key('gitlab_tier')

        expect(response.cookies['gitlab_user']).to be_nil
        expect(response.cookies['gitlab_tier']).to be_nil
      end
    end

    context 'when the gitlab_com_subscriptions saas feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not unset or modify the marketing cookies' do
        post destroy_user_session_path

        expect(response.cookies).not_to have_key('gitlab_user')
        expect(response.cookies).not_to have_key('gitlab_tier')
      end
    end
  end

  describe 'GET /users/sign_in_path', :saas_redirect_sign_in_when_login_not_found do
    before do
      stub_feature_flags(two_step_sign_in: true)
    end

    shared_examples 'returns nil sign_in_path' do |login_value|
      it 'returns nil' do
        params = login_value.nil? ? {} : { login: login_value }
        get users_sign_in_path_path, params: params, as: :json

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'sign_in_path' => nil })
      end
    end

    context 'when redirect_sign_in_when_login_not_found saas feature is available' do
      context 'when requesting JSON format' do
        it 'renders 404 when the feature flag is disabled' do
          stub_feature_flags(two_step_sign_in: false)

          get users_sign_in_path_path, params: { login: 'nonexistant' }, as: :json

          expect(response).to have_gitlab_http_status(:not_found)
        end

        context 'when login parameter is not provided' do
          it_behaves_like 'returns nil sign_in_path', nil
        end

        context 'when login parameter is blank' do
          it_behaves_like 'returns nil sign_in_path', ''
        end

        context 'when user is found by username' do
          it_behaves_like 'returns nil sign_in_path', -> { user.username }
        end

        context 'when login is not a string' do
          it 'ensures User.find_by_login does not receive an array' do
            array_param = [user.username, 'attacker@example.com']

            expect(User).not_to receive(:find_by_login)

            get users_sign_in_path_path, params: { login: array_param }, as: :json

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'sign_in_path' => nil })
          end
        end

        context 'when login parameter exceeds maximum length' do
          it 'truncates login to MAX_USERNAME_LENGTH characters' do
            long_login = 'a' * 300
            truncated_login = 'a' * ::User::MAX_USERNAME_LENGTH

            expect(User).to receive(:find_by_login).with(truncated_login).and_call_original

            get users_sign_in_path_path, params: { login: long_login }, as: :json

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'sign_in_path' => "/users/sign_in?login=#{truncated_login}" })
          end

          it 'handles login at exactly MAX_USERNAME_LENGTH characters' do
            exact_length_login = 'b' * ::User::MAX_USERNAME_LENGTH

            expect(User).to receive(:find_by_login).with(exact_length_login).and_call_original

            get users_sign_in_path_path, params: { login: exact_length_login }, as: :json

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'sign_in_path' => "/users/sign_in?login=#{exact_length_login}" })
          end
        end

        context 'when user is found by email' do
          it_behaves_like 'returns nil sign_in_path', -> { user.email }
        end

        context 'when user is not found' do
          it 'returns sign in path with login parameter' do
            get users_sign_in_path_path, params: { login: 'nonexistent' }, as: :json

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'sign_in_path' => '/users/sign_in?login=nonexistent' })
          end
        end
      end

      context 'when requesting HTML format' do
        it 'returns 404' do
          get users_sign_in_path_path, as: :html

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when redirect_sign_in_when_login_not_found feature is disabled' do
      it_behaves_like 'returns nil sign_in_path', -> { 'nonexistent' }
    end
  end
end
