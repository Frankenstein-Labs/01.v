# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class SystemDashboardPolicy < BasePolicy
      rule { ~anonymous }.enable :read_system_dashboard
    end
  end
end
