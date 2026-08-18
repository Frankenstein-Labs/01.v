# frozen_string_literal: true

module EE
  module RolesAndPermissions
    extend ActiveSupport::Concern
    include ::Gitlab::Utils::StrongMemoize

    included do
      before_action :ensure_role_exists!, only: [:show, :edit]
    end

    private

    def ensure_role_exists!
      render_404 unless member_role
    end

    def member_role
      id = params.permit(:id)[:id]

      if /\A\d+\z/.match?(id)
        ::Members::AllRolesFinder.new(current_user, id: id).execute.first
      else
        access_level = ::Types::MemberAccessLevelEnum.enum[id.downcase]
        name = ::Gitlab::Access.options_with_owner.key(access_level)

        { name: name } if name
      end
    end
    strong_memoize_attr :member_role
  end
end
