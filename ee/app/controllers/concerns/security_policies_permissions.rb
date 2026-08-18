# frozen_string_literal: true

module SecurityPoliciesPermissions
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :ensure_feature_is_available!
  end

  private

  def ensure_feature_is_available!
    render_404 unless ::Security::PolicyAvailability.any_available?(container)
  end

  def authorize_action!(action)
    return if can?(current_user, action, container)

    access_denied!(
      _('You need the Developer, Maintainer or Owner role in the project or group ' \
        'and in the security policy project.'), 403
    )
  end
end
