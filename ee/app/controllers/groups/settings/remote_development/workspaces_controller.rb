# frozen_string_literal: true

module Groups
  module Settings
    module RemoteDevelopment
      class WorkspacesController < Groups::ApplicationController
        layout 'group_settings'

        before_action :authorize_remote_development!

        feature_category :workspaces
        urgency :low

        def show; end

        private

        def authorize_remote_development!
          render_404 unless can?(current_user, :access_workspaces_feature)
        end
      end
    end
  end
end
