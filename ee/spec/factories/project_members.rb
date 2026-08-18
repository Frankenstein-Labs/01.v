# frozen_string_literal: true

FactoryBot.modify do
  factory :project_member do
    trait :banned do
      after(:create) do |member|
        create(:namespace_ban, namespace: member.member_namespace.root_ancestor, user: member.user) unless member.owner?
      end
    end
  end
end
