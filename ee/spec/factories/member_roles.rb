# frozen_string_literal: true

FactoryBot.define do
  factory :member_role do
    namespace { association(:group) }
    organization { nil }
    base_access_level { Gitlab::Access::DEVELOPER }
    name { generate(:title) }

    trait(:minimal_access) { base_access_level { Gitlab::Access::MINIMAL_ACCESS } }

    ::Gitlab::Access.sym_options_with_owner.each do |role, value|
      trait(role) { base_access_level { value } }
    end

    Gitlab::CustomRoles::Definition.standard.each_value do |attributes|
      trait attributes[:name].to_sym do
        send(attributes[:name].to_sym) { true }

        attributes.fetch(:requirements, []).each do |requirement|
          send(requirement.to_sym) { true }
        end
      end
    end

    Gitlab::CustomRoles::Definition.admin.each_value do |attributes|
      trait attributes[:name].to_sym do
        send(attributes[:name].to_sym) { true }

        namespace { nil }
        organization
        base_access_level { nil }
      end
    end

    # this trait can be used only for self-managed
    trait(:instance) do
      namespace { nil }
      organization
    end

    trait(:billable) do
      base_access_level { Gitlab::Access::GUEST }

      transient do
        billable_role do
          Gitlab::CustomRoles::Definition.standard.reject do |_k, v|
            v[:skip_seat_consumption]
          end.values.last
        end
      end

      after(:build) do |member_role, evaluator|
        next unless evaluator.billable_role

        member_role.send(:"#{evaluator.billable_role[:name]}=", true)
      end
    end

    trait(:non_billable) do
      base_access_level { Gitlab::Access::GUEST }

      transient do
        non_billable_role do
          Gitlab::CustomRoles::Definition.standard.select { |_k, v| v[:skip_seat_consumption] }.values.last
        end
      end

      after(:build) do |member_role, evaluator|
        next unless evaluator.non_billable_role

        member_role.send(:"#{evaluator.non_billable_role[:name]}=", true)
      end
    end

    transient do
      without_any_permissions { false }
    end

    after(:build) do |member_role, evaluator|
      next if evaluator.without_any_permissions
      next if evaluator.permissions.present? && evaluator.permissions.values.any?

      member_role.read_code = true
    end

    trait(:admin) do
      base_access_level { nil }
      namespace_id { nil }
      organization
      read_code { false }
      read_admin_users { true }
    end

    after(:create) do |member_role, _context|
      member_role.members.each do |member|
        next unless member.is_a?(::GroupMember)

        ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(member).execute
      end
    end
  end
end
