# frozen_string_literal: true

class Groups::Security::DashboardController < Groups::ApplicationController
  include GovernUsageGroupTracking

  layout 'group'

  feature_category :vulnerability_management
  urgency :low
  track_govern_activity 'security_dashboard', :show
  track_internal_event :show, name: 'visit_upgraded_security_dashboard', category: name,
    conditions: -> { upgraded_dashboard_available? }
  track_internal_event :show, name: 'visit_security_dashboard', category: name,
    conditions: -> { !upgraded_dashboard_available? }
  before_action :authorize_read_group_security_dashboard!
  before_action only: :show do
    push_frontend_feature_flag(:security_dashboard_agentic_adoption, group)
    push_frontend_ability(ability: :access_advanced_vulnerability_management, resource: group, user: current_user)
  end

  private

  def upgraded_dashboard_available?
    can?(current_user, :access_advanced_vulnerability_management, group)
  end
end
