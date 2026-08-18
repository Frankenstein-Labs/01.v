# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Ai::DuoWorkflowSettingsController, :with_current_organization, :enable_admin_mode, feature_category: :ai_abstraction_layer do
  let_it_be(:admin) { create(:admin, organizations: [current_organization]) }

  let(:actual_view_model) do
    Gitlab::Json.parse(
      Nokogiri::HTML(response.body).css('#js-duo-workflow-settings').first['data-view-model']
    )
  end

  before do
    allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
    sign_in(admin)
  end

  describe 'POST #create' do
    context 'when Duo Workflow is enabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
      end

      context 'when Duo Workflow is already connected' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(true)
        end

        it 'ensures service account is unblocked' do
          expect(::Ai::DuoWorkflow).to receive(:ensure_service_account_unblocked!)
                                         .with(current_user: admin)
                                         .and_return(ServiceResponse.success)

          post admin_ai_duo_workflow_settings_path

          expect(response).to redirect_to(admin_gitlab_duo_path)
          expect(flash[:notice]).to eq('Duo Agent Platform Settings have been saved')
        end

        it 'handles failure to unblock service account' do
          expect(::Ai::DuoWorkflow).to receive(:ensure_service_account_unblocked!)
                                         .with(current_user: admin)
                                         .and_return(ServiceResponse.error(message: 'Failed to unblock'))

          post admin_ai_duo_workflow_settings_path

          expect(response).to redirect_to(admin_gitlab_duo_path)
          expect(flash[:alert]).to eq('Failed to unblock')
        end
      end

      context 'when Duo Workflow is not connected' do
        let(:onboarding_service) { instance_double(::Ai::DuoWorkflows::OnboardingService) }

        before do
          allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(false)
          allow(::Ai::DuoWorkflows::OnboardingService).to receive(:new)
            .with(current_user: admin, organization: current_organization)
            .and_return(onboarding_service)
        end

        it 'executes the onboarding service successfully' do
          expect(onboarding_service).to receive(:execute).and_return(ServiceResponse.success)

          post admin_ai_duo_workflow_settings_path

          expect(response).to redirect_to(admin_gitlab_duo_path)
          expect(flash[:notice]).to eq('Duo Agent Platform Settings have been saved')
        end

        it 'handles onboarding service failure' do
          expect(onboarding_service).to receive(:execute)
                                          .and_return(ServiceResponse.error(message: 'Onboarding failed'))

          post admin_ai_duo_workflow_settings_path

          expect(response).to redirect_to(admin_gitlab_duo_path)
          expect(flash[:alert]).to eq('Onboarding failed')
        end

        it 'uses default error message when service response has no message' do
          expect(onboarding_service).to receive(:execute)
                                          .and_return(ServiceResponse.error(message: nil))

          post admin_ai_duo_workflow_settings_path

          expect(response).to redirect_to(admin_gitlab_duo_path)
          expect(flash[:alert]).to eq('Something went wrong saving Duo Agent Platform settings')
        end
      end
    end

    context 'when Duo Workflow is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(false)
      end

      it 'returns 404' do
        post admin_ai_duo_workflow_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'POST #disconnect' do
    context 'when Duo Workflow is enabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(true)
      end

      context 'when Duo Workflow is connected' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(true)
        end

        it 'ensures service account is blocked' do
          expect(::Ai::DuoWorkflow).to receive(:ensure_service_account_blocked!)
                                         .with(current_user: admin)
                                         .and_return(ServiceResponse.success)

          post disconnect_admin_ai_duo_workflow_settings_path

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'handles failure to block service account' do
          expect(::Ai::DuoWorkflow).to receive(:ensure_service_account_blocked!)
                                         .with(current_user: admin)
                                         .and_return(ServiceResponse.error(message: 'Failed to block'))

          post disconnect_admin_ai_duo_workflow_settings_path

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Failed to block')
        end
      end

      context 'when Duo Workflow is not connected' do
        before do
          allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(false)
        end

        it 'returns unprocessable_entity' do
          post disconnect_admin_ai_duo_workflow_settings_path

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end
    end

    context 'when Duo Workflow is disabled' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:enabled?).and_return(false)
      end

      it 'returns 404' do
        post disconnect_admin_ai_duo_workflow_settings_path

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
