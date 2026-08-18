# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::HandRaiseLeadsController, feature_category: :acquisition do
  describe 'POST /-/gitlab_subscriptions/hand_raise_leads' do
    let_it_be(:user) { create(:user, :with_namespace) }
    let_it_be(:namespace) { create(:group, developers: user) }
    let_it_be(:namespace_id) { namespace.id.to_s }

    let(:hand_raise_lead_result) { ServiceResponse.success }
    let(:post_params) do
      {
        namespace_id: namespace_id,
        first_name: 'James',
        last_name: 'Bond',
        company_name: 'ACME',
        phone_number: '+1-192-10-10',
        country: 'US',
        state: 'CA',
        comment: 'I want to talk to sales.',
        glm_content: 'group-billing',
        product_interaction: '_product_interaction_'
      }
    end

    subject(:post_hand_raise_lead) do
      post gitlab_subscriptions_hand_raise_leads_path, params: post_params
      response
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      allow_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
        allow(service).to receive(:execute).and_return(hand_raise_lead_result)
      end
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'calls the hand raise lead service with correct parameters' do
        hand_raise_lead_extra_params =
          {
            work_email: user.email,
            uid: user.id,
            provider: 'gitlab',
            setup_for_company: user.onboarding_status_setup_for_company,
            existing_plan: namespace.actual_plan_name,
            glm_source: 'gitlab.com'
          }
        expect_next_instance_of(GitlabSubscriptions::CreateHandRaiseLeadService) do |service|
          expected_params = ActionController::Parameters.new(post_params)
                                                        .permit!
                                                        .merge(hand_raise_lead_extra_params)
          expect(service).to receive(:execute).with(expected_params).and_return(ServiceResponse.success)
        end

        post_hand_raise_lead
      end

      context 'when gitlab_com_subscriptions are not available' do
        before do
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when namespace cannot be found' do
        let(:namespace_id) { non_existing_record_id.to_s }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'with failure' do
        let(:hand_raise_lead_result) { ServiceResponse.error(message: '_fail_') }

        it { is_expected.to have_gitlab_http_status(:forbidden) }
      end
    end

    context 'when not authenticated' do
      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end

  describe 'POST /-/gitlab_subscriptions/hand_raise_leads/track_cart_abandonment' do
    let_it_be(:user) { create(:user, :with_namespace, onboarding_status_email_opt_in: true) }
    let_it_be(:namespace) { create(:group) }

    let(:params) { { namespace_id: namespace.id.to_s, plan: 'premium' } }
    let(:service_result) { ServiceResponse.success }

    subject(:post_track_cart_abandonment) do
      post track_cart_abandonment_gitlab_subscriptions_hand_raise_leads_path, params: params
    end

    before_all do
      namespace.add_owner(user)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)

      allow_next_instance_of(GitlabSubscriptions::TrackCartAbandonmentService) do |service|
        allow(service).to receive(:execute).and_return(service_result)
      end
    end

    context 'when user is authenticated' do
      before do
        sign_in(user)
      end

      context 'when service succeeds' do
        it 'calls the service with correct parameters and returns 200 ok' do
          expect_next_instance_of(GitlabSubscriptions::TrackCartAbandonmentService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when service fails' do
        let(:service_result) { ServiceResponse.error(message: 'Invalid plan') }

        it 'returns 422 unprocessable entity with error message' do
          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('Invalid plan')
        end
      end

      context 'when neither plan nor credits param is present' do
        let(:params) { { namespace_id: namespace.id.to_s } }

        it 'calls TrackCartAbandonmentService with nil plan and returns ok' do
          expect_next_instance_of(GitlabSubscriptions::TrackCartAbandonmentService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when credits param is present' do
      let(:params) { { namespace_id: namespace.id.to_s, credits: 100 } }

      before do
        sign_in(user)

        allow_next_instance_of(GitlabSubscriptions::TrackCartAbandonmentCreditsPurchaseService) do |service|
          allow(service).to receive(:execute).and_return(service_result)
        end
      end

      context 'when service succeeds' do
        it 'calls TrackCartAbandonmentCreditsPurchaseService and returns 200 ok' do
          expect_next_instance_of(GitlabSubscriptions::TrackCartAbandonmentCreditsPurchaseService) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when service fails' do
        let(:service_result) { ServiceResponse.error(message: 'User opt-in required to track credits purchase') }

        it 'returns 422 unprocessable entity with error message' do
          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq('User opt-in required to track credits purchase')
        end
      end

      context 'when credits param is non-numeric' do
        let(:params) { { namespace_id: namespace.id.to_s, credits: 'abc' } }

        it 'coerces to 0 and calls TrackCartAbandonmentCreditsPurchaseService' do
          expect_next_instance_of(
            GitlabSubscriptions::TrackCartAbandonmentCreditsPurchaseService,
            user: user, namespace: namespace, monthly_commitment_credits: 0
          ) do |service|
            expect(service).to receive(:execute).and_return(ServiceResponse.success)
          end

          post_track_cart_abandonment

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when user is not authenticated' do
      it 'returns 404' do
        post_track_cart_abandonment

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when namespace is not found' do
      before do
        sign_in(user)
      end

      let(:params) { { namespace_id: non_existing_record_id, plan: 'premium' } }

      it 'returns 404' do
        post_track_cart_abandonment

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when gitlab_com_subscriptions is not available' do
      before do
        sign_in(user)
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns 404' do
        post_track_cart_abandonment

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
