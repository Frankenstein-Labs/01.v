# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::UsersController, feature_category: :user_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    let_it_be(:user_2) { create(:user) }

    let_it_be(:user_role_1) { create(:user_member_role, user: user) }
    let_it_be(:user_role_2) { create(:user_member_role, user: user_2) }

    it 'eager loads obstacles to user deletion' do
      get :index

      expect(assigns(:users).first.association(:oncall_schedules)).to be_loaded
      expect(assigns(:users).first.association(:escalation_policies)).to be_loaded
    end

    it 'filters by admin custom role' do
      get :index, params: { admin_role_id: user_role_2.member_role.id }

      expect(assigns(:users)).to eq([user_2])
    end

    context 'with search by partial email' do
      subject(:request) { get :index, params: { search_query: user.email[1...-1] } }

      context 'when disable_partial_email_search feature is enabled', :saas_disable_partial_email_search do
        it 'does not search users by partial email' do
          request

          expect(assigns(:users)).to eq([])
        end
      end

      context 'when disable_partial_email_search feature is not enabled' do
        it 'searches users by partial email' do
          request

          expect(assigns(:users)).to eq([user])
        end
      end
    end
  end

  describe 'POST #create' do
    context 'when no user is returned' do
      before do
        allow_next_instance_of(Users::CreateService) do |service|
          allow(service).to receive(:execute).and_return(
            ServiceResponse.error(message: 'This is an error')
          )
        end

        post :create, params: { user: attributes_for(:user) }
      end

      it 'redirects to admin path' do
        expect(response).to redirect_to(admin_users_path)
      end

      it 'sets a flash notice' do
        expect(controller).to set_flash[:notice].to('This is an error')
      end
    end
  end

  describe 'POST #update' do
    context 'update custom attributes' do
      let!(:custom_attribute) do
        user.custom_attributes.create!(key: UserCustomAttribute::ARKOSE_RISK_BAND,
          value: Arkose::VerifyResponse::RISK_BAND_MEDIUM)
      end

      let(:params) do
        {
          id: user.to_param,
          user: {
            custom_attributes_attributes: {
              id: custom_attribute.to_param,
              value: Arkose::VerifyResponse::RISK_BAND_LOW
            }
          }
        }
      end

      it 'updates the value' do
        expect { put :update, params: params }
          .to change { user.custom_attributes.by_key('arkose_risk_band').first.value }.from('Medium').to('Low')

        expect(response).to redirect_to(admin_user_path(user))
      end
    end

    context 'updating name' do
      shared_examples_for 'admin can update the name of a user' do
        it 'updates the name' do
          params = {
            id: user.to_param,
            user: {
              name: 'New Name'
            }
          }

          put :update, params: params

          expect(response).to redirect_to(admin_user_path(user))
          expect(user.reload.name).to eq('New Name')
        end
      end

      context 'when `disable_name_update_for_users` feature is available' do
        before do
          stub_licensed_features(disable_name_update_for_users: true)
        end

        context 'when the ability to update their name is disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: true)
          end

          it_behaves_like 'admin can update the name of a user'
        end

        context 'when the ability to update their name is not disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: false)
          end

          it_behaves_like 'admin can update the name of a user'
        end
      end

      context 'when `disable_name_update_for_users` feature is not available' do
        before do
          stub_licensed_features(disable_name_update_for_users: false)
        end

        it_behaves_like 'admin can update the name of a user'
      end
    end
  end

  describe 'POST #reset_runner_minutes' do
    subject(:post_reset_runners_minutes) { post :reset_runners_minutes, params: { id: user } }

    before do
      allow_next_instance_of(Ci::Minutes::ResetUsageService) do |instance|
        allow(instance).to receive(:execute).and_return(clear_runners_minutes_service_result)
      end
    end

    context 'when the reset is successful' do
      let(:clear_runners_minutes_service_result) { true }

      it 'redirects to group path' do
        post_reset_runners_minutes

        expect(response).to redirect_to(admin_user_path(user))
        expect(controller).to set_flash[:notice]
      end
    end
  end

  describe "POST #impersonate" do
    let_it_be(:user) { create(:user) }

    before do
      stub_licensed_features(extended_audit_events: true)
    end

    it 'enqueues a new worker' do
      expect(AuditEvents::UserImpersonationEventCreateWorker).to receive(:perform_async).with(admin.id, user.id,
        anything, 'started', DateTime.current).once

      post :impersonate, params: { id: user.username }
    end
  end

  describe 'POST #identity_verification_exemption' do
    before do
      allow(controller).to receive(:find_routable!).and_return(user)
    end

    subject(:post_identity_verification_exemption) do
      post :identity_verification_exemption, params: { id: user.to_param }
    end

    context 'when it is successful' do
      it 'calls add_identity_verification_exemption and redirects with a success notice' do
        expect(user).to receive(:add_identity_verification_exemption).once.with(
          "set by #{admin.username}"
        ).and_call_original

        post_identity_verification_exemption

        expect(controller).to set_flash[:notice].to(_('Added identity verification exemption.'))
        expect(response).to redirect_to(admin_user_path(user))
      end
    end

    context 'when it fails' do
      it 'calls add_identity_verification_exemption and redirects with an alert' do
        expect(user).to receive(:add_identity_verification_exemption).once.and_return(false)

        post_identity_verification_exemption

        expect(controller).to set_flash[:alert].to(_('Something went wrong. Unable to add identity verification exemption.'))
        expect(response).to redirect_to(admin_user_path(user))
      end
    end
  end

  describe 'DELETE #destroy_identity_verification_exemption' do
    before do
      allow(controller).to receive(:find_routable!).and_return(user)
    end

    subject(:delete_identity_verification_exemption) do
      delete :destroy_identity_verification_exemption, params: { id: user.to_param }
    end

    context 'when it is successful' do
      it 'calls remove_identity_verification_exemption and redirects with a success notice' do
        expect(user).to receive(:remove_identity_verification_exemption).once.and_return(instance_double(UserCustomAttribute))

        delete_identity_verification_exemption

        expect(controller).to set_flash[:notice].to(_('Removed identity verification exemption.'))
        expect(response).to redirect_to(admin_user_path(user))
      end
    end

    context 'when it fails' do
      it 'calls remove_identity_verification_exemption and redirects with an alert' do
        expect(user).to receive(:remove_identity_verification_exemption).once.and_return(false)

        delete_identity_verification_exemption

        expect(controller).to set_flash[:alert].to(_('Something went wrong. Unable to remove identity verification exemption.'))
        expect(response).to redirect_to(admin_user_path(user))
      end
    end
  end

  describe 'GET #card_match', :saas do
    it 'redirects with no match notice by default' do
      get :card_match, params: { id: user.to_param }

      expect(controller).to set_flash[:notice].to(_('No credit card data for matching'))
      expect(response).to redirect_to(admin_user_path(user))
    end

    context 'when the user has a validated credit card' do
      before do
        create(:credit_card_validation, user: user)
      end

      it 'loads the matching credit card page' do
        get :card_match, params: { id: user.to_param }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'GET #phone_match', :saas do
    it 'redirects with no match notice by default' do
      get :phone_match, params: { id: user.to_param }

      expect(controller).to set_flash[:notice].to(_('No phone number data for matching'))
      expect(response).to redirect_to(admin_user_path(user))
    end

    context 'when the user has a validated phone number' do
      before do
        create(:phone_number_validation, user: user)
      end

      it 'loads the matching phone number page' do
        get :phone_match, params: { id: user.to_param }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
