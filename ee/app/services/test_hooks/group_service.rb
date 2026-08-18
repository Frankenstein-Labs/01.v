# frozen_string_literal: true

module TestHooks
  class GroupService < TestHooks::BaseService
    def execute
      enforcer = ::Gitlab::IpRestriction::Enforcer.new(@hook.group)
      unless enforcer.allows_current_ip?
        return ServiceResponse.error(
          message: 'Group access restricted by IP address.',
          reason: :forbidden
        )
      end

      project = @hook.group.first_non_empty_project
      return error('Ensure the group has a project with commits.') unless project

      service = TestHooks::ProjectService.new(hook, current_user, @trigger || 'push_events')
      service.project = project
      service.execute
    end
  end
end
