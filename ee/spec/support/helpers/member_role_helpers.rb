# frozen_string_literal: true

module MemberRoleHelpers
  def create_member_role(namespace, ability)
    requirements_h = requirements(ability).to_h { |name| [name.to_sym, true] } || {}

    params = { :namespace => namespace, ability => true }.merge(requirements_h)

    create(:member_role, :guest, params)
  end

  def requirements(ability)
    MemberRole.all_customizable_permissions[ability][:requirements] || []
  end

  def assign_member_role(group_member, member_role)
    group_member.update!(member_role: member_role)

    ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(group_member).execute
  end

  # read_code is a requirement of manage_merge_request_setting when creating a member role,
  # but, it is not returned when fetching group-level abilities
  # because read_code is not a group-level ability
  def expected_group_abilities(ability)
    [ability] + (requirements(ability).map(&:to_sym) & MemberRole.all_customizable_group_permissions)
  end

  def expected_project_abilities(ability)
    [ability] + (requirements(ability).map(&:to_sym) & MemberRole.all_customizable_project_permissions)
  end

  def random_ability(ability, method_name = :all_customizable_permissions)
    MemberRole.send(method_name).without(ability).sample
  end
end
