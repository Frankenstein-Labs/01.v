# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DiscoversController, :saas, feature_category: :activation do
  include SubscriptionPortalHelpers

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, developers: developer, maintainers: maintainer, owners: owner) }
  let_it_be(:gitlab_subscription) do
    create(:gitlab_subscription, :active_trial, :ultimate_trial, namespace: group, trial_ends_on: Date.tomorrow)
  end

  describe 'GET show' do
    before do
      stub_saas_features(subscriptions_trials: true)
      stub_subscription_monthly_commitment_request
    end

    subject { response }

    shared_examples 'unauthorized' do
      it 'renders index with 404 status code' do
        get group_discover_path(group)

        is_expected.to have_gitlab_http_status(:not_found)
        is_expected.not_to render_template(:show)
      end
    end

    context 'when user is owner' do
      before do
        sign_in(owner)
        stub_billing_plans(group.id)
      end

      it 'renders index with 200 status code' do
        get group_discover_path(group)

        is_expected.to have_gitlab_http_status(:ok)
      end
    end

    context 'when user is maintainer' do
      before do
        sign_in(maintainer)
      end

      it_behaves_like 'unauthorized'
    end

    context 'when user is developer' do
      before do
        sign_in(developer)
      end

      it_behaves_like 'unauthorized'
    end

    it 'renders 404 when saas feature subscriptions_trials not available' do
      stub_saas_features(subscriptions_trials: false)
      sign_in(owner)

      get group_discover_path(group)

      is_expected.to have_gitlab_http_status(:not_found)
    end

    context 'when group is not on trial' do
      let_it_be(:group) { create(:group) }
      let_it_be(:expired_subscription) do
        create(:gitlab_subscription, :expired_trial, :free, namespace: group, trial_ends_on: 1.day.ago)
      end

      before do
        stub_billing_plans(group.id)
        stub_subscription_monthly_commitment_request
      end

      it 'renders page when group has an expired trial' do
        group.add_owner(owner)
        sign_in(owner)

        get group_discover_path(group)

        is_expected.to have_gitlab_http_status(:ok)
      end
    end
  end
end
