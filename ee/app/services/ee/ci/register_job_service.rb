# frozen_string_literal: true

module EE
  module Ci
    module RegisterJobService
      extend ::Gitlab::Utils::Override

      # Applied to each HTTP phase (open/read/write) of each CustomersDot
      # request, not to the whole resolution: resolution issues two sequential
      # requests, so worst-case scheduling delay is a small multiple of this.
      SECRETS_MANAGER_ENTITLEMENT_TIMEOUT_SECONDS = 0.25

      # Caps job pickup at ~one CustomersDot resolution per namespace per TTL.
      SECRETS_MANAGER_ENTITLEMENT_CACHE_TTL = 1.minute

      override :pre_assign_runner_checks
      def pre_assign_runner_checks
        super.merge({
          ip_restriction_failure: ->(build, _) { build.project.group && !::Gitlab::IpRestriction::Enforcer.new(build.project.group).allows_current_ip? },
          secrets_provider_not_found: ->(build, _) { secrets_provider_not_found?(build) },
          secrets_manager_access_denied: ->(build, _) { secrets_manager_access_denied?(build) },
          duo_workflow_not_allowed: ->(build, _) { duo_workflow_not_allowed?(build) }
        })
      end

      private

      def duo_workflow_not_allowed?(build)
        build.pipeline.duo_workflow? && !Ai::DuoWorkflow::RunnerValidator.new(runner, build.project).valid?
      end

      def secrets_provider_not_found?(build)
        return false unless build.ci_secrets_management_available?
        return false unless build.secrets?

        !build.secrets_provider?(build.secrets)
      end

      # Mirrors the entitlement gate in EE::Ci::BuildRunnerPresenter, but drops
      # the build before runner assignment so users see a dedicated failure
      # reason instead of an opaque runner secret-resolution error.
      def secrets_manager_access_denied?(build)
        return false unless build.secrets?
        return false unless requests_gitlab_secrets_manager_secrets?(build)
        return false unless secrets_manager_licensed?(build.project)

        root_ancestor = build.project.root_ancestor
        return false unless ::Feature.enabled?(:secrets_manager_paid_experience, root_ancestor)

        entitlement_namespace = ::SecretsManagement::Entitlement.root_namespace_for(root_ancestor)
        entitlement = secrets_manager_entitlement(entitlement_namespace)
        return false if entitlement.nil? || entitlement.permits_direct_read?

        ::SecretsManagement::Entitlement::DenialTelemetry.track(
          entitlement: entitlement,
          surface: :job_scheduling,
          namespace: entitlement_namespace
        )

        true
      end

      def requests_gitlab_secrets_manager_secrets?(build)
        build.secrets.any? { |_, config| config.key?('gitlab_secrets_manager') }
      end

      def secrets_manager_licensed?(project)
        project.licensed_feature_available?(::SecretsManagement::Availability::LICENSED_FEATURE)
      end

      # Fail-open: on resolution failure the build is scheduled as before.
      # Nothing caches the failure, so the runner presenter re-resolves the
      # entitlement (with default HTTP timeouts) when building the payload.
      def secrets_manager_entitlement(namespace)
        ::SecretsManagement::Entitlement.for!(
          namespace,
          http_timeout: SECRETS_MANAGER_ENTITLEMENT_TIMEOUT_SECONDS,
          cache_ttl: SECRETS_MANAGER_ENTITLEMENT_CACHE_TTL
        )
      rescue StandardError => e
        ::Gitlab::ErrorTracking.log_exception(e, ::Labkit::Fields::GL_NAMESPACE_ID => namespace&.id)
        nil
      end
    end
  end
end
