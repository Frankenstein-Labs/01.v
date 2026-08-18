# frozen_string_literal: true

module SecretsManagement
  module BillableEvents
    class SecretsStoredEmitter
      EVENT_TYPE = 'secrets_stored'
      UNIT_OF_MEASURE = 'secret'

      def self.emit_for_root_namespace_id!(root_namespace_id)
        root_namespace = ::Namespace.find_by_id(root_namespace_id)
        return unless root_namespace

        new(root_namespace).emit!
      end

      def initialize(root_namespace)
        @root_namespace = root_namespace
      end

      def emit!
        return unless feature_enabled?
        return if quantity == 0

        ::Gitlab::BillingEvents::Client.track_billing_event(
          event_type: EVENT_TYPE,
          category: self.class.name,
          unit_of_measure: UNIT_OF_MEASURE,
          quantity: quantity,
          namespace: root_namespace,
          idempotency_key: idempotency_key,
          metadata: metadata
        )
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e, root_namespace_id: root_namespace&.id)
        nil
      end

      private

      attr_reader :root_namespace

      def feature_enabled?
        ::Feature.enabled?(
          :secrets_manager_emit_secret_stored_events,
          root_namespace,
          type: :gitlab_com_derisk
        )
      end

      # One emission per root namespace per day. The billing client derives
      # `event_id = uuid_v5(instance_uuid, idempotency_key)`, so a re-enqueue
      # of the same root within the same day collapses to one billing event
      # downstream.
      def idempotency_key
        "#{EVENT_TYPE}:#{root_namespace.id}:#{Date.current.iso8601}"
      end

      def quantity
        return @quantity if defined?(@quantity)

        @quantity = NamespaceSecretCount.for_root_namespace(root_namespace.id).sum(:count)
      end

      def namespace_count
        NamespaceSecretCount.for_root_namespace(root_namespace.id).count
      end

      def metadata
        {
          namespace_count: namespace_count,
          entitlement_state: entitlement&.state&.to_s,
          blocked_reason: entitlement&.blocked_reason&.to_s
        }.compact
      end

      # Memoized: Sidekiq has no SafeRequestStore, so this keeps it to one CDot resolution per run.
      # Fail-open: on resolution failure the entitlement keys are omitted, not stamped `ineligible`.
      def entitlement
        return @entitlement if defined?(@entitlement)

        @entitlement = Entitlement.for!(Entitlement.root_namespace_for(root_namespace))
      rescue StandardError => e
        ::Gitlab::ErrorTracking.log_exception(e, root_namespace_id: root_namespace&.id)
        @entitlement = nil
      end
    end
  end
end
