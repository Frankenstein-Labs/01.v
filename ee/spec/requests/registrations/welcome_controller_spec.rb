# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::WelcomeController, :with_current_organization, :snowplow, feature_category: :onboarding do
  let_it_be_with_reload(:user) do
    create(:user, organizations: [current_organization],
      onboarding_in_progress: true, onboarding_status_email_opt_in: false)
  end

  before do
    stub_saas_features(onboarding: true)
    sign_in(user)
  end

  def parsed_view_model(body)
    ::Gitlab::Json.safe_parse(Nokogiri::HTML(body).at_css('#js-free-welcome-form')['data-view-model'])
  end

  context 'for the unified free registration flow' do
    describe 'GET #show' do
      subject(:get_show) { get users_sign_up_welcome_path }

      it 'renders the unified two-panel welcome form' do
        get_show

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('js-free-welcome-form')
      end

      it 'seeds the full step into the form submit path' do
        get_show

        expect(parsed_view_model(response.body)['submitPath']).to eq(
          users_sign_up_welcome_path(step: ::Onboarding::FreeNamespaceCreateService::FULL)
        )
      end
    end

    describe 'PATCH #update' do
      let_it_be(:project) { create(:project, namespace: create(:group, organization: current_organization)) }

      let(:update_params) do
        {
          step: ::Onboarding::FreeNamespaceCreateService::FULL,
          first_name: 'Jane',
          last_name: 'Doe',
          company_name: 'Acme',
          group_name: 'My group',
          project_name: 'My project',
          onboarding_status_role: '0',
          onboarding_status_setup_for_company: 'false',
          onboarding_status_registration_objective: '1',
          jobs_to_be_done_other: '_jobs_to_be_done_other_'
        }
      end

      let(:service_response) { ServiceResponse.success(payload: { project: project }) }

      subject(:patch_update) { patch users_sign_up_welcome_path, params: update_params }

      before do
        allow_next_instance_of(::Onboarding::FreeNamespaceCreateService) do |service|
          allow(service).to receive(:execute).and_return(service_response)
        end
      end

      it { is_expected.to have_request_urgency(:low) }

      def expect_free_namespace_create_service(params:, step:, namespace_id: nil)
        matcher = { params: hash_including(params.to_h.deep_stringify_keys), step: step }
        matcher[:namespace_id] = namespace_id.to_s if namespace_id

        expect_next_instance_of(::Onboarding::FreeNamespaceCreateService, hash_including(matcher)) do |instance|
          expect(instance).to receive(:execute).and_return(yield)
        end
      end

      it 'forwards the permitted form params and step to the service' do
        expect_free_namespace_create_service(
          params: update_params.except(:step),
          step: ::Onboarding::FreeNamespaceCreateService::FULL
        ) { service_response }

        patch_update
      end

      context 'when the user has already finished onboarding' do
        before do
          user.update!(onboarding_in_progress: false)
        end

        it 'still processes the update instead of redirecting to root' do
          patch_update

          expect(response).to redirect_to new_project_path(namespace_id: project.namespace_id)
        end
      end

      context 'when resubmitting with a namespace id' do
        let(:update_params) do
          super().merge(
            step: ::Onboarding::FreeNamespaceCreateService::GROUP_FLOW,
            namespace_id: project.namespace_id.to_s
          )
        end

        it 'forwards the namespace id to the service' do
          expect_free_namespace_create_service(
            params: update_params.except(:step, :namespace_id),
            step: ::Onboarding::FreeNamespaceCreateService::GROUP_FLOW,
            namespace_id: project.namespace_id
          ) { service_response }

          patch_update
        end
      end

      context 'when the service succeeds' do
        it 'redirects to the new project page and tracks the submission event' do
          patch_update

          expect(response).to redirect_to new_project_path(namespace_id: project.namespace_id)
          expect_snowplow_event(
            category: 'registrations:welcome:update',
            action: 'successfully_submitted_form',
            user: user,
            label: 'free_registration'
          )
        end

        context 'when remove_onboarding_tutorial_pages is disabled' do
          before do
            stub_feature_flags(remove_onboarding_tutorial_pages: false)
          end

          it 'redirects to the Learn GitLab page' do
            patch_update

            expect(response).to redirect_to project_learn_gitlab_path(project)
          end
        end

        context 'when the user is not continuing full onboarding' do
          before do
            allow_next_instance_of(::Onboarding::StatusPresenter) do |presenter|
              allow(presenter).to receive(:continue_full_onboarding?).and_return(false)
            end
          end

          it 'redirects to the signed-in path instead of the project' do
            patch_update

            expect(response).to redirect_to dashboard_projects_path
          end
        end
      end

      context 'when the step is unrecognized' do
        let(:service_response) do
          ServiceResponse.error(message: 'Not found', reason: ::Onboarding::FreeNamespaceCreateService::NOT_FOUND)
        end

        it 'renders 404' do
          patch_update

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the service fails' do
        context 'when user validation fails' do
          let(:service_response) do
            ServiceResponse.error(
              message: 'failed',
              reason: ::Onboarding::FreeNamespaceCreateService::USER_VALIDATION_FAILED,
              payload: { model_errors: {} }
            )
          end

          it 're-renders the form targeting the full step' do
            patch_update

            expect(response).to have_gitlab_http_status(:ok)
            expect(parsed_view_model(response.body)['submitPath']).to eq(
              users_sign_up_welcome_path(step: ::Onboarding::FreeNamespaceCreateService::FULL)
            )
          end
        end

        context 'when group creation fails' do
          let(:service_response) do
            ServiceResponse.error(
              message: 'failed',
              reason: ::Onboarding::FreeNamespaceCreateService::NAMESPACE_CREATE_FAILED,
              payload: { model_errors: {} }
            )
          end

          it 're-renders the form targeting the group step' do
            patch_update

            expect(response).to have_gitlab_http_status(:ok)
            expect(parsed_view_model(response.body)['submitPath']).to eq(
              users_sign_up_welcome_path(step: ::Onboarding::FreeNamespaceCreateService::GROUP_FLOW)
            )
          end
        end

        context 'when project creation fails' do
          let(:service_response) do
            ServiceResponse.error(
              message: 'failed',
              reason: ::Onboarding::FreeNamespaceCreateService::PROJECT_CREATE_FAILED,
              payload: { namespace_id: project.namespace_id, model_errors: {} }
            )
          end

          it 're-renders the form targeting the project step and round-trips the namespace id' do
            patch_update

            expect(response).to have_gitlab_http_status(:ok)
            expect(parsed_view_model(response.body)['submitPath']).to eq(
              users_sign_up_welcome_path(step: ::Onboarding::FreeNamespaceCreateService::PROJECT_FLOW)
            )
            expect(parsed_view_model(response.body)['namespaceId']).to eq(project.namespace_id)
          end
        end
      end
    end

    context 'when reverted to the welcome step by the UpdateStepUrlToWelcomePath migration' do
      # Reverted users carry a `migrating=true` marker on their step_url so they can re-enter the
      # consolidated welcome page instead of being bounced out by verify_welcome_needed! or the
      # Onboarding::Redirect loop-breaker.
      let(:step_url) { '/users/sign_up/welcome' }

      before do
        user.update!(onboarding_status_setup_for_company: true, onboarding_status_step_url: step_url)
      end

      describe 'GET #show' do
        subject(:get_show) do
          get users_sign_up_welcome_path(migrating: migrating_param)
          response
        end

        context 'with the migrating marker present' do
          let(:step_url) { '/users/sign_up/welcome?migrating=true' }
          let(:migrating_param) { true }

          it 'renders the welcome page and keeps the user in onboarding' do
            expect(get_show).to have_gitlab_http_status(:ok)
            expect(user.reload.onboarding_in_progress).to be(true)
          end
        end

        context 'without the migrating marker' do
          let(:migrating_param) { nil }

          it 'finishes onboarding and redirects the user out of the welcome step' do
            expect(get_show).to have_gitlab_http_status(:redirect)
            expect(user.reload.onboarding_in_progress).to be(false)
          end
        end
      end
    end
  end
end
