# frozen_string_literal: true

class GroupsWithTemplatesFinder
  def initialize(user, group_id = nil)
    @user = user
    @group_id = group_id
  end

  def execute
    if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      groups = extended_group_search
      simple_group_search(groups)
    else
      simple_group_search(Group.all)
    end
  end

  private

  attr_reader :user, :group_id

  def extended_group_search
    plan_ids = Plan
      .by_name(GitlabSubscriptions::Features.saas_plans_with_feature(:group_project_templates))
      .pluck(:id) # rubocop: disable CodeReuse/ActiveRecord

    Group.by_root_id(GitlabSubscription.by_hosted_plan_ids(plan_ids).select(:namespace_id))
  end

  def simple_group_search(groups)
    groups = group_id ? groups.find_by(id: group_id)&.self_and_ancestors : groups # rubocop: disable CodeReuse/ActiveRecord -- Required for group lookup

    return Group.none unless groups

    groups.with_project_templates
  end
end
