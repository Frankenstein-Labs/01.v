# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::CodeSuggestionsHelper, feature_category: :seat_cost_management do
  include SubscriptionPortalHelper

  describe '#add_duo_pro_seats_url' do
    let(:subscription_name) { 'A-S000XXX' }
    let(:env_value) { nil }

    before do
      stub_env('CUSTOMER_PORTAL_URL', env_value)
    end

    it 'returns expected url' do
      expected_url = "#{staging_customers_url}/gitlab/subscriptions/#{subscription_name}/duo_pro_seats"
      expect(helper.add_duo_pro_seats_url(subscription_name)).to eq expected_url
    end
  end
end
