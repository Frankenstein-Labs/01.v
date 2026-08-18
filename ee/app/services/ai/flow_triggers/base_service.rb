# frozen_string_literal: true

module Ai
  module FlowTriggers
    class BaseService
      attr_reader :project, :current_user

      def execute(params)
        params = params.dup

        service_account = service_account(params[:user_id])
        ai_catalog_item_consumer = ai_catalog_item_consumer(params[:ai_catalog_item_consumer_id])

        params[:user_id] = nil if ai_catalog_item_consumer.present?

        unless user_is_authorized_to_service_account?(service_account)
          return ServiceResponse.error(message: 'You are not authorized to use this service account in this project')
        end

        unless service_account_compatible_with_item_consumer?(service_account, ai_catalog_item_consumer)
          return misaligned_service_account_error
        end

        trigger = yield(params)

        if trigger.valid?
          enforce_composite_identity!(service_account)

          ServiceResponse.success(payload: trigger)
        else
          ServiceResponse.error(message: trigger.errors.full_messages.to_sentence)
        end
      end

      private

      def service_account(service_account_id)
        return unless service_account_id.present?

        User.find_by_id(service_account_id)
      end

      def ai_catalog_item_consumer(ai_catalog_item_consumer_id)
        return unless ai_catalog_item_consumer_id.present?

        @ai_catalog_item_consumers ||= {}

        if @ai_catalog_item_consumers.key?(ai_catalog_item_consumer_id)
          return @ai_catalog_item_consumers[ai_catalog_item_consumer_id]
        end

        @ai_catalog_item_consumers[ai_catalog_item_consumer_id] =
          Ai::Catalog::ItemConsumer.find_by_id(ai_catalog_item_consumer_id)
      end

      def user_is_authorized_to_service_account?(service_account)
        allowed = Ability.allowed?(current_user, :manage_ai_flow_triggers, project)
        return allowed if service_account.nil? || allowed == false

        return false unless service_account.service_account?

        group = service_account.provisioned_by_group

        return false unless group
        return false unless group.root_ancestor.id == project.root_ancestor.id

        true
      end

      def enforce_composite_identity!(service_account)
        return if service_account.nil?

        service_account.update!(
          composite_identity_enforced: true
        )
      end

      # Triggers for "manual" External Agents can only be created by users who can create External Agents.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/583687.
      def new_external_agents_allowed?
        Feature.enabled?(:ai_catalog_create_third_party_flows, current_user)
      end

      def disallow_new_external_agent_error
        ServiceResponse.error(message: 'You have insufficient permissions')
      end

      def audit_flow_trigger(event_name, trigger)
        return unless trigger

        ::Gitlab::Audit::Auditor.audit({
          name: event_name,
          author: current_user,
          scope: trigger.project,
          target: trigger,
          target_details: "#{trigger.description} (ID: #{trigger.id})",
          message: event_name.humanize
        })
      end

      def misaligned_service_account_error
        ServiceResponse.error(
          message: s_('AICatalog|The service account does not belong to the configuration for the agent or flow ' \
            'associated with this project')
        )
      end

      def service_account_compatible_with_item_consumer?(service_account, ai_catalog_item_consumer)
        return true if service_account.nil? || ai_catalog_item_consumer.nil?

        ai_catalog_item_consumer.active_service_account == service_account
      end
    end
  end
end
