# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterpriseController, :saas, :unlimited_max_formatted_output_length, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }
  let_it_be(:user_without_eligible_groups) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
  let_it_be(:another_free_group) { create(:group, owners: user) }
  let_it_be(:another_ultimate_group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }
  let_it_be(:ineligible_paid_group) { create(:group_with_plan, plan: :premium_plan, owners: user) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

  let(:subscriptions_trials_enabled) { true }

  before do
    stub_saas_features(
      subscriptions_trials: subscriptions_trials_enabled,
      marketing_google_tag_manager: false
    )
  end

  shared_examples 'namespace is not eligible for trial' do
    context 'when free group owner' do
      let(:namespace_id) { { namespace_id: another_free_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'for an ineligible group owner' do
      let(:namespace_id) { { namespace_id: ineligible_paid_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when eligible paid plan group developer' do
      let(:namespace_id) { { namespace_id: another_ultimate_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end
  end

  shared_examples 'no eligible namespaces' do
    before do
      login_as(user_without_eligible_groups)
    end

    it { is_expected.to have_gitlab_http_status(:forbidden) }
  end

  describe 'GET new' do
    let(:group_for_trial) { group }
    let(:namespace_id) { { namespace_id: group_for_trial.id } }
    let(:base_params) { namespace_id }

    subject(:get_new) do
      get new_trials_duo_enterprise_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to redirect_to_sign_in }
    end

    context 'when authenticated as a user' do
      before do
        login_as(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      context 'with tracking page render' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'render_duo_enterprise_trial_page' }
          let(:namespace) { group }

          subject(:track_event) do
            get new_trials_duo_enterprise_path, params: { namespace_id: group.id }
          end
        end
      end

      context 'when subscriptions_trials saas feature is not available' do
        let(:subscriptions_trials_enabled) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it_behaves_like 'namespace is not eligible for trial'
    end

    it_behaves_like 'no eligible namespaces'
  end

  describe 'POST create' do
    let(:group_for_trial) { group }
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
      }
    end

    let(:trial_params) { namespace_id }
    let(:base_params) { lead_params.merge(trial_params).merge(step: step) }

    subject(:post_create) do
      post trials_duo_enterprise_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it 'redirects to trial registration' do
        expect(post_create).to redirect_to_sign_in
      end
    end

    context 'when authenticated' do
      before do
        login_as(user)
      end

      context 'when successful' do
        context 'when add_on_purchase exists' do
          let(:add_on_purchase) do
            build(:gitlab_subscription_add_on_purchase, expires_on: 61.days.from_now)
          end

          before do
            expect_create_success
          end

          it { is_expected.to redirect_to(group_settings_gitlab_duo_path(group_for_trial)) }

          it 'shows valid flash message', :freeze_time do
            post_create

            message = s_(
              'DuoEnterpriseTrial|You have successfully started a Duo Enterprise trial that will expire on %{exp_date}.'
            )
            formatted_message = format(
              message,
              exp_date: I18n.l(61.days.from_now.to_date, format: :long_unpadded)
            )
            expect(flash[:success]).to have_content(formatted_message)
          end
        end

        def expect_create_success
          service_params = {
            step: step,
            params: trial_params.merge(lead_params),
            user: user
          }

          expect_next_instance_of(GitlabSubscriptions::Trials::DuoEnterpriseCreateService, service_params) do |instance|
            expect(instance).to receive(:execute).and_return(
              ServiceResponse.success(payload: { namespace: group_for_trial, add_on_purchase: add_on_purchase })
            )
          end
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
          expect_next_instance_of(GitlabSubscriptions::Trials::DuoEnterpriseCreateService) do |instance|
            response = ServiceResponse.error(message: '_error_', reason: reason, payload: payload)
            expect(instance).to receive(:execute).and_return(response)
          end
        end
      end

      context 'when subscriptions_trials is not available' do
        let(:subscriptions_trials_enabled) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
