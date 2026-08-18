# frozen_string_literal: true

module DuoChatPanel
  class Container
    attr_reader :record, :type, :source

    def initialize(project:, group:, user:, controller_name: nil)
      @source = project || group
      duo_scope = ::Gitlab::Llm::DuoChat.duo_scope_hash(user, project, group, controller_name)
      @record = duo_scope[:project] || duo_scope[:namespace]
      @type = duo_scope[:project] ? 'project' : 'group'
    end

    def project?
      type == 'project'
    end

    def persisted?
      !!record&.persisted?
    end

    def to_global_id
      record&.to_global_id
    end

    def root_ancestor
      record&.root_ancestor
    end

    def duo_features_enabled
      record&.duo_features_enabled
    end

    def admin_permission
      project? ? :admin_project : :admin_group
    end

    def user_can_admin?(user)
      # To be replaced with a granular permission in https://gitlab.com/gitlab-org/gitlab/-/work_items/596538
      user.can?(admin_permission, record)
    end

    def project_id
      to_global_id.to_s if project? && persisted?
    end

    def namespace_id
      to_global_id.to_s if !project? && persisted?
    end
  end
end
