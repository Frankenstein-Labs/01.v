# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GitlabSubscriptions::Subscriptions, :aggregate_failures, feature_category: :plan_provisioning do
  include GitlabSubscriptions::InternalApiHelpers

  def subscription_path(namespace_id, user = nil, options = {})
    api("/namespaces/#{namespace_id}/gitlab_subscription", user, **options)
  end

  describe 'POST :id/gitlab_subscription', :saas do
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
            params: params.merge(trial: true, trial_ends_on: 30.days.from_now)
          )

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.reload.gitlab_subscription.trial_starts_on).to be_present
          expect(namespace.gitlab_subscription.trial_starts_on.iso8601).to eq '2018-01-01'
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }

      let(:params) { { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' } }

      it_behaves_like 'POST request permissions for admin mode' do
        let(:current_user) { admin }
        let(:path) { "/namespaces/#{namespace.id}/gitlab_subscription" }
      end

      context 'when authenticated as a regular user' do
        it 'returns an unauthorized error' do
          user = create(:user)

          post subscription_path(namespace.id, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an admin' do
        it 'fails when the start_date is missing' do
          post api("/namespaces/#{namespace.id}/gitlab_subscription", admin, admin_mode: true),
            params: params.except(:start_date)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'fails when the record is invalid' do
          post subscription_path(namespace.id, admin, admin_mode: true), params: params.merge(start_date: nil)

          expect(response).to have_gitlab_http_status(:bad_request)
        end

        it 'creates a subscription for the namespace' do
          post subscription_path(namespace.id, admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.gitlab_subscription).to be_present
        end

        it 'sets the trial_starts_on to the start_date' do
          post(
            subscription_path(namespace.id, admin, admin_mode: true),
            params: params.merge(trial: true, trial_ends_on: 30.days.from_now)
          )

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.reload.gitlab_subscription.trial_starts_on).to be_present
          expect(namespace.gitlab_subscription.trial_starts_on.iso8601).to eq params[:start_date]
        end

        it 'can create a subscription using full_path' do
          post subscription_path(namespace.full_path, admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:created)
          expect(namespace.gitlab_subscription).to be_present
        end

        it_behaves_like 'authorizing granular token permissions', :create_gitlab_subscription do
          let(:boundary_object) { create(:group) }
          let(:user) { admin }
          let(:request) do
            post api("/namespaces/#{boundary_object.id}/gitlab_subscription", personal_access_token: pat),
              params: params
          end
        end

        it_behaves_like 'authorizing granular token permissions', :create_gitlab_subscription do
          let(:boundary_object) { :user }
          let(:user) { admin }
          let(:request) do
            post api("/namespaces/#{namespace.id}/gitlab_subscription", personal_access_token: pat), params: params
          end
        end

        context 'when the namespace does not exist' do
          it 'returns a 404' do
            post subscription_path(non_existing_record_id, admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Namespace Not Found')
          end
        end

        context 'when creating subscription for project namespace' do
          it 'returns a 404' do
            project_namespace = create(:project).project_namespace

            post subscription_path(project_namespace.id, admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Namespace Not Found')
          end
        end
      end
    end
  end

  describe 'PUT :id/gitlab_subscription', :saas do
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
          project_namespace = create(:project, namespace: namespace).project_namespace

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

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:premium_plan) { create(:premium_plan) }
      let_it_be(:group_namespace) { create(:group) }

      let_it_be(:gitlab_subscription) do
        create(:gitlab_subscription, namespace: namespace, start_date: '2018-01-01', end_date: '2019-01-01')
      end

      let_it_be(:group_gitlab_subscription) do
        create(:gitlab_subscription, namespace: group_namespace, start_date: '2018-01-01', end_date: '2019-01-01')
      end

      it_behaves_like 'PUT request permissions for admin mode' do
        let(:path) { "/namespaces/#{namespace.id}/gitlab_subscription" }
        let(:current_user) { admin }
        let(:params) { { start_date: '2018-01-01', end_date: '2019-01-01', seats: 10, plan_code: 'ultimate' } }
      end

      context 'when authenticated as a regular user' do
        it 'returns an unauthorized error' do
          user = create(:user)

          put subscription_path(namespace.id, user, admin_mode: false), params: { seats: 150 }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an admin' do
        context 'when namespace is not found' do
          it 'returns a 404 error' do
            put subscription_path(non_existing_record_id, admin, admin_mode: true), params: { seats: 150 }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when namespace does not have a subscription' do
          let_it_be(:namespace_2) { create(:group) }

          it 'returns a 404 error' do
            put subscription_path(namespace_2.id, admin, admin_mode: true), params: { seats: 150 }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when namespace is a project namespace' do
          it 'returns a 404 error' do
            project_namespace = create(:project).project_namespace

            put subscription_path(project_namespace.id, admin, admin_mode: true), params: { seats: 150 }

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response).to eq('message' => '404 Namespace Not Found')
          end
        end

        context 'when params are invalid' do
          it 'returns a 400 error' do
            put subscription_path(namespace.id, admin, admin_mode: true), params: { seats: nil }

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end

        context 'when params are valid' do
          it 'updates the subscription for the group' do
            params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            put subscription_path(namespace.id, admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload.seats).to eq(150)
            expect(gitlab_subscription.max_seats_used).to eq(0)
            expect(gitlab_subscription.plan_name).to eq('premium')
            expect(gitlab_subscription.plan_title).to eq('Premium')
          end

          it 'is successful when using full_path routing' do
            params = { seats: 150, plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            put subscription_path(namespace.full_path, admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'does not clear out existing data because of defaults' do
            gitlab_subscription.update!(seats: 20, max_seats_used: 42)

            params = { plan_code: 'premium', start_date: '2018-01-01', end_date: '2019-01-01' }

            put subscription_path(namespace.id, admin, admin_mode: true), params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(gitlab_subscription.reload).to have_attributes(
              seats: 20,
              max_seats_used: 42
            )
          end

          it 'updates the timestamp when the attributes are the same' do
            expect do
              put subscription_path(namespace.id, admin, admin_mode: true),
                params: namespace.gitlab_subscription.attributes
            end.to change { gitlab_subscription.reload.updated_at }
          end

          context 'when starting a new term' do
            it 'resets the seat attributes for the subscription' do
              gitlab_subscription.update!(seats: 20, max_seats_used: 42, seats_owed: 22)

              new_start = gitlab_subscription.end_date + 1.year
              new_end = new_start + 1.year

              expect(gitlab_subscription.seats_in_use).to eq 0

              params = { seats: 150, plan_code: 'premium', start_date: new_start, end_date: new_end }

              put subscription_path(namespace.id, admin, admin_mode: true), params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(gitlab_subscription.reload).to have_attributes(max_seats_used: 1, seats_owed: 0)
            end
          end

          context 'when updating the trial expiration date' do
            it 'updates the trial expiration date' do
              date = 30.days.from_now.to_date

              params = { seats: 150, plan_code: 'ultimate', trial_ends_on: date.iso8601 }

              put subscription_path(namespace.id, admin, admin_mode: true), params: params

              expect(response).to have_gitlab_http_status(:ok)
              expect(gitlab_subscription.reload.trial_ends_on).to eq(date)
            end
          end

          it_behaves_like 'authorizing granular token permissions', :update_gitlab_subscription do
            let(:boundary_object) { group_namespace }
            let(:user) { admin }
            let(:request) do
              put api("/namespaces/#{group_namespace.id}/gitlab_subscription", personal_access_token: pat),
                params: { seats: 150 }
            end
          end

          it_behaves_like 'authorizing granular token permissions', :update_gitlab_subscription do
            let(:boundary_object) { :user }
            let(:user) { admin }
            let(:request) do
              put api("/namespaces/#{namespace.id}/gitlab_subscription", personal_access_token: pat),
                params: { seats: 150 }
            end
          end
        end
      end
    end
  end
end
