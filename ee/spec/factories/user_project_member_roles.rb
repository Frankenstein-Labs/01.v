# frozen_string_literal: true

FactoryBot.define do
  factory :user_project_member_role, class: 'Authz::UserProjectMemberRole' do
    user { association(:user) }
    project { association(:project) }
    member_role { association(:member_role) }
  end
end
