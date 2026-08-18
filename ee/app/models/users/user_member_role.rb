# frozen_string_literal: true

module Users
  class UserMemberRole < ApplicationRecord
    include Authz::UserRoleAssignable

    self.table_name = 'user_member_roles'

    belongs_to :member_role
    belongs_to :user

    validates :member_role, presence: true
    validates :user, presence: true, uniqueness: true

    scope :ldap_synced, -> { where(ldap: true) }

    scope :with_identity_provider, ->(provider) do
      joins(user: :identities).where(identities: { provider: provider })
    end

    scope :preload_user, -> { preload(:user) }
  end
end
