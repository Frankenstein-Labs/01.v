# frozen_string_literal: true

module DuoChatPanel
  class AccessDeniedComponent < ViewComponent::Base
    include DuoChatPanel::LegacyCallout

    def initialize(container:, user:)
      @container = container
      @user = user
    end

    private

    attr_reader :container, :user

    def data
      {
        access_denied: true.to_s,
        container_type: container.type,
        auto_expand: auto_expanded?(user).to_s
      }.compact
    end
  end
end
