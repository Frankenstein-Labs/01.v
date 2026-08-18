# frozen_string_literal: true

module Cd
  module Rollouts
    # Transitions a pending rollout to in_progress and starts the corresponding
    # AutoFlow workflow on KAS, persisting the returned workflow key.
    #
    # The rollout graph is passed to Gitlab::Kas::Client#start_workflow as plain
    # Ruby kwargs, which the client converts into AutoFlow protobuf values
    # (see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/242249).
    class StartService
      def initialize(rollout)
        @rollout = rollout
      end

      def execute
        # Idempotent no-op: a previous attempt already started the workflow.
        return ServiceResponse.success(payload: { rollout: rollout }) if rollout.workflow_ref.present?

        return error(_('Rollout cannot be started because it is not pending.')) unless startable?
        return error(_('Rollout cannot be started because it has no flow definition.')) unless flow_definition

        unless driver_ref
          return error(_('Rollout cannot be started because it has no environments bound to a deploy driver.'))
        end

        if ambiguous_driver_refs?
          return error(_('Rollout cannot be started because its environments use different deploy drivers.'))
        end

        unless driver
          return error(format(_("Rollout cannot be started because deploy driver '%{driver_ref}' is not registered."),
            driver_ref: driver_ref))
        end

        return error(flow_definition_schema_errors) if flow_definition_schema_errors.present?

        # Call KAS before the database write so a slow or failing gRPC request does
        # not hold a transaction open. A KAS failure raises before any write,
        # leaving the rollout untouched (still pending, no workflow_ref) so the
        # idempotent worker can retry.
        response = kas_client.start_workflow(
          idempotency_key: idempotency_key,
          workflow_definition: workflow_definition,
          namespace_id: rollout.organization_id,
          kwargs: workflow_kwargs
        )

        # start! persists workflow_ref and the state transition in a single update.
        # workflow_ref is assigned first because a non-pending rollout requires it.
        rollout.workflow_ref = response.workflow_key
        rollout.start!

        ServiceResponse.success(payload: { rollout: rollout })
      end

      private

      attr_reader :rollout

      # Only a pending rollout can be started. A failed KAS call leaves the
      # rollout pending (the transition is persisted only after KAS succeeds), so
      # the idempotent worker always retries from pending.
      def startable?
        rollout.pending?
      end

      def flow_definition
        rollout.application_flow_definition
      end

      def kas_client
        @kas_client ||= ::Gitlab::Kas::Client.new
      end

      def idempotency_key
        "cd-rollout-#{rollout.id}"
      end

      # Unencoded: KAS runs the Starlark as-is and fails on base64. An assembler
      # ArgumentError propagates: its inputs are vendored gem bytes, so it means a
      # malformed release, and StartWorker discards the ServiceResponse.
      def workflow_definition
        ::Cd::DeployDrivers::Registry.orchestrator.assemble(driver_scripts: driver_scripts)
      end

      # Keyed by gem name, which the engine derives each fragment's identifier from.
      def driver_scripts
        drivers.sort_by(&:gem_name).to_h { |resolved| [resolved.gem_name, resolved.deploy_fragment] }
      end

      def driver
        drivers.first
      end

      # filter_map drops unregistered refs, safe only while ambiguous_driver_refs? caps
      # this at one, so the `unless driver` guard still reports it.
      def drivers
        @drivers ||= driver_refs.filter_map { |ref| ::Cd::DeployDrivers::Registry.find(ref) }
      end

      # Checked here, against the driver actually resolved for this rollout, rather
      # than at flow definition authoring time: a driver rebinding after the flow was
      # written would otherwise leave a stale, incompatible config undetected until the
      # deploy failed inside KAS.
      def flow_definition_schema_errors
        @flow_definition_schema_errors ||= ::Cd::DeployDrivers::FlowDefinitionValidator.new(
          document: YAML.safe_load(flow_definition.definition), drivers: [driver]
        ).errors
      end

      # Beta ships exactly one driver, so every rollout_environment is expected
      # to share the same driver_ref; ambiguous_driver_refs? guards the future
      # multi-driver case generically instead of silently picking one.
      def driver_ref
        driver_refs.first
      end

      def ambiguous_driver_refs?
        driver_refs.size > 1
      end

      def driver_refs
        @driver_refs ||= rollout_environments.map { |re| re.driver_binding.driver_ref }.uniq
      end

      # Ordered so the assembled program's bytes do not depend on row order.
      def rollout_environments
        @rollout_environments ||= rollout.rollout_environments.ordered.preload_environment_and_driver_binding
      end

      # The rollout graph passed as plain Ruby kwargs so AutoFlow can resolve the
      # environments, driver bindings and version set to deploy. Nested Hashes and
      # Arrays are converted to AutoFlow dict/list values by Gitlab::Kas::Client.
      def workflow_kwargs
        WorkflowKwargs.new(rollout).to_h.merge(
          'callback_token' => ::Gitlab::Kas::Autoflow::ValueConverter.sensitive_string(CallbackToken.encode(rollout))
        )
      end

      def error(message)
        ServiceResponse.error(message: Array(message), payload: { rollout: rollout })
      end
    end
  end
end
