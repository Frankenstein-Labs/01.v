# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions routing', feature_category: :subscription_management do
  it 'routes to track_cart_abandonment' do
    expect(post('/-/gitlab_subscriptions/hand_raise_leads/track_cart_abandonment')).to route_to(
      controller: 'gitlab_subscriptions/hand_raise_leads',
      action: 'track_cart_abandonment'
    )
  end

  it "routes to TrialsController when constraint matches saas", :saas_subscriptions_trials do
    expect(get('/-/trials/new')).to route_to('gitlab_subscriptions/trials#new')
  end

  it "routes to SelfManaged::TrialsController when constraint does not match saas" do
    expect(get('/-/trials/new')).to route_to('gitlab_subscriptions/self_managed/trials#new')
  end

  context 'when the in_instance_self_managed_trial_activation feature flag is disabled' do
    before do
      stub_feature_flags(in_instance_self_managed_trial_activation: false)
    end

    let(:default_return_to) do
      Gitlab::Routing.url_helpers.general_admin_application_settings_url(anchor: 'js-add-license-toggle')
    end

    it 'redirects /-/trials/new to the customers portal with the default return_to', type: :request do
      expect(get('/-/trials/new')).to redirect_to(
        subscription_portal_new_trial_url(return_to: default_return_to)
      )
    end

    it 'preserves a caller-supplied return_to', type: :request do
      expect(get('/-/trials/new?return_to=https%3A%2F%2Fexample.com%2Ffoo')).to redirect_to(
        subscription_portal_new_trial_url(return_to: 'https://example.com/foo')
      )
    end
  end
end
