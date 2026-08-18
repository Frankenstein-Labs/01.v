# frozen_string_literal: true

module Groups
  class HookLogsController < Groups::ApplicationController
    before_action :authorize_admin_hook!

    include ::WebHooks::HookLogActions

    layout 'group_settings'

    private

    def hook
      @hook ||= @group.hooks.find(params[:hook_id])
    end

    def after_retry_redirect_path
      edit_group_hook_path(@group, hook)
    end

    def authorize_admin_hook!
      render_404 unless can?(current_user, :admin_web_hook, group)
    end
  end
end
