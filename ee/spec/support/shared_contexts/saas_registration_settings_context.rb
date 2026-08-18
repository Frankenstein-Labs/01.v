# frozen_string_literal: true

# goal of this context: provide a close/stable representation of how SaaS is configured currently
# things that belong in here:
# - settled-not-yet-removed-in-saas feature flag settings
# - application settings for SaaS
# - .com specific type things like enforcing of terms
# things that don't belong in here:
# - unsettled feature flag settings in SaaS(still in rollout), instead test both branches to cover SaaS
RSpec.shared_context 'with saas settings for registration flows' do
  include TermsHelper
  include SaasRegistrationHelpers

  before do
    # Saas doesn't require admin approval.
    stub_application_setting(require_admin_approval_after_user_signup: false)

    stub_application_setting(import_sources: %w[github gitlab_project])

    # SaaS always requires confirmation, since the default is set to `off` we want to ensure SaaS is set to `hard`
    stub_application_setting_enum('email_confirmation_setting', 'hard')

    stub_saas_features(identity_verification: true)

    stub_config(extra: { 'google_tag_manager_nonce_id' => 'key' })

    allow_next_instance_of(::Onboarding::CreateIterableTriggerService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success)
    end

    enforce_terms
  end
end

RSpec.configure do |rspec|
  rspec.include_context 'with saas settings for registration flows', saas_registration: true
end
