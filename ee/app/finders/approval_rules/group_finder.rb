# frozen_string_literal: true

# For caching group related queries relative to current_user
module ApprovalRules
  class GroupFinder
    include Gitlab::Utils::StrongMemoize

    attr_reader :rule, :current_user

    def initialize(rule, user)
      @rule = rule
      @current_user = user
    end

    def visible_groups
      strong_memoize(:visible_groups) do
        groups.accessible_to_user(current_user)
      end
    end

    def hidden_groups
      @hidden_groups ||= groups.id_not_in((visible_groups + project_groups).map(&:id).uniq)
    end

    def contains_hidden_groups?
      hidden_groups.loaded? ? hidden_groups.present? : hidden_groups.exists?
    end

    private

    def project_groups
      project = rule.rule_project

      return Group.none unless project

      return Group.none unless Feature.enabled?(:show_private_groups_as_approvers,
        project) && current_user&.can?(:read_project, project)

      project.invited_groups
    end

    def groups
      strong_memoize(:groups) do
        rule.any_approver? ? Group.none : rule.groups
      end
    end
  end
end
