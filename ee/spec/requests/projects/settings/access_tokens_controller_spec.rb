# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Settings::AccessTokensController, :saas, feature_category: :system_access do
  include GitlabSubscriptions::SubscriptionHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:resource) { create(:project, group: group, maintainers: user) }
  let_it_be(:access_token_user) { create(:user, :project_bot, maintainer_of: resource) }

  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    sign_in(user)
  end

  shared_examples 'feature unavailable' do
    context 'with a free plan' do
      let(:group) { create(:group_with_plan, plan: :free_plan) }
      let(:resource) { create(:project, group: group) }

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not a maintainer with a paid group plan' do
      before_all do
        resource.add_developer(user)
      end

      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end

  describe 'POST /:namespace/:project/-/settings/access_tokens' do
    let_it_be(:access_token_params) { { name: 'Nerd bot', scopes: ["api"], expires_at: 1.month.from_now } }

    subject(:request) do
      post project_settings_access_tokens_path(resource), params: { resource_access_token: access_token_params }
      response
    end

    context 'when has a bronze subscription' do
      before_all do
        # Use create_or_replace_subscription because maintainers: user (line 10)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :bronze)
      end

      it_behaves_like 'feature unavailable'
      it_behaves_like 'POST resource access tokens available'
    end

    context 'when has an active trial subscription' do
      before_all do
        create(:plan_limits, :ultimate_trial_plan, project_access_token_limit: 1)
        # Use create_or_replace_subscription because maintainers: user (line 10)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate_trial)
      end

      it 'can create first token successfully' do
        expect { request }.to change { PersonalAccessToken.count }.from(0).to(1)
        expect(response).to have_gitlab_http_status(:success)
      end

      it 'cannot create second token' do
        create(:personal_access_token, user: access_token_user)

        expect { request }.not_to change { PersonalAccessToken.count }
        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end

      context 'when there is token under different project of same group' do
        let(:another_project) { build(:project, group: group) }

        subject(:request) do
          post project_settings_access_tokens_path(another_project),
            params: { resource_access_token: access_token_params }
          response
        end

        before do
          another_project.add_maintainer(user)
        end

        it 'still cannot create new token' do
          create(:personal_access_token, user: access_token_user)

          expect { request }.not_to change { PersonalAccessToken.count }
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end
    end
  end

  describe 'PUT /:namespace/:project/-/settings/access_tokens/:id/revoke', :sidekiq_inline do
    let(:resource_access_token) { create(:personal_access_token, user: access_token_user) }

    subject(:request) do
      put revoke_project_settings_access_token_path(resource, resource_access_token)
      response
    end

    it_behaves_like 'feature unavailable'
    it_behaves_like 'PUT resource access tokens available'

    context 'when has trial subscription' do
      context 'when the trial subscription is active' do
        before do
          # Use create_or_replace_subscription because maintainers: user (line 10)
          # triggers Internal Events tracking, which auto-generates a FREE subscription
          create_or_replace_subscription(group, :ultimate_trial)
        end

        it 'can revoke token successfully' do
          request

          expect(resource_access_token.reload).to be_revoked
        end
      end

      context 'when the trial subscription is expired' do
        before do
          # Use create_or_replace_subscription because maintainers: user (line 10)
          # triggers Internal Events tracking, which auto-generates a FREE subscription
          create_or_replace_subscription(group, :expired_trial, :free)
        end

        it 'still can revoke token successfully' do
          request

          expect(resource_access_token.reload).to be_revoked
        end
      end
    end
  end
end
