# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsController, feature_category: :subscription_management do
  let_it_be(:user) { create(:user) }

  describe 'GET #new' do
    context 'when the request is unauthenticated' do
      subject(:get_new) { get :new, params: { plan_id: 'premium-plan-id' } }

      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_registration_path }

      it 'stores the subscription path to redirect to after sign up' do
        get_new

        expect(controller.stored_location_for(:user)).to eq(new_subscriptions_path(plan_id: 'premium-plan-id'))
      end
    end

    context 'when the user is authenticated' do
      before do
        sign_in(user)
      end

      let_it_be(:owned_group) { create(:group) }

      before_all do
        owned_group.add_owner(user)
      end

      context 'when the user has already selected a group' do
        before do
          allow(GitlabSubscriptions)
            .to receive(:find_eligible_namespace)
            .with(user: user, namespace_id: owned_group.id.to_s)
            .and_return(owned_group)
        end

        it 'redirects to customers dot' do
          get :new, params: { plan_id: 'premium-plan-id', namespace_id: owned_group.id }

          expect(response)
            .to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{owned_group.id}&plan_id=premium-plan-id}
        end

        context 'when promo_code is provided' do
          it 'includes promo_code in the redirect URL' do
            get :new, params: { plan_id: 'premium-plan-id', namespace_id: owned_group.id, promo_code: 'TESTPROMO' }

            expect(response).to redirect_to(
              %r{/subscriptions/new\?gl_namespace_id=#{owned_group.id}&plan_id=premium-plan-id&promo_code=TESTPROMO}
            )
          end
        end
      end

      context 'when the user has not selected a group' do
        it 'redirects to the group selection page' do
          get :new, params: { plan_id: 'premium-plan-id' }

          expect(response).to redirect_to %r{/-/subscriptions/groups/new\?plan_id=premium-plan-id}
        end

        context 'when promo_code is provided' do
          it 'includes promo_code in the redirect URL' do
            get :new, params: { plan_id: 'premium-plan-id', promo_code: 'TESTPROMO' }

            expect(response).to redirect_to(
              %r{/-/subscriptions/groups/new\?plan_id=premium-plan-id&promo_code=TESTPROMO}
            )
          end
        end
      end

      context 'when deployment_type is self_managed' do
        let(:params) { { plan_id: 'premium-plan-id', deployment_type: 'self_managed', auto_submit_sso: true } }

        subject(:get_new) { get :new, params: params }

        it 'redirects to the subscription portal new subscription page with correct params' do
          get_new

          new_subscriptions_url = Gitlab::Routing.url_helpers.subscription_portal_new_subscription_url

          query = 'auto_submit_sso=true&deployment_type=self_managed&plan_id=premium-plan-id'
          expected_url = "#{new_subscriptions_url}?#{query}"
          expect(response).to redirect_to(expected_url)
        end

        context 'when auto_submit_sso is omitted' do
          let(:params) { super().except(:auto_submit_sso) }

          it 'redirects without auto_submit_sso in the URL' do
            get_new

            new_subscriptions_url = Gitlab::Routing.url_helpers.subscription_portal_new_subscription_url

            expected_url = "#{new_subscriptions_url}?deployment_type=self_managed&plan_id=premium-plan-id"
            expect(response).to redirect_to(expected_url)
          end
        end

        context 'when plan_id is blank' do
          let(:params) { super().except(:plan_id) }

          it { is_expected.to redirect_to promo_pricing_url }
        end
      end

      context 'when URL has no plan_id param' do
        before do
          get :new
        end

        it { is_expected.to redirect_to promo_pricing_url }
      end

      context 'when gitlab_credits purchase for self_managed' do
        let(:params) { { plan_type: 'gitlab_credits', deployment_type: 'self_managed', auto_submit_sso: true } }

        subject(:get_new) { get :new, params: params }

        it 'redirects to the subscription portal new subscription page with correct params' do
          get_new

          purchase_credits_url = Gitlab::Utils.add_url_parameters(
            Gitlab::Routing.url_helpers.subscription_portal_self_managed_purchase_credits_url,
            { auto_submit_sso: true }
          )

          expect(response).to redirect_to(purchase_credits_url)
        end

        context 'when auto_submit_sso is omitted' do
          let(:params) { super().except(:auto_submit_sso) }

          it 'redirects without auto_submit_sso in the URL' do
            get_new

            purchase_credits_url = Gitlab::Routing.url_helpers.subscription_portal_self_managed_purchase_credits_url

            expect(response).to redirect_to(purchase_credits_url)
          end
        end
      end
    end
  end

  describe 'GET #upgrade_base_plan' do
    let_it_be(:owned_group) { create(:group) }

    before_all do
      owned_group.add_owner(user)
    end

    context 'when the request is unauthenticated' do
      it 'redirects to the sign in page' do
        get :upgrade_base_plan, params: { namespace_id: owned_group.id }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when the user is authenticated', :saas_gitlab_com_subscriptions do
      before do
        sign_in(user)
      end

      context 'when the namespace is not owned by the user' do
        let_it_be(:other_group) { create(:group) }

        it 'returns 404' do
          get :upgrade_base_plan, params: { plan_name: ::Plan::ULTIMATE, namespace_id: other_group.id }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the plan name resolves to a customers dot plan id' do
        let(:resolved_plan) { Hashie::Mash.new(id: 'resolved-plan-id', code: ::Plan::ULTIMATE) }

        before do
          allow_next_instance_of(::GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
            allow(service).to receive(:execute).and_return([resolved_plan])
          end
        end

        context 'when the namespace is on a paid plan' do
          before do
            create(:gitlab_subscription, :premium, namespace: owned_group)
          end

          it 'redirects to the customers dot upgrade path' do
            get :upgrade_base_plan, params: { plan_name: ::Plan::ULTIMATE, namespace_id: owned_group.id }

            expect(response).to redirect_to(
              Gitlab::Routing.url_helpers.subscription_portal_upgrade_subscription_url(owned_group.id,
                'resolved-plan-id')
            )
          end
        end

        context 'when the namespace is on a free plan' do
          it 'redirects to the customers dot new subscription path' do
            get :upgrade_base_plan, params: { plan_name: ::Plan::ULTIMATE, namespace_id: owned_group.id }

            expect(response).to redirect_to(
              %r{/subscriptions/new\?gl_namespace_id=#{owned_group.id}&plan_id=resolved-plan-id}
            )
          end
        end

        context 'when the plan name is omitted' do
          it 'falls back to the ultimate plan' do
            get :upgrade_base_plan, params: { namespace_id: owned_group.id }

            expect(response).to redirect_to(
              %r{/subscriptions/new\?gl_namespace_id=#{owned_group.id}&plan_id=resolved-plan-id}
            )
          end
        end
      end

      context 'when the plan name cannot be resolved' do
        before do
          allow_next_instance_of(::GitlabSubscriptions::FetchSubscriptionPlansService) do |service|
            allow(service).to receive(:execute).and_return(nil)
          end
        end

        it 'redirects to the pricing page' do
          get :upgrade_base_plan, params: { plan_name: ::Plan::ULTIMATE, namespace_id: owned_group.id }

          expect(response).to redirect_to(promo_pricing_url)
        end
      end

      context 'when the plan name is not an upgradable plan' do
        it 'redirects to the pricing page without calling the plans service' do
          expect(::GitlabSubscriptions::FetchSubscriptionPlansService).not_to receive(:new)

          get :upgrade_base_plan, params: { plan_name: ::Plan::FREE, namespace_id: owned_group.id }

          expect(response).to redirect_to(promo_pricing_url)
        end
      end
    end
  end

  describe 'GET #buy_minutes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:plan_id) { 'ci_minutes' }

    context 'when the user not authenticated' do
      it 'redirects to the sign in page' do
        get :buy_minutes, params: { selected_group: group.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when the user is authenticated' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'when the add on does not exist' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it 'returns not found' do
          get :buy_minutes, params: { selected_group: group.id }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add on exists' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'ci_minutes' }] })
        end

        context 'when the group does not exist' do
          it 'returns not found' do
            get :buy_minutes, params: { selected_group: non_existing_record_id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is not eligible for CI minutes' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'ci_minutes')
              .and_return(nil)
          end

          it 'returns not found' do
            get :buy_minutes, params: { selected_group: group.id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is eligible for CI minutes' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'ci_minutes')
              .and_return(group)
          end

          it 'redirects to the customers dot purchase flow' do
            get :buy_minutes, params: { selected_group: group.id }

            expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=ci_minutes}
          end

          context 'when the group is upgradable' do
            before do
              allow(group).to receive(:upgradable?).and_return(true)
            end

            it 'redirects to the customers dot purchase flow' do
              get :buy_minutes, params: { selected_group: group.id }

              expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=ci_minutes}
            end
          end
        end
      end
    end
  end

  describe 'GET #buy_storage' do
    let_it_be(:group) { create(:group) }

    context 'when the user not authenticated' do
      it 'redirects to the sign in page' do
        get :buy_storage, params: { selected_group: group.id }

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'when the user is authenticated' do
      before_all do
        group.add_owner(user)
      end

      before do
        sign_in(user)
      end

      context 'when the add on does not exist' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it 'returns not found' do
          get :buy_storage, params: { selected_group: group.id }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add on exists' do
        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'storage' }] })
        end

        context 'when the group does not exist' do
          it 'returns not found' do
            get :buy_storage, params: { selected_group: non_existing_record_id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is not eligible for storage' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'storage')
              .and_return(nil)
          end

          it 'returns not found' do
            get :buy_storage, params: { selected_group: group.id }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when the group is eligible for storage' do
          before do
            allow(GitlabSubscriptions)
              .to receive(:find_eligible_namespace)
              .with(user: user, namespace_id: group.id.to_s, plan_id: 'storage')
              .and_return(group)
          end

          it 'redirects to the customers dot purchase flow' do
            get :buy_storage, params: { selected_group: group.id }

            expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=storage}
          end

          context 'when the group is upgradable' do
            before do
              allow(group).to receive(:upgradable?).and_return(true)
            end

            it 'redirects to the customers dot purchase flow' do
              get :buy_storage, params: { selected_group: group.id }

              expect(response).to redirect_to %r{/subscriptions/new\?gl_namespace_id=#{group.id}&plan_id=storage}
            end
          end
        end
      end
    end
  end

  describe 'GET #payment_form' do
    subject { get :payment_form, params: { id: 'cc', user_id: 5 } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { signature: 'x', token: 'y' } }

        allow(Gitlab::SubscriptionPortal::Client)
          .to receive(:payment_form_params)
          .with('cc', user.id)
          .and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"signature":"x","token":"y"}')
      end
    end
  end

  describe 'GET #validate_payment_method' do
    let(:params) { { id: 'foo' } }

    subject do
      post :validate_payment_method, params: params, as: :json
    end

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:unauthorized) }
    end

    context 'with authorized user' do
      before do
        sign_in(user)

        expect(Gitlab::SubscriptionPortal::Client)
          .to receive(:validate_payment_method)
          .with(params[:id], { gitlab_user_id: user.id })
          .and_return({ success: true })
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it { is_expected.to be_successful }
    end
  end
end
