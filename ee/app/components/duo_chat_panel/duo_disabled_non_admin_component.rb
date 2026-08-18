# frozen_string_literal: true

module DuoChatPanel
  class DuoDisabledNonAdminComponent < ViewComponent::Base
    include DuoChatPanel::PanelAutoExpand

    def initialize(container:, user:)
      @container = container
      @user = user
    end

    private

    attr_reader :container, :user

    def data
      {
        is_duo_disabled_non_admin: 'true',
        # Force agentic_available to true so the router uses the agentic chat component,
        # which has the isDuoDisabledNonAdmin empty state UI
        agentic_available: 'true',
        auto_expand: should_auto_expand_panel?(user, 'duo_panel_auto_expanded').to_s,
        container_type: container.type,
        namespace_id: container.namespace_id,
        project_id: container.project_id
      }.compact
    end
  end
end
