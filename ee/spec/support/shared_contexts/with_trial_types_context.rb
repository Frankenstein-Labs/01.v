# frozen_string_literal: true

RSpec.shared_context 'with stubbing of trial types fetching' do
  include SubscriptionPortalHelpers

  before do
    stub_saas_features(subscriptions_trials: true)
    stub_subscription_trial_types
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with stubbing of trial types fetching', with_trial_types: true
end
