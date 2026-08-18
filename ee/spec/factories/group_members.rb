# frozen_string_literal: true

FactoryBot.modify do
  factory :group_member do
    trait :banned do
      after(:create) do |member|
        create(:namespace_ban, namespace: member.member_namespace.root_ancestor, user: member.user) unless member.owner?
      end
    end

    transient do
      create_user_group_member_roles { true }
    end

    after(:create) do |member, context|
      if context.create_user_group_member_roles && member.member_role
        ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(member).execute
      end
    end
  end
end
