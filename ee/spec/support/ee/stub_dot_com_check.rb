# frozen_string_literal: true

RSpec.configure do |config|
  %i[saas saas_registration saas_trial].each do |_metadata|
    config.include SubscriptionPortalHelpers

    config.before do
      # Stubbing calls to the customers portal globally as the Duo panel calls it
      # to check trial duration.
      stub_subscription_trial_types
    end
  end
end
