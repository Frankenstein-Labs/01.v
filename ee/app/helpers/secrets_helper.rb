# frozen_string_literal: true

module SecretsHelper
  def project_secrets_app_data(project)
    root_namespace = project.root_ancestor

    {
      base_path: project_secrets_path(project),
      enrollment_settings_path: enrollment_settings_path(root_namespace),
      manage_permissions_path: edit_project_path(project, anchor: 'js-shared-permissions'),
      project_path: project.full_path,
      top_level_group_full_path: root_namespace.is_a?(Group) ? root_namespace.full_path : ''
    }
  end

  def group_secrets_app_data(group)
    {
      base_path: group_secrets_path(group),
      enrollment_settings_path: enrollment_settings_path(group.root_ancestor),
      group_path: group.full_path,
      manage_permissions_path: edit_group_path(group, anchor: 'js-permissions-settings'),
      top_level_group_full_path: group.root_ancestor.full_path
    }
  end

  def namespace_enrollment_data(namespace, user)
    {
      can_manage_secrets_manager: can?(user, :admin_group, namespace).to_s, # rubocop:disable Gitlab/Authz/PermissionCheck -- will iterate on this. provision_secrets_manager is a good fit but it needs to be fetched/updated dynamically on enrollment
      can_enroll_namespace: can?(user, :create_secrets_manager_enrollment, namespace).to_s,
      full_path: namespace.full_path,
      group_path_regex: JsRegex.new(Gitlab::PathRegex::FULL_NAMESPACE_FORMAT_REGEX).source,
      is_namespace_enrollable: (namespace.root? && Gitlab.com?).to_s, # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- testing SaaS behavior directly (feature is also available for self-managed, but enrollment behavior is different)
      top_level_group_full_path: namespace.root_ancestor.full_path
    }
  end

  def instance_secrets_manager_enrollment_data
    {
      # On self-managed, entitlement is instance-wide so any root group works as the
      # GraphQL entry point for the secretsManagerEntitlement query.
      # See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/240453#note_3472085787
      top_level_group_full_path: Group.where(parent_id: nil).pick(:path) || '' # rubocop:disable CodeReuse/ActiveRecord -- simple query for any root group path; no suitable scope exists
    }
  end

  private

  def enrollment_settings_path(root_group)
    if allow_secrets_manager_instance_enrollment?
      general_admin_application_settings_path(anchor: 'js-secrets-manager-instance-enrollment-settings')
    else
      edit_group_path(root_group, anchor: 'js-permissions-settings')
    end
  end
end
