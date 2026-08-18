# frozen_string_literal: true

module Ai
  module Catalog
    module ItemConsumers
      class CreateService < ::BaseContainerService
        include EventsTracking

        MAX_SERVICE_NAME_LENGTH = 90
        SERVICE_ACCOUNT_ACCESS_LEVEL = ::Gitlab::Access::DEVELOPER

        def execute
          # When creating a project-level item consumer, a parent group-level item consumer is required.
          # If one is not explicitly provided, we attempt to auto-resolve it by looking for an existing
          # group item consumer or creating one by recursively calling this service with the project's
          # top-level group as the container.
          #
          # Since the user may not have permissions on the top-level group directly, we pass
          # `authorization_container` set to the project, so authorization is checked against
          # the project rather than the group.
          if should_auto_resolve_parent_item_consumer?
            resolve_result = auto_resolve_parent_item_consumer
            return resolve_result if resolve_result.error?

            params[:parent_item_consumer] = resolve_result.payload[:item_consumer]
          end

          return validation_error if validation_error

          add_service_account_result = create_service_account_result = create_item_consumer_result = nil
          project_member = item_consumer = service_account_response = nil

          ApplicationRecord.transaction do
            create_service_account_result, service_account_response = create_service_account
            raise ActiveRecord::Rollback if create_service_account_result == :failure

            create_item_consumer_result, item_consumer = create_item_consumer(service_account_response)
            raise ActiveRecord::Rollback if create_item_consumer_result == :failure

            add_service_account_result, project_member = add_service_account_to_project
            raise ActiveRecord::Rollback if add_service_account_result == :failure
          end

          return error(service_account_response) if create_service_account_result == :failure
          return error_creating(project_member) if add_service_account_result == :failure
          return error_creating(item_consumer) if create_item_consumer_result == :failure

          track_item_consumer_event(item_consumer, 'create_ai_catalog_item_consumer', item_consumer.flow_trigger)
          send_audit_events(item_consumer, audit_event_name)

          if create_service_account_result == :success
            ServiceAccountProvisionedAuditor.new(
              current_user: current_user,
              service_account: service_account_response,
              item: item,
              item_consumer: item_consumer
            ).audit
          end

          ServiceResponse.success(payload: { item_consumer: item_consumer })
        end

        private

        strong_memoize_attr def validation_error
          return error_not_project_or_top_level_group unless for_project_or_top_level_group?
          return error_no_permissions unless allowed?
          return error_foundational_flow_not_in_allowlist if foundational_flow_not_in_allowlist?
          return error_parent_item_consumer_not_passed if project_item_without_parent_item_consumer?
          return error_version_not_released if requested_version_invalid?
          return error_no_pinned_version_prefix if pinned_version_prefix.nil? && !nil_version_pin_enforced?
          return error_foundational_flow_triggers_not_allowed if foundational_flow_with_user_triggers?

          error_flow_triggers_must_be_for_project if flow_triggers_not_for_project?
        end

        def audit_event_name
          "enable_ai_catalog_#{item.item_type}"
        end

        def parent_item_consumer_service_account
          parent_item_consumer&.service_account
        end

        def parent_item_consumer
          params[:parent_item_consumer]
        end

        def requires_parent_item_consumer?
          return false if project.nil?

          return true if item.third_party_flow? || item.flow?

          item.agent?
        end

        def nil_version_pin_enforced?
          container.is_a?(Project) && item.project_id.present? && container.id == item.project_id
        end
        strong_memoize_attr :nil_version_pin_enforced?

        def project_item_without_parent_item_consumer?
          requires_parent_item_consumer? && parent_item_consumer.nil?
        end

        def flow_triggers_not_for_project?
          (params[:trigger_types] || params[:trigger_filter]) && project.nil?
        end

        def foundational_flow_not_in_allowlist?
          return false unless item.foundational_flow?

          container.enabled_flow_catalog_item_ids.exclude?(item.id)
        end

        def foundational_flow_with_user_triggers?
          item.foundational_flow? && params[:trigger_types].present?
        end

        def create_item_consumer(service_account)
          return [:success, @healed_consumer] if @healed_consumer

          # The enabled setting is not currently used, so always set new records as enabled.
          # https://gitlab.com/gitlab-org/gitlab/-/issues/553912#note_2706802395
          params.merge!(
            project: project,
            group: group,
            service_account: service_account,
            enabled: true,
            pinned_version_prefix: pinned_version_prefix
          )
          prepare_trigger_params

          item_consumer_params = params.except(:authorization_container, :pinned_version)
          item_consumer = ::Ai::Catalog::ItemConsumer.create(item_consumer_params)
          return [:success, item_consumer] if item_consumer.persisted?

          [:failure, item_consumer]
        end

        def create_service_account
          # In case we don't need to create the service account (because this is not group level), we should return
          # no_op, and continue creating the item consumer.
          return [:no_op, nil] if group.nil? || item.agent?

          orphan_consumer = find_orphan_group_consumer
          if orphan_consumer
            response = provision_service_account
            if response.error?
              log_error(
                "Failed to create service account with name '#{service_account_username}': #{response.message}"
              )
              return [:failure, response.message]
            end

            new_service_account = response.payload[:user]
            unless orphan_consumer.update(service_account: new_service_account)
              return [:failure, orphan_consumer.errors.full_messages]
            end

            @healed_consumer = orphan_consumer
            return [:success, new_service_account]
          end

          existing_service_account = group.service_accounts.find_by_username(service_account_username)

          if existing_service_account.present? &&
              Ai::Catalog::ItemConsumer.for_service_account(existing_service_account).none?
            return [:no_op, existing_service_account]
          end

          response = provision_service_account

          if response.error?
            log_error("Failed to create service account with name '#{service_account_username}': #{response.message}")
            return [:failure, response.message]
          end

          [:success, response.payload[:user]]
        end

        def find_orphan_group_consumer
          return unless item.flow? || item.third_party_flow?

          # Self-heal lookup: scoped to (group_id, ai_catalog_item_id) which is
          # unique per the validate_item_uniqueness validator, so this matches
          # at most one row. Both columns are indexed (index_ai_catalog_item_consumers_on_group_id
          # and index_ai_catalog_item_consumers_on_ai_catalog_item_id), so the planner
          # can resolve the predicate from a tiny seek without scanning service_account_id.
          # rubocop:disable CodeReuse/ActiveRecord -- narrow self-heal query scoped to group + item
          group.configured_ai_catalog_items
            .for_item(item.id)
            .where(service_account_id: nil)
            .first
          # rubocop:enable CodeReuse/ActiveRecord
        end

        def provision_service_account
          ::Namespaces::ServiceAccounts::GroupCreateService.new(
            current_user,
            service_account_params,
            uniquify_provided_username: true
          ).execute
        end

        def service_account_params
          {
            namespace_id: group.id,
            name: service_account_name,
            username: service_account_username,
            avatar: service_account_avatar,
            organization_id: group.organization_id,
            composite_identity_enforced: true,
            skip_ai_prefix_validation: true,
            skip_owner_check: true
          }
        end
        strong_memoize_attr :service_account_params

        def add_service_account_to_project
          return [:no_op, nil] unless project_container? && (item.flow? || item.third_party_flow?)

          return [:no_op, nil] if project.team.member?(
            parent_item_consumer_service_account, SERVICE_ACCOUNT_ACCESS_LEVEL
          )

          project_member = project.team.add_member(
            parent_item_consumer_service_account, SERVICE_ACCOUNT_ACCESS_LEVEL,
            current_user: current_user, skip_authorization: true
          )

          return [:failure, project_member.presence] unless project_member.present? && project_member.persisted?

          [:success, project_member]
        end

        def prepare_trigger_params
          return if project.nil?

          trigger_filter = params.delete(:trigger_filter)

          if item.foundational_flow?
            flow_definition = ::Ai::Catalog::FoundationalFlow[item.foundational_flow_reference]
            return unless flow_definition&.triggers&.any?

            trigger_types = flow_definition.triggers
          else
            return if params[:trigger_types].nil?

            trigger_types = params.delete(:trigger_types).map { |type| ::Ai::FlowTrigger::EVENT_TYPES[type.to_sym] }
          end

          params[:flow_trigger_attributes] = {
            project: project,
            description: "Auto-created triggers for #{item.name}",
            event_types: trigger_types,
            filter: trigger_filter || {}
          }
        end

        def service_account_name
          name = item.name
          name = "Duo #{name}" if item.foundational_flow_reference.present?

          name[0, MAX_SERVICE_NAME_LENGTH]
        end

        def service_account_username
          prefix = item.foundational_flow_reference.present? ? "duo" : "ai"
          "#{prefix}-#{item.name}-#{group.name}".parameterize
        end

        def service_account_avatar
          Ai::Avatars::LoadService.new(item).execute
        end

        def for_project_or_top_level_group?
          project || group&.root?
        end

        def item
          params[:item]
        end

        def pinned_version_prefix
          return if nil_version_pin_enforced?

          return resolved_requested_version.version if resolved_requested_version&.released?

          latest_released_version = item.latest_released_version

          return latest_released_version.version if latest_released_version

          # TODO: Remove the below when we can rely on all items having a `latest_released_version`
          # after the data migration of https://gitlab.com/gitlab-org/gitlab/-/issues/572145
          latest_released_version = item.versions.where.not(release_date: nil).order(id: :desc).take # rubocop:disable CodeReuse/ActiveRecord -- Can be removed after https://gitlab.com/gitlab-org/gitlab/-/issues/572145
          latest_released_version&.version
        end
        strong_memoize_attr :pinned_version_prefix

        def resolved_requested_version
          return unless params[:pinned_version]

          item.resolve_version(params[:pinned_version])
        end
        strong_memoize_attr :resolved_requested_version

        def requested_version_invalid?
          params[:pinned_version].present? && !resolved_requested_version&.released?
        end

        def error_creating(record)
          return error('Failed to enable agent or flow') if record.nil?

          messages = record.errors.full_messages.presence || ['Failed to enable agent or flow']

          if already_configured_error?(record)
            return ServiceResponse.error(message: messages, reason: :already_configured)
          end

          error(messages)
        end

        def already_configured_error?(record)
          record.errors.of_kind?(:base, _('Agent or flow already enabled')) ||
            record.errors.of_kind?(
              :base, s_('AICatalog|An agent or flow can only be enabled once per group or project')
            )
        end

        def should_auto_resolve_parent_item_consumer?
          project_container? &&
            params[:parent_item_consumer].nil? &&
            requires_parent_item_consumer?
        end

        def auto_resolve_parent_item_consumer
          top_level_group = project.root_ancestor
          return error('Project must belong to a group') unless top_level_group.is_a?(Group)

          existing = top_level_group.configured_ai_catalog_items.for_item(item).first
          return ServiceResponse.success(payload: { item_consumer: existing }) if existing && !orphan?(existing)

          self.class.new(
            container: top_level_group,
            current_user: current_user,
            params: { item: item, authorization_container: project }
          ).execute
        end

        def orphan?(consumer)
          (item.flow? || item.third_party_flow?) && consumer.service_account_id.nil?
        end

        def allowed?
          auth_container = params[:authorization_container] || container

          if item.custom_agent? && !Ability.allowed?(current_user, :create_ai_catalog_agent_item_consumer,
            auth_container)
            return false
          end

          if item.flow?
            if item.foundational_flow?
              return false unless Ability.allowed?(current_user, :create_ai_foundational_flow_item_consumer,
                auth_container)
            else
              return false unless Ability.allowed?(current_user, :create_ai_catalog_flow_item_consumer, auth_container)
            end
          end

          if item.third_party_flow? &&
              !Ability.allowed?(current_user, :create_ai_catalog_third_party_flow_item_consumer, auth_container)
            return false
          end

          Ability.allowed?(current_user, :create_ai_catalog_item_consumer, auth_container) &&
            Ability.allowed?(current_user, :read_ai_catalog_item, item)
        end

        def error(message)
          ServiceResponse.error(message: Array(message))
        end

        def error_no_permissions
          error("You don't have permission to enable this agent or flow, or it doesn't exist")
        end

        def error_flow_triggers_must_be_for_project
          error("Triggers can only be set for projects")
        end

        def error_foundational_flow_not_in_allowlist
          error("Foundational flow is not allowed by the top-level group settings")
        end

        def error_foundational_flow_triggers_not_allowed
          error("You can't create triggers for foundational flows")
        end

        def error_parent_item_consumer_not_passed
          error("Enable this agent or flow in the top-level group first")
        end

        def error_not_project_or_top_level_group
          error('This agent or flow can only be enabled in projects or top-level groups')
        end

        def error_no_pinned_version_prefix
          if requires_parent_item_consumer?
            error('This agent or flow must be pinned to a version in the top-level group')
          else
            error('Agent or flow has no latest released version to pin to')
          end
        end

        def error_version_not_released
          error('Pinned version must resolve to a released version of the agent or flow')
        end
      end
    end
  end
end
