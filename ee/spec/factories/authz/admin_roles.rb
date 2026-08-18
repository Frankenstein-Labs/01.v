# frozen_string_literal: true

FactoryBot.define do
  factory :admin_role, class: 'Authz::AdminRole' do
    name { FFaker::Lorem.unique.word }
    description { FFaker::Lorem.sentence }
    organization { association(:common_organization) }

    transient do
      without_any_permissions { false }
    end

    after(:build) do |admin_role, evaluator|
      next if evaluator.without_any_permissions || evaluator.permissions.any?

      admin_role.read_admin_users = true
    end

    Gitlab::CustomRoles::Definition.admin.each_value do |attributes|
      trait attributes[:name].to_sym do
        send(attributes[:name].to_sym) { true }
      end
    end
  end
end
