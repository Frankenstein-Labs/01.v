# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionHelper, feature_category: :seat_cost_management do
  describe '#gitlab_com_subscription?' do
    context 'when GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'returns true' do
        expect(helper.gitlab_com_subscription?).to be_truthy
      end
    end

    context 'when not GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns false' do
        expect(helper.gitlab_com_subscription?).to be_falsy
      end
    end
  end
end
