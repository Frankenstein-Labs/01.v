# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SelfManaged::TrialsController, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  describe 'GET new' do
    subject(:get_new) do
      get '/-/trials/new'
      response
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        expect(get_new).to redirect_to_sign_in
      end
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      context 'when not on GitLab.com' do
        it 'renders the trial form' do
          expect(get_new).to have_gitlab_http_status(:ok)
          expect(response.body).to include(_('Start your free Ultimate trial!'))
        end
      end
    end
  end

  describe 'POST create' do
    let(:trial_params) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email_address: 'john@example.com',
        company_name: 'ACME Corp',
        country: 'US',
        state: 'CA',
        consent_to_marketing: '1'
      }
    end

    subject(:post_create) do
      post '/-/trials', params: trial_params
      response
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        expect(post_create).to redirect_to_sign_in
      end
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      context 'when on self managed' do
        context 'when trial submission succeeds' do
          before do
            allow_next_instance_of(GitlabSubscriptions::SelfManaged::CreateTrialService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.success)
            end
          end

          it 'redirects to admin projects path' do
            expect(post_create).to redirect_to(dashboard_projects_path)
          end

          it 'tracks the success banner render event' do
            expect { post_create }
              .to trigger_internal_events('sm_trial_create_form_success_banner_render')
              .with(user: user)
          end

          it 'sets the success flash message' do
            post_create
            expect(flash[:success]).to eq(
              s_('Trial|You have successfully started an Ultimate trial for GitLab.')
            )
          end
        end

        context 'when trial submission fails with form_failure reason' do
          let(:error_message) do
            s_(
              'Trial|This email address was already registered for a trial. Please enter a different email address.'
            )
          end

          before do
            allow_next_instance_of(GitlabSubscriptions::SelfManaged::CreateTrialService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(
                  message: error_message,
                  reason: GitlabSubscriptions::SelfManaged::CreateTrialService::FORM_FAILURE
                )
              )
            end
          end

          it 're-renders the trial form' do
            expect(post_create).to have_gitlab_http_status(:ok)
            expect(response.body).to include(_('Start your free Ultimate trial!'))
            expect(response.body).not_to include(_('Trial registration unsuccessful'))
          end

          it 'sets the alert flash message' do
            post_create
            expect(flash[:alert]).to eq(error_message)
          end
        end

        context 'when trial submission fails with generic error' do
          let(:error_message) do
            s_('Trial|Please reach out to %{support_link_start}GitLab Support%{support_link_end} for assistance.')
          end

          before do
            allow_next_instance_of(GitlabSubscriptions::SelfManaged::CreateTrialService) do |service|
              allow(service).to receive(:execute).and_return(
                ServiceResponse.error(message: error_message, reason: :generic_failure)
              )
            end
          end

          it 'renders the resubmit component' do
            expect(post_create).to have_gitlab_http_status(:ok)
            expect(response.body).to include(_('Trial registration unsuccessful'))
          end

          it 'displays the error message with support link' do
            post_create
            expect(response.body).to include('GitLab Support')
            expect(response.body).to include(Gitlab::Saas.customer_support_url)
          end
        end

        context 'when extra params are submitted' do
          let(:trial_params) { super().merge(malicious_field: 'ignored', admin: true) }

          it 'only passes permitted params to the service' do
            expect_next_instance_of(
              GitlabSubscriptions::SelfManaged::CreateTrialService,
              params: ActionController::Parameters.new(trial_params).permit(
                :first_name, :last_name, :email_address, :company_name,
                :country, :state, :consent_to_marketing
              ),
              user: user
            ) do |service|
              expect(service).to receive(:execute).and_return(ServiceResponse.success)
            end

            post_create
          end
        end
      end

      context 'when the in_instance_self_managed_trial_activation feature flag is disabled' do
        before do
          stub_feature_flags(in_instance_self_managed_trial_activation: false)
        end

        it 'has no matching route' do
          expect { post_create }.to raise_error(
            ActionController::RoutingError, %r{No route matches \[POST\] "/-/trials"}
          )
        end
      end

      context 'when on GitLab.com', :saas_subscriptions_trials do
        it 'returns 404' do
          expect(post_create).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
