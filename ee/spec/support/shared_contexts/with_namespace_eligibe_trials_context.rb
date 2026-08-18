# frozen_string_literal: true

RSpec.shared_context 'with stubbing of namespace eligible trials fetching' do
  include SubscriptionPortalHelpers

  before do
    stub_cdot_namespace_eligible_trials
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with stubbing of namespace eligible trials fetching', with_namespace_eligible_trials: true
end
