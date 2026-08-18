# frozen_string_literal: true

FactoryBot.define do
  factory :user_member_role, aliases: [:admin_member_role], class: 'Users::UserMemberRole' do
    member_role
    user
    ldap { false }

    # Create Admin Member Roles by using the desired permission to enable as a
    # trait. For example:
    #
    # create(:admin_member_role, :read_admin_cicd, user: a_user)
    #
    # By providing a user to the factory we can create the MemberRole record and
    # Users::UserMemberRole with one method call.
    MemberRole.all_customizable_admin_permission_keys.each do |permission|
      # This relies on :member_role factory traits dynamically defined for each
      # custom admin permission.
      trait permission do
        association :member_role, permission
      end
    end
  end
end
