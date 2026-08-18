# frozen_string_literal: true

module Authz
  class BaseRole < ApplicationRecord
    include Authz::AdminRollable

    validate :validate_permissions

    self.abstract_class = true

    def enabled_permissions
      self.class.all_customizable_permissions.filter do |permission, _|
        attributes[permission.to_s]
      end
    end

    private

    def validate_permissions
      self.permissions = permissions.select { |_, enabled| enabled }

      if permissions.empty?
        errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
        return
      end

      allowed_permissions = available_permissions
      permissions.each_key do |permission|
        next if allowed_permissions.include?(permission.to_sym)

        message = format(s_('MemberRole|Unknown permission: %{permission}'), permission: permission)
        errors.add(:base, message)
      end
    end

    def available_permissions
      if admin_related_role?
        self.class.all_customizable_admin_permissions
      else
        self.class.all_customizable_standard_permissions
      end
    end
  end
end
