# frozen_string_literal: true

module SecretsManagement
  class GroupUserJwt < GroupSecretsManagerJwt
    def payload
      claims = super
      claims[:sub] = "user:#{current_user.username}"
      claims[:secrets_manager_scope] = 'user'
      claims[:groups] = group_ids
      claims[:role_id] = role_id
      claims[:member_role_id] = member_role_id
      claims
    end

    private

    def group_ids
      # Get all groups the user is a member of that are relevant to this group hierarchy
      user_groups = current_user.authorized_groups
      group_hierarchy = group.self_and_ancestors

      user_groups.where(id: group_hierarchy.pluck(:id)).pluck(:id).map(&:to_s) # rubocop:disable CodeReuse/ActiveRecord -- We are using .where here because the models are ActiveRecord classes.
    end

    def role_id
      # Use the share-aware effective access so that membership granted via a
      # GroupGroupLink (group sharing) is resolved, not just direct/inherited
      # membership.
      # only_concrete_membership: true ensures instance/org admins
      # are NOT treated as an Owner
      group.max_member_access_for_user(current_user, only_concrete_membership: true).to_s
    end

    def member_role_id
      group_member = current_user.members.find_by(source: group) # rubocop:disable CodeReuse/ActiveRecord -- We are using .where here because the models are ActiveRecord classes.
      return group_member&.member_role&.id.to_s if group_member&.member_role_id.present?

      group.ancestors.each do |ancestor|
        group_member = current_user.members.find_by(source: ancestor) # rubocop:disable CodeReuse/ActiveRecord -- We are using .where here because the models are ActiveRecord classes.
        return group_member&.member_role&.id.to_s if group_member&.member_role_id.present?
      end

      nil
    end
  end
end
