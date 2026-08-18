# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::LearnGitlabController, :saas, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  let(:params) { { namespace_id: namespace.to_param, project_id: project } }

  before_all do
    namespace.add_owner(user)
  end

  describe 'GET #show' do
    subject(:action) { get :show, params: params }

    context 'for unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'for authenticated user' do
      before do
        sign_in(user)
      end

      context 'when learn gitlab is available' do
        before do
          create(:onboarding_progress, namespace: namespace)
        end

        it { is_expected.to render_template(:show) }

        context 'when not on gitlab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when learn_gitlab is not available' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end

  describe 'PATCH #end_tutorial' do
    subject(:patch_end_tutorial) { patch :end_tutorial, params: params }

    context 'for unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'for authenticated user' do
      let_it_be_with_reload(:onboarding_progress) { create(:onboarding_progress, namespace: namespace) }

      before do
        sign_in(user)
      end

      context 'when update is successful' do
        it 'updates the onboarding progress ended value to be set and triggers tracking' do
          expect { patch_end_tutorial }
            .to trigger_internal_events('click_end_tutorial_button')
            .with(
              user: user,
              project: project,
              namespace: namespace,
              additional_properties: {
                label: 'learn_gitlab',
                property: 'progress_percentage_on_end',
                value: 8
              }
            )

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({ 'success' => true, 'redirect_path' => project_path(project) })
          expect(flash[:success]).to eql("You've ended the Learn GitLab tutorial.")
          expect(onboarding_progress.ended_at).to be_present
        end
      end

      context 'when update has an error' do
        before do
          allow(controller).to receive(:onboarding_progress).and_return(onboarding_progress)
          allow(onboarding_progress).to receive(:update).and_return(false)
        end

        it 'does not update the onboarding progress and shows an error message' do
          error = "There was a problem trying to end the Learn GitLab tutorial. Please try again."
          expect { patch_end_tutorial }.not_to change { onboarding_progress.reload.ended_at }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({ 'success' => false, 'message' => error })
        end

        it 'does not trigger tracking' do
          expect { patch_end_tutorial }.to not_trigger_internal_events('click_end_tutorial_button')
        end
      end
    end
  end
end
