# frozen_string_literal: true

FactoryBot.define do
  factory :user_group_member_role, class: 'Authz::UserGroupMemberRole' do
    user { association(:user) }
    group { association(:group) }
    member_role { association(:member_role) }
  end
end
