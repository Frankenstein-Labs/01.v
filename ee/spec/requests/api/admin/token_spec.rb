# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Token, :aggregate_failures, feature_category: :system_access do
  let_it_be(:admin) { create(:admin, :with_namespace) }
  let(:api_user) { admin }
  let(:url) { '/admin/token' }
  let(:params) { { token: plaintext } }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:scim_group) { create(:group) }
  let_it_be(:scim_oauth_token) { create(:scim_oauth_access_token, organization: organization) }
  let_it_be(:scim_group_token) { create(:group_scim_auth_access_token, group: scim_group) }
  let_it_be(:user) { create(:user) }

  describe 'POST /admin/token' do
    subject(:post_token) { post(api(url, api_user, admin_mode: true), params: params) }

    context 'when the user is an admin' do
      context 'with SCIM tokens' do
        where(:token, :plaintext) do
          [
            [ref(:scim_oauth_token), lazy { scim_oauth_token.token }],
            [ref(:scim_group_token), lazy { scim_group_token.token }]
          ]
        end

        with_them do
          it 'returns info about the token' do
            post_token

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['id']).to eq(token.id)
          end
        end

        context 'with ScimOauthAccessToken' do
          let(:plaintext) { scim_oauth_token.token }

          it 'returns the correct entity fields including organization_id' do
            post_token

            expect(json_response.keys).to include('id', 'created_at', 'group_id', 'organization_id')
            expect(json_response['organization_id']).to eq(organization.id)
          end
        end

        context 'with GroupScimAuthAccessToken' do
          let(:plaintext) { scim_group_token.token }

          it 'returns the correct entity fields including group_id' do
            post_token

            expect(json_response.keys).to include('id', 'created_at', 'group_id')
            expect(json_response['group_id']).to eq(scim_group.id)
          end
        end
      end
    end

    context 'when the user is not an admin' do
      let(:api_user) { user }
      let(:plaintext) { scim_oauth_token.token }

      it_behaves_like 'returning response status', :forbidden
    end

    context 'without a user' do
      let(:api_user) { nil }
      let(:plaintext) { scim_oauth_token.token }

      it_behaves_like 'returning response status', :unauthorized
    end
  end

  describe 'DELETE /admin/token' do
    subject(:delete_token) { delete(api(url, api_user, admin_mode: true), params: params) }

    context 'when the user is an admin' do
      context 'with SCIM tokens' do
        let(:scim_oauth_token) { create(:scim_oauth_access_token, organization: organization) }
        let(:scim_group_token) { create(:group_scim_auth_access_token, group: scim_group) }

        where(:token, :plaintext) do
          [
            [ref(:scim_oauth_token), lazy { scim_oauth_token.token }],
            [ref(:scim_group_token), lazy { scim_group_token.token }]
          ]
        end

        with_them do
          it 'resets the token and returns no_content' do
            old_token = token.token

            delete_token

            expect(response).to have_gitlab_http_status(:no_content)
            expect(token.reload.token).not_to eq(old_token)
          end
        end
      end
    end

    context 'when the user is not an admin' do
      let(:api_user) { user }
      let(:plaintext) { scim_oauth_token.token }

      it_behaves_like 'returning response status', :forbidden
    end

    context 'without a user' do
      let(:api_user) { nil }
      let(:plaintext) { scim_oauth_token.token }

      it_behaves_like 'returning response status', :unauthorized
    end
  end
end
