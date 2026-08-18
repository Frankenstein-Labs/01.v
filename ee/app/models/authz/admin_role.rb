# frozen_string_literal: true

module Authz
  class AdminRole < Authz::BaseRole
    belongs_to :organization, class_name: 'Organizations::Organization'
    has_many :user_admin_roles, class_name: 'Authz::UserAdminRole'
    has_many :users, through: :user_admin_roles

    validates :name, presence: true, uniqueness: { scope: :organization_id }
    validates :permissions, json_schema: { filename: 'admin_role_permissions' }

    alias_method :user_member_roles, :user_admin_roles

    jsonb_accessor :permissions,
      Gitlab::CustomRoles::Definition.admin.keys.index_with(::Gitlab::Database::Type::JsonbBoolean.new)

    class << self
      alias_method :all_customizable_permissions, :all_customizable_admin_permissions
    end

    def admin_related_role?
      true
    end
  end
end
