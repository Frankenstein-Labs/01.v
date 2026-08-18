# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::TrialWelcomeController, :with_current_organization, :saas_onboarding, :saas_subscriptions_trials, feature_category: :onboarding do
  let_it_be_with_reload(:user) do
    create(:user, organizations: [current_organization], onboarding_status_registration_type: 'trial')
  end

  let_it_be(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }
  let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }

  let(:subscriptions_trials_enabled) { true }

  before do
    stub_saas_features(subscriptions_trials: subscriptions_trials_enabled, marketing_google_tag_manager: false)
  end

  describe 'GET #show' do
    let(:base_params) { glm_params }

    subject(:get_new) do
      get users_sign_up_welcome_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }
    end
  end

  describe 'PUT update' do
    let_it_be_with_reload(:namespace) { create(:group_with_plan, plan: :free_plan, owners: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    let(:default_params) do
      {
        company_name: '_company_name_',
        country: '_country_',
        state: '_state_',
        group_name: "group name",
        project_name: "project name",
        organization_id: current_organization.id,
        onboarding_status_role: '0',
        onboarding_status_setup_for_company: 'true',
        onboarding_status_registration_objective: '1'
      }.merge(glm_params).with_indifferent_access
    end

    let(:params) { default_params }

    subject(:put_update) do
      request_params = step ? params.merge(step: step) : params
      put users_sign_up_welcome_path, params: request_params
      response
    end

    context 'when authenticated', :use_clean_rails_memory_store_caching do
      let(:step) { Onboarding::TrialNamespaceCreateService::FULL }

      before do
        login_as(user)
      end

      context 'when remove_onboarding_tutorial_pages is enabled' do
        it "redirects to the new project page when successful" do
          expect_trial_namespace_create_service(params: params) do
            ServiceResponse.success(message: 'Trial applied', payload: { namespace: namespace, project: project })
          end

          expect(put_update).to redirect_to(new_project_path(namespace_id: namespace.id))
        end
      end

      context 'when remove_onboarding_tutorial_pages is disabled' do
        before do
          stub_feature_flags(remove_onboarding_tutorial_pages: false)
        end

        it "redirects to get started path when successful" do
          expect_trial_namespace_create_service(params: params) do
            ServiceResponse.success(message: 'Trial applied', payload: { namespace: namespace, project: project })
          end

          expect(put_update).to redirect_to(namespace_project_get_started_path(namespace, project))
        end
      end

      it "renders form with group_flow step when group creation fails" do
        expect_trial_namespace_create_service(params: params) do
          ServiceResponse.error(
            message: 'Trial creation failed in namespace stage',
            reason: Onboarding::TrialNamespaceCreateService::NAMESPACE_CREATE_FAILED,
            payload: { namespace_id: nil, project_id: nil,
                       model_errors: [groupName: ["group creation failed"]] }
          )
        end

        put_update

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('group creation failed'))
        expect(response.body).to include("step=#{Onboarding::TrialNamespaceCreateService::GROUP_FLOW}")
      end

      context "when no step is provided" do
        let(:step) { nil }

        it "responds with not_found" do
          expect(put_update).to have_gitlab_http_status(:not_found)
        end
      end

      it "returns not_found when user can not create a group" do
        expect_trial_namespace_create_service(params: params) do
          ServiceResponse.error(
            message: 'Trial creation failed in namespace stage',
            reason: Onboarding::TrialNamespaceCreateService::NOT_FOUND
          )
        end

        expect(put_update).to have_gitlab_http_status(:not_found)
      end

      it "renders form with project_flow step when project creation fails" do
        expect_trial_namespace_create_service(params: params) do
          ServiceResponse.error(
            message: 'Trial creation failed in project stage',
            reason: Onboarding::TrialNamespaceCreateService::PROJECT_CREATE_FAILED,
            payload: { namespace_id: namespace.id, project_id: nil,
                       model_errors: [projectName: ["project creation failed"]] }
          )
        end

        expect(put_update).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('project creation failed'))
        expect(response.body).to include("step=#{Onboarding::TrialNamespaceCreateService::PROJECT_FLOW}")
      end

      it "renders form with full step when user validation fails" do
        expect_trial_namespace_create_service(params: params) do
          ServiceResponse.error(
            message: 'Trial creation failed in user stage',
            reason: Onboarding::TrialNamespaceCreateService::USER_VALIDATION_FAILED,
            payload: { namespace_id: namespace.id, project_id: project.id,
                       model_errors: { role: "must be present" } }
          )
        end

        put_update

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_("must be present"))
        expect(response.body).to include("step=#{Onboarding::TrialNamespaceCreateService::FULL}")
      end

      it "renders resubmit form with lead_flow step when lead creation fails" do
        expect_trial_namespace_create_service(params: params) do
          ServiceResponse.error(
            message: 'Trial creation failed in lead stage',
            reason: Onboarding::TrialNamespaceCreateService::LEAD_FAILED,
            payload: { namespace_id: namespace.id, project_id: project.id }
          )
        end

        put_update

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include(_('Trial creation failed in lead stage'))
        expect(response.body).to include("step=#{Onboarding::TrialNamespaceCreateService::LEAD_FLOW}")
      end

      context "when resubmission with step param" do
        let(:step) { Onboarding::TrialNamespaceCreateService::PROJECT_FLOW }
        let(:params) { default_params.merge(namespace_id: namespace.id) }

        context 'when remove_onboarding_tutorial_pages is enabled' do
          it "creates the project and redirects to the new project page" do
            expect_trial_namespace_create_service(
              params: params.without(:namespace_id),
              step: Onboarding::TrialNamespaceCreateService::PROJECT_FLOW,
              namespace_id: namespace.id.to_s
            ) do
              ServiceResponse.success(
                message: 'Trial applied',
                payload: { namespace: namespace, project: project }
              )
            end

            expect(put_update).to redirect_to(new_project_path(namespace_id: namespace.id))
          end
        end

        context 'when remove_onboarding_tutorial_pages is disabled' do
          before do
            stub_feature_flags(remove_onboarding_tutorial_pages: false)
          end

          it "creates the project and redirects successfully" do
            expect_trial_namespace_create_service(
              params: params.without(:namespace_id),
              step: Onboarding::TrialNamespaceCreateService::PROJECT_FLOW,
              namespace_id: namespace.id.to_s
            ) do
              ServiceResponse.success(
                message: 'Trial applied',
                payload: { namespace: namespace, project: project }
              )
            end

            expect(put_update).to redirect_to(namespace_project_get_started_path(namespace, project))
          end
        end
      end

      context 'when first_name and last_name are provided' do
        let(:params) { default_params.merge(first_name: 'Jane', last_name: 'Smith') }

        context 'when remove_onboarding_tutorial_pages is enabled' do
          it 'permits and passes name params to service and redirects to the new project page' do
            expect_trial_namespace_create_service(params: params) do
              ServiceResponse.success(message: 'Trial applied', payload: { namespace: namespace, project: project })
            end

            expect(put_update).to redirect_to(new_project_path(namespace_id: namespace.id))
          end
        end

        context 'when remove_onboarding_tutorial_pages is disabled' do
          before do
            stub_feature_flags(remove_onboarding_tutorial_pages: false)
          end

          it 'permits and passes name params to service' do
            expect_trial_namespace_create_service(params: params) do
              ServiceResponse.success(message: 'Trial applied', payload: { namespace: namespace, project: project })
            end

            expect(put_update).to redirect_to(namespace_project_get_started_path(namespace, project))
          end
        end
      end
    end
  end

  def expect_trial_namespace_create_service(
    params:, step: Onboarding::TrialNamespaceCreateService::FULL, namespace_id: nil, project_id: nil
  )
    matcher_hash = { params: hash_including(params.to_h.deep_stringify_keys), step: step }
    matcher_hash[:namespace_id] = namespace_id.to_s if namespace_id
    matcher_hash[:project_id] = project_id.to_s if project_id

    expect_next_instance_of(Onboarding::TrialNamespaceCreateService,
      hash_including(matcher_hash)) do |instance|
      expect(instance).to receive(:execute).and_return(yield)
    end
  end
end
