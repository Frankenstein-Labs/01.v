# frozen_string_literal: true

module SecretsManagement
  class ProjectSecretsPermission < BaseSecretsPermission
    RESOURCE_TYPE = 'Project'

    def resource_type
      RESOURCE_TYPE
    end

    private

    def principal_group_has_access_to_resource?(principal_group)
      # Check if the project belongs directly to the group or its subgroups
      return false unless resource.group

      # Same group
      return true if resource.group.id == principal_group.id

      # Principal is ancestor of project's group (parent can access child's project secrets)
      return true if resource.group.ancestor_ids.include?(principal_group.id)

      # Principal is descendant of project's group (child can access parent's project secrets)
      return true if principal_group.ancestor_ids.include?(resource.group.id)

      # Project is explicitly shared with the principal group
      return true if resource.project_group_links.where(group_id: principal_group.id).exists?

      false
    end

    def member_role_has_access_to_resource?(member_role)
      resource.namespace.self_and_ancestors.where(id: member_role.namespace_id).exists?
    end

    def find_group_link(principal_group)
      resource.project_group_links.find_by(group_id: principal_group.id)
    end
  end
end
