# frozen_string_literal: true

module SecretsManagement
  module EnrollmentHelpers
    # Satisfies the instance-enrollment leg of `Availability.enabled_for_*?`
    # (`license AND FF AND enrollment`). Use in specs that exercise SM-gated
    # code paths without going through the `provision_*_secrets_manager`
    # helpers (which auto-enroll). For the SaaS namespace branch, set
    # `Gitlab.com?` and create a `:secrets_manager_namespace_enrollment`
    # record instead.
    def enroll_instance_in_secrets_manager
      stub_application_setting(secrets_manager_instance_enrolled: true)
      stub_secrets_manager_entitlement
    end

    # The entitlement-aware policy denies all SM abilities unless the namespace is
    # entitled, and the flag that activates it is on by default in tests. Specs that
    # set up SM availability without modelling a subscription should call this so the
    # SM-gated paths stay reachable; specs exercising specific entitlement states
    # re-stub `Entitlement.for` afterwards.
    def stub_secrets_manager_entitlement(state: :paid, blocked_reason: :grace)
      allow(::SecretsManagement::Entitlement)
        .to receive(:for)
        .and_return(
          ::SecretsManagement::Entitlement.new(
            state: state,
            blocked_reason: state == :blocked ? blocked_reason : nil
          )
        )
    end
  end
end
