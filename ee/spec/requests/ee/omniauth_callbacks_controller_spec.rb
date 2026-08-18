# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniauthCallbacksController, feature_category: :system_access do
  include LoginHelpers
  include SessionHelpers

  context 'with strategies', :aggregate_failures do
    let(:provider) { :github }
    let(:check_namespace_plan) { true }

    before do
      stub_omniauth_setting(block_auto_created_users: false)
      mock_auth_hash(provider.to_s, 'my-uid', user.email)
    end

    around do |example|
      with_omniauth_full_host { example.run }
    end

    context 'when user is not registered yet', :with_current_organization, :clean_gitlab_redis_sessions do
      let(:user) { build_stubbed(:user, email: 'new@example.com') }
      let(:path) { '/user/return/to/path' }

      before do
        stub_session(session_data: { user_return_to: path })
      end

      context 'when onboarding is enabled', :saas do
        it 'wipes the previously stored location for user' do
          expect_next_instance_of(described_class) do |controller|
            expect(controller).to receive(:store_location_for).with(:user, users_sign_up_welcome_path)
          end

          post public_send("user_#{provider}_omniauth_callback_path")

          expect(request.env['warden']).to be_authenticated
        end
      end

      context 'when onboarding is disabled' do
        it 'does not wipe the previously stored location for user' do
          expect_next_instance_of(described_class) do |controller|
            expect(controller).to receive(:store_location_for).with(:user, path)
          end

          post public_send("user_#{provider}_omniauth_callback_path")

          expect(request.env['warden']).to be_authenticated
        end
      end

      context 'when user is in subscription onboarding' do
        let(:path) { new_subscriptions_path(plan_id: 'bronze_id') }

        it 'preserves the previously stored location for user' do
          expect_next_instance_of(described_class) do |controller|
            expect(controller).not_to receive(:store_location_for).with(:user)
          end

          post public_send("user_#{provider}_omniauth_callback_path")

          expect(request.env['warden']).to be_authenticated
        end
      end
    end
  end

  describe 'audit event on a rejected OAuth login', :with_current_organization do
    let(:extern_uid) { 'collision-uid' }
    let_it_be(:existing_user) { create(:user, email: 'collision@example.com') }

    before do
      stub_licensed_features(extended_audit_events: true)
      stub_omniauth_setting(enabled: true, auto_link_user: false, allow_single_sign_on: ['atlassian_oauth2'])
      stub_omniauth_setting(block_auto_created_users: false)
      mock_auth_hash('atlassian_oauth2', extern_uid, existing_user.email)
    end

    around do |example|
      with_omniauth_full_host { example.run }
    end

    shared_examples 'records the failed-login audit event' do
      it 'creates a security event for the rejected login' do
        expect { post '/users/auth/atlassian_oauth2/callback' }
          .to change { AuditEventReader.where(entity_type: 'User', entity_id: -1).count }.from(0).to(1)

        expect(request.env['warden']).not_to be_authenticated
        expect(AuditEventReader.last.details).to include(failed_login: 'ATLASSIAN_OAUTH2')
      end
    end

    it_behaves_like 'records the failed-login audit event'

    it 'diverts to the identity-link prompt' do
      post '/users/auth/atlassian_oauth2/callback'

      expect(response).to redirect_to(new_user_session_path)
    end

    context 'when link_omniauth_to_existing_user_on_login is disabled' do
      before do
        stub_feature_flags(link_omniauth_to_existing_user_on_login: false)
      end

      it_behaves_like 'records the failed-login audit event'

      it 'renders the 422 error page' do
        post '/users/auth/atlassian_oauth2/callback'

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end
    end
  end
end
