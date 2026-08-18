# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::PersonalAccessTokens, :aggregate_failures, feature_category: :system_access do
  describe 'DELETE /personal_access_tokens/:id' do
    let_it_be(:current_user) { create(:user) }

    context 'for GitLab.com', :saas do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:group) { create(:group, :private) }
      let_it_be(:user) { create(:user) }
      let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }

      where(:group_member, :group_owner?, :licensed?, :http_status) do
        ref(:user)            | false          | false      | :bad_request
        ref(:user)            | false          | true       | :bad_request
        ref(:user)            | true           | false      | :bad_request
        ref(:user)            | true           | true       | :bad_request

        ref(:enterprise_user) | false          | false      | :bad_request
        ref(:enterprise_user) | false          | true       | :bad_request
        ref(:enterprise_user) | true           | false      | :bad_request
        ref(:enterprise_user) | true           | true       | :no_content
      end

      with_them do
        let(:token) { create(:personal_access_token, user: group_member) }
        let(:path) { "/personal_access_tokens/#{token.id}" }

        it "has HTTP status #{params[:http_status]}" do
          stub_licensed_features(domain_verification: licensed?, credentials_inventory: licensed?)

          access_level = group_owner? ? :owner : :maintainer
          group.add_member(current_user, access_level)
          group.add_developer(group_member)

          delete api(path, current_user)

          expect(response).to have_gitlab_http_status(http_status)
        end
      end
    end
  end
end
