# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsController, :saas, feature_category: :acquisition do
  include SubscriptionPortalHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let(:glm_params) { { glm_source: '_glm_source_', glm_content: '_glm_content_' } }
  let(:subscriptions_trials_enabled) { true }

  before do
    stub_saas_features(subscriptions_trials: subscriptions_trials_enabled, marketing_google_tag_manager: false)
    stub_subscription_trial_types
  end

  shared_examples 'namespace_id is passed' do
    context 'when namespace_id is 0' do
      let(:namespace_id) { { namespace_id: 0 } }

      it { is_expected.to have_gitlab_http_status(:ok) }
    end

    context 'for an ineligible group due to subscription level' do
      let(:namespace_id) { { namespace_id: create(:group_with_plan, plan: :ultimate_plan, owners: user) } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'for an ineligible group due to user permissions' do
      let(:namespace_id) { { namespace_id: create(:group) } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end
  end

  describe 'GET new' do
    let_it_be(:group_for_trial) { create(:group_with_plan, plan: :free_plan) }
    let(:namespace_id) { {} }
    let(:base_params) { glm_params.merge(namespace_id) }

    subject(:get_new) do
      get new_trial_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to redirect_to_trial_registration }
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it_behaves_like 'namespace_id is passed'

      context 'with tracking page render' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'render_trial_page' }

          subject(:track_event) do
            get new_trial_path, params: base_params
          end
        end
      end

      context 'when there are no eligible namespaces' do
        it 'is empty' do
          get_new

          expect(assigns(:eligible_namespaces)).to be_empty
        end
      end

      context 'with an unconfirmed email address present' do
        let(:user) { create(:user, confirmed_at: nil, unconfirmed_email: 'unconfirmed@gitlab.com') }

        it 'does not show email confirmation warning' do
          get_new

          expect(flash).to be_empty
        end
      end
    end
  end

  describe 'POST create' do
    let_it_be_with_reload(:group_for_trial) { create(:group_with_plan, plan: :free_plan, owners: user) }
    let(:step) { 'full' }
    let(:namespace_id) { { namespace_id: group_for_trial.id.to_s } }
    let(:lead_params) do
      {
        company_name: '_company_name_',
        first_name: '_first_name_',
        last_name: '_last_name_',
        phone_number: '123',
        country: '_country_',
        state: '_state_'
      }.with_indifferent_access
    end

    let(:trial_params) { namespace_id.with_indifferent_access }
    let(:base_params) { lead_params.merge(trial_params).merge(glm_params).merge(step: step) }

    subject(:post_create) do
      post trials_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it 'redirects to trial registration' do
        expect(post_create).to redirect_to_trial_registration
      end
    end

    context 'when user is banned' do
      before do
        user.ban!
        login_as(user)
      end

      it 'redirects to sign in with banned message' do
        post_create

        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to include('Your account has been blocked')
      end
    end

    context 'when authenticated', :use_clean_rails_memory_store_caching do
      before do
        Rails.cache.write(
          "namespaces:eligible_trials:#{group_for_trial.id}",
          [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE, GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2]
        )
        login_as(user)
      end

      it_behaves_like 'namespace_id is passed' do
        before do
          allow_next_instance_of(GitlabSubscriptions::Trials::UltimateCreateService) do |instance|
            response = ServiceResponse.error(message: '_message_', payload: { namespace: group_for_trial })
            allow(instance).to receive(:execute).and_return(response)
          end
        end
      end

      context 'when user is then banned' do
        before do
          user.ban!
        end

        it 'redirects to trial registration' do
          post_create

          expect(response).to redirect_to(new_user_session_path)
          expect(flash[:alert]).to include('Your account has been blocked')
        end
      end

      context 'when successful' do
        let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
        let_it_be(:ultimate_trial_plan) { create(:ultimate_trial_plan) }

        context 'for basic success cases' do
          before do
            expect_create_success(group_for_trial)
          end

          it { is_expected.to redirect_to(group_path(group_for_trial)) }

          it 'shows valid flash message', :freeze_time do
            post_create

            message = format(
              s_(
                'BillingPlans|You have successfully started a GitLab Ultimate trial that will expire on %{exp_date}.'
              ),
              exp_date: I18n.l(30.days.from_now.to_date, format: :long_unpadded)
            )
            expect(flash[:success]).to have_content(message)
          end
        end

        context 'when the namespace applying is on the premium plan' do
          let_it_be_with_reload(:premium_group_for_trial) do
            create(:group_with_plan, plan: :premium_plan, owners: user)
          end

          let_it_be(:ultimate_trial_paid_customer_plan) { create(:ultimate_trial_paid_customer_plan) }

          context 'when trial is applied' do
            before do
              Rails.cache.write_multi(
                "namespaces:eligible_trials:#{group_for_trial.id}" =>
                  [GitlabSubscriptions::Trials::FREE_TRIAL_TYPE, GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2],
                "namespaces:eligible_trials:#{premium_group_for_trial.id}" =>
                  [GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE, GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2]
              )

              expect_create_with_premium_success(premium_group_for_trial)
            end

            it 'shows valid flash message', :freeze_time do
              post_create

              message = format(
                s_(
                  'BillingPlans|You have successfully started a GitLab Ultimate trial that will ' \
                    'expire on %{exp_date}.'
                ),
                exp_date: I18n.l(30.days.from_now.to_date, format: :long_unpadded)
              )
              expect(flash[:success]).to have_content(message)
            end
          end
        end

        where(
          case_names: ->(glm_content) { "when submitted with glm_content value of #{glm_content}" },
          glm_content: %w[discover-group-security discover-project-security]
        )

        with_them do
          let(:glm_params) { { glm_source: '_glm_source_', glm_content: glm_content } }

          it 'redirects to the group security dashboard' do
            expect_create_success(group_for_trial)

            expect(post_create).to redirect_to(group_security_dashboard_path(group_for_trial))
          end

          it 'shows valid flash message' do
            expect_create_success(group_for_trial)

            post_create

            expect(flash[:success]).to eq(s_("BillingPlans|Congratulations, your free trial is activated."))
          end
        end

        def expect_create_with_premium_success(namespace)
          service_params = {
            step: step,
            params: trial_params.merge(lead_params, glm_params, organization_id: anything),
            user: user
          }

          expect_next_instance_of(GitlabSubscriptions::Trials::UltimateCreateService, service_params) do |instance|
            expect(instance).to receive(:execute) do
              namespace.gitlab_subscription.update!(
                hosted_plan: ultimate_trial_paid_customer_plan, end_date: Time.current + 60.days
              )
            end.and_return(ServiceResponse.success(payload: { namespace: namespace }))
          end
        end

        def expect_create_success(namespace)
          service_params = {
            step: step,
            params: trial_params.merge(lead_params, glm_params, organization_id: anything),
            user: user
          }

          expect_next_instance_of(GitlabSubscriptions::Trials::UltimateCreateService, service_params) do |instance|
            expect(instance).to receive(:execute) do
              update_with_applied_trials(namespace)
            end.and_return(
              ServiceResponse.success(payload: { namespace: namespace })
            )
          end
        end

        def update_with_applied_trials(namespace)
          namespace.gitlab_subscription.update!(
            hosted_plan: ultimate_trial_plan,
            trial: true,
            end_date: Time.current + 60.days,
            trial_starts_on: Time.current,
            trial_ends_on: Time.current + 60.days
          )
        end
      end

      context 'with create service failures' do
        let(:payload) { {} }

        before do
          expect_create_failure(failure_reason, payload)
        end

        context 'when namespace is not found or not allowed to create' do
          let(:failure_reason) { :not_found }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when lead creation fails' do
          let(:failure_reason) { :lead_failed }

          it 'renders lead form' do
            expect(post_create).to have_gitlab_http_status(:ok)

            expect(response.body).to include(_('Trial registration unsuccessful'))
          end
        end

        context 'with trial failure' do
          let(:failure_reason) { :trial_failed }
          let(:payload) { { namespace_id: group_for_trial.id } }

          it 'renders the select namespace form again with trial creation errors only' do
            expect(post_create).to have_gitlab_http_status(:ok)

            expect(response.body).to include(_('Trial registration unsuccessful'))
          end
        end

        def expect_create_failure(reason, payload = {})
          # validate params passed/called here perhaps
          expect_next_instance_of(GitlabSubscriptions::Trials::UltimateCreateService) do |instance|
            response = ServiceResponse.error(message: '_error_', reason: reason, payload: payload)
            expect(instance).to receive(:execute).and_return(response)
          end
        end
      end
    end
  end

  RSpec::Matchers.define :redirect_to_trial_registration do
    match do |response|
      expect(response).to redirect_to(new_trial_registration_path(glm_params))
    end
  end
end
