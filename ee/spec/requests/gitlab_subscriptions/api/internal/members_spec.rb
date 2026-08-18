# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Members, :aggregate_failures, :api, feature_category: :subscription_management do
  describe 'GET /internal/gitlab_subscriptions/namespaces/:id/owners', :saas do
    include GitlabSubscriptions::InternalApiHelpers

    let_it_be(:namespace) { create(:group) }

    def owners_path(namespace_id)
      internal_api("namespaces/#{namespace_id}/owners")
    end

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get owners_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get owners_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Group Namespace Not Found')
        end
      end

      context 'when the namespace does not have any owners' do
        it 'returns an empty response' do
          get owners_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when the namespace has owners and other members' do
        let_it_be(:owner_1) { create(:user) }
        let_it_be_with_reload(:owner_2) { create(:user) }
        let_it_be(:maintainer) { create(:user) }
        let_it_be(:guest) { create(:user) }

        let_it_be(:sub_group_owner) { create(:user) }
        let_it_be(:sub_group) { create(:group, parent: namespace) }

        before_all do
          namespace.add_owner(owner_1)
          namespace.add_owner(owner_2)

          namespace.add_maintainer(maintainer)
          namespace.add_guest(guest)

          sub_group.add_owner(sub_group_owner)
        end

        it 'returns only direct owners of the namespace' do
          expected_response = [
            {
              'user' => {
                'id' => owner_1.id,
                'username' => a_kind_of(String),
                'name' => a_kind_of(String),
                'public_email' => nil
              },
              'access_level' => 50,
              'notification_email' => a_kind_of(String)
            },
            {
              'user' => {
                'id' => owner_2.id,
                'username' => a_kind_of(String),
                'name' => a_kind_of(String),
                'public_email' => nil
              },
              'access_level' => 50,
              'notification_email' => a_kind_of(String)
            }
          ]

          expected_pagination_headers = {
            'X-Per-Page' => '20',
            'X-Page' => '1',
            'X-Next-Page' => '',
            'X-Prev-Page' => '',
            'X-Total' => '2',
            'X-Total-Pages' => '1'
          }

          get owners_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers).to match(hash_including(expected_pagination_headers))

          expect(json_response.count).to eq(2)
          expect(json_response).to match_array(expected_response)
        end

        context 'when the owner is inactive' do
          before do
            owner_2.block!
          end

          it 'does not return inactive users' do
            get owners_path(namespace.id), headers: internal_api_headers

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.count).to eq(1)
            expect(json_response.first['user']['id']).to eq(owner_1.id)
          end
        end
      end
    end
  end
end
