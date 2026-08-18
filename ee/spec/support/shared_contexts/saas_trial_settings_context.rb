# frozen_string_literal: true

# goal of this context: provide a close/stable representation of how SaaS is configured currently
# things that belong in here:
# - settled-not-yet-removed-in-saas feature flag settings
# - application settings for SaaS
# - .com specific type things google tag manager(gtm)
# things that don't belong in here:
# - unsettled feature flag settings in SaaS(still in rollout), instead test both branches to cover SaaS
RSpec.shared_context 'with saas settings for in-app trial flows' do
  include Features::TrialHelpers

  before do
    stub_config(extra: { 'google_tag_manager_nonce_id' => 'key' })
    stub_subscription_trial_types
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with saas settings for in-app trial flows', saas_trial: true
end
