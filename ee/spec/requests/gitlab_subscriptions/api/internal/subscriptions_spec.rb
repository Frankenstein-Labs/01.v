# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Subscriptions, :aggregate_failures, :api, feature_category: :plan_provisioning do
  include GitlabSubscriptions::InternalApiHelpers

  def subscription_path(namespace_id)
    internal_api("namespaces/#{namespace_id}/gitlab_subscription")
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:id/gitlab_subscription', :saas do
    let_it_be(:namespace) { create(:group) }

    context 'when unauthenticated' do
      it 'returns an error response' do
        get subscription_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get subscription_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the namespace does not have a subscription' do
        it 'returns an empty response' do
          get subscription_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to match_array(%w[plan usage billing])

          expect(json_response['plan']).to eq(
            'name' => nil,
            'code' => nil,
            'auto_renew' => nil,
            'trial' => nil,
            'upgradable' => nil,
            'exclude_guests' => nil
          )

          expect(json_response['usage']).to eq(
            'max_seats_used' => nil,
            'seats_in_subscription' => nil,
            'seats_in_use' => nil,
            'seats_owed' => nil
          )

          expect(json_response['billing']).to eq(
            'subscription_start_date' => nil,
            'subscription_end_date' => nil,
            'trial_ends_on' => nil
          )
        end
      end

      context 'when the request is authenticated for a namespace with a subscription' do
        it 'returns the subscription data' do
          subscription = create(
            :gitlab_subscription,
            :ultimate,
            namespace: namespace,
            auto_renew: true,
            max_seats_used: 5
          )

          get subscription_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to match_array(%w[plan usage billing])

          expect(json_response['plan']).to eq(
            'name' => 'Ultimate',
            'code' => 'ultimate',
            'auto_renew' => true,
            'trial' => false,
            'upgradable' => false,
            'exclude_guests' => true
          )

          expect(json_response['usage']).to eq(
            'max_seats_used' => 5,
            'seats_in_subscription' => 10,
            'seats_in_use' => 0,
            'seats_owed' => 0
          )

          expect(json_response['billing']).to eq(
            'subscription_start_date' => subscription.start_date.iso8601,
            'subscription_end_date' => subscription.end_date.iso8601,
            'trial_ends_on' => nil
          )
        end
      end
    end
  end

  describe 'POST /internal/gitlab_subscriptions/namespaces/:id/gitlab_subscription', :saas do
    let_it_be_with_reload(:namespace) { create(:namespace) }

    let(:params) { { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' } }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        post subscription_path(namespace.id), params: params

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace does not exist' do
        it 'returns a 404' do
          post subscription_path(non_existing_record_id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when creating subscription for project namespace' do
        it 'returns a 404' do
          project_namespace = create(:project).project_namespace

          post subscription_path(project_namespace.id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when the params are invalid' do
        it 'responds with an error' do
          post subscription_path(namespace.id), headers: internal_api_headers, params: params.merge(start_date: nil)

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when the params are valid' do
        it 'creates a subscription for the namespace' do
          post subscription_path(namespace.id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.gitlab_subscription).to be_present
        end
      end

      context 'when creating a trial' do
        it 'sets the trial_starts_on to the start_date' do
          post(
            subscription_path(namespace.id),
            headers: internal_api_headers,
            params: params.merge(
              trial: true,
              trial_ends_on: 1.month.from_now
            )
          )

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.reload.gitlab_subscription.trial_starts_on.iso8601).to eq '2018-01-01'
        end
      end
    end
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:id/gitlab_subscription', :saas do
    let_it_be_with_reload(:namespace) { create(:namespace) }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        put subscription_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when namespace is not found' do
        it 'returns a 404 error' do
          put subscription_path(non_existing_record_id), headers: internal_api_headers, params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace does not have a subscription' do
        it 'returns a 404 error' do
          put subscription_path(namespace.id), headers: internal_api_headers, params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace is a project namespace' do
        it 'returns a 404 error' do
          project_namespace = create(:project).project_namespace

          put subscription_path(project_namespace.id), headers: internal_api_headers, params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when the subscription exists' do
        let_it_be(:premium_plan) { create(:premium_plan) }

        let_it_be(:gitlab_subscription) do
          create(:gitlab_subscription, namespace: namespace, start_date: '2018-01-01', end_date: '2019-01-01')
        end

        context 'when params are invalid' do
          it 'returns a 400 error' do
            put subscription_path(namespace.id), headers: internal_api_headers, params: { seats: nil }

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when the params are valid' do
          it 'updates the subscription for the group' do
            params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            put subscription_path(namespace.id), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload.seats).to eq(150)
            expect(gitlab_subscription.max_seats_used).to eq(0)
            expect(gitlab_subscription.plan_name).to eq('premium')
            expect(gitlab_subscription.plan_title).to eq('Premium')
          end

          it 'does not clear out existing data because of defaults' do
            gitlab_subscription.update!(seats: 20, max_seats_used: 42)

            params = { plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            put subscription_path(namespace.id), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload).to have_attributes(seats: 20, max_seats_used: 42)
          end

          it 'updates the timestamp when the attributes are the same' do
            expect do
              put subscription_path(namespace.id),
                headers: internal_api_headers,
                params: namespace.gitlab_subscription.attributes
            end.to change { gitlab_subscription.reload.updated_at }
          end

          context 'when starting a new term' do
            it 'resets the seat attributes for the subscription' do
              gitlab_subscription.update!(seats: 20, max_seats_used: 42, seats_owed: 22)

              expect(gitlab_subscription.seats_in_use).to eq 0

              new_start = gitlab_subscription.end_date + 1.year
              new_end = new_start + 1.year

              params = { seats: 150, plan_code: 'premium', start_date: new_start, end_date: new_end }

              put subscription_path(namespace.id), headers: internal_api_headers, params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(gitlab_subscription.reload).to have_attributes(max_seats_used: 1, seats_owed: 0)
            end
          end

          context 'when updating as a trial' do
            it 'sets the trial_starts_on to the start_date' do
              params = {
                start_date: '2018-01-01',
                trial: true,
                trial_ends_on: 1.month.from_now
              }

              put subscription_path(namespace.id), headers: internal_api_headers, params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(namespace.reload.gitlab_subscription.trial_starts_on).to be_present
              expect(namespace.gitlab_subscription.trial_starts_on.iso8601).to eq '2018-01-01'
            end
          end

          context 'when updating the trial expiration date' do
            it 'updates the trial expiration date' do
              date = 30.days.from_now.to_date

              params = { seats: 150, plan_code: 'ultimate', trial_ends_on: date.iso8601 }

              put subscription_path(namespace.id), headers: internal_api_headers, params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(gitlab_subscription.reload.trial_ends_on).to eq(date)
            end
          end
        end
      end
    end
  end
end
