# frozen_string_literal: true

module EE
  module IssuableBaseService
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    private

    attr_reader :amazon_q_params

    override :associations_before_update
    def associations_before_update(issuable)
      associations = super

      associations[:escalation_policy] = issuable.escalation_status&.policy if issuable.escalation_policies_available?
      associations[:approval_rules] = issuable.approval_rules.map(&:hook_attrs) if issuable.supports_approval_rules?
      associations[:status] = issuable.status_with_fallback if issuable.supports_status?

      associations
    end

    override :filter_params
    def filter_params(issuable)
      can_admin_issuable = can_admin_issuable?(issuable)

      unless can_admin_issuable && issuable.weight_available?
        params.delete(:weight)
      end

      unless can_admin_issuable && issuable.supports_health_status?
        params.delete(:health_status)
      end

      [:iteration, :sprint_id].each { |iteration_param| params.delete(iteration_param) } unless can_admin_issuable

      @amazon_q_params = params.delete(:amazon_q) # rubocop:disable Gitlab/ModuleWithInstanceVariables -- This is an instance method

      super
    end

    def update_task_event?
      strong_memoize(:update_task_event) do
        params.key?(:update_task)
      end
    end

    override :allowed_create_params
    def allowed_create_params(params)
      super(params).except(:epic)
    end

    override :allowed_update_params
    def allowed_update_params(params)
      super(params).except(:epic, :last_test_report_state)
    end

    override :execute_triggers
    def execute_triggers(_issuable, _old_associations = {})
      execute_amazon_q_trigger if amazon_q_params
    end

    def execute_flow_triggers(issuable, users, event_type)
      return unless users.present? && current_user&.can?(:trigger_ai_flow, project)

      flow_triggers = project.ai_flow_triggers.triggered_on(event_type).by_service_accounts(users)
      return unless flow_triggers.exists?

      flow_triggers.find_each do |flow_trigger|
        ::Ai::FlowTriggers::RunService.new(
          project: project,
          current_user: current_user,
          resource: issuable,
          flow_trigger: flow_trigger
        ).execute({ input: issuable.iid.to_s, event: event_type, triggered_by_username: current_user.username })
      end
    end

    def execute_amazon_q_trigger
      ::Ai::AmazonQ::AmazonQTriggerService.new(
        user: current_user,
        command: amazon_q_params[:command],
        source: amazon_q_params[:source]
      ).execute
    end
  end
end
