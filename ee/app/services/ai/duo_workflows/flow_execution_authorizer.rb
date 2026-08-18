# frozen_string_literal: true

module Ai
  module DuoWorkflows
    # Governance follows how a run is executed, not which flow it is. Per-container flow
    # enablement governs what GitLab runs unattended, so it does not reach a run the
    # caller performs itself.
    #
    # Nothing the client asserts about itself feeds this classification, so client
    # execution cannot be claimed while still getting background execution.
    class FlowExecutionAuthorizer
      include Gitlab::Utils::StrongMemoize
      include Gitlab::Loggable

      # `new` is private, so the classification cannot be forged from a raw value. CLIENT
      # and BACKGROUND are for this class to hand out: do not pass them to
      # CreateWorkflowService from anywhere else.
      class Classification
        private_class_method :new

        CLIENT = new.freeze
        BACKGROUND = new.freeze

        def client_executed?
          equal?(CLIENT)
        end

        def background?
          equal?(BACKGROUND)
        end
      end

      # Conditions of Ai::Catalog::ItemConsumerPolicy that a client-executed run is
      # deliberately not subject to. Not read at runtime; enforced by the accounting
      # spec in flow_execution_authorizer_spec.rb.
      #
      # The conditions ItemConsumerPolicy delegates to, such as the AI catalog
      # entitlement behind :execute_ai_catalog_item, are waived as a class: a user may
      # run any flow definition locally, and one resembling a catalog item does not make
      # the run a use of the catalog.
      WAIVED_ITEM_CONSUMER_CONDITIONS = {
        foundational_flow_in_allowlist: 'per-container flow enablement governs unattended execution only',
        foundational_flows_available: 'the owner flows switch governs the unattended flows surface; ' \
          'a client-executed session answers to the Duo and CLI switches instead',
        pinned_version_available: 'version pinning describes what GitLab runs on the user behalf',
        pinned_version_draft: 'version pinning describes what GitLab runs on the user behalf'
      }.freeze

      # For endpoints whose callers never perform the run themselves.
      def self.for_background_caller(current_user:, container:, workflow_definition:, resolve_service_account: true)
        new(
          current_user: current_user,
          container: container,
          workflow_definition: workflow_definition,
          start_workflow: false,
          item_consumer_id: nil,
          caller_can_execute: false,
          resolve_service_account: resolve_service_account
        )
      end

      # `caller_can_execute` is a property of the endpoint, not of the request.
      # Required, so a new call site cannot silently land in the client-executed branch.
      def initialize(
        current_user:, container:, workflow_definition:,
        start_workflow:, item_consumer_id:, caller_can_execute:,
        resolve_service_account: true)
        @current_user = current_user
        @container = container
        @workflow_definition = workflow_definition
        @start_workflow = start_workflow
        @item_consumer_id = item_consumer_id
        @caller_can_execute = caller_can_execute
        @resolve_service_account = resolve_service_account
      end

      def execute
        return not_governed unless flow
        return allow_ungovernable_flow unless catalog_item

        log_classification if client_executable?

        client_executed? ? authorize_client_executed : authorize_background
      end

      private

      attr_reader :current_user, :container, :workflow_definition

      def flow
        ::Ai::Catalog::FoundationalFlow[workflow_definition]
      end
      strong_memoize_attr :flow

      def catalog_item
        flow&.catalog_item
      end
      strong_memoize_attr :catalog_item

      def client_executed?
        client_executable? && feature_flag_enabled?
      end

      def client_executable?
        return false unless @caller_can_execute
        return false if @start_workflow
        return false if @item_consumer_id.present?

        true
      end

      def authorize_background
        # A user namespace holds no flow enablement, so it fails closed.
        return forbidden unless container.is_a?(::Project) || container.is_a?(::Group)

        item_consumer = container.configured_ai_catalog_items.for_item(catalog_item).first

        return forbidden unless Ability.allowed?(current_user, :execute_ai_catalog_item, item_consumer)
        return allowed unless @resolve_service_account

        result = ::Ai::Catalog::ItemConsumers::ResolveServiceAccountService.new(
          container: container,
          item: catalog_item
        ).execute

        return forbidden(result.message) if result.error?

        allowed(service_account: result.payload.fetch(:service_account))
      end

      # There is no item consumer to evaluate ItemConsumerPolicy against; the entitlement
      # half applies to the container. See WAIVED_ITEM_CONSUMER_CONDITIONS.
      def authorize_client_executed
        return forbidden('GitLab Duo Agent Platform is not available for this namespace') unless
          agentic_chat_allowed?

        # Generic on purpose: naming the flow's feature flag or maturity would disclose
        # unreleased feature names to anyone who can guess a flow reference.
        return forbidden('This flow is not available') unless flow_available?

        allowed
      end

      # Also fails closed for a user namespace, which holds no such ability.
      def agentic_chat_allowed?
        Ability.allowed?(current_user, :access_duo_agentic_chat, container)
      end
      strong_memoize_attr :agentic_chat_allowed?

      def flow_available?
        flow.available_for?(root_ancestor)
      end
      strong_memoize_attr :flow_available?

      # An item can be absent transiently (seeding is a worker-run service, not a
      # constraint); refusing would turn that into a 403 for a user.
      def allow_ungovernable_flow
        ::Gitlab::AppLogger.warn(
          build_structured_payload_labkit(
            **log_context,
            message: 'Foundational flow has no catalog item, skipping flow execution authorization'
          )
        )

        not_governed
      end

      def feature_flag_enabled?
        Feature.enabled?(:duo_client_executed_flow_governance, root_ancestor)
      end
      strong_memoize_attr :feature_flag_enabled?

      def root_ancestor
        container.root_ancestor
      end
      strong_memoize_attr :root_ancestor

      def allowed(service_account: nil)
        ServiceResponse.success(payload: {
          service_account: service_account,
          execution: client_executed? ? Classification::CLIENT : Classification::BACKGROUND
        })
      end

      def not_governed
        ServiceResponse.success(payload: { service_account: nil, execution: nil })
      end

      def forbidden(message = nil)
        ServiceResponse.error(message: message, reason: :forbidden)
      end

      # Includes runs the flag would have reclassified, so the size of the change can be
      # measured before rollout. The client-executed checks are reported whichever way
      # the run classifies, so a run that would lose access can be counted while the flag
      # is still off. Remove with the flag:
      # https://gitlab.com/gitlab-org/gitlab/-/issues/608032
      def log_classification
        ::Gitlab::AppLogger.info(
          build_structured_payload_labkit(
            **log_context,
            message: 'Duo flow execution classified',
            execution: client_executed? ? :client : :background,
            client_executable: client_executable?,
            feature_flag_enabled: feature_flag_enabled?,
            agentic_chat_allowed: agentic_chat_allowed?,
            flow_available: flow_available?,
            gl_user_id: current_user&.id
          )
        )
      end

      def log_context
        {
          duo_workflow_definition: workflow_definition,
          container_type: container.class.name,
          container_id: container.id,
          root_namespace_id: root_ancestor.id
        }
      end
    end
  end
end
