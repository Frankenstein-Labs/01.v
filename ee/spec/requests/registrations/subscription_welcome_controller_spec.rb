# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::SubscriptionWelcomeController, :with_current_organization, feature_category: :onboarding do
  include SessionHelpers

  let(:onboarding_enabled?) { true }

  before do
    stub_saas_features(onboarding: onboarding_enabled?)
  end

  shared_examples 'onboarding is not available' do
    context 'when user is not in onboarding' do
      before do
        user.update!(onboarding_in_progress: false)
      end

      it { is_expected.to redirect_to(root_path) }
    end

    context 'when onboarding feature is not available' do
      let(:onboarding_enabled?) { false }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end

  describe 'GET show' do
    let_it_be_with_reload(:user) do
      create(
        :user, onboarding_in_progress: true, onboarding_status_email_opt_in: false,
        onboarding_status_registration_type: 'subscription'
      )
    end

    subject(:get_show) do
      get users_sign_up_welcome_path
      response
    end

    context 'with signed in user' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it_behaves_like 'onboarding is not available'

      context 'when 2FA is required from group' do
        before do
          user.update!(require_two_factor_authentication_from_group: true)
          sign_in(user)
        end

        it { is_expected.not_to redirect_to(profile_two_factor_auth_path) }
      end

      context 'when the welcome step is completed' do
        before do
          user.update!(onboarding_status_setup_for_company: true)
        end

        context 'when user is confirmed' do
          before do
            sign_in(user)
          end

          it { is_expected.to redirect_to(users_sign_up_customers_portal_redirect_path) }
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

  describe 'PUT update' do
    let(:user) do
      create(
        :user, onboarding_in_progress: true, onboarding_status_email_opt_in: false,
        onboarding_status_registration_type: 'subscription'
      )
    end

    let(:update_params) do
      {
        first_name: 'Test',
        last_name: 'User',
        company_name: 'Test Company',
        group_name: 'test-group',
        project_name: 'test-project'
      }
    end

    subject(:patch_update) do
      put users_sign_up_welcome_path, params: update_params
      response
    end

    context 'with a signed in user' do
      before do
        sign_in(user)
      end

      it_behaves_like 'onboarding is not available'

      context 'when namespace creation is successful' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:project) { create(:project, namespace: namespace) }

        before do
          expect_subscription_namespace_create_service do
            ServiceResponse.success(payload: { namespace: namespace, project: project })
          end
        end

        it 'redirects to the customers portal redirect path' do
          expect(patch_update).to redirect_to(users_sign_up_customers_portal_redirect_path)
        end

        it 'sets the namespace id in the user return to session', :clean_gitlab_redis_sessions do
          stub_session(session_data: { user_return_to: new_subscriptions_path })
          patch_update

          uri = Gitlab::Utils.parse_url(session['user_return_to'])
          expect(uri.query_values['namespace_id']).to eq(namespace.id.to_s)
        end
      end

      context 'when namespace creation fails' do
        before do
          expect_subscription_namespace_create_service do
            ServiceResponse.error(
              message: 'Namespace creation failed',
              reason: Onboarding::SubscriptionNamespaceCreateService::NAMESPACE_CREATE_FAILED,
              payload: { namespace_id: nil, model_errors: { group_name: 'has already been taken' } }
            )
          end
        end

        it 'renders the form with group_flow step' do
          patch_update

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('has already been taken')
          expect(response.body).to include("step=#{Onboarding::SubscriptionNamespaceCreateService::GROUP_FLOW}")
        end
      end

      context 'when project creation fails' do
        before do
          expect_subscription_namespace_create_service do
            ServiceResponse.error(
              message: 'Project creation failed',
              reason: Onboarding::SubscriptionNamespaceCreateService::PROJECT_CREATE_FAILED,
              payload: { namespace_id: 1, model_errors: { project_name: 'has already been taken' } }
            )
          end
        end

        it 'renders the form with project_flow step' do
          patch_update

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('has already been taken')
          expect(response.body).to include("step=#{Onboarding::SubscriptionNamespaceCreateService::PROJECT_FLOW}")
        end
      end

      context 'when lead creation fails' do
        before do
          expect_subscription_namespace_create_service do
            ServiceResponse.error(
              message: '',
              payload: { namespace_id: 1, project_id: 1 }
            )
          end
        end

        it 'renders the resubmit form with lead_flow step' do
          patch_update

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include("step=#{Onboarding::SubscriptionNamespaceCreateService::LEAD_FLOW}")
        end
      end

      context 'when not found' do
        before do
          expect_subscription_namespace_create_service do
            ServiceResponse.error(
              message: 'Not found',
              reason: Onboarding::SubscriptionNamespaceCreateService::NOT_FOUND
            )
          end
        end

        it 'returns not found' do
          expect(patch_update).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  def expect_subscription_namespace_create_service
    allow_next_instance_of(::Onboarding::SubscriptionNamespaceCreateService) do |instance|
      expect(instance).to receive(:execute).and_return(yield)
    end
  end
end
