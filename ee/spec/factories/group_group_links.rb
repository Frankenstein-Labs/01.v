# frozen_string_literal: true

FactoryBot.modify do
  factory :group_group_link do
    transient do
      create_user_group_member_roles { true }
    end

    after(:create) do |link, context|
      if context.create_user_group_member_roles
        ::Authz::UserGroupMemberRoles::UpdateForSharedGroupService.new(link).execute
      end
    end
  end
end
