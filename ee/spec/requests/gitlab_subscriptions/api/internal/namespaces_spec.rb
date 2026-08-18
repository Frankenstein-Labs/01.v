# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Namespaces, :saas, :aggregate_failures, :api, feature_category: :plan_provisioning do
  include AfterNextHelpers
  include GitlabSubscriptions::InternalApiHelpers

  def namespace_path(namespace_id)
    internal_api("namespaces/#{namespace_id}")
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:id' do
    let_it_be(:namespace) { create(:group) }

    context 'when unauthenticated' do
      it 'returns an error response' do
        get namespace_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get namespace_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when fetching a group namespace' do
        it 'successfully returns the namespace attributes' do
          get namespace_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'id' => namespace.id,
            'kind' => 'group',
            'name' => namespace.name,
            'parent_id' => nil,
            'path' => namespace.path,
            'full_path' => namespace.full_path,
            'avatar_url' => nil,
            'plan' => 'free',
            'projects_count' => 0,
            'root_repository_size' => nil,
            'shared_runners_minutes_limit' => nil,
            'trial' => false,
            'trial_ends_on' => nil,
            'web_url' => namespace.web_url,
            'additional_purchased_storage_size' => 0,
            'additional_purchased_storage_ends_on' => nil,
            'billable_members_count' => 0,
            'extra_shared_runners_minutes_limit' => nil,
            'members_count_with_descendants' => 0
          })
        end
      end

      context 'when fetching a user namespace' do
        it 'successfully returns the namespace attributes' do
          user_namespace = create(:user, :with_namespace).namespace

          get namespace_path(user_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to match(
            'id' => user_namespace.id,
            'kind' => 'user',
            'name' => user_namespace.name,
            'parent_id' => nil,
            'path' => user_namespace.path,
            'full_path' => user_namespace.full_path,
            'avatar_url' => user_namespace.avatar_url,
            'plan' => 'free',
            'shared_runners_minutes_limit' => nil,
            'trial' => false,
            'trial_ends_on' => nil,
            'web_url' => a_string_including(user_namespace.path),
            'additional_purchased_storage_size' => 0,
            'additional_purchased_storage_ends_on' => nil,
            'billable_members_count' => 1,
            'extra_shared_runners_minutes_limit' => nil
          )
        end
      end
    end
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:id' do
    context 'when unauthenticated' do
      it 'returns an error response' do
        put namespace_path(non_existing_record_id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          put namespace_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when a project namespace ID is passed' do
        it 'returns 404' do
          project = create(:project)

          put namespace_path(project.project_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when updating gitlab subscription data' do
        let_it_be(:root_namespace) { create(:namespace_with_plan) }

        it "updates the gitlab_subscription record" do
          existing_subscription = root_namespace.gitlab_subscription

          params = {
            gitlab_subscription_attributes: {
              start_date: '2019-06-01',
              end_date: '2020-06-01',
              plan_code: 'ultimate',
              seats: 20,
              max_seats_used: 10,
              auto_renew: true,
              trial: true,
              trial_starts_on: '2019-05-01',
              trial_ends_on: '2019-06-01',
              trial_extension_type: GitlabSubscription.trial_extension_types[:reactivated]
            }
          }

          put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

          expect(root_namespace.reload.gitlab_subscription.reload.seats).to eq 20
          expect(root_namespace.gitlab_subscription).to eq existing_subscription
        end

        it 'returns a 400 error with invalid data' do
          params = {
            gitlab_subscription_attributes: {
              start_date: nil,
              end_date: '2020-06-01',
              plan_code: 'ultimate',
              seats: nil,
              max_seats_used: 10,
              auto_renew: true
            }
          }

          put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(
            "gitlab_subscription.seats" => ["can't be blank"],
            "gitlab_subscription.start_date" => ["can't be blank"]
          )
        end
      end

      describe 'runners minutes limits' do
        let_it_be(:root_namespace) do
          create(
            :group,
            :with_ci_minutes,
            ci_minutes_used: 1600,
            shared_runners_minutes_limit: 1000,
            extra_shared_runners_minutes_limit: 500
          )
        end

        context 'when updating the extra_shared_runners_minutes_limit' do
          let(:params) { { extra_shared_runners_minutes_limit: 1000 } }

          it 'updates the extra shared runners minutes limit' do
            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['extra_shared_runners_minutes_limit'])
              .to eq(params[:extra_shared_runners_minutes_limit])
          end

          it 'expires the compute minutes CachedQuota' do
            expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'resets the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect { put namespace_path(root_namespace.id), headers: internal_api_headers, params: params }
              .to change { usage.reload.notification_level }
              .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end

          it 'refreshes cached data' do
            expect(::Ci::Minutes::RefreshCachedDataService)
              .to receive(:new)
              .with(root_namespace)
              .and_call_original

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end
        end

        context 'when updating the shared_runners_minutes_limit' do
          let(:params) { { shared_runners_minutes_limit: 9000 } }

          it 'expires the compute minutes CachedQuota' do
            expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'resets the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect do
              put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
            end.to change { usage.reload.notification_level }
               .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end
        end

        context 'when neither minutes_limit params is provided' do
          let(:params) { { plan_code: 'free' } }

          it 'does not expire the compute minutes CachedQuota' do
            expect(Gitlab::Ci::Minutes::CachedQuota).not_to receive(:new)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'does not reset the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect { put namespace_path(root_namespace.id), headers: internal_api_headers, params: params }
              .not_to change { usage.reload.notification_level }
          end
        end
      end
    end
  end
end
