# frozen_string_literal: true

module Ai
  module Catalog
    module Onboarding
      class RunService < Ai::Catalog::BaseService
        LEASE_TTL = 2.minutes

        def initialize(project:, current_user:, params: {})
          super
          @initializer = Initializer.find(params[:event_type])
        end

        def execute
          return error_no_permissions unless allowed?
          return error('Unknown initializer.') unless initializer
          return error('Initializer is not applicable.') unless initializer.applicable_for?(project)
          return error('An initializer run is already in progress.') if active_workflow?

          start_workflow
        end

        private

        attr_reader :initializer

        def allowed?
          Feature.enabled?(:duo_agent_onboarding, current_user, type: :beta) &&
            Ability.allowed?(current_user, :duo_workflow, project)
        end

        def active_workflow?
          tracker.active_workflow(initializer.event_type).present?
        end

        def start_workflow
          lease_uuid = Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TTL.to_i).try_obtain
          return error('An initializer run is already in progress.') unless lease_uuid

          begin
            result = ExecuteDeveloperGoalService.new(
              project: project,
              current_user: current_user,
              params: { event_type: initializer.event_type.to_sym }
            ).execute

            return error(Array(result.message).first) unless result.success?

            workflow = result.payload[:workflow]
            tracker.track(initializer.event_type, workflow) if workflow

            ServiceResponse.success(payload: { workflow_id: workflow&.id })
          ensure
            Gitlab::ExclusiveLease.cancel(lease_key, lease_uuid)
          end
        end

        def tracker
          @tracker ||= WorkflowTracker.new(project)
        end

        def lease_key
          "duo_agent_onboarding:#{initializer.event_type}:#{project.id}"
        end
      end
    end
  end
end
