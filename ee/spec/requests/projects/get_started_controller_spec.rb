# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GetStartedController, :saas, feature_category: :onboarding do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, namespace: namespace) }

  describe 'GET /:namespace/:project/-/get_started' do
    let(:onboarding_enabled?) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled?)
    end

    subject(:get_show) do
      get project_get_started_path(project), params: { project_id: project.to_param }

      response
    end

    context 'for unauthenticated user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'for authenticated user' do
      before do
        sign_in(user)
      end

      context 'when get started is available' do
        before do
          create(:onboarding_progress, namespace: namespace)
        end

        it { is_expected.to render_template(:show) }

        context 'when onboarding is not available' do
          let(:onboarding_enabled?) { false }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when namespace is not onboarding' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end

  describe 'PATCH #end_tutorial' do
    subject(:patch_end_tutorial) do
      patch end_tutorial_project_get_started_path(project)
      response
    end

    it 'for unauthenticated user' do
      patch_end_tutorial
      expect(response).to have_gitlab_http_status(:redirect)
    end

    context 'for authenticated user' do
      before do
        sign_in(user)
      end

      context "when namespace is onboarding" do
        let_it_be_with_reload(:onboarding_progress) { create(:onboarding_progress, namespace: namespace) }

        context 'when onboarding is not available' do
          before do
            stub_saas_features(onboarding: false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when update is successful' do
          it 'sets onboarding progress ended value and triggers tracking' do
            expect { patch_end_tutorial }
              .to trigger_internal_events('click_end_tutorial_button')
              .with(
                user: user,
                project: project,
                namespace: namespace,
                additional_properties: {
                  label: 'get_started',
                  property: 'progress_percentage_on_end',
                  value: 0
                }
              )

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'success' => true, 'redirect_path' => project_path(project) })
            expect(flash[:success]).to eql("You've ended the tutorial.")
            expect(onboarding_progress.ended_at).to be_present
          end

          context 'when update has an error' do
            before do
              allow(onboarding_progress).to receive(:update).and_return(false)
              allow_next_instance_of(described_class) do |instance|
                allow(instance).to receive(:onboarding_progress).and_return(onboarding_progress)
              end
            end

            it 'does not update the onboarding progress and shows an error message' do
              error = "There was a problem trying to end the tutorial. Please try again."
              expect { patch_end_tutorial }.not_to change { onboarding_progress.reload.ended_at }

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response).to eq({ 'success' => false, 'message' => error })
            end

            it 'does not trigger tracking' do
              expect { patch_end_tutorial }.not_to trigger_internal_events('click_end_tutorial_button')
            end
          end
        end
      end

      context 'when namespace is not onboarding' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
