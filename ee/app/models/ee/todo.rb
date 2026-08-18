# frozen_string_literal: true

module EE
  module Todo
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    EE_ACTION_NAMES = {
      ::Todo::MERGE_TRAIN_REMOVED => :merge_train_removed,
      ::Todo::OKR_CHECKIN_REQUESTED => :okr_checkin_requested,
      ::Todo::ADDED_APPROVER => :added_approver,
      ::Todo::DUO_PRO_ACCESS_GRANTED => :duo_pro_access_granted,
      ::Todo::DUO_ENTERPRISE_ACCESS_GRANTED => :duo_enterprise_access_granted,
      ::Todo::DUO_CORE_ACCESS_GRANTED => :duo_core_access_granted,
      ::Todo::DUO_WORKFLOW_INPUT_REQUIRED => :duo_workflow_input_required
    }.freeze
    private_constant :EE_ACTION_NAMES

    EE_PARENTLESS_ACTION_TYPES = [
      ::Todo::DUO_PRO_ACCESS_GRANTED,
      ::Todo::DUO_ENTERPRISE_ACCESS_GRANTED,
      ::Todo::DUO_CORE_ACCESS_GRANTED
    ].freeze
    private_constant :EE_PARENTLESS_ACTION_TYPES

    prepended do
      include UsageStatistics
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :action_names
      def action_names
        super.merge(EE_ACTION_NAMES).freeze
      end

      override :parentless_action_types
      def parentless_action_types
        (super + EE_PARENTLESS_ACTION_TYPES).freeze
      end
    end

    override :body
    def body
      return ::GitlabSubscriptions::Duo.todo_message if for_duo_access_granted?
      return target.workflow_definition if for_duo_workflow_input_required?

      super
    end

    override :target_url
    def target_url
      return if target.nil?
      return build_duo_getting_started_url if for_duo_access_granted?
      return target.web_url if for_duo_workflow_input_required?

      case target
      when Vulnerability, Epic, ComplianceManagement::Projects::ComplianceViolation
        ::Gitlab::UrlBuilder.build(
          target,
          anchor: note.present? ? ActionView::RecordIdentifier.dom_id(note) : nil
        )
      else
        super
      end
    end

    private

    def build_duo_getting_started_url
      ::Gitlab::Routing.url_helpers.help_page_path('user/get_started/getting_started_gitlab_duo.md')
    end

    def for_duo_workflow_input_required?
      action == self.class::DUO_WORKFLOW_INPUT_REQUIRED
    end

    def for_duo_access_granted?
      [
        self.class::DUO_PRO_ACCESS_GRANTED,
        self.class::DUO_ENTERPRISE_ACCESS_GRANTED,
        self.class::DUO_CORE_ACCESS_GRANTED
      ].include?(action)
    end
  end
end
