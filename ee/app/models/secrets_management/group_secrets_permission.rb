# frozen_string_literal: true

module SecretsManagement
  class GroupSecretsPermission < BaseSecretsPermission
    RESOURCE_TYPE = 'Group'

    def resource_type
      RESOURCE_TYPE
    end

    private

    def principal_group_has_access_to_resource?(principal_group)
      # Same group
      return true if principal_group.id == resource.id

      # Principal is ancestor of target (parent can access child's secrets)
      return true if resource.ancestor_ids.include?(principal_group.id)

      # Principal is descendant of target (child can access parent's secrets)
      return true if principal_group.ancestor_ids.include?(resource.id)

      # Target group is shared with principal group
      return true if resource.shared_with_groups.where(id: principal_group.id).exists?

      false
    end

    def member_role_has_access_to_resource?(member_role)
      resource.self_and_ancestors.where(id: member_role.namespace_id).exists?
    end

    def find_group_link(principal_group)
      resource.shared_with_group_links.find_by(shared_with_group_id: principal_group.id)
    end
  end
end
