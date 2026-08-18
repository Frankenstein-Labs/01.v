# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::WelcomeController, feature_category: :onboarding do
  let_it_be_with_reload(:user) { create(:user, onboarding_in_progress: true, onboarding_status_email_opt_in: false) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  shared_examples 'user not in onboarding' do
    before do
      user.update!(onboarding_in_progress: false)
    end

    it { is_expected.to redirect_to(root_path) }
  end

  describe '#show' do
    let(:show_params) { {} }

    subject(:get_show) { get :show, params: show_params }

    context 'with signed in user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'user not in onboarding'

      context 'when onboarding feature is not available' do
        let(:onboarding_enabled?) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when completed welcome step' do
        context 'when onboarding_status_setup_for_company is set to false' do
          before do
            user.update!(onboarding_status_setup_for_company: false)
            sign_in(user)
          end

          it { is_expected.to redirect_to(dashboard_projects_path) }
        end
      end

      context 'when 2FA is required from group' do
        before do
          user = create(:user, onboarding_in_progress: true, require_two_factor_authentication_from_group: true)
          sign_in(user)
        end

        it { is_expected.not_to redirect_to(profile_two_factor_auth_path) }
      end

      context 'when welcome step is completed' do
        before do
          user.update!(onboarding_status_setup_for_company: true)
        end

        context 'when user is confirmed' do
          before do
            sign_in(user)
          end

          it { is_expected.not_to redirect_to user_session_path }
        end

        context 'when user is not confirmed' do
          before do
            stub_application_setting_enum('email_confirmation_setting', 'hard')

            sign_in(user)

            user.update!(confirmed_at: nil)
          end

          it { is_expected.to redirect_to user_session_path }
        end
      end
    end
  end
end
