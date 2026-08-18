# frozen_string_literal: true

FactoryBot.define do
  factory :user_admin_role, class: 'Authz::UserAdminRole' do
    admin_role
    user

    Authz::AdminRole.all_customizable_admin_permission_keys.each do |permission|
      # This relies on :admin_role factory traits dynamically defined for each
      # custom admin permission.
      trait permission do
        association :admin_role, permission
      end
    end
  end
end
