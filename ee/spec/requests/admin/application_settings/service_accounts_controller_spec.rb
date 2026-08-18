# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::ApplicationSettings::ServiceAccountsController, :enable_admin_mode, feature_category: :user_management do
  let_it_be(:admin) { create(:admin) }

  shared_examples 'not found' do
    it 'is not found' do
      get_method

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'access control' do |licenses|
    context 'with non-admin user' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'not found'
    end

    context 'when no user is logged in' do
      it 'redirects to login page' do
        get_method

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    context 'with an admin user' do
      before do
        sign_in(admin)
      end

      context 'when no suitable license is available' do
        it 'returns a 200 status code' do
          get_method

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when a suitable license is available' do
        using RSpec::Parameterized::TableSyntax

        where(license: licenses)

        with_them do
          it 'returns a 200 status code' do
            get_method

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'when on SaaS' do
            before do
              stub_saas_features(gitlab_com_subscriptions: true)
            end

            it_behaves_like 'not found'
          end
        end
      end
    end
  end

  describe 'GET #index' do
    subject(:get_method) { get admin_application_settings_service_accounts_path }

    it_behaves_like 'access control', [:default_roles_assignees]
  end
end
