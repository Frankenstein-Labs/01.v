# frozen_string_literal: true

module Users
  module MemberRoles
    class AssignService < BaseService
      attr_accessor :current_user, :user_to_be_assigned, :admin_role

      def initialize(current_user, params = {})
        @current_user = current_user

        @user_to_be_assigned = params[:user]
        @admin_role = params[:member_role]
      end

      def execute
        return error('custom_roles licensed feature must be available') unless License.feature_available?(:custom_roles)

        return error('Forbidden') unless current_user.can?(:admin_member_role)

        return error('Only admin custom roles can be assigned directly to a user.') unless admin_related_role?

        assign_or_unassign_admin_role
      end

      private

      def admin_related_role?
        return true if admin_role.blank?

        admin_role.admin_related_role?
      end

      def assign_or_unassign_admin_role
        # Admins already have all abilities custom admin roles grants
        return destroy_record if user_to_be_assigned.admin? # rubocop:disable Cop/UserAdmin -- Not current_user so no need to check if admin mode is enabled

        # if admin role is present -> create or update database record
        # if admin role is nil -> that means we are unassigning admin role from user,
        # hence destroy any existing records
        admin_role ? create_or_update_record : destroy_record
      end

      def create_or_update_record
        record = Authz::UserAdminRole.klass(current_user).create_or_update(user: user_to_be_assigned,
          member_role: admin_role)

        if record.valid?
          log_audit_event(
            action: 'custom_admin_role_assigned_to_user',
            admin_role: admin_role
          )
          success(record)
        else
          error(record.errors.full_messages.join(', '))
        end
      end

      def destroy_record
        record = Authz::UserAdminRole.klass(current_user).find_by_user_id(user_to_be_assigned.id)

        return success(nil) unless record

        if record.destroy
          log_audit_event(
            action: 'custom_admin_role_unassigned_from_user',
            admin_role: record.member_role
          )
          success(nil)
        else
          error(record.errors.full_messages.join(', '))
        end
      end

      def log_audit_event(action:, admin_role:)
        audit_context = {
          name: action,
          author: current_user,
          scope: user_to_be_assigned,
          target: admin_role,
          message: action.humanize
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def success(record)
        ::ServiceResponse.success(payload: { user_member_role: record })
      end

      def error(message)
        ::ServiceResponse.error(message: message)
      end
    end
  end
end
