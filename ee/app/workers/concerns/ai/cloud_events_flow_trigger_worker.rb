# frozen_string_literal: true

module Ai
  module CloudEventsFlowTriggerWorker
    extend ActiveSupport::Concern
    include Gitlab::EventStore::Subscriber

    included do
      data_consistency :sticky
      feature_category :code_suggestions
    end

    def handle_event(cloud_event)
      unless cloud_event.is_a?(self.class.cloud_event_class)
        logger.warn(structured_payload(message: 'Unexpected cloud event type.',
          expected: self.class.cloud_event_class.name,
          got: cloud_event.class.name))
        return
      end

      resource, container = find_resource_and_container(cloud_event)
      return unless resource

      return unless feature_enabled?(container)

      current_user = resolve_current_user(cloud_event, resource)

      unless current_user
        logger.info(structured_payload(message: 'User not found.',
          gitlab_user_id: cloud_event.data[:gitlab_user_id]))
        return
      end

      return unless passes_event_checks?(cloud_event, resource)

      execute_flow_triggers(resource, container, current_user)
    end

    private

    # Subclasses must implement. Returns [resource, container] or nil if not found.
    def find_resource_and_container(_cloud_event)
      raise NotImplementedError, "#{self.class} must implement #find_resource_and_container"
    end

    # Override in subclasses to gate on a feature flag.
    # Defaults to true so workers can remove the override after full rollout.
    def feature_enabled?(_container)
      true
    end

    # Override in subclasses to add event specific pre-checks.
    def passes_event_checks?(_cloud_event, _resource)
      true
    end

    # Override in subclasses for events that do not carry the acting user.
    def resolve_current_user(cloud_event, _resource)
      cloud_event.current_user
    end

    # Override in subclasses to pass event specific params to RunService#execute.
    def additional_run_params(_resource)
      {}
    end

    def execute_flow_triggers(resource, container, current_user)
      event_type = self.class.event_type
      action = self.class.respond_to?(:action) ? self.class.action : nil

      flow_triggers = container.ai_flow_triggers.triggered_on(event_type)

      # Some workers and their event_type
      # define an action (e.g. event_type: merge_request, action: 'approved')
      # while others might not
      filter_data = action ? { 'action' => action } : {}

      flow_triggers.each do |trigger|
        next unless ::Ai::FlowTriggers::FilterEvaluator.new(
          flow_trigger: trigger,
          hook_scope: event_type,
          data: filter_data
        ).allowed?

        run_params = { input: resource.iid.to_s, event: event_type }
        run_params[:action] = action if action
        run_params.merge!(additional_run_params(resource))

        ::Ai::FlowTriggers::RunService.new(
          project: container,
          current_user: current_user,
          flow_trigger: trigger,
          resource: resource
        ).execute(run_params)
      rescue StandardError => error
        Gitlab::ErrorTracking.track_exception(error,
          flow_trigger_id: trigger.id,
          resource_id: resource.id,
          container_id: container.id
        )
      end
    end
  end
end
