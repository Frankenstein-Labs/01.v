# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'view usage quotas', :saas, feature_category: :consumables_cost_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:subscription_history) do
    create(
      :gitlab_subscription_history,
      namespace: namespace,
      start_date: 1.year.ago,
      end_date: Time.now.utc,
      seats: 10,
      seats_in_use: 8,
      max_seats_used: 12,
      change_type: :gitlab_subscription_updated
    )
  end

  describe 'GET /groups/:group/-/usage_quotas', :with_trial_types do
    subject(:request) { get group_usage_quotas_path(namespace) }

    before_all do
      namespace.add_owner(user)
    end

    before do
      login_as(user)
    end

    context 'when storage size is over limit' do
      it_behaves_like 'namespace storage limit alert'
    end
  end

  describe 'GET /groups/:group/-/usage_quotas/subscription_history' do
    subject(:request) { get subscription_history_group_usage_quotas_path(namespace) }

    before do
      login_as(user)
      request
    end

    it 'returns :not_found if user is not a member of the group' do
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when user is not an owner' do
      before_all do
        namespace.add_developer(user)
      end

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when user is owner of the group' do
      before_all do
        namespace.add_owner(user)
      end

      it { expect(response).to have_gitlab_http_status(:ok) }

      it 'returns csv with expected data' do
        expect(response.body).to eq(
          "History entry date,Subscription updated at,Start date,End date," \
            "Seats purchased,Seats in use,Max seats used,Change Type\n" \
            "#{subscription_history.created_at},#{subscription_history.gitlab_subscription_updated_at}," \
            "#{subscription_history.start_date},#{subscription_history.end_date}," \
            "#{subscription_history.seats},#{subscription_history.seats_in_use}," \
            "#{subscription_history.max_seats_used},#{subscription_history.change_type}\n"
        )
      end
    end
  end
end
